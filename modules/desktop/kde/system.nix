{
  pkgs,
  lib,
  ...
}: {
  services = {
    # machine-wide effects that reach hyprland too: drkonqi's coredump hook,
    # XDG_CONFIG_DIRS gains ~/.config/kdedefaults for every login, kde-gtk-config
    # writes the shared dconf db (a plasma session can leak fonts/theme into hyprland,
    # fix is `dconf reset`), and geoclue2 is enabled globally
    desktopManager.plasma6.enable = true;

    orca.enable = false;
    power-profiles-daemon.enable = false;
    # plasma6.nix sets it without mkDefault. only systemsettings' users page reads it
    accounts-daemon.enable = lib.mkForce false;
  };

  programs.kde-pim.enable = false;

  # meta+middle click toggles maximize, kwin finds it through QT_PLUGIN_PATH
  environment.systemPackages = [(pkgs.callPackage ./_maximize-toggle {})];

  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    elisa
    khelpcenter
    krdp
    plasma-keyboard
    qtvirtualkeyboard
    union
    kwin-x11
    aurorae
    qrca
  ];

  # greetd uses "login" for every session, and kwalletd is only reaped by plasma's
  # logout, so each hyprland login leaves a session stuck "closing" in logind
  security.pam.services.login.kwallet.enable = lib.mkForce false;
  security.pam.services.kde.kwallet.enable = lib.mkForce false;
}
