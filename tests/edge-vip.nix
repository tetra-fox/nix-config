# the edge HA claim, exercised for real: two caddy nodes from the actual caddy module (vrrp
# included) fronting a route published by a third node through the topology engine. kills
# caddy on the VIP holder and asserts the chain the modules promise: pgrep track script ->
# FAULT -> keepalived releases -> the peer claims -> requests keep working. also pins
# noPreempt: a recovered node must not steal the VIP back.
{
  modules,
  fleet,
  caps,
}: let
  hostNames = {
    edge1 = "testsite-edge-01";
    edge2 = "testsite-edge-02";
    web = "testsite-web-01";
  };
  fleetNode = import ./fleet-node.nix {inherit hostNames;};

  vip = "192.168.2.100";
  route = "app.testsite.test";

  mkEdge = hostname: hostIp: {
    imports = [fleetNode modules.services.caddy.system];

    networking.hostName = hostname;

    lab.site = {
      domain = "testsite.test";
      dataDir = "/var/lib/testsite";
      serverInterface = "eth1";
      inherit hostIp;
    };

    lab.caddy = {
      ha = {
        enable = true;
        inherit vip;
      };
      # no internet in the test VM: certs from caddy's internal CA instead of dns-01
      certIssuer = ''
        {
        	local_certs
        }
      '';
    };
  };
in {
  name = "edge-vip-failover";

  node.specialArgs = {inherit modules fleet caps;};

  nodes = {
    edge1 = mkEdge "testsite-edge-01" "192.168.2.1";
    edge2 = mkEdge "testsite-edge-02" "192.168.2.2";

    # publishes a route the engine resolves into the edges' Caddyfiles; the route firewall
    # admits the edge hosts to 8080 without this node writing a rule
    web = {pkgs, ...}: {
      imports = [fleetNode];
      networking.hostName = "testsite-web-01";
      lab.site = {
        domain = "testsite.test";
        dataDir = "/var/lib/testsite";
        serverInterface = "eth1";
        hostIp = "192.168.2.3";
      };
      lab.topology.routes = [
        {
          host = route;
          port = 8080;
        }
      ];
      services.static-web-server = {
        enable = true;
        listen = "0.0.0.0:8080";
        root = pkgs.writeTextDir "index.html" "hello from testsite web";
      };
    };

    # hostname "client" has no site prefix, so the engine never counts it as a fleet member
    client = {};
  };

  testScript = ''
    import time

    curl = "curl -skf --max-time 5 --resolve ${route}:443:${vip} https://${route} | grep -q 'hello from testsite web'"

    def holder():
        for m in [edge1, edge2]:
            if m.execute("ip -4 addr show eth1 | grep -q '${vip}/'")[0] == 0:
                return m
        return None

    start_all()

    for m in [edge1, edge2]:
        m.wait_for_unit("caddy.service")
        m.wait_for_unit("keepalived.service")
    web.wait_for_unit("static-web-server.service")

    with subtest("an edge claims the vip and serves the engine-rendered route"):
        client.wait_until_succeeds(curl, timeout=180)
        first = holder()
        assert first is not None, "no edge holds the vip"

    with subtest("killing caddy on the holder moves the vip to the peer"):
        first.succeed("systemctl stop caddy")
        other = edge2 if first == edge1 else edge1
        other.wait_until_succeeds("ip -4 addr show eth1 | grep -q '${vip}/'", timeout=30)
        client.wait_until_succeeds(curl, timeout=60)

    with subtest("a recovered caddy does not steal the vip back (noPreempt)"):
        first.succeed("systemctl start caddy")
        first.wait_until_succeeds("pgrep -x caddy")
        time.sleep(10)
        assert holder() == other, "vip flapped back to the recovered node"
        client.succeed(curl)
  '';
}
