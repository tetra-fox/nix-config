hl.monitor({ output = "DP-1", mode = "preferred", position = "0x0", scale = @scale@ })
hl.monitor({ output = "DP-3", mode = "preferred", position = "auto-left", scale = @scale@ })
hl.monitor({ output = "HDMI-A-3", mode = "preferred", position = "auto-right", scale = @scale@ })

hl.on("hyprland.start", function()
  hl.exec_cmd("@xrdb@ -merge @xresources@")
end)
