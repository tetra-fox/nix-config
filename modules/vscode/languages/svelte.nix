{pkgs, ...}: {
  programs.vscode.profiles.default = {
    extensions = with pkgs.open-vsx; [
      svelte.svelte-vscode
    ];
    userSettings = {
      "[svelte]" = {
        "editor.defaultFormatter" = "svelte.svelte-vscode";
      };
    };
  };
}
