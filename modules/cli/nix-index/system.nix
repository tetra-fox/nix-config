{inputs, ...}: {
  imports = [inputs.nix-index-database.nixosModules.nix-index];
  programs.nix-index-database = {
    enable = true;
    comma.enable = true;
  };
}
