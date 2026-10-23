# points jellyfin's LDAP plugin at the site's authentik outpost. the plugin keeps runtime
# state (LdapUsers, EnabledFolders) in the same file, so only the connection fields are
# owned here, rewritten before every start
{
  config,
  lib,
  pkgs,
  topo,
  ...
}: let
  ldap = topo.authLdap;
  configFile = "${config.services.jellyfin.dataDir}/plugins/configurations/LDAP-Auth.xml";

  # group names from modules/services/authentik/blueprints/groups.yaml. ldap memberOf
  # only carries direct memberships, so admins need superadmin directly
  settings = pkgs.writeText "ldap-auth-settings.json" (builtins.toJSON {
    LdapServer = ldap.ip;
    LdapPort = ldap.port;
    # plaintext on the internal VLAN, same trust model as the outpost's listener
    UseSsl = false;
    UseStartTls = false;
    LdapBindUser = "cn=${ldap.bindUser},ou=users,${ldap.baseDn}";
    LdapBaseDn = ldap.baseDn;
    LdapSearchFilter = "(memberOf=cn=jellyfin_users,ou=groups,${ldap.baseDn})";
    LdapAdminFilter = "(memberOf=cn=superadmin,ou=groups,${ldap.baseDn})";
    LdapUidAttribute = "uid";
    LdapUsernameAttribute = "cn";
    CreateUsersFromLdap = true;
  });

  # the password comes from a file so it never lands in an argv
  patch = pkgs.writeText "ldap-auth-patch.py" ''
    import json, sys
    import xml.etree.ElementTree as ET

    path, settings_path, password_path = sys.argv[1:]
    tree = ET.parse(path)
    root = tree.getroot()
    settings = json.load(open(settings_path))
    settings["LdapBindPassword"] = open(password_path).read().strip()
    for key, value in settings.items():
        el = root.find(key)
        if el is None:
            el = ET.SubElement(root, key)
        el.text = str(value).lower() if isinstance(value, bool) else str(value)
    tree.write(path, xml_declaration=True, encoding="utf-8")
  '';
in {
  config = lib.mkIf (ldap != null) {
    sops.secrets."jellyfin/ldap_bind_password" = {
      owner = config.services.jellyfin.user;
      restartUnits = ["jellyfin.service"];
    };

    # the plugin writes its defaults on first load, so a fresh install picks these up on
    # the start after that
    systemd.services.jellyfin.preStart = ''
      if [ -e ${lib.escapeShellArg configFile} ]; then
        ${pkgs.python3}/bin/python3 ${patch} ${lib.escapeShellArg configFile} ${settings} \
          ${config.sops.secrets."jellyfin/ldap_bind_password".path}
      fi
    '';
  };
}
