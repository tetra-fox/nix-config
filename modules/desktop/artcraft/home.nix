{inputs, ...}: {
  imports = [inputs.artcraft.homeManagerModules.default];

  programs.craftapps = {
    enable = true;
    apps = {
      photocraft.enable = true;
      lightcraft.enable = true;
      filmcraft.enable = true;
      vectorcraft.enable = true;
      effectcraft.enable = true;
    };
  };
}
