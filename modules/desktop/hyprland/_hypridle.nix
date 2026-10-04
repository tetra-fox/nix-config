{
  lib,
  pkgs,
  osConfig,
  ...
}: let
  idle-dim = lib.getExe (pkgs.writeShellApplication {
    name = "idle-dim";
    runtimeInputs = [pkgs.brightnessctl pkgs.util-linux]; # util-linux for flock
    text = builtins.readFile ./_idle-dim.sh;
  });
  hyprctl = lib.getExe' osConfig.programs.hyprland.package "hyprctl";
in {
  # no lock_cmd on purpose: idling only dims and blanks the displays, any input
  # brings them back without a lockscreen
  services.hypridle = {
    enable = true;
    # default is graphical-session.target, which plasma reaches too
    systemdTarget = "wayland-session@hyprland.desktop.target";
    settings.listener = [
      {
        timeout = 300;
        on-timeout = "${idle-dim} dim 33";
        on-resume = "${idle-dim} restore";
      }
      {
        timeout = 900;
        # restore while the monitors are still awake: ddc/ci writes get no reply, and a
        # monitor asleep or waking drops them silently. it keeps the level through standby
        on-timeout = "${idle-dim} restore; ${hyprctl} dispatch 'hl.dsp.dpms({ action = \"off\" })'";
        on-resume = "${hyprctl} dispatch 'hl.dsp.dpms({ action = \"on\" })'";
      }
    ];
  };
}
