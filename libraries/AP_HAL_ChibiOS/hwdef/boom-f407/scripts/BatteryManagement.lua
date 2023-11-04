-- Script for the automatic control of battery heater and charger via GPIO

local function hysteresis_controller(pin, param_prefix, param_key, default_target, default_hysteresis, default_low_cutoff)
  local self = {}

  -- Set pin as outputs and turn off
  gpio:pinMode(pin, 1)
  gpio:write(pin, 0)

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

  function self.off()
    active = false
    gpio:write(pin, 0)
  end

  function self.update(measured)
    if (measured == nil) or (measured < low_cutoff:get()) then
      self.off()
      return false
    end

    if measured < (target:get() - math.max(hysteresis:get(), 0.1)) then
      -- Under hysteresis threshold, always active
      active = true

    elseif measured > target:get() then
      -- relaxing from target down to hysteresis threshold
      active = false

    end

    if active then
      gpio:write(pin, 1)
    else
      gpio:write(pin, 0)
    end

    return active
  end

  return self
end

-- Battery monitor instance
local BATT_INST = 0

-- Controllers
local charge_control = hysteresis_controller(3, "CHARGE", 1, 58, 0.1,  0)
local heater_control = hysteresis_controller(5, "HEAT",   2, 30, 5, -10)

function update()

  local voltage = battery:voltage(BATT_INST)
  local temp = battery:get_temperature(BATT_INST)

  if charge_control.update(voltage) then
    -- Charger on and heater off
    heater_control.off()

  else
    -- Charger off and auto heater
    heater_control.update(temp)

  end

end

function protected_wrapper()
  local success, ret = pcall(update)
  if not success then
     print("SCR Error: " .. ret)
     return protected_wrapper, 2000
  end
  return protected_wrapper, 100
end

return protected_wrapper()
