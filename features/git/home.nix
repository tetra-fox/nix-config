{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.my.git.identity = {
    name = lib.mkOption {
      type = lib.types.str;
    };
    email = lib.mkOption {
      type = lib.types.str;
    };
    signingKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
  };

  config = let
    signingEnabled = config.my.git.identity.signingKey != null;
  in {
    home.packages = with pkgs; [
      git-credential-oauth
    ];

    programs.git = {
      enable = true;

      settings = {
        user = {
          name = config.my.git.identity.name;
          email = config.my.git.identity.email;
        } // lib.optionalAttrs signingEnabled {
          signingKey = config.my.git.identity.signingKey;
        };

        init.defaultBranch = "main";
        push.autoSetupRemote = true;

        credential = {
          helper = [
            "cache --timeout 21600"
            "oauth"
          ];
        };
      } // lib.optionalAttrs signingEnabled {
        gpg = {
          format = "ssh";
        };

        "gpg \"ssh\"" = {
          program = "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}";
        };

        commit = {
          gpgsign = true;
        };
      };
    };
  };
}
