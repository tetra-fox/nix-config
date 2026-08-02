{pkgs, ...}: {
  programs.vscodium.profiles.default = {
    extensions = with pkgs.open-vsx; [
      dbaeumer.vscode-eslint
      denoland.vscode-deno
      yoavbls.pretty-ts-errors
    ];
    userSettings = {
      "deno.path" = "${pkgs.deno}/bin/deno";
      "[javascript]" = {
        "editor.defaultFormatter" = "oxc.oxc-vscode";
      };
      "[typescript]" = {
        "editor.defaultFormatter" = "oxc.oxc-vscode";
      };
    };
  };
}
