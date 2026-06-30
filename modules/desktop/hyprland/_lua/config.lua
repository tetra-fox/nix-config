hl.config({
  input = {
    kb_layout = "us",
    numlock_by_default = true,

    follow_mouse = 2,                -- scroll in unfocused windows
    float_switch_override_focus = 0, -- dont steal my shit
    sensitivity = -0.5,
  },

  general = {
    gaps_in = 4,
    -- top=1 since Bar already adds its own vertical padding,
    -- but 0 looks uneven because of window border_size
    gaps_out = { top = 1, right = 8, bottom = 8, left = 8 },

    border_size = 1,

    resize_on_border = false,

    allow_tearing = false,
  },

  decoration = {
    rounding = 4,
    rounding_power = 2,

    active_opacity = 1,
    inactive_opacity = 0.98,

    blur = {
      enabled = true,
      size = 8,
      passes = 1,
      brightness = 1.0,
      vibrancy = 1,
    },
  },

  animations = {
    enabled = true,
  },

  dwindle = {
    preserve_split = true,
  },

  master = {
    new_status = "master",
  },

  misc = {
    force_default_wallpaper = -1,
    disable_hyprland_logo = true,
    focus_on_activate = true,
    layers_hog_keyboard_focus = true,
  },

  xwayland = {
    force_zero_scaling = true,
  },
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })

hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })

hl.animation({ leaf = "windows", enabled = true, speed = 1.2, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 1.2, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.2, bezier = "linear", style = "popin 87%" })

hl.animation({ leaf = "fade", enabled = true, speed = 1, bezier = "quick" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })

hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 1.5, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })

hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
