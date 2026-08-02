{
  config,
  pkgs,
  ...
}: {
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        # sessions come from the displayManager registry, not /run/current-system/sw,
        # so session packages show up even when they aren't in systemPackages
        command = "${pkgs.tuigreet}/bin/tuigreet --time-format '%A, %B %e - %T' --remember --remember-session -g 'hey kiddo!' --greet-align left --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";
        user = "greeter";
      };
    };
  };

  # without this stack greetd spams errors + bootlogs onto the tty
  # https://github.com/apognu/tuigreet/issues/68#issuecomment-1586359960
  systemd.services.greetd.serviceConfig = {
    Type = "idle";
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "journal";
    TTYReset = true;
    TTYVHangup = true;
    TTYVTDisallocate = true;
  };
}
