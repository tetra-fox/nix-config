{
  config,
  pkgs,
  siteData,
  hostVethIp,
  ...
}: let
  cfg = config.lab.arrStack;
  torrents = cfg.torrentsPath;

  autoUnrar = pkgs.writeShellApplication {
    name = "qbittorrent-auto-unrar";
    runtimeInputs = with pkgs; [unrar coreutils findutils];
    text = builtins.readFile ./auto-unrar.sh;
  };
in {
  config = {
    systemd.tmpfiles.rules = [
      "d ${siteData}/qbittorrent 0750 qbittorrent ${cfg.mediaGroup} -"
    ];

    services.qbittorrent = {
      enable = true;
      group = cfg.mediaGroup;
      profileDir = "${siteData}/qbittorrent";
      webuiPort = 8888; # 8080 would collide with sabnzbd
      torrentingPort = 42924;
      serverConfig = {
        Application.FileLogger = {
          Age = 1;
          AgeType = 1;
          Backup = true;
          DeleteOld = true;
          Enabled = true;
          MaxSizeBytes = 66560;
          Path = "${siteData}/qbittorrent/qBittorrent/data/logs";
        };

        # auto-unrar on torrent completion
        AutoRun = {
          OnTorrentAdded.Enabled = false;
          OnTorrentAdded.Program = "";
          enabled = true;
          program = ''${autoUnrar}/bin/qbittorrent-auto-unrar "%R"'';
        };

        BitTorrent.Session = {
          ResumeDataStorageType = "Legacy";
          AddTorrentStopped = false;
          AlternativeGlobalDLSpeedLimit = 1024;
          AlternativeGlobalUPSpeedLimit = 1024;
          DHTEnabled = false;
          DefaultSavePath = torrents;
          DisableAutoTMMByDefault = false;
          DisableAutoTMMTriggers = {
            CategorySavePathChanged = false;
            DefaultSavePathChanged = false;
          };
          ExcludedFileNames = "";
          LSDEnabled = false;
          MaxActiveCheckingTorrents = 1;
          MaxActiveTorrents = -1;
          MaxActiveUploads = -1;
          PeXEnabled = false;
          Preallocation = true;
          QueueingSystemEnabled = true;
          ReannounceWhenAddressChanged = true;
          SSL.Port = 59034;
          ShareLimitAction = "Stop";
          Tags = "TD";
          TempPath = "${torrents}/temp";
          TorrentContentLayout = "Subfolder";
          TorrentExportDirectory = "${torrents}/.torrents";
        };

        Core.AutoDeleteAddedTorrentFile = "Never";
        LegalNotice.Accepted = true;
        Meta.MigrationVersion = 8;

        Network = {
          Cookies = "@Invalid()";
          PortForwardingEnabled = false;
          Proxy.OnlyForTorrents = false;
        };

        Preferences = {
          Advanced = {
            RecheckOnCompletion = false;
            trackerPort = 9000;
            trackerPortForwarding = false;
          };
          Connection.ResolvePeerCountries = true;
          Downloads = {
            SavePath = "${torrents}/";
            TempPath = "${torrents}/temp/";
          };
          General.Locale = "en";
          Scheduler.days = "EveryDay";
          WebUI = {
            Address = "*";
            AlternativeUIEnabled = false;
            AuthSubnetWhitelist = "0.0.0.0/0";
            AuthSubnetWhitelistEnabled = true;
            BanDuration = 3600;
            CSRFProtection = true;
            ClickjackingProtection = true;
            HostHeaderValidation = false;
            LocalHostAuth = false;
            MaxAuthenticationFailCount = 5;
            ReverseProxySupportEnabled = true;
            SecureCookie = true;
            ServerDomains = "*";
            SessionTimeout = 3600;
            TrustedReverseProxiesList = "${hostVethIp},127.0.0.1";
            UseUPnP = false;
          };
        };

        RSS.AutoDownloader = {
          DownloadRepacks = false;
          SmartEpisodeFilter = "";
        };
      };
    };
  };
}
