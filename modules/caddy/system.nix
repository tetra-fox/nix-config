{
  config,
  lib,
  pkgs,
  siteData,
  ...
}: {
  options.lab.caddy.caddyfile = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = null;
  };

  config = {
    services.caddy = {
      enable = true;
      dataDir = "${siteData}/caddy";
      package = pkgs.caddy.withPlugins {
        plugins = [
          "github.com/caddy-dns/cloudflare@v0.2.4"
          "github.com/caddyserver/transform-encoder@v0.0.0-20260423033309-ba4124974830"
        ];
        hash = "sha256-ToYLHHaFx90AhOqJbprczuA6cRfIJRQ11p7mGpQYXYk=";
      };
      configFile = lib.mkIf (config.lab.caddy.caddyfile != null) config.lab.caddy.caddyfile;
    };

    sops.secrets."net/cf_token" = {};
    sops.templates."caddy.env" = {
      content = "CF_TOKEN=${config.sops.placeholder."net/cf_token"}\n";
      owner = "caddy";
      group = "caddy";
    };

    systemd.services.caddy.serviceConfig.EnvironmentFile = [
      config.sops.templates."caddy.env".path
    ];

    networking.firewall.allowedTCPPorts = [80 443];

    services.fail2ban = {
      enable = true;
      bantime = "1h";
      bantime-increment = {
        enable = true;
        maxtime = "168h"; # 1 week ceiling for repeat offenders
        overalljails = true;
      };
      ignoreIP = [
        "127.0.0.0/8"
        "::1/128"
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
        "fc00::/7"
      ];
      jails.caddy-status.settings = {
        enabled = true;
        filter = "caddy-status";
        logpath = "/var/log/caddy/access.log";
        backend = "auto";
        findtime = "10m";
        maxretry = 5;
      };
      # state under siteData so one backup target catches it
      daemonSettings.Definition.dbfile = "${siteData}/fail2ban/fail2ban.sqlite3";
    };

    systemd.services.fail2ban.serviceConfig.StateDirectory = lib.mkForce "mesa/fail2ban";

    environment.etc."fail2ban/filter.d/caddy-status.conf".text = ''
      [Definition]
      failregex = ^<HOST>.*"(GET|POST|HEAD|OPTIONS|PUT|DELETE|PATCH).*" 4[0-9][0-9] [0-9]+$
      ignoreregex =
    '';
  };
}
