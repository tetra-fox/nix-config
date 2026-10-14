{
  config,
  lib,
  pkgs,
  topo,
  ...
}: {
  # zone assembly is site policy, bind only sees the finished zone file
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
