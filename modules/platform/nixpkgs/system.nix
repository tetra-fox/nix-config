{pkgs, ...}: {
  nixpkgs = {
    config = {
      allowUnfree = true;
    };
    overlays = [
      (final: prev: {
        inherit
          (prev.lixPackageSets.stable)
          nixpkgs-review
          nix-eval-jobs
          nix-fast-build
          colmena
          ;
      })

      (final: prev: {
        pythonPackagesExtensions =
          prev.pythonPackagesExtensions
          ++ [
            (pyFinal: pyPrev: {
              # TODO: remove when hydra bumps nixos-unstable
              # cheetah3 -> ct3 so sabnzbd builds
              cheetah3 = pyPrev.cheetah3.overridePythonAttrs (_: {dontCheckPythonMetadata = true;});
            })
          ];
      })
    ];
  };

  nix.package = pkgs.lixPackageSets.stable.lix;
}
