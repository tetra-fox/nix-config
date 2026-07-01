{lib}: rec {
  # { _sops = "apps/sonarr_api_key" } marks a value to resolve via placeholderFn
  isSopsRef = v: builtins.isAttrs v && v ? _sops;

  # mkServarrEnv "SONARR" { auth.method = "Forms"; postgres.port = 5432; }
  #   => { SONARR__AUTH__METHOD = "Forms"; SONARR__POSTGRES__PORT = "5432"; }
  mkServarrEnv = placeholderFn: prefix: settings: let
    flatten = path: value:
      if value == null
      then []
      else if isSopsRef value
      then [
        {
          name = lib.toUpper (lib.concatStringsSep "__" ([prefix] ++ path));
          value = placeholderFn value._sops;
        }
      ]
      else if builtins.isAttrs value
      then lib.concatLists (lib.mapAttrsToList (k: v: flatten (path ++ [k]) v) value)
      else [
        {
          name = lib.toUpper (lib.concatStringsSep "__" ([prefix] ++ path));
          value =
            if builtins.isBool value
            then lib.boolToString value
            else toString value;
        }
      ];
  in
    lib.listToAttrs (flatten [] settings);

  collectSopsRefs = value:
    if isSopsRef value
    then [value._sops]
    else if builtins.isAttrs value
    then lib.concatLists (lib.mapAttrsToList (_: collectSopsRefs) value)
    else if builtins.isList value
    then lib.concatLists (map collectSopsRefs value)
    else [];
}
