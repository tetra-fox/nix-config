# lab.site.* + lab.topology.* option declarations. fleet-wide (not in a site's facts file)
# because site-topology + the colmena deploy output read them on every host, not just one site's.
{lib, ...}: {
  # capabilities this host advertises for same-site service discovery. each service module
  # appends its own capability string when its enable flag is on (gated on a plain input, never
  # a derived value -- see the no-recursion rule in site-topology.nix). site-topology reads this
  # across hosts to answer "which host in my site provides X".
  options.lab = {
    topology = {
      provides = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["db-server" "db-client"];
      };

      # the caddy vhosts this host serves. the edge host folds every same-site host's routes into a
      # rendered Caddyfile, resolving each publisher's address with ipOf (so a route carries no IP --
      # the host that declares a route IS the upstream; caddy resolves where). must be a plain input
      # (each service module appends its own route, gated on a plain flag) so the cross-host fold can't
      # cycle, same rule as lab.topology.provides.
      routes = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            host = lib.mkOption {
              type = lib.types.str;
              description = "the vhost FQDN, e.g. immich.mesa.tetra.cool";
              example = "immich.mesa.tetra.cool";
            };
            port = lib.mkOption {
              type = lib.types.port;
              description = "the port the service listens on, on the declaring host";
              example = 2283;
            };
            scheme = lib.mkOption {
              type = lib.types.enum ["http" "https"];
              default = "http";
              description = "upstream scheme; https for services caddy must reach over TLS";
            };
            maxBodySize = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "request_body max_size for this vhost (e.g. immich's large uploads); null = caddy default";
              example = "50GB";
            };
          };
        });
        default = [];
      };
    };

    site = {
      hostIp = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "this host's IPv4 on its site's server VLAN (the rest of the layout is fixed per-site)";
        example = "192.168.10.130";
      };

      internalIp = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "this host's IPv4 on the isolated internal VLAN; null = not on it";
        example = "10.10.0.130";
      };

      # NIC names are a proxmox convention (virtio slot order), so they get fleet-wide
      # defaults here; a site with different naming overrides in its facts file. service
      # modules read these instead of hardcoding ens18/ens19.
      serverInterface = lib.mkOption {
        type = lib.types.str;
        default = "ens18";
        description = "the NIC on the site's server VLAN (proxmox slot 0 by convention)";
      };

      internalInterface = lib.mkOption {
        type = lib.types.str;
        default = "ens19";
        description = "the NIC on the isolated internal VLAN (proxmox slot 1); only meaningful when internalIp is set";
      };

      internalCidr = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "the internal VLAN's subnet, set in the site facts file; null = site has no internal VLAN";
        example = "10.10.0.0/24";
      };

      dataDir = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          site-scoped state root (service modules put their state under it), set in the
          site facts file. each host creates and owns the directory itself via tmpfiles
          (ownership differs per host). null = host belongs to no site.
        '';
        example = "/var/lib/mesa";
      };

      # the site's public domain, set in the per-site facts file. service modules build their vhost
      # FQDNs as <service>.<domain> so a route declaration stays site-agnostic.
      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "this site's public domain, e.g. mesa.tetra.cool";
        example = "mesa.tetra.cool";
      };

      # the proxmox node this VM runs on, for the topology diagram's parent edge. single-node
      # sites (mesa/milkfish) can ignore it and hardcode the parent; multi-node sites (fairlane:
      # plush/pooltoy) set it per host so the diagram shows which physical node hosts each VM.
      proxmoxParent = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "the proxmox node hosting this VM (for topology); set on multi-node sites";
        example = "pooltoy";
      };
    };
  };
}
