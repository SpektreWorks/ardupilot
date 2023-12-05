-- Copyright SpektreWorks
-- battery heater management script
local function hysteresis_controller(param_prefix, param_key, default_target, default_hysteresis, default_low_cutoff)
  local self = {}

  -- Add params
  param_prefix = param_prefix .. "_"
  assert(param:add_table(param_key, param_prefix, 3))

  assert(param:add_param(param_key, 1, "TARGET",  default_target))
  assert(param:add_param(param_key, 2, "HYSTER",  default_hysteresis))
  assert(param:add_param(param_key, 3, "LOW_CUT", default_low_cutoff))

  local target =     Parameter(param_prefix .. "TARGET")
  local hysteresis = Parameter(param_prefix .. "HYSTER")
  local low_cutoff = Parameter(param_prefix .. "LOW_CUT")

  local active = false
  local low_cutoff_active = false

  function self.update(measured)
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

  return self
end

-- Battery monitor instance
local BATT_INST = 0

-- setup the initial pin states
local charge_pin = 3
local heater_pin = 5
gpio:pinMode (charge_pin, 1)
-- gpio:write (charge_pin, 0)
gpio:pinMode (heater_pin, 1)
gpio:write (heater_pin, 0)

-- Controllers
local charge_control = hysteresis_controller("CHARGE", 1, 58, 0.1,  0)
local heater_control = hysteresis_controller("HEAT",   2, 30, 5, -10)

local state = {}
state.is_charging = false
state.is_heating = false
state.timer = uint32_t(0)

local function start_charge ()
  gpio:write (charge_pin, 1)
  state.timer = millis ()
  state.is_charging = true
end

local function start_heat ()
  gpio:write (heater_pin, 1)
  state.is_heating = true
end

local function stop_heat ()
  gpio:write (heater_pin, 0)
  state.is_heating  = false
end

local function stop_all ()
  assert (false, "should not be called")
  gpio:write (charge_pin, 0)
  gpio:write (heater_pin, 0)
  state.is_charging = false
  state.is_heating  = false
end

local charge_limit = uint32_t (2*60*1000) -- in milliseconds
local heater_limit = charge_limit + uint32_t (1*60*1000) -- this is a weird approach but the actual on time here
                                                         -- is the difference between this and the previous timer

function update()
  local voltage = battery:voltage(BATT_INST)
  local temp = battery:get_temperature(BATT_INST)

  local should_charge = charge_control.update(voltage)
  local should_heat   = heater_control.update(temp)

  if should_heat then
      start_heat ()
  else
      stop_heat ()
  end

  -- if should_charge and should_heat then
  --   -- we want to run both functions, but do not have enough battery power
  --   -- so we have to make a tradeoff here if we want to run both then just
  --   -- commit to 80% charge, 20% heat, over a 5 minute course.
  --   local now = millis ()

  --   local delta = now - state.timer
  --   if (now - state.timer) > charge_limit then
  --     should_charge = false
  --   end
  --   if (now - state.timer) > heater_limit then
  --     should_heat = false
  --     state.timer = millis ()
  --   end
  --   if (not should_charge and not should_heat) then
  --       -- we turned off both charger and heater as they exceeded their time budgets
  --       -- clear the budgets, and start charging again
  --       should_charge = true
  --   end
  -- end

  -- -- finally if the heater is off we want to target the charger being on
  -- should_charge = should_charge or not should_heat

  -- if not state.is_charging and not state.is_heating then
  --   -- not charging or heating, pick the optimal state
  --   if should_charge then
  --     start_charge ()
  --   else
  --     start_heat ()
  --   end
  -- elseif should_charge then
  --   if not state.is_charging then
  --     stop_all ()
  --   end
  -- elseif should_heat then
  --   if not state.is_heating then 
  --     stop_all ()
  --   end
  -- end

end

function protected_wrapper()
  local success, ret = pcall(update)
  if not success then
     print("SCR Error: " .. ret)
     return protected_wrapper, 2000
  end
  -- limit the update rate to allow the heater to fully poweroff before turning the charger on
  return protected_wrapper, 1000
end

return protected_wrapper()
