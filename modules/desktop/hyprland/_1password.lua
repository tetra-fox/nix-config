hl.bind("CTRL + SHIFT + SPACE", hl.dsp.exec_cmd("@onepassword@ --quick-access"))
-- hl.bind("CTRL + BACKSLASH", hl.dsp.exec_cmd("@onepassword@ --fill")) this may work someday.....

hl.window_rule({
  match = { title = "Quick Access — 1Password" },
  stay_focused = true,
})
