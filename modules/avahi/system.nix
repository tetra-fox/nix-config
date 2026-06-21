{
  config,
  lib,
  ...
}: let
  cfg = config.lab.avahi;
in {
  options.lab.avahi.publish = lib.mkEnableOption "announcing this host's name and services over mDNS";

  config.services.avahi = {
    enable = true;
    openFirewall = true;
    nssmdns4 = true;
    publish = lib.mkIf cfg.publish {
      enable = true;
      addresses = true;
      workstation = true;
      domain = true;
      hinfo = true;
      userServices = true;
    };
  };
}
