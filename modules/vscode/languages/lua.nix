{pkgs, ...}: {
  programs.vscode.profiles.default = {
    extensions = with pkgs.open-vsx; [
      sumneko.lua
    ];
    userSettings = {
      "Lua.misc.executablePath" = "${pkgs.lua-language-server}/bin/lua-language-server";
      "[lua]" = {
        "editor.defaultFormatter" = "sumneko.lua";
      };
    };
  };
}
