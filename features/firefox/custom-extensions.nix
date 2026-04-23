{ pkgs }:
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
    meta = with pkgs.lib; {
      homepage = "https://addons.mozilla.org/en-US/firefox/addon/scam/";
      license = licenses.mit;
    };
  };

  matte-black = buildFirefoxXpiAddon {
    pname = "matte-black-v1";
    version = "2024.1.24";
    addonId = "{f2b832a9-f0f5-4532-934c-74b25eb23fb9}";
    url = "https://addons.mozilla.org/firefox/downloads/file/4226379/matte_black_v1-2024.1.24.xpi";
    sha256 = "6a3c1f592bb1b1ebc411580b26ab25fb826aa67e23123720e41afdb7a271039a";
    meta = with pkgs.lib; {
      homepage = "https://addons.mozilla.org/en-US/firefox/addon/matte-black-v1/";
      license = licenses.cc-by-nc-sa-30;
    };
  };

  surge = buildFirefoxXpiAddon {
    pname = "surge";
    version = "2.0.1";
    addonId = "surge@surge-downloader.com";
    url = "https://addons.mozilla.org/firefox/downloads/file/4765075/surge-2.0.1.xpi";
    sha256 = "ada8c80bccebaf7ef33518a16ad2a08f212dc1895000d52791eda6658d1defb9";
    meta = with pkgs.lib; {
      homepage = "https://addons.mozilla.org/en-US/firefox/addon/surge/";
      license = licenses.mit;
    };
  };

  json-alexander = buildFirefoxXpiAddon {
    pname = "json-alexander";
    version = "1.1.0";
    addonId = "json-alexander@local";
    url = "https://raw.githubusercontent.com/wesbos/JSON-Alexander/main/json-alexander.zip";
    sha256 = "0rdmraqnaa16asx577nams6vibv3vg19vikgyac0dsz941p94721";
    meta = with pkgs.lib; {
      homepage = "https://github.com/wesbos/JSON-Alexander";
      license = licenses.mit;
    };
  };
}
