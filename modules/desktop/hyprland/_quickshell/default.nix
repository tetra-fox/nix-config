{
  pkgs,
  lib,
  main_mod,
  ...
}: let
  material-symbols-filled = import ./material-symbols-filled.nix {inherit pkgs;};

  shell = pkgs.runCommand "quickshell-config" {} ''
    cp -r ${./shell} $out
  '';
in {
  programs.quickshell = {
    enable = true;
    package = pkgs.quickshell;
    configs.default = shell;
    systemd = {
      enable = true;
      target = "wayland-session@hyprland.desktop.target";
    };
  };

  # config lives in the read-only nix store, file watcher has nothing useful to do
  systemd.user.services.quickshell.Service.Environment = ["QS_DISABLE_FILE_WATCHER=1"];

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
    selawik
  ];

  wayland.windowManager.hyprland.extraLuaFiles.quickshell.content =
    pkgs.replaceVars ./hyprland-binds.lua {inherit main_mod;};

  # hide tray applets that duplicate quickshell functionality (networkmanager, from cosmic)
  xdg.configFile."autostart/nm-applet.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';
}
