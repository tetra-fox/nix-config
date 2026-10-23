# fleet-wide, not per site: the topology layer and colmena read these on every host
{
  config,
  lib,
  caps,
  ...
}: {
  options.lab = {
    topology = {
      # gate on a plain input, never a derived value, or the cross-host read can cycle
      provides = lib.mkOption {
        # a name outside caps.nix fails here at the producer
        type = lib.types.listOf (lib.types.enum (map (c: c.name) (lib.attrValues caps)));
        default = [];
        example = ["db-server" "db-client"];
      };

      # same plain-input rule as provides. the declaring host is the upstream, so no ip here
      routes = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            host = lib.mkOption {
              type = lib.types.str;
              description = "the vhost FQDN, e.g. immich.mesa.tetra.cool";
              example = "immich.mesa.tetra.cool";
            };
            title = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "display name, used for the authentik app a forward_auth route gets; null = the host's first label";
              example = "qBittorrent";
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
            middlewares = lib.mkOption {
              type = lib.types.listOf (lib.types.enum ["lan_only" "forward_auth"]);
              default = [];
              description = ''
                caddy middleware imports wrapped around the reverse_proxy, applied in order:
                lan_only aborts non-LAN requests, forward_auth gates on the site's authentik
                outpost. empty = a plain public reverse_proxy.
              '';
              example = ["lan_only" "forward_auth"];
            };
            openFirewall = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = ''
                let _route-firewall.nix admit the site's edge hosts to this route's port.
                false for upstreams reachable another way (podman-published ports DNAT
                before the input chain ever sees them).
              '';
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
          site facts file. _common.nix creates it via tmpfiles, group per dataDirGroup.
          null = host belongs to no site.
        '';
        example = "/var/lib/mesa";
      };

      dataDirGroup = lib.mkOption {
        type = lib.types.str;
        default = "root";
        description = "group owning the dataDir root; media hosts set the shared media group so services co-write";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "this site's public domain, e.g. mesa.tetra.cool";
        example = "mesa.tetra.cool";
      };

      proxmoxParent = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "the proxmox node hosting this VM (for topology); set on multi-node sites";
        example = "pooltoy";
      };
    };

    # both sites use this plan on purpose; a site with a different one overrides in its facts file
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

    appliances = {
      # HAOS isn't nix-managed: its http.trusted_proxies must list the edge hosts' internal
      # addresses by hand, or every proxied request gets "400: Bad Request"
      haosIp = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "the address services reach Home Assistant OS at; null = site has no HAOS box";
      };

      # keys match lab.site.proxmoxParent
      proxmoxNodes = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        example = {milkfish = "192.168.10.2";};
        description = "the site's proxmox nodes as name -> server-VLAN address; the site's mon host scrapes each one's node exporter";
      };

      proxmoxIp = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = let
          addrs = builtins.attrValues config.lab.appliances.proxmoxNodes;
        in
          if builtins.length addrs == 1
          then builtins.head addrs
          else null;
        description = "the proxmox web UI address the edge proxies and the topology draws; null unless the site has exactly one node";
      };
    };

    media = {
      gid = lib.mkOption {
        type = lib.types.int;
        default = 1002;
        description = "gid of the shared media group; must match on the NFS store host and all clients";
      };
      group = lib.mkOption {
        type = lib.types.str;
        default = "media";
        description = "name of the shared media group";
      };
    };
  };
}
