{config, ...}: {
  # wallpaper + splash are set by stylix; we only need to preload the image
  services.hyprpaper = {
    enable = true;
    settings.preload = [(toString config.stylix.image)];
    # default is graphical-session.target, which plasma reaches too; hyprpaper
    # then talks to kwin and segfaults in hyprtoolkit's layer-surface configure
    systemdTarget = "wayland-session@hyprland.desktop.target";
  };
}
