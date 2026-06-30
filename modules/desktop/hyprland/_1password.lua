hl.bind("CTRL + SHIFT + SPACE", hl.dsp.exec_cmd("1password --quick-access"))
-- hl.bind("CTRL + BACKSLASH", hl.dsp.exec_cmd("1password --fill")) this may work someday.....

hl.window_rule({
  match = { title = "Quick Access — 1Password" },
  stay_focused = true,
})

hl.on("hyprland.start", function()
  hl.exec_cmd("app2unit -- 1password --silent")
end)
