hl.bind("CTRL + SHIFT + SPACE", hl.dsp.exec_cmd("@onepassword@ --quick-access"))

hl.window_rule({
  match = { title = "Quick Access — 1Password" },
  stay_focused = true,
})
