# records, not bare strings, so a typo is a missing-attribute eval error instead of a null lookup.
# vipPath is the option path the service declares its floating VIP at
{
  monitoring = {name = "monitoring";};
  authServer = {name = "auth-server";};
  # the LDAP outpost endpoint; advertised for discovery, no nix consumer yet
  authLdap = {name = "auth-ldap";};
  media = {name = "media";};
  storage = {name = "storage";};
  immich = {name = "immich";};
  arr = {name = "arr";};

  dbServer = {name = "db-server";};
  dbClient = {name = "db-client";};
  dbHaNode = {
    name = "db-ha-node";
    vipPath = ["lab" "postgres" "ha" "vip"];
  };
  edge = {
    name = "edge";
    vipPath = ["lab" "caddy" "ha" "vip"];
  };
  # clients get the resolver from DHCP; the vipPath consumer is blackbox's dns probe
  dns = {
    name = "dns";
    vipPath = ["lab" "bind" "ha" "vip"];
  };
}
