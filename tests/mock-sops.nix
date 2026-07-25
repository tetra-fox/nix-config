# stand-in for sops-nix in the VM tests: declares the option surface the service modules
# touch (secrets.<n>.path/owner, templates.<n>.content/path, placeholder.<n>) and
# materializes every secret as a world-readable mock file under /etc. the tests assert
# behavior, not secrecy; every secret's value is the literal string "mockpass".
{
  config,
  lib,
  ...
}: {
  options.sops = {
    secrets = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({name, ...}: {
        options = {
          path = lib.mkOption {
            type = lib.types.str;
            default = "/etc/mock-sops/${name}";
          };
          owner = lib.mkOption {
            type = lib.types.str;
            default = "root";
          };
          group = lib.mkOption {
            type = lib.types.str;
            default = "root";
          };
          mode = lib.mkOption {
            type = lib.types.str;
            default = "0400";
          };
        };
      }));
      default = {};
    };

    templates = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({name, ...}: {
        options = {
          content = lib.mkOption {
            type = lib.types.lines;
            default = "";
          };
          path = lib.mkOption {
            type = lib.types.str;
            default = "/etc/mock-sops-templates/${name}";
          };
          owner = lib.mkOption {
            type = lib.types.str;
            default = "root";
          };
          group = lib.mkOption {
            type = lib.types.str;
            default = "root";
          };
        };
      }));
      default = {};
    };

    placeholder = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
    };
  };

  config = {
    sops.placeholder = lib.mapAttrs (name: _: "mock-placeholder-${name}") config.sops.secrets;

    environment.etc =
      # no trailing newline: consumers read the file content as the literal value
      lib.mapAttrs' (name: _: lib.nameValuePair "mock-sops/${name}" {text = "mockpass";})
      config.sops.secrets
      // lib.mapAttrs' (name: t: lib.nameValuePair "mock-sops-templates/${name}" {text = t.content;})
      config.sops.templates;
  };
}
