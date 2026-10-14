# tracks upstream releases faster than nixpkgs
inputs: final: _prev: {
  # voice mode dlopens a bundled audio-capture.node that needs libasound.so.2 and has no rpath.
  # RUNPATH doesn't reach a dlopened lib's deps, DT_RPATH does
  # TODO: drop once claude-code-nix ships alsa-lib (sadjow/claude-code-nix#258)
  claude-code = (final.callPackage "${inputs.claude-code-nix}/package.nix" {}).overrideAttrs {
    # alsa-lib is linux-only, referencing it on darwin fails eval
    runtimeDependencies = final.lib.optional final.stdenv.hostPlatform.isLinux final.alsa-lib;
    patchelfFlags = ["--force-rpath"];
  };
}
