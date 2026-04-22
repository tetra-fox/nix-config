{
  pkgs,
  inputs,
  config,
  username,
  features,
  ...
}:

{
  imports = [
    features.cosmic.home
    features.vscode.home
    features.fastfetch.home
    features.firefox.home
    features.fonts.home
    features.git.home
    features.helix.home
    features.hyprland.home
    features.kitty.home
    features.nvidia.home
    features.obs-studio.home
    # features.openrgb.home
    features.ssh.home
    features.starship.home
    features.steam.home
    features.surge-dm.home
    features.walker.home
    features.zsh.home
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  my.git.identity = {
    name = "tetra";
    email = "me@tetra.cool";
    signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHseoQ278Qrc45S8MUE8vwXnmdxd8OiWXViK0yHYYELz";
  };

  home.sessionVariables = {
    # electron/ozone
    NIXOS_OZONE_WL = "1";

    # xdg session
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_DESKTOP = "Hyprland";

    # gtk
    GDK_BACKEND = "wayland,x11,*";
    CLUTTER_BACKEND = "wayland";

    # qt
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
  };

  systemd.user.sessionVariables = config.home.sessionVariables;

  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  home.packages = with pkgs; [
    # apps
    # firefox
    telegram-desktop
    discord
    signal-desktop
    vlc
    cider-2
    bitwig-studio
    tenacity
    vrcx

    (prismlauncher.override {
      jdks = [
        javaPackages.compiler.temurin-bin.jre-25
        javaPackages.compiler.temurin-bin.jre-21
        javaPackages.compiler.temurin-bin.jre-17
        javaPackages.compiler.temurin-bin.jre-8
      ];
    })

    (bottles.override { removeWarningPopup = true; })

    # system
    kdePackages.dolphin
    vulkan-tools # vulkaninfo, vkcube

    #dev
    rustup
    gnumake
    pnpm
    nodejs
    gcc
    sqlite
    nixfmt
    dbeaver-bin
    python3
  ];

  # paws off!
  home.stateVersion = "25.11";
}
