{ ... }:

{
  programs.hyprshot.enable = true;

  wayland.windowManager.hyprland.settings.bind = [
    "L_Control&L_Shift,3,exec,hyprshot -m output -m active -z --clipboard-only"
    "L_Control&L_Shift,4,exec,hyprshot -m region -z --clipboard-only"
  ];
}
