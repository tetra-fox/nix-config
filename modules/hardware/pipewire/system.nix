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

  # extraGroups only renders a group into /etc/group if it's also declared
  # under users.groups; without this, "realtime" was a dangling group name,
  # so security.pam.loginLimits @realtime entries silently matched no one.
  users.groups.realtime = {};

  users.users.${username}.extraGroups = [
    "audio"
    "realtime"
  ];
}
