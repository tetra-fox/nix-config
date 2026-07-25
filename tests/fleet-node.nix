# the per-node harness for the VM tests: the same fleet-wide modules every production nixos
# host gets (the lab.site/lab.topology option contract, the topo module arg, the route
# firewall), a sops mock, and the adapter that lets the topology engine see the test's nodes
# as a fleet. hostNames maps node attr names (python-safe, no dashes) to fleet hostnames;
# each node sets networking.hostName to its fleet name so engine membership works unchanged.
{hostNames}: {
  config,
  lib,
  nodes,
  ...
}: {
  imports = [
    ../modules/sites/_options.nix
    ../modules/sites/_topology.nix
    ../modules/sites/_route-firewall.nix
    ./mock-sops.nix
  ];

  config = {
    # what production gets from inputs.self.nixosConfigurations: every fleet member's config,
    # keyed by hostname. the test framework's `nodes` carries each node's config already.
    _module.args.nixosConfigurations =
      lib.mapAttrs' (attr: hostname: lib.nameValuePair hostname {config = nodes.${attr};})
      hostNames;

    # what _common.nix does on a proxmox VM, minus the mtu/gateway facts that mean nothing
    # on the test wire: park the site addresses on the shared test vlan (eth1)
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
