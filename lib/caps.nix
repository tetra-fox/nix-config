# the mesa capability vocabulary: the named services hosts advertise (lab.topology.provides) and
# the consumer derives in topology.nix resolve. one record per capability so the string lives in
# exactly one place -- providers and consumers both read caps.<x>.name, and a typo is an eval error
# (missing attribute) rather than a silently-null lookup. HA caps also carry the vipPath their
# endpoint derive reads (the option path each service declares its floating VIP at).
#
# the generic engine (engine.nix) names none of this. keeping the vocabulary here, in the mesa
# policy layer, not in the engine, is what keeps the engine a reusable library (see fleet-test.nix).
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
  dns = {
    name = "dns";
    vipPath = ["lab" "bind" "ha" "vip"];
  };
}
