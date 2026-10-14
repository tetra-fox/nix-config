{pkgs, ...}: {
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  # gpg-agent is one daemon shared across sessions with a fixed pinentry path, and
  # its env is from whichever session started it. so pick the qt theme per prompt
  # from the active seat0 session. values mirror uwsm/env-hyprland in home.nix
  programs.gnupg.agent.pinentryPackage = pkgs.writeShellApplication {
    name = "pinentry-dispatch";
    runtimeInputs = [pkgs.systemd pkgs.pinentry-qt];
    text = ''
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
