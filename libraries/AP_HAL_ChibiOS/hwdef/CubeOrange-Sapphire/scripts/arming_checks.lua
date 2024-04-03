-- copyright SpektreWorks Inc
local PARAM_TABLE_KEY = 74
local PARAM_TABLE_PREFIX = "ARM"

assert(param:add_table(PARAM_TABLE_KEY, PARAM_TABLE_PREFIX, 3), 'could not add param table')

-- add a parameter and bind it to a variable
function bind_add_param(name, idx, default_value)
  assert(param:add_param(PARAM_TABLE_KEY, idx, name, default_value), string.format('could not add param %s', name))
  local p = Parameter()
  assert(p:init(PARAM_TABLE_PREFIX .. name), string.format('could not find %s parameter', name))
  return p
end

local batt_temp_min = bind_add_param("_BAT_TEMP_MIN", 1, 25)
local batt_temp_max = bind_add_param("_BAT_TEMP_MAX", 2, 50)
local batt_temp_mask = bind_add_param("_BAT_TEMP_MSK", 3, 6)

local auth_id = arming:get_aux_auth_id()

function update()
  if auth_id then
    local all_passing = true
    -- battery temp checks
    local batt_mask = batt_temp_mask:get()
    local temp_min = batt_temp_min:get()
    local temp_max = batt_temp_max:get()
    for i=0,10 do
      if (batt_mask & (1 << i)) > 0 then
        batt_temp = battery:get_temperature(i)
        if not batt_temp then
          arming:set_aux_auth_failed(auth_id, "Could not retrieve battery" .. i + 1 .. " temperature")
          all_passing = false
          break
        elseif (batt_temp > temp_max) then
          arming:set_aux_auth_failed(auth_id, string.format("Battery %d temp too high (%.1f > %.0f C)", i + 1, batt_temp, temp_max))
          all_passing = false
          break
        elseif (batt_temp < temp_min) then
          arming:set_aux_auth_failed(auth_id, string.format("Battery %d temp too low (%.1f < %.0f C)", i + 1, batt_temp, temp_min))
          all_passing = false
          break
        end
      end
    end

    -- if everything passed then we're happy
    if all_passing then
      arming:set_aux_auth_passed(auth_id)
    end
  end
  return update, 5000
end

return update()
