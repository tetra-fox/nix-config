# resolver policy shared by every site's dns facts file (mesa-dns.nix, fairlane-dns.nix): the RPZ
# blocklists and the split-horizon zone assembly. the zone is built identically for every site --
# nsIp is the host's own address, edgeVip and the per-host A records come from the topology engine,
# and both the zone name and the zone file derive from lab.site.domain -- so only the genuinely
# per-site parts (fairlane's dual-stack knobs) stay in the site file.
{
  config,
  pkgs,
  topo,
  ...
}: {
  lab.bind = {
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
      file = pkgs.replaceVars (./files + "/${config.lab.site.domain}.zone.in") {
        nsIp = config.lab.site.hostIp;
        edgeVip = topo.edgeEndpointIp;
        hostRecords = topo.hostRecords;
      };
    };
  };
}
