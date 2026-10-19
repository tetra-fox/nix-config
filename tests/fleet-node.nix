# hostNames maps python-safe node attrs to fleet hostnames, so the engine sees the nodes as a fleet
{hostNames}: {
  config,
  lib,
  modules,
  nodes,
  ...
}: {
  imports = [
    modules.platform.fleet.system
    ./mock-sops.nix
  ];

  config = {
    # extraInputRules only exists in the nftables backend. on iptables the route firewall
    # and vrrp rules eval fine and never reach the ruleset
    networking.nftables.enable = true;
    # matches sites/_common.nix, keepalived's vip has to hold up under networkd
    networking.useNetworkd = true;

    # production gets this from inputs.self.nixosConfigurations
    _module.args.nixosConfigurations =
      lib.mapAttrs' (attr: hostname: lib.nameValuePair hostname {config = nodes.${attr};})
      hostNames;

    # sites/_common.nix's addressing, minus mtu and gateway
    networking.interfaces.eth1.ipv4.addresses =
      map (address: {
        inherit address;
        prefixLength = 24;
      })
      (lib.filter (a: a != null) (lib.unique [config.lab.site.hostIp config.lab.site.internalIp]));

    systemd.tmpfiles.rules = lib.mkIf (config.lab.site.dataDir != null) [
      "d ${config.lab.site.dataDir} 0755 root ${config.lab.site.dataDirGroup} -"
    ];
  };
}
