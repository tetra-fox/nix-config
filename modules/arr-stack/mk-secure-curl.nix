# build a curl invocation that passes a secret api key via curl's --variable +
# --expand-header instead of interpolating it into argv. the key is read from a
# file at runtime (LoadCredential path or sops secret path), so it never lands in
# the nix store, the unit's environment, or the process arg list (where it would
# show up in `ps`/`/proc/<pid>/cmdline`).
#
# adapted from nixflix's lib/mk-secure-curl.nix.
#
#   mkSecureCurl "/run/credentials/foo.service/sonarr-key" {
#     url = "$BASE_URL/downloadclient";
#     method = "POST";
#     dataVar = "BODY";   # name of a shell var holding the json body
#   }
#
# dataVar is the NAME of a shell variable already holding the request body, not the
# body itself. the body is written to a temp file and sent with --data-binary @file,
# so a large or quote-heavy json payload never has to survive shell argv quoting.
{
  lib,
  pkgs,
}: keyFile: {
  url,
  method ? "GET",
  dataVar ? null,
  extraArgs ? "",
}: let
  methodArg = lib.optionalString (method != "GET") "-X ${method}";

  # --variable reads the key from the file into a curl variable, then
  # --expand-header substitutes it. :trim drops the trailing newline sops adds.
  keyArgs = "--variable apiKey@${lib.escapeShellArg keyFile} --expand-header \"X-Api-Key: {{apiKey:trim}}\"";

  dataArg = lib.optionalString (dataVar != null) ''--data-binary @"$CURL_DATA_FILE" -H "Content-Type: application/json"'';

  curlCmd = ''${lib.getExe pkgs.curl} -s ${keyArgs} ${methodArg} ${dataArg} ${extraArgs} "${url}"'';
in
  if dataVar == null
  then curlCmd
  else
    # wrap body-bearing requests in a function so the call-site redirect (e.g.
    # `... >/dev/null`) and exit status apply to the curl, while the temp body file
    # is removed right after rather than via an EXIT trap (a script makes several of
    # these calls and one EXIT trap would only clean the last).
    ''
      _secure_curl() {
        local CURL_DATA_FILE
        CURL_DATA_FILE=$(mktemp)
        printf '%s' "''$${dataVar}" > "$CURL_DATA_FILE"
        ${curlCmd}
        local rc=$?
        rm -f "$CURL_DATA_FILE"
        return $rc
      }
      _secure_curl''
