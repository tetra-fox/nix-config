{pkgs, ...}: {
  programs.vscodium.profiles.default = {
    extensions = with pkgs.open-vsx; [
      golang.go
    ];
    userSettings = {
      "go.useLanguageServer" = true;
      "go.toolsManagement.autoUpdate" = false;
      "go.alternateTools" = {
        "go" = "${pkgs.go}/bin/go";
        "gopls" = "${pkgs.gopls}/bin/gopls";
        "dlv" = "${pkgs.delve}/bin/dlv";
        "gofumpt" = "${pkgs.gofumpt}/bin/gofumpt";
        "golangci-lint" = "${pkgs.golangci-lint}/bin/golangci-lint";
      };
      "go.formatTool" = "gofumpt";
      "go.lintTool" = "golangci-lint";
      "go.lintOnSave" = "package";
      "gopls" = {
        "formatting.gofumpt" = true;
      };
      "[go]" = {
        "editor.defaultFormatter" = "golang.go";
        "editor.codeActionsOnSave" = {
          "source.organizeImports" = "explicit";
        };
      };
    };
  };
}
