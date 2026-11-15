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

    # KnownNetworks makes the web ui auth-free for that subnet
    ipcSettings = {
      Kestrel = {
        Endpoints.HTTP.Url = "http://${config.lab.site.hostIp}:1242";
        KnownNetworks = [
          config.lab.net.trustedCidr
        ];
      };
    };
  };

  # the asf module has no usernameFile, so the whole bot json goes through sops
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

  # asf derives StateDirectory from basename(dataDir), which leaves a stray /var/lib/asf.
  # ReadWritePaths lets the pre-start cp of ASF.json into dataDir succeed
  systemd.services.archisteamfarm.serviceConfig = {
    StateDirectory = lib.mkForce "mesa/asf";
    ReadWritePaths = ["${config.lab.site.dataDir}/asf"];
  };

  # match KnownNetworks, there's no IPCPassword behind asf's own subnet check
  networking.firewall.extraInputRules = ''
    ip saddr ${config.lab.net.trustedCidr} tcp dport 1242 accept
  '';
}
