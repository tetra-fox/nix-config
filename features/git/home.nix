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
      type = lib.types.str;
    };
  };

  config = {
    home.packages = with pkgs; [
      git-credential-oauth
    ];

    programs.git = {
      enable = true;

      settings = {
        user = {
          name = config.my.git.identity.name;
          email = config.my.git.identity.email;
          signingKey = config.my.git.identity.signingKey;
        };

        init.defaultBranch = "main";
        push.autoSetupRemote = true;

        gpg = {
          format = "ssh";
        };

        "gpg \"ssh\"" = {
          program = "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}";
        };

        commit = {
          gpgsign = true;
        };

        credential = {
          helper = [
            "cache --timeout 21600"
            "oauth"
          ];
        };
      };
    };
  };
}
