local PATTERN_INTERVAL = uint32_t(4 * 1000) -- 4 seconds between flashes

local STROBE_PULSE_LENGTH = 50
local STROBE_FLASHES = 3
local STROBE_DURATION = uint32_t ((STROBE_PULSE_LENGTH * 2) * STROBE_FLASHES)
local STROBE_IR_DURATION = uint32_t (STROBE_DURATION + ((STROBE_PULSE_LENGTH * 2) * STROBE_FLASHES))

local LIGHT_ON = 255
local LIGHT_OFF = 0

local PARAM_TABLE_KEY = 73
local PARAM_TABLE_PREFIX = "NTF_NAV_"

assert(param:add_table(PARAM_TABLE_KEY, PARAM_TABLE_PREFIX, 2), 'could not add param table')

-- add a parameter and bind it to a variable
function bind_add_param(name, idx, default_value)
  assert(param:add_param(PARAM_TABLE_KEY, idx, name, default_value), string.format('could not add param %s', name))
  local p = Parameter()
  assert(p:init(PARAM_TABLE_PREFIX .. name), string.format('could not find %s parameter', name))
  return p
end

local nav_vis_target = bind_add_param("VIS", 1, 0)
local nav_ir_target = bind_add_param("IR", 2, 0)
nav_vis_target:set(0) -- always default to disabled
nav_ir_target:set(0) -- always default to disabled

local PARAM_NAV_LIGHT = 1 << 0

local last_vis_value = 0
local last_ir_value = 0
local light_period_start = millis() -- time the current sequence began

function update_LEDs()
  local now = millis()

  local new_vis_light = nav_vis_target:get()
  local new_ir_light = nav_ir_target:get()
  do -- manage reseting the state if the user has changed their intentions
    if (last_vis_value ~= new_vis_light) or (last_ir_value ~= new_ir_light) then
     gcs:send_text(0, "resetting targets: ")

      last_vis_value = new_vis_light
      last_ir_value = new_ir_light
      light_period_start = now
    end
  end

  local delta = now - light_period_start

  -- reset the tracking to now if we are ready to loop
  if delta > PATTERN_INTERVAL then
    delta = 0
    light_period_start = now
  end

  -- these track if the respective LED's should be on or off, set them to off, then set the required ones on
  local should_strobe = LIGHT_OFF
  local should_nav    = LIGHT_OFF
  local should_ir     = LIGHT_OFF

  -- handle nav light and visual strobe calculation
  if (new_vis_light & PARAM_NAV_LIGHT) ~= 0 then
    if delta < STROBE_DURATION then
      if (delta % (STROBE_PULSE_LENGTH * 2)) < STROBE_PULSE_LENGTH then
        should_strobe = LIGHT_ON
      end
    else
      should_nav = LIGHT_ON
    end
  end

  -- handle ir strobe
  if (new_ir_light & PARAM_NAV_LIGHT) ~= 0 then
    if (delta > STROBE_DURATION) and (delta < STROBE_IR_DURATION) then
      if (delta % (STROBE_PULSE_LENGTH * 2)) < STROBE_PULSE_LENGTH then
        should_ir = LIGHT_ON
      end
    end
  end

  -- hardware channel assignment:
  --  blue  - IR strobe
  --  red   - White strobe
  --  green - Nav lights
  notify:handle_rgb(should_strobe, should_nav, should_ir, 0)

  return update_LEDs, 50 -- run at 20Hz
end

return update_LEDs()
