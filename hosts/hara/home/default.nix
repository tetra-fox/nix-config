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
    features.cursor.home
    features.fastfetch.home
    features.firefox.home
    features.fonts.home
    features.git.home
    features.helix.home
    features.hyprland.home
    features.kitty.home
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
    NIXOS_OZONE_WL = "1"; # tell electron to use wayland.
    QT_QPA_PLATFORMTHEME = "qt6ct";
  };

  systemd.user.sessionVariables = config.home.sessionVariables;

  # XDG portal color-scheme — GTK4, Qt6, Firefox, Chromium query this
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

    (bottles.override { removeWarningPopup = true; })

    # system
    kdePackages.dolphin
    overskride

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
