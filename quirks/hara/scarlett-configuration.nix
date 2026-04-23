{...}: {
  services.pipewire.wireplumber.extraConfig."51-scarlett-lowlatency" = {
    "monitor.alsa.rules" = [
      {
        matches = [
          {"node.name" = "~alsa_(output|input)\\..*Y8DGCDH9A84CDF.*(source|sink)$";}
        ];
        actions.update-props = {
          "audio.format" = "S32LE";
          "audio.rate" = 48000;
          "api.alsa.period-size" = 32;
          "api.alsa.headroom" = 16;
          "node.latency" = "32/48000";
        };
      }
    ];
  };
}
