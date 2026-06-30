{pkgs, ...}: {
  programs.vscodium.profiles.default = {
    extensions = with pkgs.open-vsx; [
      foxundermoon.shell-format
      timonwong.shellcheck
    ];
    userSettings = {
      "shellformat.path" = "${pkgs.shfmt}/bin/shfmt";
      "shellcheck.executablePath" = "${pkgs.shellcheck}/bin/shellcheck";
      "[shellscript]" = {
        "editor.defaultFormatter" = "foxundermoon.shell-format";
      };
    };
  };
}
