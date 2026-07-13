# immich (self-hosted photo library), native services.immich.
#
# data layout, and the reasoning behind it:
#   the photo library lives on megamax/immich (the store box's raidz1), NFS-mounted
#   here at /mnt/immich. postgres runs LOCALLY on this box, not over NFS: running
#   $PGDATA on nfs breaks postgres's fsync/locking assumptions and corrupts on a
#   network blip. so the db is local, the library is remote, and they'd normally
#   drift on restore.
#
#   the fix is immich's own backup: the server runs pg_dumpall|gzip on a schedule and
#   writes it to <mediaLocation>/backups, i.e. onto megamax/immich next to the photos.
#   a single restic snapshot of megamax/immich (taken on the store box) therefore
#   captures the library AND the db dump together, consistent by construction. on
#   restore you load the dump and immich re-indexes the photos, which is immich's
#   designed recovery path. no cross-box atomic snapshot, no postgres on nfs.
#
#   the vectorchord vector extension is enabled automatically by the nixpkgs module.
{
  config,
  lib,
  fleet,
  nixosConfigurations,
  ...
}: let
  cfg = config.lab.immich;
  topo = import fleet.topology {inherit lib;} {
    inherit nixosConfigurations;
    hostName = config.networking.hostName;
  };
  # the public FQDN, declared once. the caddy route and immich's externalDomain (for
  # share links) both derive from it, so the hostname lives in one place.
  fqdn = "immich.${config.lab.site.domain}";
