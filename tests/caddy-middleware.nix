# the lan_only claim, exercised for real. fairlane's arr vhosts have no authentik outpost,
# so lan_only is the only thing standing between a LAN client and an unauthenticated
# sonarr/radarr/prowlarr/qbittorrent UI. nothing asserted that it actually rejects anything.
#
# the matcher is caddy's `remote_ip ... private_ranges`, which reads the real TCP peer, so
# the only honest way to test it is to connect from an address outside RFC1918. both edge
# and client carry a second address in TEST-NET-3 (203.0.113.0/24, deliberately not a
# private range) alongside the site subnet, and the assertions drive each path by which of
# the edge's two addresses the request is aimed at.
#
# the un-gated control route matters as much as the gated one: without it, a failing
# request from the non-LAN address proves only that the wire is broken, not that the
# middleware did anything.
{
  modules,
  fleet,
  caps,
}: let
  hostNames = {
    edge = "testsite-edge-01";
    web = "testsite-web-01";
  };
  fleetNode = import ./fleet-node.nix {inherit hostNames;};

  edgeLanIp = "192.168.2.1";
  edgeOutsideIp = "203.0.113.1";
  clientLanIp = "192.168.2.9";
  clientOutsideIp = "203.0.113.9";

  lanRoute = "lan.testsite.test";
  openRoute = "open.testsite.test";

  siteFacts = hostIp: {
    domain = "testsite.test";
    dataDir = "/var/lib/testsite";
    serverInterface = "eth1";
    inherit hostIp;
  };
in {
  name = "caddy-middleware";

  node.specialArgs = {inherit modules fleet caps;};

  # caddy, a static file server and a curl client need very little; the nixos-test default
  # of 1G per node is three times what this uses and prices the test out of small runners
  defaults.virtualisation.memorySize = 512;

  nodes = {
    edge = {
      imports = [fleetNode modules.services.caddy.system];

      networking.hostName = hostNames.edge;
      lab.site = siteFacts edgeLanIp;

      # merges with the site address fleet-node.nix parks on eth1
      networking.interfaces.eth1.ipv4.addresses = [
        {
          address = edgeOutsideIp;
          prefixLength = 24;
        }
      ];

      # no internet in the test VM: caddy's internal CA instead of dns-01
      lab.caddy.certIssuer = ''
        {
        	local_certs
        }
      '';
    };

    web = {pkgs, ...}: {
      imports = [fleetNode];
      networking.hostName = hostNames.web;
      lab.site = siteFacts "192.168.2.3";

      lab.topology.routes = [
        {
          host = lanRoute;
          port = 8080;
          middlewares = ["lan_only"];
        }
        # control: same upstream, no middleware
        {
          host = openRoute;
          port = 8080;
        }
      ];

      services.static-web-server = {
        enable = true;
        listen = "0.0.0.0:8080";
        root = pkgs.writeTextDir "index.html" "hello from testsite web";
      };
    };

    # no site prefix in the name, so the engine never counts it as a fleet member
    client = {
      networking.interfaces.eth1.ipv4.addresses = [
        {
          address = clientLanIp;
          prefixLength = 24;
        }
        {
          address = clientOutsideIp;
          prefixLength = 24;
        }
      ];
    };
  };

  testScript = ''
    # aiming at the edge's LAN address makes the kernel pick the client's LAN source, and
    # likewise for the outside pair, so the source address follows the target
    def req(host, via):
        return (
            "curl -skf --max-time 5 "
            f"--resolve {host}:443:{via} https://{host} "
            "| grep -q 'hello from testsite web'"
        )

    start_all()

    edge.wait_for_unit("caddy.service")
    web.wait_for_unit("static-web-server.service")

    with subtest("a private-range client reaches the lan_only route"):
        client.wait_until_succeeds(req("${lanRoute}", "${edgeLanIp}"), timeout=180)

    with subtest("the un-gated route answers the same non-LAN client (control)"):
        client.wait_until_succeeds(req("${openRoute}", "${edgeOutsideIp}"), timeout=60)

    with subtest("lan_only rejects the same client from outside RFC1918"):
        # the control above proves the wire and the vhost work from this source, so a
        # failure here is the middleware and nothing else. caddy's `abort` tears down the
        # connection rather than answering, so curl fails instead of returning a status.
        client.fail(req("${lanRoute}", "${edgeOutsideIp}"))
  '';
}
