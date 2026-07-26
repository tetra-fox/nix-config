# the db HA claim, exercised for real: three nodes from the actual postgres-ha module
# (etcd + patroni + haproxy + keepalived), a client resolving the cluster through the
# capability engine. bootstraps the cluster, writes through the VIP, hard-crashes the
# leader, and asserts a replica promotes, the VIP follows, and the data survived. also
# pins the admin.enable-on-HA regression (the role must exist on the cluster).
{
  modules,
  fleet,
  caps,
}: let
  hostNames = {
    db1 = "testsite-db-01";
    db2 = "testsite-db-02";
    db3 = "testsite-db-03";
    svc = "testsite-svc-01";
  };
  fleetNode = import ./fleet-node.nix {inherit hostNames;};

  vip = "192.168.2.115";

  # nixpkgs' patroni module derives restapi.listen from nodeIp, so the rest api binds the
  # node's internal ip and never loopback; the leader probe has to address nodes by ip
  dbIps = {
    db1 = "192.168.2.11";
    db2 = "192.168.2.12";
    db3 = "192.168.2.13";
  };
  patroniRestPort = 8008;

  site = {
    domain = "testsite.test";
    dataDir = "/var/lib/testsite";
    serverInterface = "eth1";
    internalInterface = "eth1";
    internalCidr = "192.168.2.0/24";
  };

  mkDb = hostname: internalIp: {pkgs, ...}: {
    imports = [fleetNode modules.services.postgres-ha.system];

    networking.hostName = hostname;
    lab.site = site // {inherit internalIp;};

    lab.postgres = {
      ha = {
        enable = true;
        inherit vip;
      };
      # regression pin: admin.enable must reconcile a role on HA nodes (it used to be
      # silently inert there, mapped only in the single-server module)
      admin.enable = true;
      roles.app = {
        passwordSecret = "postgres/app_pass";
        owns = ["app"];
      };
    };

    # for the leader probe in the test script
    environment.systemPackages = [pkgs.curl];

    # etcd + patroni + postgres + haproxy in one VM; the 1G default OOMs during initdb
    virtualisation.memorySize = 1536;
  };
in {
  name = "db-failover";

  node.specialArgs = {inherit modules fleet caps;};

  nodes = {
    db1 = mkDb "testsite-db-01" dbIps.db1;
    db2 = mkDb "testsite-db-02" dbIps.db2;
    db3 = mkDb "testsite-db-03" dbIps.db3;

    # a fleet client: client.enable feeds its /32 into the cluster's pg_hba through the
    # topology derive, the same path the arr/authentik hosts use in production
    svc = {pkgs, ...}: {
      imports = [fleetNode modules.services.postgres.options];
      networking.hostName = "testsite-svc-01";
      lab.site = site // {internalIp = "192.168.2.20";};
      lab.postgres.client.enable = true;
      environment.systemPackages = [pkgs.postgresql_17];
    };
  };

  testScript = ''
    dbs = [db1, db2, db3]
    rest = {db1: "${dbIps.db1}", db2: "${dbIps.db2}", db3: "${dbIps.db3}"}

    def psql(sql, user="app", db="app"):
        return f"PGPASSWORD=mockpass psql -h ${vip} -U {user} -d {db} -tAc \"{sql}\""

    def probe(m, endpoint):
        return f"curl -sf http://{rest[m]}:${toString patroniRestPort}/{endpoint} >/dev/null"

    def leader(candidates):
        for m in candidates:
            if m.execute(probe(m, "primary"))[0] == 0:
                return m
        return None

    start_all()

    for m in dbs:
        m.wait_for_unit("etcd.service")
        m.wait_for_unit("patroni.service")

    with subtest("the cluster bootstraps and the vip serves writes"):
        svc.wait_until_succeeds(psql("SELECT 1"), timeout=600)
        svc.succeed(psql("CREATE TABLE t (v text)"))
        svc.succeed(psql("INSERT INTO t VALUES ('before-failover')"))

    with subtest("admin.enable reconciled a superuser role on the cluster"):
        svc.wait_until_succeeds(psql("SELECT 1", user="admin", db="postgres"), timeout=120)

    with subtest("crashing the leader promotes a replica and the vip follows"):
        old = leader(dbs)
        assert old is not None, "no node answers /primary"
        survivors = [m for m in dbs if m != old]
        # the leader answers /primary as soon as it holds the lock, well before the replicas
        # finish seeding from it with pg_basebackup. crashing it mid-copy strands them at
        # "not healthy enough for leader race" forever, so gate on both streaming first.
        for m in survivors:
            m.wait_until_succeeds(probe(m, "replica"), timeout=300)
        old.crash()
        svc.wait_until_succeeds(psql("INSERT INTO t VALUES ('after-failover')"), timeout=300)
        count = svc.succeed(psql("SELECT count(*) FROM t")).strip()
        assert count == "2", f"expected both rows after failover, got {count}"
        new = leader(survivors)
        assert new is not None and new != old, "no surviving node promoted"
  '';
}
