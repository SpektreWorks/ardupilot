local PARAM_TABLE_KEY = 117

-- create custom parameter set
local function add_params(key, prefix, tbl)
    assert(param:add_table(key, prefix, #tbl), string.format('Could not add %s param table.', prefix))
    for num = 1, #tbl do
        assert(param:add_param(key, num,  tbl[num][1], tbl[num][2]), string.format('Could not add %s%s.', prefix, tbl[num][1]))
    end
end

-- edit this function call to suit your use case
add_params(PARAM_TABLE_KEY, 'FS_RALLY', {
        { '_TIMEOUT',        30*60 },
    })

local timeout = Parameter()
timeout:init('FS_RALLY_TIMEOUT')
local rally_start_time = nil

function update()
  if vehicle:get_mode() == 11 then
    -- we are in rally
    if rally_start_time == nil then
      -- we weren't tracking time, so start it
      rally_start_time = millis()
    else
      local timeout_v = timeout:get()
      if (timeout_v > 0) and (millis() - rally_start_time >= timeout_v*1000) then
        if mission:jump_to_landing_sequence() then
          -- only change to auto if we could pick a landing
          vehicle:set_mode(10) -- jump to auto
        else
          gcs:send_text(4, "Rally Failsafe: No landing sequence available")
          rally_start_time = nil
        end
      end
    end
  else
    rally_start_time = nil
  end

  return update, 500 -- run at 2Hz
end

return update()
