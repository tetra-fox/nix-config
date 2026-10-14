{
  pkgs,
  lib,
  ...
}: {
  # machine-wide effects that reach hyprland too: drkonqi's coredump hook (below),
  # XDG_CONFIG_DIRS gains ~/.config/kdedefaults for every login, kde-gtk-config
  # writes the shared dconf db (a plasma session can leak fonts/theme into hyprland,
  # fix is `dconf reset`), and accounts-daemon, power-profiles-daemon, geoclue2,
  # fwupd and orca are enabled globally
  services.desktopManager.plasma6.enable = true;

  # duplicates what plasma6.nix wires, so the crash dialog stays if plasma6 is dropped
  systemd.packages = [pkgs.kdePackages.drkonqi];
  systemd.services."drkonqi-coredump-processor@".wantedBy = ["systemd-coredump@.service"];

  # greetd uses "login" for every session, and kwalletd is only reaped by plasma's
  # logout, so each hyprland login leaves a session stuck "closing" in logind
  security.pam.services.login.kwallet.enable = lib.mkForce false;
  security.pam.services.kde.kwallet.enable = lib.mkForce false;
}
