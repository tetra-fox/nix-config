{
  config,
  lib,
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
    dataDir = "${config.lab.site.dataDir}/asf";
    web-ui.enable = true;

    settings = {
      Headless = true;
      SteamTokenDumperPluginEnabled = true;
    };

    # KnownNetworks gates auth-free web UI access by subnet
    ipcSettings = {
      Kestrel = {
        Endpoints.HTTP.Url = "http://*:1242";
        KnownNetworks = [
          config.lab.net.trustedCidr
        ];
      };
    };
  };

  # the asf module's `username` is a plain string (no usernameFile), so render the whole bot json via sops
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
    path = "${config.lab.site.dataDir}/asf/config/tetra.json";
    owner = "archisteamfarm";
    group = "archisteamfarm";
    mode = "0400";
  };

  # asf derives StateDirectory from basename(dataDir), so dataDir=/var/lib/mesa/asf yields a stray /var/lib/asf.
  # pin it under mesa, and widen ReadWritePaths so the pre-start cp of ASF.json into the custom dataDir succeeds.
  systemd.services.archisteamfarm.serviceConfig = {
    StateDirectory = lib.mkForce "mesa/asf";
    ReadWritePaths = ["${config.lab.site.dataDir}/asf"];
  };

  networking.firewall.allowedTCPPorts = [1242]; # asf web ui (KnownNetworks gates auth)
}
