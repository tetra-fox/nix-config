local mod = "@main_mod@"

-- toggle: close the clipse window if one exists, otherwise open it
hl.bind(mod .. " + V", function()
  local w = hl.get_windows({ class = "clipse" })[1]
  if w then
    hl.dispatch(hl.dsp.window.kill({ window = w }))
  else
    hl.exec_cmd("@kitty@ --class clipse -e @clipse@")
  end
end)

hl.window_rule({
  match = { class = "clipse" },
  float = true,
  size = "622 652",
  pin = true,
})
