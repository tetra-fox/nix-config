{
  pkgs,
  lib,
  ...
}:
let
  buildFirefoxXpiAddon = pkgs.nur.repos.rycee.lib.mozilla.mkBuildMozillaXpiAddon {
    inherit (pkgs) fetchurl stdenv;
  };
in
{
  scam = buildFirefoxXpiAddon {
    pname = "scam";
    version = "1.3.1";
    addonId = "{4071edd9-4815-443f-bcea-55fa59ce6c2a}";
    url = "https://addons.mozilla.org/firefox/downloads/file/3960567/scam-1.3.1.xpi";
    sha256 = "sha256:efeb2291b62f93b79e2c836a0f7a2cbbb324123bd4baa1899c05d1f183e7b010";
    meta = with lib; {
      homepage = "https://addons.mozilla.org/en-US/firefox/addon/scam/";
      license = licenses.mit;
    };
  };
}
