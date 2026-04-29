{
  config,
  lib,
  pkgs,
  modules,
  siteData,
  siteEnvFile,
  netns,
  netnsPath,
  nsVethIp,
  hostVethIp,
  ...
}: let
  cfg = config.lab.arrStack;

  arrPgUser = "arr";
  arrApps = ["sonarr" "radarr" "prowlarr"];
  arrDbs = lib.flatten (map (a: ["${a}-main" "${a}-log"]) arrApps);

  mkPgEnv = appName: let
    prefix = "${lib.toUpper appName}__POSTGRES";
  in ''
    ${prefix}__HOST=${hostVethIp}
    ${prefix}__PORT=5432
    ${prefix}__USER=${arrPgUser}
    ${prefix}__PASSWORD=${config.sops.placeholder."arr/pg_pass"}
    ${prefix}__MAIN_DB=${appName}-main
    ${prefix}__LOG_DB=${appName}-log
  '';
in {
  imports = [
    ./qbittorrent.nix
    ./sabnzbd.nix
    ./recyclarr.nix
    modules.postgres.system
  ];

  options.lab.arrStack = {
    lanProxy = lib.mkEnableOption "socat LAN proxies into the netns" // {default = true;};

    mediaGroup = lib.mkOption {
      type = lib.types.str;
      default = "media";
    };

    torrentsPath = lib.mkOption {type = lib.types.str;};
    nzbPath = lib.mkOption {type = lib.types.str;};

    lanProxyPorts = lib.mkOption {
      type = lib.types.attrsOf lib.types.port;
      default = {
        sonarr = 8989;
        radarr = 7878;
        prowlarr = 9696;
        qbittorrent = 8888;
      };
    };
  };

  config = let
    arrSecrets = {
      sops.secrets = {
        "apps/sonarr_api_key" = {};
        "apps/radarr_api_key" = {};
      };
      sops.templates = let
        mkEnv = content: {
          inherit content;
          group = cfg.mediaGroup;
          mode = "0440";
        };
      in {
        "sonarr.env" = mkEnv ''
          SONARR__AUTH__APIKEY=${config.sops.placeholder."apps/sonarr_api_key"}
          ${mkPgEnv "sonarr"}
        '';
        "radarr.env" = mkEnv ''
          RADARR__AUTH__APIKEY=${config.sops.placeholder."apps/radarr_api_key"}
          ${mkPgEnv "radarr"}
        '';
        "prowlarr.env" = mkEnv (mkPgEnv "prowlarr");
      };
    };
  in
    lib.mkMerge [
      arrSecrets
      (let
        netnsBind = {
          NetworkNamespacePath = netnsPath;
          BindReadOnlyPaths = ["/etc/netns/${netns}/resolv.conf:/etc/resolv.conf"];
        };

        mkLanProxy = name: port: {
          description = "LAN proxy for ${name}: host:${toString port} -> ${nsVethIp}:${toString port}";
          after = ["wg-vpn.service"];
          requires = ["wg-vpn.service"];
          bindsTo = ["wg-vpn.service"];
          wantedBy = ["multi-user.target"];
          serviceConfig = {
            Type = "simple";
            ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:${toString port},fork,reuseaddr TCP:${nsVethIp}:${toString port}";
            Restart = "on-failure";
            DynamicUser = true;
          };
        };

        arrAuthSettings = {
          auth.method = "Forms";
          auth.required = "DisabledForLocalAddresses";
          log.level = "info";
        };
      in {
        services.flaresolverr = {
          enable = true;
          openFirewall = true;
        };

        lab.postgres = {
          allowedCidrs = ["10.200.200.0/24"];
          roles.${arrPgUser} = {
            passwordSecret = "arr/pg_pass";
            owns = arrDbs;
          };
        };

        services.sonarr = {
          enable = true;
          group = cfg.mediaGroup;
          dataDir = "${siteData}/sonarr";
          environmentFiles = siteEnvFile "sonarr.env";
          settings = arrAuthSettings;
        };

        services.radarr = {
          enable = true;
          group = cfg.mediaGroup;
          dataDir = "${siteData}/radarr";
          environmentFiles = siteEnvFile "radarr.env";
          settings = arrAuthSettings;
        };

        services.prowlarr = {
          enable = true;
          dataDir = "${siteData}/prowlarr";
          settings = arrAuthSettings;
        };

        users.users.prowlarr = {
          isSystemUser = true;
          uid = 276; # next after radarr (275)
          group = cfg.mediaGroup;
          home = "${siteData}/prowlarr";
        };

        networking.firewall.allowedTCPPorts = lib.mkIf cfg.lanProxy (lib.attrValues cfg.lanProxyPorts);

        systemd.tmpfiles.rules = [
          "d ${siteData}/prowlarr 0750 prowlarr ${cfg.mediaGroup} -"
        ];

        # fail closed on wg; gate on pg-password to avoid auth-failure
        # crash loop on first boot.
        systemd.services = let
          arrDeps = {
            after = ["wg-vpn.service" config.lab.postgres.passwordUnits.${arrPgUser}];
            requires = ["wg-vpn.service" config.lab.postgres.passwordUnits.${arrPgUser}];
            bindsTo = ["wg-vpn.service"];
            serviceConfig = netnsBind;
          };
        in
          lib.mkMerge [
            {
              sonarr = arrDeps;
              radarr = arrDeps;
              qbittorrent = arrDeps;
              # sabnzbd intentionally absent (stays in main ns).
              prowlarr =
                arrDeps
                // {
                  serviceConfig =
                    netnsBind
                    // {
                      DynamicUser = lib.mkForce false;
                      User = "prowlarr";
                      Group = lib.mkForce cfg.mediaGroup;
                      StateDirectory = lib.mkForce "";
                      ExecStart = lib.mkForce "${pkgs.prowlarr}/bin/Prowlarr -nobrowser -data=${siteData}/prowlarr";
                      EnvironmentFile = siteEnvFile "prowlarr.env";
                    };
                };
            }

            (lib.mkIf cfg.lanProxy (
              lib.mapAttrs' (name: port: lib.nameValuePair "arr-lan-${name}" (mkLanProxy name port)) cfg.lanProxyPorts
            ))
          ];
      })
    ];
}
