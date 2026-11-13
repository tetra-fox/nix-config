{
  config,
  pkgs,
  ...
}: {
  imports = [
    ../common/arr-host.nix
    ./storage.nix
    ./asf.nix
    ./bambuddy.nix
    ./nowplaying.nix
    ./radio.nix
  ];

  lab = {
    arrStack = {
      torrentsPath = "/mnt/store/torrents";
      nzbPath = "/mnt/store/nzb";
      # AirVPN's forwarded port
      torrentingPort = 42924;
      reseek = {
        enable = true;
        # AirVPN's forwarded port
        soulseekPort = 22026;
      };
    };

    site.hostIp = "192.168.10.130";
    site.internalIp = "10.10.0.130";

    podman.cadvisor.enable = true;
  };

  services.reseek = {
    settings = {
      transfers.upload.slots = 32;
      analysis.on_download = true;
      # the netns port admits only the edge, so mesa-mon-01 scrapes it through caddy
      metrics.enabled = true;
    };
    extraConfigFiles = [config.sops.templates."reseek-metrics.toml".path];
  };

  services.reseek.settings = {
    soulseek = {
      username = "portapuppy";
      description = ''
        average transbian therian age regressor nixos sysadmin rust dev seattleite puppygirl =w=

        i tend to keep 24bit aiffs for proper ID3 tagging + archival (sowwy no flacs), with mp3 320s as a fallback and 256k aac as a last resort (soundcloud rips xwx)

        music is for the critters!!!!
      '';
      # reseek sends JPEG, GIF or BMP; the png is the source
      picture = pkgs.runCommand "slsk_pic.jpg" {nativeBuildInputs = [pkgs.imagemagick];} ''
        magick ${./slsk_pic.png} -resize '512x512>' -quality 90 $out
      '';
      interests = {
        liked = ["diapers" "lossless" "p2p" ":3" "knots" "t4t" "girls" "linux" "open source" "preservation" "nixos"];
      };
    };
    remote_file_management = true;
    schedules = {
      cleanup = "5m";
      vacuum = "1d";
      release_check = "1d";
    };
    shares = {
      cache = {
        retention = "12h";
        storage_mode = "memory";
      };
    };
  };

  sops.secrets."reseek/metrics_password" = {};
  sops.templates."reseek-metrics.toml" = {
    owner = config.services.reseek.user;
    content = ''
      [metrics.authentication]
      username = "prometheus"
      password = "${config.sops.placeholder."reseek/metrics_password"}"
    '';
    restartUnits = ["reseek.service"];
  };
}
