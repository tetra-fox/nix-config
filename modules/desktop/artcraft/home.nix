{inputs, ...}: {
  imports = [inputs.artcraft.homeManagerModules.default];

  programs.craftapps = {
    enable = true;
    apps.photocraft.enable = true;
    apps.lightcraft.enable = true;
    apps.filmcraft.enable = true;
    apps.vectorcraft.enable = true;
    apps.effectcraft.enable = true;
  };
}
