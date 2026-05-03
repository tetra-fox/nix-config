{pkgs, ...}: {
  programs.vscode.profiles.default = {
    extensions = with pkgs.open-vsx; [
      matthewpi.caddyfile-support
    ];
    userSettings = {
      "caddyfile.executable" = "${pkgs.caddy}/bin/caddy";
    };
  };
}
