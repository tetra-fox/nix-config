{pkgs, ...}: {
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  # plasma6.nix sets programs.gnupg.agent.pinentryPackage = mkDefault pinentry-qt
  # globally. gpg-agent is one long-lived daemon shared across logins, and its
  # pinentry-program path is static (no per-request IPC to swap it), so hyprland
  # can't get its own pinentry the way the qt env vars got scoped via uwsm/env-*.
  # instead: wrap the same pinentry-qt, and have the wrapper check loginctl for
  # the actually-active session at prompt time (not gpg-agent's own inherited
  # env, which may be stale from whichever session started it) and apply
  # hyprland's qt theme env only when that session is hyprland. values mirror
  # modules/desktop/hyprland/home.nix's uwsm/env-hyprland.
  programs.gnupg.agent.pinentryPackage = pkgs.writeShellApplication {
    name = "pinentry-dispatch";
    runtimeInputs = [pkgs.systemd pkgs.pinentry-qt];
    text = ''
      # any failure here (no seat0, no active session, loginctl missing) just
      # falls through to plain pinentry-qt rather than breaking gpg outright
      active_session="$(loginctl show-seat seat0 -p ActiveSession --value 2>/dev/null || true)"
      desktop=""
      if [ -n "$active_session" ]; then
        desktop="$(loginctl show-session "$active_session" -p Desktop --value 2>/dev/null || true)"
      fi
      if [[ "$desktop" == *hyprland* ]]; then
        export QT_QPA_PLATFORMTHEME=qt5ct
        export QT_STYLE_OVERRIDE=kvantum
      fi
      exec pinentry-qt "$@"
    '';
  };

  security.pam.services.quickshell = {};

  xdg.portal = {
    enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
  };

  environment.systemPackages = with pkgs; [
    qt5.qtwayland
    qt6.qtwayland
    libnotify
  ];
}
