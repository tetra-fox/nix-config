{
  config,
  nsVethIp,
  ...
}: let
  mkScore = score: ids: {
    trash_ids =
      if builtins.isList ids
      then ids
      else [ids];
    assign_scores_to = [
      {
        name = "best_recyclarr";
        inherit score;
      }
    ];
  };
in {
  services.recyclarr = {
    enable = true;
    schedule = "daily";
    configuration = {
      sonarr.sonarr = {
        base_url = "http://${nsVethIp}:8989";
        api_key._secret = config.sops.secrets."apps/sonarr_api_key".path;
        quality_definition.type = "series";
        quality_profiles = [
          {
            name = "best_recyclarr";
            upgrade = {
              allowed = true;
              until_quality = "Bluray-2160p Remux";
              until_score = 1700;
            };
            min_format_score = 0;
            qualities = [
              {name = "Bluray-2160p Remux";}
              {name = "Bluray-2160p";}
              {
                name = "WEB 2160p";
                qualities = ["WEBDL-2160p" "WEBRip-2160p"];
              }
              {name = "HDTV-2160p";}
              {name = "Bluray-1080p Remux";}
              {name = "Bluray-1080p";}
              {
                name = "WEB 1080p";
                qualities = ["WEBDL-1080p" "WEBRip-1080p"];
              }
              {name = "HDTV-1080p";}
              {name = "Bluray-720p";}
              {
                name = "WEB 720p";
                qualities = ["WEBDL-720p" "WEBRip-720p"];
              }
              {name = "HDTV-720p";}
              {name = "Bluray-576p";}
              {name = "Bluray-480p";}
              {name = "DVD";}
              {
                name = "WEB 480p";
                qualities = ["WEBDL-480p" "WEBRip-480p"];
              }
              {name = "SDTV";}
            ];
          }
        ];
        custom_formats = [
          (mkScore 1000 "7c3a61a9c6cb04f52f1544be6d44a026") # DV boost
          (mkScore 500 "505d871304820ba7106b693be6fe4a9e") # HDR
          (mkScore 100 "0c4b99df9206d2cfac3c05ab897dd62a") # HDR10Plus boost
          (mkScore 7 "44e7c4de10ae50265753082e5dc76047") # Repack3
          (mkScore 6 "eb3d5cc0a2be0db205fb823640db6a3c") # Repack2
          (mkScore 5 "ec8fa7296b64e8cd390a1600981f3923") # Repack/Proper
          # bulk negative scores - releases we never want
          (mkScore (-10000) [
            "15a05bc7c1a36e2b57fd628f8977e2fc" # AV1
            "85c61753df5da1fb2aab6f2a47426b09" # BR-DISK
            "9c11cd3f07101cdba90a2d81cf0e56b4" # LQ
            "e2315f990da2e2cbfc9fa5b7a6fcfe48" # LQ (release title)
            "23297a736ca77c0fc8e70f8edd7ee56c" # Upscaled
            "47435ece6b99a0b477caf360e79ba0bb" # x265 (HD)
            "fbcb31d8dabd2a319072b84fc0b7249c" # Extras
            "82d40da2bc6923f41e14394075dd4b03" # No-RlsGroup
            "e1a997ddb54e3ecbfe06341ad323c458" # Obfuscated
            "06d66ab109d4d2eddb2794d21526d140" # Retags
            "1b3994c551cbb92a2c781af061f4ab44" # Scene
            "32b367365729d530ca1c124a0b180c64" # Bad Dual Groups
            "041d90b435ebd773271cea047a457a6a" # x266
          ])
        ];
      };
      radarr.radarr = {
        base_url = "http://${nsVethIp}:7878";
        api_key._secret = config.sops.secrets."apps/radarr_api_key".path;
      };
    };
  };
}
