-- Copyright SpektreWorks
-- battery heater management script

local param_key = 110
local param_prefix = "VPS_"

assert(param:add_table(param_key, param_prefix, 3*2*2+2))

local function hysteresis_controller(param_name, battery_fn, battery_instance, pin, param_ofs, default_target, default_hysteresis, default_low_cutoff)
  local self = {}

  -- Add params
  assert(param:add_param(param_key, (3 * param_ofs) + 1,  param_name .. "TARGET", default_target))
  assert(param:add_param(param_key, (3 * param_ofs) + 2,  param_name .. "HYSTER", default_hysteresis))
  assert(param:add_param(param_key, (3 * param_ofs) + 3,  param_name .. "LOW_CT", default_low_cutoff))

  local target =     Parameter(param_prefix .. param_name .. "TARGET")
  local hysteresis = Parameter(param_prefix .. param_name .. "HYSTER")
  local low_cutoff = Parameter(param_prefix .. param_name .. "LOW_CT")

  local active = false
  local low_cutoff_active = false

  function self.update()
    local measured = battery_fn(battery, battery_instance)
    if (measured == nil) or (measured < low_cutoff:get()) then
      active = false
      low_cutoff_active = true
      return false
    end

    if low_cutoff_active == true then
      -- if we are coming out of the low cutoff delay a cycle before enabling
      low_cutoff_active = false
      return false
    end

    if measured < (target:get() - math.max(hysteresis:get(), 0.1)) then
      -- Under hysteresis threshold, always active
      active = true

    elseif measured > target:get() then
      -- relaxing from target down to hysteresis threshold
      active = false

    end

    return active
  end

  function self.on()
    relay:on(pin)
  end

  function self.off()
    relay:off(pin)
  end

  function self.was_on()
    return relay:get(pin) == 1
  end

  function self.below_cutoff()
    return low_cutoff_active
  end

  function self.desired_active()
    return active
  end

  return self
end

-- Controllers
local left_batt = 1
local right_batt = 2
local charger_left  = hysteresis_controller("L_CHG_", battery.voltage,         left_batt,   6, 0, 58, 0.1,   0)
local heater_left   = hysteresis_controller("L_HEA_", battery.get_temperature, left_batt,   8, 1, 30,   5, -10)
local charger_right = hysteresis_controller("R_CHG_", battery.voltage,         right_batt,  7, 2, 58, 0.1,   0)
local heater_right  = hysteresis_controller("R_HEA_", battery.get_temperature, right_batt,  9, 3, 30,   5, -10)

assert(param:add_param(param_key, (3*2*2)+1, "DEBUG", 0))
assert(param:add_param(param_key, (3*2*2)+2, "PAYLOAD_POWR", 0))
local debug = Parameter("VPS_DEBUG")
local payload_power = Parameter("VPS_PAYLOAD_POWR")
payload_power:set(0) -- turn it off it was on
local payload_pin = 2

local charge_limit = uint32_t (30*1000) -- in milliseconds
local heater_limit = charge_limit + uint32_t (30*1000) -- this is a weird approach but the actual on time here
                                                         -- is the difference between this and the previous timer
function payload_power_should_be_active()
  return payload_power:get() > 0
end

function run_boom_per_desires(charger, heater)
  local should_charge = charger.desired_active()
  local should_heat = heater.desired_active()

  -- if everything wants to run we need to make a decision about which to pick here
  if should_charge and should_heat then
    should_charge = (millis() % heater_limit) < charge_limit
    should_heat = not should_charge
  end

  -- ensure we always want to run *something*
  if should_charge == false and should_heat == false then
    should_charge = true
  end

  if should_charge then
      if heater.was_on() then
        heater.off()
      else
        charger.on()
      end
  else
      if charger.was_on() then
        charger.off()
      else
        heater.on()
      end
  end
end

function run_per_desire(controller)
  if controller.desired_active() then
    controller.on()
  else
    controller.off()
  end
end

function run_one_charger()
  -- we want to always run the left charger, make sure we can turn it on
  if (charger_left.was_on() and heater_left.was_on() and heater_right.was_on()) then
    heater_left.off()
    heater_right.off()
    -- we aren't ready to force the charger situation, bail out
    return
  else
    -- we shouldn't be at risk of overload, enable the left charger
    charger_right.on()
    charger_left.off()
  end

  -- run heaters as desired, no need to coordinate
  run_per_desire(heater_left)
  run_per_desire(heater_right)
end

