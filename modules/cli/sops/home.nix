# sops resolves the operator's age key through go's os.UserConfigDir, which is
# ~/.config on linux but ~/Library/Application Support on darwin. point it at the
# XDG path on both, so the location .sops.yaml documents is the one sops actually
# reads instead of the mac looking somewhere the key was never written
{config, ...}: {
  home.sessionVariables.SOPS_AGE_KEY_FILE = "${config.xdg.configHome}/sops/age/keys.txt";
}
