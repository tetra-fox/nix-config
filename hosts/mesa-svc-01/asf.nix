{
  config,
  siteData,
  ...
}: {
  sops.secrets = {
    "apps/asf_tetra_username" = {
      owner = "archisteamfarm";
      group = "archisteamfarm";
    };
    "apps/asf_tetra_password" = {
      owner = "archisteamfarm";
      group = "archisteamfarm";
    };
  };

  services.archisteamfarm = {
    enable = true;
    dataDir = "${siteData}/asf";
    web-ui.enable = true;

    settings = {
      Headless = true;
      SteamTokenDumperPluginEnabled = true;
    };

    # gates web UI auth-free access to LAN subnets via KnownNetworks.
    ipcSettings = {
      Kestrel = {
        Endpoints.HTTP.Url = "http://*:1242";
        KnownNetworks = [
          "192.168.20.0/24" # trusted VLAN
        ];
      };
    };
  };

  # bot config rendered via sops because the asf module's `username`
  # option is a plain string (no usernameFile variant) and we want both
  # creds in sops
  sops.templates."asf-tetra.json" = {
    content = builtins.toJSON {
      Enabled = true;
      GamesPlayedWhileIdle = [250820];
      OnlineStatus = 0;
      RemoteCommunication = 0;
      SteamLogin = config.sops.placeholder."apps/asf_tetra_username";
      SteamPassword = config.sops.placeholder."apps/asf_tetra_password";
      EnableFreePackages = true;
      FreePackagesFilters = [
        {
          IgnoredTypes = [];
          PlaytestMode = 3;
        }
      ];
      FreePackagesLimit = 30;
      PauseFreePackagesWhilePlaying = true;
    };
    path = "${siteData}/asf/config/tetra.json";
    owner = "archisteamfarm";
    group = "archisteamfarm";
    mode = "0400";
  };

  # asf module hardcodes StateDirectory=archisteamfarm with ProtectSystem=strict;
  # widen ReadWritePaths so the unit's pre-start cp of ASF.json into our
  # custom dataDir succeeds.
  systemd.services.archisteamfarm.serviceConfig.ReadWritePaths = ["${siteData}/asf"];

  networking.firewall.allowedTCPPorts = [1242]; # asf web ui (KnownNetworks gates auth)
}
