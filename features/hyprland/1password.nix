{ ... }:

{
  wayland.windowManager.hyprland.settings = {
    bind = [
      "L_Control&L_Shift,SPACE,exec,1password --quick-access"
      "L_Control,BACKSLASH,exec,1password --fill"
    ];

    exec-once = [ "1password --silent" ];
  };
}
