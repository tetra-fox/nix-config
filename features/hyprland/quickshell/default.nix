{
  pkgs,
  lib,
  main_mod,
  ...
}: let
  material-symbols-filled = import ./material-symbols-filled.nix {inherit pkgs;};
in {
  programs.quickshell = {
    enable = true;
    package = pkgs.quickshell;
    configs.default = ./shell;
    systemd = {
      enable = true;
      target = "wayland-session@hyprland.desktop.target";
    };
  };

  home.activation.restartQuickshell = lib.hm.dag.entryAfter ["reloadSystemd"] ''
    ${pkgs.systemd}/bin/systemctl --user restart quickshell.service 2>/dev/null || true
  '';

  home.packages = with pkgs; [
    overskride
    iproute2
    iw
    material-symbols-filled
    networkmanager
    wl-clipboard
  ];

  wayland.windowManager.hyprland.settings = {
    bind = [
      "${main_mod},ESCAPE,global,quickshell:lock"
      "${main_mod}&L_SHIFT,ESCAPE,global,quickshell:logout"
      "L_ALT,TAB,global,quickshell:switcher-next"
      "L_ALT&L_SHIFT,TAB,global,quickshell:switcher-prev"
    ];

    layerrule = [
      "match:namespace quickshell-bar,blur on,ignore_alpha 0.1"
      "match:namespace quickshell-popup,blur on,ignore_alpha 0.1"
      "match:namespace quickshell-notifications,blur on,ignore_alpha 0.1"
      "match:namespace quickshell-switcher,blur on,ignore_alpha 0.1"
    ];
  };

  # hide tray applets that duplicate quickshell functionality (networkmanager, from cosmic)
  xdg.configFile."autostart/nm-applet.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';
}
