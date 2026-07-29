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

      (final: prev: {
        # TODO: remove when hydra bumps nixos-unstable past nixpkgs commit 1dce89d
        # (https://github.com/NixOS/nixpkgs/pull/545542). cmake 4.3 hard-errors if
        # CUDAToolkit_ROOT doesn't contain nvcc instead of falling back to PATH like
        # 4.1 did, and nixpkgs' generic cuda setup hook builds that var without nvcc's
        # dir in it. unsetting it restores the PATH fallback; cuda_nvcc is already a
        # nativeBuildInput regardless. https://github.com/NixOS/nixpkgs/issues/545286
        ollama-cuda = prev.ollama-cuda.overrideAttrs (old: {
          preBuild =
            ''
              unset CUDAToolkit_ROOT
            ''
            + old.preBuild;
        });
      })
    ];
  };

  nix.package = pkgs.lixPackageSets.stable.lix;
}
