{ pkgs, ... }:

{
  # requires `features.openrgb` enabled on the host
  services.hardware.openrgb.motherboard = "amd";

  systemd.services.suspend-hook = {
    description = "pre/post suspend hook";
    wantedBy = [ "sleep.target" ];
    before = [ "sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      ExecStart = "${pkgs.coreutils}/bin/echo pre-suspend";
      ExecStop = "${pkgs.coreutils}/bin/echo post-suspend";
    };
  };
}
