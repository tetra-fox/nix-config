{
  config,
  lib,
  pkgs,
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

  radio = import ../common/fc05-radio.nix;
  radioNumber = "05";
  # asterisk restarts a program that exits, but can crash reloading music on hold while it is
  # down, so this keeps retrying the stream instead of exiting
  radioHold = pkgs.writeShellScript "fc05-hold" ''
    while true; do
      ${lib.getExe pkgs.ffmpeg-headless} -nostdin -loglevel error \
        -i https://${radio.subdomain}.${site.domain}/${radio.mount} \
        -f s16le -ar 16000 -ac 1 -
      ${pkgs.coreutils}/bin/sleep 5
    done
  '';
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
    extensions
    // lib.mapAttrs' (number: _: {
      name = "pbx/vm_${number}";
      value.reloadUnits = ["asterisk.service"];
    })
    extensions
    // {
      "pbx/trunk_voipms".reloadUnits = ["asterisk.service"];
    };

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
          voicemail.pin = secret "vm_${number}";
        })
        extensions;

      # also the ciscos' messages button
      voicemailMenu = "*97";

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

      # the ciscos answer on speaker, the ht801 has no speaker to answer on
      paging.all = {
        number = "*80";
        members = lib.attrNames (lib.filterAttrs (_: device: lib.hasPrefix "cisco-" device.model) config.services.asterix.phones.devices);
      };

      trunks.voipms = {
        host = "seattle1.voip.ms";
        username = "579864_pbx";
        password = secret "trunk_voipms";
        # the codec the sub-account allows
        allow = ["ulaw"];
        # seattle1.voip.ms, which the sip acl needs as an address. calls to a number come from
        # the pop it is routed to, so the numbers stay on seattle1
        identify.match = ["208.100.60.42"];
      };

      # no prefix, 10 digits go out as dialled
      outbound = {
        prefix = "";
        trunk = "voipms";
      };

      # TODO: callerId once the numbers arrive and 911's address is registered to one
      emergency.numbers = ["911"];

      phones = {
        listenAddress = voip.address;
        allowedNetworks = [voip.cidr];
        cisco = {
          timeZone = "Pacific Standard/Daylight Time";
          # so sccp and factory reset phones flash to sip. cisco's license keeps it out of this
          # public repo, so it is added to the store by hand
          firmware = {
            load = "SIP42.9-4-2SR3-1S";
            directory = pkgs.requireFile {
              name = "cisco-7962-sip-9.4.2SR3";
              hashMode = "recursive";
              hash = "sha256-OVsE++6cBetYQ5FVVvc8X1CPKrqsn6zQd5CZ/Vv+Flo=";
              message = "add cmterm-7942_7962-sip.9-4-2SR3-1.zip's files with: nix-store --add-fixed --recursive sha256 cisco-7962-sip-9.4.2SR3";
            };
          };
        };
        grandstream.timeZone = "PST8PDT,M3.2.0/02:00:00,M11.1.0/02:00:00";
        # config over tftp, the protocol the adapters came set to, so they never switch
        grandstream.settings.P212 = 0;

        devices = {
          "273" = {
            model = "grandstream-ht801";
            mac = "ec:74:d7:29:d7:e8";
          };
          "567" = {
            model = "cisco-7962g";
            mac = "3c:0e:23:6d:3e:50";
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

        # the grandstreams fetch their files over tftp, see P212 above
        files =
          lib.mapAttrs' (_: device: {
            name = "cfg${lib.toLower (lib.replaceStrings [":"] [""] device.mac)}.xml";
            value.tftp = true;
          })
          (lib.filterAttrs (_: device: lib.hasPrefix "grandstream-" device.model) config.services.asterix.phones.devices);
      };
    };

    asterisk = {
      # home assistant has no sip account, so it is let in by address
      pjsip.endpoints.homeassistant = {
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

      dialplan.contexts.pbx-internal.extensions = {
        ${haNumber} = [
          "Dial(PJSIP/homeassistant)"
          "Hangup()"
        ];
        ${radioNumber} = [
          "Answer()"
          "MusicOnHold(default)"
        ];
      };

      # the host runs on utc, so messages give their time in the house's zone
      voicemail.settings.tz = "pacific";
      settings."voicemail.conf".zonemessages.pacific = "America/Los_Angeles|'vm-received' Q 'digits/at' IMp";

      # holds, parking and the radio number all play the default class
      musicOnHold.classes.default = {
        mode = "custom";
        # spawn_mp3 passes the files of the directory to the program, which takes none
        directory = "nodir";
        application = "${radioHold}";
        # 16 khz to match the program's output, so g722 calls hear wideband
        settings.format = "slin16";
      };
    };
  };
}
