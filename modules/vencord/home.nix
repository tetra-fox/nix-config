{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.vesktop = {
    enable = true;

    # bundle pkgs.vencord from our pinned nixpkgs instead of letting vesktop
    # fetch vencord at runtime, so the mod tracks the flake lock
    vencord.useSystem = true;

    # vesktop app shell settings -> ~/.config/vesktop/settings.json
    settings = {
      # rich presence is handled by the standalone services.arrpc below.
      # leaving vesktop's own arRPC on too would put two listeners on the
      # discord-ipc socket, so keep it off here
      arRPC = false;

      minimizeToTray = true;
      tray = true;
      customTitleBar = true;
      hardwareAcceleration = true;
      discordBranch = "stable";
      checkUpdates = false;
    };

    # vencord mod settings -> ~/.config/vesktop/settings/settings.json
    vencord.settings = {
      # the mod itself is pinned, so its updater has nothing to do
      autoUpdate = false;
      autoUpdateNotification = false;
      notifyAboutUpdates = false;

      plugins = {
        ClearURLs.enabled = true;
        FixYoutubeEmbeds.enabled = true;
      };
    };
  };

  # vesktop shows its welcome wizard whenever the firstLaunch key is absent
  # from ~/.config/vesktop/state.json (an Object.hasOwn check). state.json is
  # vesktop's mutable runtime state (window bounds, updater info) so it is not
  # managed by the HM module and must not be a read-only store symlink. seed
  # the key once if the file is absent, leaving vesktop free to write the rest
  home.activation.vesktopFirstLaunch = lib.hm.dag.entryAfter ["writeBoundary"] ''
    state="${config.xdg.configHome}/vesktop/state.json"
    if [ ! -e "$state" ]; then
      run mkdir -p "$(dirname "$state")"
      run ${pkgs.coreutils}/bin/install -m644 /dev/stdin "$state" <<< '{"firstLaunch":false}'
    fi
  '';

  # rich presence bridge for the modded client. WantedBy graphical-session.target
  # alone would not start it here because hyprland's HM systemd integration is
  # off (modules/hyprland/home.nix); point it at the uwsm session target that
  # app2unit actually brings up, the same one quickshell binds to
  services.arrpc = {
    enable = true;
    systemdTarget = "wayland-session@hyprland.desktop.target";
  };
}
