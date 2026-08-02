{
  config,
  ...
}: {
  imports = [../_autostart.nix];

  programs.nixcord = {
    enable = true;
    discord = {
      vencord.enable = true;
      krisp.enable = true;
      openASAR.enable = true;
      settings = {
        openH264Enabled = true;
        offloadAdmControls = true;
        BACKGROUND_COLOR = "#000000";
        openasar = {
          setup = true;
          cmdPreset = "perf";
          noTrack = true;
          noTyping = true;
          themeSync = true;
          quickstart = true;
          multiInstance = false;
        };
      };
    };
    config = {
      plugins = {
        clearUrls.enable = true;
        fixYoutubeEmbeds.enable = true;
        fakeNitro.enable = true;
        expressionCloner.enable = true;
        shikiCodeblocks.enable = true;
        typingTweaks.enable = true;
        unindent.enable = true;
        userMessagesPronouns.enable = true;
        youtubeAdblock.enable = true;
        revealAllSpoilers.enable = true;
        platformIndicators.enable = true;
        mutualGroupDms.enable = true;
        imageZoom.enable = true;
        fixImagesQuality.enable = true;
      };
    };
  };

  # home.file."${config.programs.nixcord.discord.configDir}/settings.json".force = true;

  my.autostart.apps.discord = {
    exec = "${config.programs.nixcord.finalPackage.discord}/bin/discord --start-minimized";
    tray = true;
  };
}
