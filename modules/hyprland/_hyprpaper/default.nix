{config, ...}: {
  # wallpaper + splash are set by stylix; we only need to preload the image
  services.hyprpaper = {
    enable = true;
    settings.preload = [(toString config.stylix.image)];
  };
}