in {
  options.lab.immich = {
    mediaLocation = lib.mkOption {
      type = lib.types.path;
      default = "/mnt/immich";
      description = ''
        where immich stores the library and its db-dump backups. an NFS mount of
        megamax/immich from the store box. immich writes library/ and backups/ under here.
      '';
    };

    uid = lib.mkOption {
      type = lib.types.int;
      default = 990;
      description = ''
        pinned immich uid. the NFS export squashes on uid not name, so this must line
        up with the owner the store box gives /mnt/megamax/immich. one below jellyfin's
        991 to avoid collision.
      '';
    };
  };

  config = {
    lab.topology.provides = ["immich"];
    # immich uploads whole photos/videos in one request, so lift the body cap well past any
    # single asset (caddy's default would reject large originals).
    lab.topology.routes = [
      {
        host = fqdn;
        port = 2283;
        maxBodySize = "100GB"; # mmmm prores log :woozy:
      }
    ];

    # pin the uid: the NFS export squashes on uid, and the module otherwise
    # auto-allocates it, which would drift from the store box's export owner
    users.users.immich.uid = cfg.uid;

    services.immich = {
      enable = true;
      mediaLocation = cfg.mediaLocation;
      host = config.lab.site.internalIp;
      openFirewall = false;
      # database.enable + redis.enable default true: both run locally on this box.
      # vectorchord is enabled automatically by the module.
      machine-learning.enable = true; # cpu inference, no accelerationDevices set

      settings = {
        backup.database = {
          cronExpression = "0 02 * * *";
          enabled = true;
          keepLastAmount = 14;
        };

        ffmpeg = {
          accel = "disabled";
          accelDecode = true;
          acceptedAudioCodecs = ["aac" "mp3" "opus"];
          acceptedContainers = ["mov" "ogg" "webm"];
          acceptedVideoCodecs = ["h264"];
          bframes = -1;
          cqMode = "auto";
          crf = 23;
          gopSize = 0;
          maxBitrate = "0"; # immich wants this as a string
          preferredHwDevice = "auto";
          preset = "ultrafast";
          realtime = {
            enabled = false;
            resolutions = [480 720 1080];
            videoCodecs = ["h264" "hevc"];
          };
          refs = 0;
          targetAudioCodec = "aac";
          targetResolution = "720";
          targetVideoCodec = "h264";
          temporalAQ = false;
          threads = 0;
          tonemap = "hable";
          transcode = "required";
          twoPass = false;
        };

        image = {
          colorspace = "p3";
          extractEmbedded = false;
          fullsize = {
            enabled = false;
            format = "jpeg";
            progressive = false;
            quality = 80;
          };
          preview = {
            format = "jpeg";
            progressive = false;
            quality = 80;
            size = 1440;
          };
          thumbnail = {
            format = "webp";
            progressive = false;
            quality = 80;
            size = 250;
          };
        };

        integrityChecks = {
          checksumFiles = {
            cronExpression = "0 03 * * *";
            enabled = true;
            percentageLimit = 1;
            timeLimit = 3600000;
          };
          missingFiles = {
            cronExpression = "0 03 * * *";
            enabled = true;
          };
          untrackedFiles = {
            cronExpression = "0 03 * * *";
            enabled = true;
          };
        };

        job = {
          backgroundTask.concurrency = 5;
          editor.concurrency = 2;
          faceDetection.concurrency = 2;
          integrityCheck.concurrency = 1;
          library.concurrency = 5;
          metadataExtraction.concurrency = 5;
          migration.concurrency = 5;
          notifications.concurrency = 5;
          ocr.concurrency = 1;
          search.concurrency = 5;
          sidecar.concurrency = 5;
          smartSearch.concurrency = 2;
          thumbnailGeneration.concurrency = 3;
          videoConversion.concurrency = 1;
          workflow.concurrency = 5;
        };

        library = {
          scan = {
            cronExpression = "0 0 * * *";
            enabled = true;
          };
          watch.enabled = false;
        };

        logging = {
          enabled = true;
          level = "log";
        };

        machineLearning = {
          availabilityChecks = {
            enabled = true;
            interval = 30000;
            timeout = 2000;
          };
          clip = {
            enabled = true;
            modelName = "ViT-B-32__openai";
          };
          duplicateDetection = {
            enabled = true;
            maxDistance = 0.01;
          };
          enabled = true;
          facialRecognition = {
            enabled = true;
            maxDistance = 0.5;
            minFaces = 3;
            minScore = 0.7;
            modelName = "buffalo_l";
          };
          ocr = {
            enabled = true;
            maxResolution = 736;
            minDetectionScore = 0.5;
            minRecognitionScore = 0.8;
            modelName = "PP-OCRv5_mobile";
          };
          urls = ["http://localhost:3003"];
        };

        map = {
          darkStyle = "https://tiles.immich.cloud/v1/style/dark.json";
          enabled = true;
          lightStyle = "https://tiles.immich.cloud/v1/style/light.json";
        };

        metadata.faces.import = false;

        newVersionCheck = {
          channel = "stable";
          enabled = true;
        };

        nightlyTasks = {
          clusterNewFaces = true;
          databaseCleanup = true;
          generateMemories = true;
          missingThumbnails = true;
          startTime = "00:00";
          syncQuotaUsage = true;
        };

        notifications.smtp = {
          enabled = false;
          from = "";
          replyTo = "";
          transport = {
            host = "";
            ignoreCert = false;
            password = "";
            port = 587;
            secure = false;
            username = "";
          };
        };

        # oauth disabled for now. when wiring authentik: set enabled=true, issuerUrl to
        # the authentik provider, clientId, and clientSecret._secret = <sops path>.
        oauth = {
          allowInsecureRequests = false;
          autoLaunch = false;
          autoRegister = true;
          buttonText = "Login with OAuth";
          clientId = "";
          clientSecret = "";
          defaultStorageQuota = null;
          enabled = false;
          endSessionEndpoint = "";
          issuerUrl = "";
          mobileOverrideEnabled = false;
          mobileRedirectUri = "";
          profileSigningAlgorithm = "none";
          prompt = "";
          roleClaim = "immich_role";
          scope = "openid email profile";
          signingAlgorithm = "RS256";
          storageLabelClaim = "preferred_username";
          storageQuotaClaim = "immich_quota";
          timeout = 30000;
          tokenEndpointAuthMethod = "client_secret_post";
        };

        passwordLogin.enabled = true;

        reverseGeocoding.enabled = true;

        server = {
          externalDomain = "https://${fqdn}"; # was empty in export; derived from the route's fqdn
          loginPageMessage = "";
          publicUsers = true;
        };

        storageTemplate = {
          enabled = false;
          hashVerificationEnabled = true;
          template = "{{y}}/{{y}}-{{MM}}-{{dd}}/{{filename}}";
        };

        templates.email = {
          albumInviteTemplate = "";
          albumUpdateTemplate = "";
          welcomeTemplate = "";
        };

        theme.customCss = "";

        trash = {
          days = 30;
          enabled = true;
        };

        user.deleteDelay = 7;
      };
    };

    # reach immich from this site's edge (caddy) hosts only, source-scoped via nftables.
    # caddy proxies from its own box IP, not the VIP, so allow every edge host's real IP.
    networking.firewall.extraInputRules =
      lib.concatMapStringsSep "\n" (
        ip: "ip saddr ${ip} tcp dport ${toString config.services.immich.port} accept"
      )
      topo.edgeHostIps;
  };
}
