# claude-code is packaged out of the claude-code-nix input's package.nix rather than
# nixpkgs so it tracks upstream releases faster than the nixpkgs bump cycle.
inputs: final: _prev: {
  # voice mode dlopens a bundled audio-capture.node that needs libasound.so.2 and has no rpath,
  # an exe's RUNPATH doesn't reach a dlopened lib's deps but DT_RPATH does, hence --force-rpath
  # TODO: drop once claude-code-nix ships alsa-lib (sadjow/claude-code-nix#258)
  claude-code = (final.callPackage "${inputs.claude-code-nix}/package.nix" {}).overrideAttrs {
    runtimeDependencies = [final.alsa-lib];
    patchelfFlags = ["--force-rpath"];
  };
}
