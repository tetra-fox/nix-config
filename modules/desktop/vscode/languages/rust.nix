{pkgs, ...}: {
  programs.vscodium.profiles.default = {
    extensions =
      (with pkgs.open-vsx; [
        rust-lang.rust-analyzer
      ])
      ++ [
        # nix-vscode-extensions pins vscode-lldb to an unbuildable version;
        # use nixpkgs' own properly-wrapped build instead
        pkgs.vscode-extensions.vadimcn.vscode-lldb
      ];
    userSettings = {
      "rust-analyzer.server.path" = "${pkgs.rust-analyzer}/bin/rust-analyzer";
      "[rust]" = {
        "editor.defaultFormatter" = "rust-lang.rust-analyzer";
      };
      "lldb.library" = "${pkgs.lldb}/lib/liblldb.so";
    };
  };
}
