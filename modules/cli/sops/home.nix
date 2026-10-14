# go's os.UserConfigDir is ~/Library/Application Support on darwin, use XDG on both
{config, ...}: {
  home.sessionVariables.SOPS_AGE_KEY_FILE = "${config.xdg.configHome}/sops/age/keys.txt";
}
