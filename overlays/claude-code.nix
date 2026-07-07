# claude-code is packaged out of the claude-code-nix input's package.nix rather than
# nixpkgs so it tracks upstream releases faster than the nixpkgs bump cycle.
inputs: final: _prev: {
  claude-code = final.callPackage "${inputs.claude-code-nix}/package.nix" {};
}
