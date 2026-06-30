{username, ...}: {
  programs.wireshark = {
    enable = true;
    dumpcap.enable = true;
    usbmon.enable = true;
  };

  users.users.${username}.extraGroups = ["wireshark"];
}
