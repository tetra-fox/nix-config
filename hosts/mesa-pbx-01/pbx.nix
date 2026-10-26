{
  config,
  lib,
  inputs,
  ...
}: let
  inherit (config.lab) site appliances;
  secret = name: config.lib.asterisk.secret config.sops.secrets."pbx/${name}".path;

  # vlan 100, the phones' own, so calls don't depend on the router's inter-vlan routing
  voip = {
    interface = "ens20";
    address = "192.168.100.170";
    cidr = "192.168.100.0/24";
  };

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

  # on-link only: the phones are on this subnet, everything else goes out the server vlan
  networking.interfaces.${voip.interface}.ipv4.addresses = [
    {
      inherit (voip) address;
      prefixLength = 24;
    }
  ];

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

  services = {
    asterix = {
      enable = true;
      openFirewall = true;

      # one transport on every address, so the kernel picks the source of each reply by route.
      # with a transport per address, pjsip sends replies to a request without rport (the
      # 7962g's) from whichever udp transport it finds first (pjsip_get_response_addr then
      # pjsip_tpmgr_acquire_transport2), so phones got their 401 from 10.10.0.170 and ignored it
      # TODO: split per address again if asterisk pins replies to the receiving transport
      networks.voip = {
        inherit (voip) interface;
        # home assistant reaches the pbx on its internal leg
        subnets = [voip.cidr "${appliances.haosIp}/32"];
      };

      extensions =
        lib.mapAttrs (number: e: {
          inherit (e) name;
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
        listenAddress = voip.address;
        allowedNetworks = [voip.cidr];
        cisco.timeZone = "Pacific Standard/Daylight Time";
        grandstream.timeZone = "PST8PDT,M3.2.0/02:00:00,M11.1.0/02:00:00";

        devices = {
          "273" = {
            model = "grandstream-ht801";
            mac = "ec:74:d7:29:d7:e8";
          };
          "567" = {
            model = "grandstream-ht801";
            mac = "ec:74:d7:97:73:f2";
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

    asterisk = {
      # home assistant has no sip account, so it is let in by address
      pjsip.endpoints.homeass = {
        context = "pbx-internal";
        allow = ["opus"];
        identify.match = [appliances.haosIp];
        aor = {
          contacts = ["sip:${appliances.haosIp}:5060"];
          qualifyFrequency = 0;
        };
      };

      # the network's interface, plus home assistant's leg
      firewallInterfaces = [voip.interface site.internalInterface];

      dialplan.contexts.pbx-internal.extensions.${haNumber} = [
        "Dial(PJSIP/homeass)"
        "Hangup()"
      ];
    };
  };
}
