# library is NFS from megamax/immich, postgres is local (PGDATA on nfs corrupts).
# immich's own db dump lands in <mediaLocation>/backups, so one restic snapshot of
# megamax/immich holds a consistent library and db
{
  config,
  lib,
  topo,
  caps,
  ...
}: let
  cfg = config.lab.immich;
  fqdn = "immich.${config.lab.site.domain}";
in {
  options.lab.immich = {
    mediaLocation = lib.mkOption {
      type = lib.types.path;
      default = "/mnt/immich";
      description = ''
        library and db-dump location, an NFS mount of megamax/immich
      '';
    };

    uid = lib.mkOption {
      type = lib.types.int;
      default = 990;
      description = ''
        pinned uid, must match the store box's owner of /mnt/megamax/immich since NFS
        squashes on uid
      '';
    };

    oauth.clientId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        authentik's client id for immich. null disables oauth, password login stays on
      '';
    };
  };

  config = {
    assertions = [
      {
        assertion = topo.myIp != null;
        message = "immich listens on this host's east-west address (lab.site.internalIp, falling back to hostIp); neither is set.";
      }
      {
        assertion = cfg.oauth.clientId == null || topo.authServerUrl != null;
        message = "lab.immich.oauth.clientId is set but immich's oauth issuerUrl derives from the same-site auth-server route and no host in this site provides 'auth-server'; deploy authentik there or unset the clientId.";
      }
    ];

    lab.topology.provides = [caps.immich.name];
    # uploads are one request per asset, this is the only body cap in the path
    lab.topology.routes = [
      {
        host = fqdn;
        port = config.services.immich.port;
        maxBodySize = "128GB";
      }
    ];

    sops.secrets."immich/oauth_client_secret" = lib.mkIf (cfg.oauth.clientId != null) {
      owner = config.services.immich.user;
      group = config.services.immich.group;
    };

    users.users.immich.uid = cfg.uid;

    services.immich = {
      enable = true;
      inherit (cfg) mediaLocation;
      # same address caddy resolves for this host
      host = topo.myIp;
      openFirewall = false;
      machine-learning.enable = true;
      # never unload, the ~4gb clip model takes seconds to reload on the first search
      machine-learning.environment.MACHINE_LEARNING_MODEL_TTL = "0";

      settings = {
        backup.database = {
          # UTC, before the store box's 14:30 restic run. see SCHEDULE.md
          cronExpression = "0 14 * * *";
          enabled = true;
          keepLastAmount = 14;
        };

        ffmpeg = {
          accel = "disabled";
          accelDecode = true;
          acceptedAudioCodecs = ["aac" "mp3" "opus"];
          acceptedContainers = ["mov" "mp4" "ogg" "webm"];
          acceptedVideoCodecs = ["h264" "hevc"];
          bframes = -1;
          cqMode = "auto";
          crf = 28;
          gopSize = 0;
          maxBitrate = "0"; # immich wants this as a string
          preferredHwDevice = "auto";
          preset = "faster";
          realtime = {
            enabled = true;
            resolutions = [480 720 1080 1440 2160];
            videoCodecs = ["h264" "hevc" "av1"];
          };
          refs = 0;
          targetAudioCodec = "aac";
          targetResolution = "original";
          targetVideoCodec = "hevc";
          temporalAQ = false;
          threads = 0;
          tonemap = "mobius";
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

        # UTC, see SCHEDULE.md
        integrityChecks = {
          checksumFiles = {
            cronExpression = "0 13 * * *";
            enabled = true;
            percentageLimit = 1;
            timeLimit = 3600000;
          };
          missingFiles = {
            cronExpression = "0 13 * * *";
            enabled = true;
          };
          untrackedFiles = {
            cronExpression = "0 13 * * *";
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
          thumbnailGeneration.concurrency = 5;
          videoConversion.concurrency = 1;
          workflow.concurrency = 5;
        };

        library = {
          scan = {
            # UTC, see SCHEDULE.md
            cronExpression = "0 12 * * *";
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
            modelName = "ViT-SO400M-16-SigLIP2-384__webli";
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
          startTime = "12:00"; # UTC, see SCHEDULE.md
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

        oauth = {
          allowInsecureRequests = false;
          autoLaunch = false;
          autoRegister = true;
          buttonText = "Login with Authentik";
          # "" when oauth is off, matching immich's settings export
          clientId =
            if cfg.oauth.clientId != null
            then cfg.oauth.clientId
            else "";
          clientSecret =
            if cfg.oauth.clientId != null
            then {_secret = config.sops.secrets."immich/oauth_client_secret".path;}
            else "";
          defaultStorageQuota = null;
          enabled = cfg.oauth.clientId != null;
          endSessionEndpoint = "";
          issuerUrl =
            if cfg.oauth.clientId != null
            then "${topo.authServerUrl}/application/o/immich/"
            else "";
          mobileOverrideEnabled = false;
          mobileRedirectUri = "";
          profileSigningAlgorithm = "none";
          prompt = "";
          # authentik's application entitlements (admin, user) arrive as `roles`
          roleClaim = "roles";
          scope = "openid email profile entitlements";
          signingAlgorithm = "RS256";
          storageLabelClaim = "preferred_username";
          storageQuotaClaim = "immich_quota";
          timeout = 30000;
          tokenEndpointAuthMethod = "client_secret_post";
        };

        passwordLogin.enabled = true;

        reverseGeocoding.enabled = true;

        server = {
          externalDomain = "https://${fqdn}";
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
  };
}
