# resolver policy shared by every site's dns facts file (mesa-dns.nix, fairlane-dns.nix): the RPZ
# blocklists and the split-horizon zone assembly. the zone is built identically for every site --
# nsIp is the host's own address, edgeVip and the per-host A records come from the topology engine,
# and both the zone name and the zone file derive from lab.site.domain -- so only the genuinely
# per-site parts (fairlane's dual-stack knobs) stay in the site file.
{
  config,
  lib,
  pkgs,
  topo,
  ...
}: {
  # declared here, not in the bind module: this is a template input for the zone assembly
  # below, which is site policy; bind itself only ever sees the finished zone file
  options.lab.bind.zone.extraRecords = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = "site-specific records appended to the generated zone (e.g. mesa's unifi A record)";
  };

  config.lab.bind = {
    rpzLists = [
      {
        name = "oisd.rpz";
        url = "https://big.oisd.nl/rpz";
        format = "rpz";
      }
      {
        name = "vrchat.rpz";
        url = "https://raw.githubusercontent.com/louisa-uno/VRChatAnalyticsBlocklist/main/hosts.txt";
        format = "hosts";
      }
    ];

    zone = {
      name = config.lab.site.domain;
      # one template for every site; only the substituted facts differ
      file = pkgs.replaceVars ./files/site.zone.in {
        domain = config.lab.site.domain;
        nsIp = config.lab.site.hostIp;
        edgeVip = topo.edgeEndpointIp;
        extraRecords = config.lab.bind.zone.extraRecords;
        inherit (topo) hostRecords;
      };
    };
  };
}
