{config, ...}: let
  nsVethIp = config.vpnNamespaces.wg.namespaceAddress;

  # arr scores are a single summed integer, so each quality axis lives in its own
  # magnitude band to keep orthogonal axes from cancelling (great audio +X vs bad
  # encode -X netting 0). each band's full range is below one step of the band above:
  #   ban          x -1_000_000
  #   HDR family   x    100_000  (any HDR beats an SDR remux)
  #   group tier   x      1_000
  #   audio        x          1
  # TRaSH HDR formats stack additively: every HDR release matches base "HDR", DV and
  # HDR10+ add their own boost, so DV(300000) > HDR10+(200000) > HDR(100000) > SDR(0).
  # resolution is enforced by each profile's hard quality cap, not scored here.
  #
  # to re-verify trash_ids: clone TRaSH-Guides/Guides and grep
  # docs/json/{sonarr,radarr}/cf/*.json for the format name -> trash_id.

  profileNames = import ./profile-names.nix;
  mkScore = score: ids: {
    trash_ids =
      if builtins.isList ids
      then ids
      else [ids];
    assign_scores_to = map (name: {inherit name score;}) profileNames;
  };

  mkCustomFormats = ids: [
    (mkScore 100000 ids.hdr)
    (mkScore 100000 ids.hdr10Plus)
    (mkScore 200000 ids.dvBoost)
    (mkScore 12000 ids.remuxTier01)
    (mkScore 11000 ids.remuxTier02)
    (mkScore 10000 ids.hdBlurayTier01)
    (mkScore 9000 ids.hdBlurayTier02)
    (mkScore 8000 ids.webTier01)
    (mkScore 7000 ids.webTier02)
    (mkScore 6000 ids.webTier03)
    (mkScore 16 ids.truehdAtmos)
    (mkScore 15 ids.ddpAtmos)
    (mkScore 14 ids.atmos)
    (mkScore 13 ids.truehd)
    (mkScore 12 ids.dtsX)
    (mkScore 11 ids.dtsHdMa)
    (mkScore 10 ids.dtsHdHra)
    (mkScore 9 ids.dtsEs)
    (mkScore 8 ids.dts)
    (mkScore 7 ids.flac)
    (mkScore 6 ids.pcm)
    (mkScore 5 ids.ddp)
    (mkScore 4 ids.dd)
    (mkScore 3 ids.aac)
    (mkScore 30 ids.repack3)
    (mkScore 20 ids.repack2)
    (mkScore 10 ids.repackProper)
    # -20000 sits below the tier band but above min_format_score (-50000) so a demoted
    # release ranks below any clean one yet survives as a fallback
    (mkScore (-20000) ids.demotes)
    # below min_format_score so bans are hard-rejected, not just unpreferred
    (mkScore (-1000000) ids.bans)
  ];

  # hard-capped at `cap` but every lower tier is allowed so it can still grab
  # something when nothing at the cap exists
  mkProfile = name: cap: qualities: {
    inherit name qualities;
    upgrade = {
      allowed = true;
      until_quality = cap;
      until_score = 10000000;
    };
    # below one or two stacked demotes (-40000) so a flagged-but-fine release survives,
    # above the ban band so broken ones are rejected
    min_format_score = -50000;
    # zero out unmanaged formats so a stale manual score in the arr can't skew selection
    reset_unmatched_scores.enabled = true;
  };

  sonarrLadder = {
    "2160p" = [
      {name = "Bluray-2160p Remux";}
      {name = "Bluray-2160p";}
      {
        name = "WEB 2160p";
        qualities = ["WEBDL-2160p" "WEBRip-2160p"];
      }
      {name = "HDTV-2160p";}
    ];
    "1080p" = [
      {name = "Bluray-1080p Remux";}
      {name = "Bluray-1080p";}
      {
        name = "WEB 1080p";
        qualities = ["WEBDL-1080p" "WEBRip-1080p"];
      }
      {name = "HDTV-1080p";}
    ];
    "720p" = [
      {name = "Bluray-720p";}
      {
        name = "WEB 720p";
        qualities = ["WEBDL-720p" "WEBRip-720p"];
      }
      {name = "HDTV-720p";}
    ];
    sd = [
      {name = "Bluray-576p";}
      {name = "Bluray-480p";}
      {name = "DVD";}
      {
        name = "WEB 480p";
        qualities = ["WEBDL-480p" "WEBRip-480p"];
      }
      {name = "SDTV";}
    ];
  };

  # radarr uses different quality names than sonarr (Remux-1080p vs Bluray-1080p Remux)
  radarrLadder = {
    "2160p" = [
      {name = "Remux-2160p";}
      {name = "Bluray-2160p";}
      {
        name = "WEB 2160p";
        qualities = ["WEBDL-2160p" "WEBRip-2160p"];
      }
      {name = "HDTV-2160p";}
    ];
    "1080p" = [
      {name = "Remux-1080p";}
      {name = "Bluray-1080p";}
      {
        name = "WEB 1080p";
        qualities = ["WEBDL-1080p" "WEBRip-1080p"];
      }
      {name = "HDTV-1080p";}
    ];
    "720p" = [
      {name = "Bluray-720p";}
      {
        name = "WEB 720p";
        qualities = ["WEBDL-720p" "WEBRip-720p"];
      }
      {name = "HDTV-720p";}
    ];
    sd = [
      {name = "Bluray-576p";}
      {name = "Bluray-480p";}
      {
        name = "WEB 480p";
        qualities = ["WEBDL-480p" "WEBRip-480p"];
      }
      {name = "DVD-R";}
      {name = "DVD";}
      {name = "DVDSCR";}
      {name = "REGIONAL";}
      {name = "TELECINE";}
      {name = "TELESYNC";}
      {name = "CAM";}
      {name = "WORKPRINT";}
      {name = "SDTV";}
    ];
  };

  mkProfiles = ladder: capName: [
    (mkProfile "best-2160p" capName.r2160 (ladder."2160p" ++ ladder."1080p" ++ ladder."720p" ++ ladder.sd))
    (mkProfile "best-1080p" capName.r1080 (ladder."1080p" ++ ladder."720p" ++ ladder.sd))
    (mkProfile "best-720p" capName.r720 (ladder."720p" ++ ladder.sd))
    (mkProfile "best-sd" capName.rsd ladder.sd)
  ];

  # sonarr and radarr use different trash_ids for the same formats, hence two tables
  sonarrIds = {
    remuxTier01 = "9965a052eb87b0d10313b1cea89eb451";
    remuxTier02 = "8a1d0c3d7497e741736761a1da866a2e";
    hdBlurayTier01 = "d6819cba26b1a6508138d25fb5e32293";
    hdBlurayTier02 = "c2216b7b8aa545dc1ce8388c618f8d57";
    webTier01 = "e6258996055b9fbab7e9cb2f75819294";
    webTier02 = "58790d4e2fdcd9733aa7ae68ba2bb503";
    webTier03 = "d84935abd3f8556dcd51d4f27e22d0a6";
    dvBoost = "7c3a61a9c6cb04f52f1544be6d44a026";
    hdr10Plus = "0c4b99df9206d2cfac3c05ab897dd62a";
    hdr = "505d871304820ba7106b693be6fe4a9e";
    truehdAtmos = "0d7824bb924701997f874e7ff7d4844a";
    ddpAtmos = "4232a509ce60c4e208d13825b7c06264";
    atmos = "b6fbafa7942952a13e17e2b1152b539a";
    truehd = "1808e4b9cee74e064dfae3f1db99dbfe";
    dtsX = "9d00418ba386a083fbf4d58235fc37ef";
    dtsHdMa = "c429417a57ea8c41d57e6990a8b0033f";
    dtsHdHra = "cfa5fbd8f02a86fc55d8d223d06a5e1f";
    dtsEs = "c1a25cd67b5d2e08287c957b1eb903ec";
    dts = "5964f2a8b3be407d083498e4459d05d0";
    flac = "851bd64e04c9374c51102be3dd9ae4cc";
    pcm = "30f70576671ca933adbdcfc736a69718";
    ddp = "63487786a8b01b7f20dd2bc90dd4a477";
    dd = "dbe00161b08a25ac6154c55f95e6318d";
    aac = "a50b8a0c62274a7c38b09a9619ba9d86";
    repack3 = "44e7c4de10ae50265753082e5dc76047";
    repack2 = "eb3d5cc0a2be0db205fb823640db6a3c";
    repackProper = "ec8fa7296b64e8cd390a1600981f3923";
    # x265 demoted not banned: jellyfin clients direct-play hevc and lots of animated
    # 1080p is x265-only
    demotes = [
      "47435ece6b99a0b477caf360e79ba0bb" # x265 (HD)
      "e1a997ddb54e3ecbfe06341ad323c458" # Obfuscated
      "06d66ab109d4d2eddb2794d21526d140" # Retags
      "1b3994c551cbb92a2c781af061f4ab44" # Scene
      "32b367365729d530ca1c124a0b180c64" # Bad Dual Groups
      "82d40da2bc6923f41e14394075dd4b03" # No-RlsGroup
    ];
    bans = [
      "041d90b435ebd773271cea047a457a6a" # x266
      "15a05bc7c1a36e2b57fd628f8977e2fc" # AV1
      "85c61753df5da1fb2aab6f2a47426b09" # BR-DISK
      "9c11cd3f07101cdba90a2d81cf0e56b4" # LQ
      "e2315f990da2e2cbfc9fa5b7a6fcfe48" # LQ (Release Title)
      "23297a736ca77c0fc8e70f8edd7ee56c" # Upscaled
    ];
  };

  radarrIds = {
    remuxTier01 = "3a3ff47579026e76d6504ebea39390de";
    remuxTier02 = "9f98181fe5a3fbeb0cc29340da2a468a";
    hdBlurayTier01 = "ed27ebfef2f323e964fb1f61391bcb35";
    hdBlurayTier02 = "c20c8647f2746a1f4c4262b0fbbeeeae";
    webTier01 = "c20f169ef63c5f40c2def54abaf4438e";
    webTier02 = "403816d65392c79236dcb6dd591aeda4";
    webTier03 = "af94e0fe497124d1f9ce732069ec8c3b";
    dvBoost = "b337d6812e06c200ec9a2d3cfa9d20a7";
    hdr10Plus = "caa37d0df9c348912df1fb1d88f9273a";
    hdr = "493b6d1dbec3c3364c59d7607f7e3405";
    truehdAtmos = "496f355514737f7d83bf7aa4d24f8169";
    ddpAtmos = "1af239278386be2919e1bcee0bde047e";
    atmos = "417804f7f2c4308c1f4c5d380d4c4475";
    truehd = "3cafb66171b47f226146a0770576870f";
    dtsX = "2f22d89048b01681dde8afe203bf2e95";
    dtsHdMa = "dcf3ec6938fa32445f590a4da84256cd";
    dtsHdHra = "8e109e50e0a0b83a5098b056e13bf6db";
    dtsEs = "f9f847ac70a0af62ea4a08280b859636";
    dts = "1c1a4c5e823891c75bc50380a6866f73";
    flac = "a570d4a0e56a2874b64e5bfa55202a1b";
    pcm = "e7c2fcae07cbada050a0af3357491d7b";
    ddp = "185f1dd7264c4562b9022d963ac37424";
    dd = "c2998bd0d90ed5621d8df281e839436e";
    aac = "240770601cc226190c367ef59aba7463";
    repack3 = "5caaaa1c08c1742aa4342d8c4cc463f2";
    repack2 = "ae43b294509409a6a13919dedd4764c4";
    repackProper = "e7718d7a3ce595f289bfee26adc178f5";
    demotes = [
      "dc98083864ea246d05a42df0d05f81cc" # x265 (HD)
      "7357cf5161efbf8c4d5d0c30b4815ee2" # Obfuscated
      "5c44f52a8714fdd79bb4d98e2673be1f" # Retags
      "f537cf427b64c38c8e36298f657e4828" # Scene
      "b6832f586342ef70d9c128d40c07b872" # Bad Dual Groups
      "ae9b7c9ebde1f3bd336a8cbd1ec4c5e5" # No-RlsGroup
    ];
    bans = [
      "390455c22a9cac81a738f6cbad705c3c" # x266
      "cae4ca30163749b891686f95532519bd" # AV1
      "ed38b889b31be83fda192888e2286d83" # BR-DISK
      "90a6f9a284dff5103f6346090e6280c8" # LQ
      "e204b80c87be9497a8a6eaff48f72905" # LQ (Release Title)
      "bfd8eb01832d646a0a89c4deb46f8564" # Upscaled
      "b8cd450cbfa689c0259a01d9e29ba3d6" # 3D
    ];
  };
