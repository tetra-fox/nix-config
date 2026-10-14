local mod = "@main_mod@"

hl.bind(mod .. " + GRAVE", hl.dsp.exec_cmd("@app2unit@ -- @terminal@"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd("@app2unit@ -- @file_manager@"))
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd("@menu@"))
hl.bind(mod .. " + C", hl.dsp.exec_cmd("@hyprpicker@ -a"))

-- floats the window under the cursor, not the focused one. the lua api has no
-- window-at-cursor query, so hit-test: floating is above tiled, and a lower
-- focus_history_id is more recently focused, which tracks raise order
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

for i = 1, 9 do
  hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }))
  hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
