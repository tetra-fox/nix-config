{modules, ...}: {
  imports = [
    modules.profiles.server.system

    modules.services.caddy.system
    modules.platform.sops.system
  ];

  networking.hostName = "mesa-edge-01";

  lab = {
    sops.secretsFile = ../../secrets/mesa-edge-01.yaml;

    site.hostIp = "192.168.10.150";
    site.internalIp = "10.10.0.150";

    # the resolvable reverse-proxy vhosts (auth, jellyfin, immich, stats, np) render from
    # lab.topology.routes; this tail holds the site-specific blocks the engine can't derive: the
    # root vhost, the two appliances with no capability publisher, and the arr forward_auth block
    # (deferred, see TODO). the (lan_only)/(log)/(authentik) snippets + cert_issuer come from the
    # module preamble.
    caddy.staticTail = ''
      # public
      mesa.tetra.cool {
      	import log
      	respond "my paws hurt :("
      }

      home.mesa.tetra.cool {
      	import log
      	reverse_proxy 10.10.0.20:8123
      }

      pve.mesa.tetra.cool {
      	route {
      		import lan_only
      		reverse_proxy https://192.168.10.2:8006 {
      			transport http {
      				tls_insecure_skip_verify
      			}
      		}
      	}
      }

      qb.mesa.tetra.cool,
      sonarr.mesa.tetra.cool,
      radarr.mesa.tetra.cool,
      prowlarr.mesa.tetra.cool,
      sabnzbd.mesa.tetra.cool {
      	route {
      		import lan_only
      		reverse_proxy {$AUTH_UPSTREAM}
      	}
      }
    '';

    caddy.ha = {
      enable = true;
      vip = "192.168.10.155";
    };
  };

  system.stateVersion = "26.11";
}
