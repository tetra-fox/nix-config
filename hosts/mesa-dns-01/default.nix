{modules, ...}: {
  imports = [
    ../common/dns-host.nix
    modules.sites.mesa-dns
  ];

  lab.site = {
    hostIp = "192.168.10.160";
    internalIp = "10.10.0.160";
  };
}
