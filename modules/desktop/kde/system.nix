{
  pkgs,
  lib,
  ...
}: {
  # stock plasma 6; greetd stays the greeter, the wayland session is named "plasma"
  #
  # plasma6.enable pulls in more than the plasma session itself. most of it
  # (kwin, plasmashell, kded6, kcminit...) is bound to plasma-workspace.target
  # and only runs when actually logged into plasma, but a few things are
  # unconditional and machine-wide, reaching hyprland too:
  # - drkonqi's systemd-coredump hook: see below, pulled out explicitly
  # - environment.sessionVariables.XDG_CONFIG_DIRS gains ~/.config/kdedefaults
  #   for every login, not just plasma's
  # - dconf.enable + kde-gtk-config (plasma -> gtk settings sync) write into
  #   the same dconf database hyprland's gtk apps read; a plasma session can
  #   leak fonts/theme into hyprland afterward, fix is `dconf reset` (bit us
  #   2026-08-01, see modules/profiles/workstation home/system for dconf use)
  # - accounts-daemon, power-profiles-daemon, geoclue2, fwupd, orca all get
  #   switched on globally (mostly idle background daemons, low practical cost)
  services.desktopManager.plasma6.enable = true;

  # DrKonqi's crash dialog, hooked into systemd-coredump so it fires for a
  # crash in any session, hyprland included. plasma6.enable already wires this
  # (nixpkgs' plasma6.nix), so this is currently a no-op duplicate -- declared
  # explicitly on purpose, so if plasma6.enable is ever dropped this doesn't
  # silently vanish with it. remove this block on purpose when that day comes.
  systemd.packages = [pkgs.kdePackages.drkonqi];
  systemd.services."drkonqi-coredump-processor@".wantedBy = ["systemd-coredump@.service"];

  # plasma6.nix also wires pam_kwallet5 into the "login" and "kde" PAM
  # services (login is what greetd includes for every session, hyprland or
  # plasma). pam_kwallet5's session-close hook is a no-op upstream -- kwalletd
  # is only ever reaped by Plasma's own logout sequence, which hyprland
  # doesn't have, so every hyprland login left an orphaned kwalletd/ksecretd
  # pinning its session's cgroup, stuck in "closing" state in logind forever.
  # not using kwallet, so stop it from starting instead of teaching hyprland
  # to clean up after it.
  security.pam.services.login.kwallet.enable = lib.mkForce false;
  security.pam.services.kde.kwallet.enable = lib.mkForce false;
}
