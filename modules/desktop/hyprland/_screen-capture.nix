{pkgs, ...}: {
  programs.hyprshot.enable = true;

  home.packages = with pkgs; [
    wf-recorder
    slurp
  ];

  wayland.windowManager.hyprland.extraLuaFiles."screen-capture" = ./_screen-capture.lua;
}
