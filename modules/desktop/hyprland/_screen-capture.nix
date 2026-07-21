{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.hyprshot.enable = true;

  home.packages = with pkgs; [
    wf-recorder
    slurp
  ];

  wayland.windowManager.hyprland.extraLuaFiles."screen-capture".content = pkgs.replaceVars ./_screen-capture.lua {
    hyprshot = lib.getExe config.programs.hyprshot.package;
    wfrecorder = lib.getExe pkgs.wf-recorder;
    slurp = lib.getExe pkgs.slurp;
  };
}
