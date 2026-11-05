# the svelte plugin starts its lsp as `svelteserver` off claude's PATH. suffixed so a devshell's
# copy wins. the real binary stays at bin/.claude-wrapped, which the url handler execs
_inputs: final: prev: {
  claude-code = prev.claude-code.overrideAttrs (old: {
    postInstall =
      (old.postInstall or "")
      + ''
        wrapProgram $out/bin/claude --suffix PATH : ${final.lib.makeBinPath [final.svelte-language-server]}
      '';
  });
}
