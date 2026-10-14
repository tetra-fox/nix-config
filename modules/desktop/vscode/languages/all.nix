{
  modules,
  lib,
  ...
}: {
  imports = lib.attrValues (removeAttrs modules.desktop.vscode.languages ["all"]);
}
