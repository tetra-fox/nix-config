local mod = "@main_mod@"

hl.bind(mod .. " + GRAVE", hl.dsp.exec_cmd("@app2unit@ -- @terminal@"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd("@app2unit@ -- @file_manager@"))
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd("@menu@"))
hl.bind(mod .. " + C", hl.dsp.exec_cmd("@hyprpicker@ -a"))

-- float the window under the cursor instead of the focused one, so a window
-- on another monitor can be floated without focusing it first. the lua api
-- has no window-at-cursor query (only get_monitor_at_cursor), so hit-test
-- cursor against window geometry: floating renders above tiled, and lower
-- focus_history_id means more recently focused which tracks raise order.
-- TODO: replace the hit-test if hyprland grows a window-at-cursor query
local function window_under_cursor()
  local pos = hl.get_cursor_pos()
  if not pos then return nil end
  local best
  for _, w in ipairs(hl.get_windows({ mapped = true })) do
    if w.visible then
      local at, size = w.at, w.size
      if pos.x >= at.x and pos.x < at.x + size.x and pos.y >= at.y and pos.y < at.y + size.y then
        if not best
          or (w.floating and not best.floating)
          or (w.floating == best.floating and w.focus_history_id < best.focus_history_id) then
          best = w
        end
      end
    end
  end
  return best
end

hl.bind(mod .. " + mouse:274", function()
  local w = window_under_cursor()
  if w then
    hl.dispatch(hl.dsp.window.float({ action = "toggle", window = w }))
  end
end)

hl.bind(mod .. " + Q", hl.dsp.window.close())

-- super+[1-9] switch workspace, super+shift+[1-9] move active window to workspace
for i = 1, 9 do
  hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }))
  hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
