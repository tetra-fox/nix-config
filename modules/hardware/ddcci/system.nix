{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.lab.ddcci;

  attach = pkgs.writeShellApplication {
    name = "ddcci-attach";
    runtimeInputs = [pkgs.i2c-tools pkgs.coreutils]; # i2ctransfer for the 0x50 EDID probe, timeout/sleep around it
    text = builtins.readFile ./ddcci-attach.sh;
  };
in {
  options.lab.ddcci.forceProbe = lib.mkEnableOption ''
    forcing the ddcci attach on nvidia, which won't auto-bind. leave off on
    intel/amd
  '';

  config = {
    # /dev/i2c-* nodes plus the i2c group and udev access
    hardware.i2c.enable = true;

    # registers each DDC/CI monitor as /sys/class/backlight/ddcci*
    boot.extraModulePackages = [config.boot.kernelPackages.ddcci-driver];
    boot.kernelModules = ["ddcci_backlight"];

    # its udev rule makes the backlight node video-group-writable, so a user in
    # video sets brightness without root
    environment.systemPackages = [pkgs.brightnessctl];
    services.udev.packages = [pkgs.brightnessctl];

    # nvidia doesn't auto-attach ddcci_backlight, so bind on drm hotplug (fires
    # on boot mode-set, plug/unplug, and resume) once the monitor is awake
    services.udev.extraRules = lib.mkIf cfg.forceProbe ''
      SUBSYSTEM=="drm", ACTION=="change", ENV{HOTPLUG}=="1", TAG+="systemd", ENV{SYSTEMD_WANTS}+="ddcci-attach.service"
    '';

    systemd.services.ddcci-attach = lib.mkIf cfg.forceProbe {
      description = "bind ddcci to each nvidia i2c bus that answers DDC/CI";
      # boot run alongside the hotplug rule. after (not before) multi-user.target,
      # auto-added Before cleared, so it never holds up login
      wantedBy = ["multi-user.target"];
      after = ["multi-user.target"];
      before = lib.mkForce [];
      # a hotplug flood fires many starts; don't let the burst trip the limit
      startLimitIntervalSec = 0;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe attach;
      };
    };
  };
}
