{ pkgs, ... }:

{
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time-format '%A, %B %e - %T' --remember --remember-session -g 'hey kiddo!' --greet-align left --sessions /run/current-system/sw/share/wayland-sessions";
        user = "greeter";
      };
    };
  };
}
