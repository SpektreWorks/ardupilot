local PARAM_TABLE_KEY = 122

-- create custom parameter set
local function add_params(key, prefix, tbl)
    assert(param:add_table(key, prefix, #tbl), string.format('Could not add %s param table.', prefix))
    for num = 1, #tbl do
        assert(param:add_param(key, num,  tbl[num][1], tbl[num][2]), string.format('Could not add %s%s.', prefix, tbl[num][1]))
    end
end

-- edit this function call to suit your use case
add_params(PARAM_TABLE_KEY, 'FENCE', {
        { '_CIRCLE_KM',  0 },
        { '_ALTITUDE_M', 0 },
        { '_ALTITUDE_F', 1 },
    })

local fence_radius = Parameter()
fence_radius:init('FENCE_CIRCLE_KM')
local fence_altitude = Parameter()
fence_altitude:init('FENCE_ALTITUDE_M')
local fence_frame = Parameter()
fence_frame:init('FENCE_ALTITUDE_F')

function test_breaches()
  if vehicle:get_mode() == 11 then
    -- in rally, nothing to do
    return
  end

  local pos = ahrs:get_location()
  if pos == nil then
    -- no valid position
    return
  end

  local radius = fence_radius:get()
  if radius > 0 then
    -- radius is valid lets see if we breached it
    if pos:get_distance(ahrs:get_home()) >= radius * 1000 then
      if vehicle:set_mode(11) then
        gcs:send_text(4, "Aircraft has breached the cirular geofence")
      end
    end
  end

  local altitude = fence_altitude:get()
  local target_frame = fence_frame:get()
  if altitude > 0 and target_frame >= 0 and target_frame <= 3 then
    if pos:change_alt_frame (target_frame) then
      -- altitude is now relative to home
      if pos:alt() > altitude * 100 then
        if vehicle:set_mode(11) then
          gcs:send_text(4, "Aircraft has breached the high altitude geofence")
        end
      end
    end
  end
end

function update()
  test_breaches()

  return update, 1000 -- run at 2Hz
end

return update(), 150 -- slighly offset the script
