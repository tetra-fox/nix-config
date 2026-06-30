local mod = "@main_mod@"

hl.bind(mod .. " + ESCAPE", hl.dsp.global("quickshell:lock"))
hl.bind(mod .. " + SHIFT + ESCAPE", hl.dsp.global("quickshell:logout"))
hl.bind("ALT + TAB", hl.dsp.global("quickshell:switcher-next"))
hl.bind("ALT + SHIFT + TAB", hl.dsp.global("quickshell:switcher-prev"))

for _, namespace in ipairs({
  "quickshell-bar",
  "quickshell-popup",
  "quickshell-notifications",
  "quickshell-switcher",
}) do
  hl.layer_rule({
    match = { namespace = namespace },
    blur = true,
    ignore_alpha = 0.1,
  })
end
