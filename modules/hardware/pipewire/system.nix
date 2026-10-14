{username, ...}: {
  services.pipewire = {
    enable = true;
    audio.enable = true;
    wireplumber.enable = true;
    pulse.enable = true;
    jack.enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
  };

  security.rtkit.enable = true;

  # extraGroups doesn't create groups, without this @realtime loginLimits match no one
  users.groups.realtime = {};

  users.users.${username}.extraGroups = [
    "audio"
    "realtime"
  ];
}
