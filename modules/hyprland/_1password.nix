{...}: {
  wayland.windowManager.hyprland.settings = {
    bind = [
      "L_Control&L_Shift,SPACE,exec,1password --quick-access"
      # "L_Control,BACKSLASH,exec,1password --fill" this may work someday.....
    ];

    windowrule = ["match:title Quick Access — 1Password, stay_focused on"];

    exec-once = ["app2unit -- 1password --silent"];
  };
}
