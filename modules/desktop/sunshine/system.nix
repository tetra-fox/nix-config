{
  lib,
  pkgs,
  ...
}: {
  # the module also turns on avahi publishing (mkDefault) so moonlight can discover this host,
  # and creates sink-sunshine-* virtual sinks that become the default output while streaming
  services.sunshine = {
    enable = true;
    # the default build sets SUNSHINE_ENABLE_CUDA=false, and nvenc needs cuda
    package = pkgs.sunshine.override {cudaSupport = true;};
    openFirewall = true;
  };

  # its unit hangs off graphical-session.target, which plasma's logout leaves running, so a
  # relogin never starts it again. home.nix starts it per session through my.autostart instead.
  # disabling masks /etc/systemd/user/sunshine.service, and the home unit of the same name in
  # ~/.config/systemd/user comes first in the user search path
  systemd.user.services.sunshine.enable = lib.mkForce false;
}