in {
  services.recyclarr = {
    enable = true;
    # see SCHEDULE.md
    schedule = "12:00"; # servers are UTC. 4a/5a pacific
    configuration = {
      sonarr.sonarr = {
        base_url = "http://${nsVethIp}:8989";
        api_key._secret = config.sops.secrets."apps/sonarr_api_key".path;
        delete_old_custom_formats = true;
        quality_definition.type = "series";
        quality_profiles = mkProfiles sonarrLadder {
          r2160 = "Bluray-2160p Remux";
          r1080 = "Bluray-1080p Remux";
          r720 = "Bluray-720p";
          rsd = "Bluray-576p";
        };
        custom_formats = mkCustomFormats sonarrIds;
      };
      radarr.radarr = {
        base_url = "http://${nsVethIp}:7878";
        api_key._secret = config.sops.secrets."apps/radarr_api_key".path;
        delete_old_custom_formats = true;
        quality_definition.type = "movie";
        quality_profiles = mkProfiles radarrLadder {
          r2160 = "Remux-2160p";
          r1080 = "Remux-1080p";
          r720 = "Bluray-720p";
          rsd = "Bluray-576p";
        };
        custom_formats = mkCustomFormats radarrIds;
      };
    };
  };

  # order after the netns + arrs so it doesn't fire on boot before they can accept
  # connections. wants not requires: a missing arr shouldn't permanently block recyclarr
  systemd.services.recyclarr = {
    after = ["wg.service" "sonarr.service" "radarr.service"];
    wants = ["sonarr.service" "radarr.service"];
  };
}
