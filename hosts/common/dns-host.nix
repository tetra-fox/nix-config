# zone data lives in modules.sites.<site>-dns
{
  lib,
  modules,
  ...
}: {
  imports = [modules.profiles.server.system];

  # the router forwards to us, resolving through it would loop
  networking.nameservers = lib.mkForce ["127.0.0.1"];

  lab.bind = {
    enable = true;
    ha = {
      enable = true;
      vip = "192.168.10.53";
    };
  };

  system.stateVersion = "26.11";
}