function run_dual_charger()
  local should_heat_left = heater_left.desired_active()
  local should_heat_right = heater_right.desired_active()

  if not (heater_left.was_on() and heater_right.was_on()) then
    -- we were not running both heaters, so we can just kick both chargers on
    charger_left.on()
    charger_right.on()
  end

  -- can't run both heaters, pick one
  if should_heat_left and should_heat_right then
      -- FIXME: does not work to toggle
    should_charge_left = ((millis() / 60000) % 1) == 1
    should_charge_right = not should_charge_left
  end

  if should_heat_left then
    if not heater_right.was_on() then
      heater_left.on() -- delay until the right heater got to go off
    end
    heater_right.off()
  elseif should_heat_right then
    if not heater_left.was_on() then
      heater_right.on() -- delay until the right heater got to go off
    end
    heater_left.off()
  else
    heater_left.off()
    heater_right.off()
  end
end

function run_no_charger_required()
  run_boom_per_desires(charger_left, heater_left)
  run_boom_per_desires(charger_right, heater_right)
end

function run_no_batt_connected()
  charger_left.on()
  charger_right.on()
  run_per_desire(heater_left)
  run_per_desire(heater_right)
end

function run_no_payload_power()
  -- this is actually identical
  run_no_batt_connected()
end

function get_power_budget()
  if heater_left.below_cutoff() or heater_right.below_cutoff() then
    return run_no_batt_connected
  elseif not payload_power_should_be_active() then
    return run_no_payload_power
  elseif (arming:is_armed()) then -- armed VPS can be assumed to be on
    return run_no_charger_required
  elseif SRV_Channels:get_safety_state() == false then -- surfaces unlocked, need to have 2 chargers around
    return run_dual_charger
  else
    return run_one_charger
  end
end

local function budget_to_string (budget)
  if budget == run_no_batt_connected then
    return "no batt"
  end
  if budget == run_no_payload_power then
    return "no payload"
  end
  if budget == run_no_charger_required then
    return "independent boom"
  end
  if budget == run_one_charger then
    return "single charger forced"
  end
  if budget == run_dual_charger then
    return "dual charger forced"
  end
  assert (false)
end

function get_output_states()
  local out = 0
  if charger_left.was_on()  then out = out | 1 << 0 end
  if heater_left.was_on()   then out = out | 1 << 1 end
  if charger_right.was_on() then out = out | 1 << 2 end
  if heater_right.was_on()  then out = out | 1 << 3 end
  return out
end

function get_boom_debug (charger, heater)
  local value = ""
  if charger.was_on() then
    value = value .. "charging"
  end
  if heater.was_on() then
    if #value > 0 then
      value  = value .. " and "
    end
    value = value .. "heating"
  end

  -- we might not be doing anything while changing states
  if #value == 0 then
    value = "off"
  end

  return value
end

function emit_debug(output_states, budget)
  local debug_level = debug:get()
  if (debug_level > 0) -- we want to debug
      and ((output_states ~= get_output_states()) -- state changed ( assumed to be debug 1, but anything higher also counts
            or
            (debug_level > 1) -- 2 is debug once, 3 is always debug
            ) then
    gcs:send_text(3, "BMS: left " .. get_boom_debug (charger_left, heater_left) .. " right " .. get_boom_debug(charger_right, heater_right) .. " " .. budget_to_string(budget) .. " payload " .. tostring (relay:get(payload_pin) == 0))
    if debug_level == 2 then
      debug:set(0)
    end
  end
end

local payload_power_delay = false

function update_payload_power()
  -- need to toggle payload power
  if payload_power_should_be_active() then
    if payload_power_delay == false then
      -- because payload power turning on means we might need to turn some stuff off
      -- we want to delay a round before actually enabling power
      payload_power_delay = true
    else
      -- the power is inverted, so off is on
      relay:off(payload_pin)
    end
  else
    relay:on(payload_pin)
    payload_power_delay = false
  end
end

local controllers = {charger_left, charger_right, heater_left, heater_right}

function update()
  -- run all the controllers
  for i,v in ipairs(controllers) do
    v.update()
  end

  local output_states = get_output_states()
  local budget = get_power_budget()
  budget()

  update_payload_power()

  emit_debug(output_states, budget)
end

function protected_wrapper()
  local success, ret = pcall(update)
  if not success then
     gcs:send_text(0, "SCR Error: " .. ret)
     return protected_wrapper, 2000
  end
  -- limit the update rate to allow the heater to fully poweroff before turning the charger on
  return protected_wrapper, 500
end

return protected_wrapper()

