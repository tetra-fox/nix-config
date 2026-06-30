{
  modules,
  lib,
  ...
}: {
  # auto-discover sibling language modules
  imports = lib.attrValues (removeAttrs modules.desktop.vscode.languages ["all"]);
}
