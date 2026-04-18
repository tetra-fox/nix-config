{ ... }:

{
  wayland.windowManager.hyprland.settings = {
    bind = [
      "L_Control&L_Shift,SPACE,exec,app2unit --1password --quick-access"
      "L_Control,BACKSLASH,exec,app2unit --1password --fill"
    ];

    exec-once = [ "app2unit --1password --silent" ];
  };
}
