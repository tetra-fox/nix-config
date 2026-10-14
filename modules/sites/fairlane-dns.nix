{modules, ...}: {
  imports = [modules.services.bind.system ./_dns-common.nix];

  lab.bind = {
    # real dual-stack WAN. -4 would refuse every v6 socket, the v6 VIP included
    dualStack = true;

    # the default trustedRanges is v4-only, so v6 clients would get REFUSED
    extraTrustedRanges = [
      "fd00::/8" # LAN ULAs (the resolver VIP + v6 clients)
      "fe80::/10" # v6 link-local
    ];

    # the v4 vip is in hosts/common/dns-host.nix
    ha.vip6 = "fd00:10::53";
  };
}
