{
  config,
  lib,
  inputs,
  ...
}: let
  inherit (config.lab) site appliances;
  secret = name: config.lib.asterisk.secret config.sops.secrets."pbx/${name}".path;

  # the phones sit on their own vlan and reach the pbx through the router
  phoneCidr = "192.168.100.0/24";

  extensions = {
    "273".name = "creek";
    "567".name = "lori";
    "838".name = "tetra";
    "839".name = "tetra_2";
  };

  # home assistant's voip integration, which answers with assist and calls phones itself
  haNumber = "2";
in {
  imports = [inputs.asterix.nixosModules.default];

  sops.secrets =
    lib.mapAttrs' (number: _: {
      name = "pbx/sip_${number}";
      value = {
        reloadUnits = ["asterisk.service"];
        # the provisioning files embed the passwords
        restartUnits = ["asterix-provisioning.service"];
      };
    })
    extensions;

  services.asterix = {
    enable = true;
    openFirewall = true;

    networks = {
      server = {
        interface = site.serverInterface;
        address = site.hostIp;
        subnets = [phoneCidr];
      };
      # home assistant only talks to the pbx on its internal leg
      internal = {
        interface = site.internalInterface;
        address = site.internalIp;
        subnets = ["${appliances.haosIp}/32"];
      };
    };

    extensions =
      lib.mapAttrs (number: e: {
        inherit (e) name;
        network = "server";
        password = secret "sip_${number}";
      })
      extensions;

    featureCodes = {
      dnd = "*76";
      record = "*1";
      forward = {
        always = {
          on = "*72";
          off = "*73";
        };
        busy = {
          on = "*90";
          off = "*91";
        };
        noAnswer = {
          on = "*52";
          off = "*53";
        };
      };
    };

    parking.number = "70";

    phones = {
      network = "server";
      cisco.timeZone = "Pacific Standard/Daylight Time";
      grandstream.timeZone = "PST8PDT,M3.2.0/02:00:00,M11.1.0/02:00:00";

      # 273 is a grandstream set up by hand
      devices = {
        "567" = {
          model = "grandstream-ht801";
          mac = throw "TODO: mac of lori's ht801";
        };
        "838" = {
          model = "cisco-7962g";
          mac = "3c:0e:23:6c:b6:d1";
        };
        "839" = {
          model = "cisco-7962g";
          mac = "1c:1d:86:c4:b5:39";
        };
      };
    };
  };

  # home assistant has no sip account, so it is let in by address
  services.asterisk.pjsip.endpoints.homeass = {
    context = "pbx-internal";
    transport = "internal";
    allow = ["opus"];
    identify.match = [appliances.haosIp];
    aor = {
      contacts = ["sip:${appliances.haosIp}:5060"];
      qualifyFrequency = 0;
    };
  };

  services.asterisk.dialplan.contexts.pbx-internal.extensions.${haNumber} = [
    "Dial(PJSIP/homeass)"
    "Hangup()"
  ];
}
