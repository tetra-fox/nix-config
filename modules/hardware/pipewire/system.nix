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

  # apps that set SCHED_FIFO themselves (jack clients, the ableton launcher's
  # `chrt -r 10` probe) need RLIMIT_RTPRIO, rtkit alone doesn't grant it
  security.pam.loginLimits = [
    {
      domain = "@realtime";
      item = "rtprio";
      type = "-";
      value = "99";
    }
    {
      domain = "@realtime";
      item = "memlock";
      type = "-";
      value = "unlimited";
    }
  ];

  # extraGroups doesn't create groups, without this the limits above match no one
  users.groups.realtime = {};

  users.users.${username}.extraGroups = [
    "audio"
    "realtime"
  ];
}
