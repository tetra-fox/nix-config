# lab.site.* + lab.topology.* + the shared lab.net/lab.appliances facts. fleet-wide (not in a
# site's facts file) because the topology layer + the colmena deploy output read them on every
# host, not just one site's.
{
  lib,
  caps,
  ...
}: {
  # capabilities this host advertises for same-site service discovery. each service module
  # appends its own capability string when its enable flag is on (gated on a plain input, never
  # a derived value -- see the no-recursion rule in topology.nix). the topology layer reads this
  # across hosts to answer "which host in my site provides X".
  options.lab = {
    topology = {
      provides = lib.mkOption {
        # enum over the caps registry: a name outside caps.nix fails at the producer, matching
        # the consumer side where a caps.<x> typo is already a missing-attribute error
        type = lib.types.listOf (lib.types.enum (map (c: c.name) (lib.attrValues caps)));
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

    # addresses of the routers and the private address plan, shared by both sites on purpose
    # (physically separate networks built to the same layout). a site with a different plan
    # overrides these in its facts file.
    net = {
      gateway = lib.mkOption {
        type = lib.types.str;
        default = "192.168.10.1";
        description = "the site router's server-VLAN address; VMs use it as default gateway and resolver";
      };

      trustedCidr = lib.mkOption {
        type = lib.types.str;
        default = "192.168.20.0/24";
        description = "the trusted/admin VLAN; services that admit humans directly (psql, web UIs) allow it";
      };

      privateRanges = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["192.168.0.0/16" "10.0.0.0/8"];
        description = "the private v4 ranges LAN clients come from; lan-scoped defaults (bind, arr, fail2ban) read this";
      };
    };

    # addresses of the site's non-nix appliances (things the fleet proxies or scrapes but
    # doesn't configure). per-site values, set in the site facts file.
    appliances = {
      haosIp = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "the address services reach Home Assistant OS at; null = site has no HAOS box";
      };

      proxmoxIp = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "the proxmox web UI address the edge proxies and monitoring scrapes; null on sites with no single node to point at";
      };
    };

    # the shared `media` group's gid. one fleet constant because NFS group-write squashes on gid
    # (not name), so the store host (NFS server) and every client must agree. arr-stack pins the
    # group to this on compute hosts; the store hosts set it directly.
    media.gid = lib.mkOption {
      type = lib.types.int;
      default = 1002;
      description = "gid of the shared media group; must match on the NFS store host and all clients";
    };
  };
}
