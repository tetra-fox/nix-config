{pkgs, ...}: {
  programs.vscodium.profiles.default = {
    extensions = with pkgs.open-vsx; [
      svelte.svelte-vscode
    ];
    userSettings = {
      "[svelte]" = {
        "editor.defaultFormatter" = "oxc.oxc-vscode";
      };
      "svelte.enable-ts-plugin" = true;
    };
  };
}
