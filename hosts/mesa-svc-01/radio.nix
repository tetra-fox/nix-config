# furryconvention2005's archive on shuffle forever, as an icy mp3 stream. liquidsoap's harbor
# serves listeners itself, so there is no icecast and no source password
{
  caps,
  config,
  fleet,
  pkgs,
  topo,
  ...
}: let
  radio = import ../common/fc05-radio.nix;
  port = 8010;
  library = "${config.lab.storage.mounts.music.mountpoint}/furryconvention2005/_ARCHIVE";
  # file names, wherever they are in the library
  excluded = [
    "audio_pro_tip_snare_excision_inspired_01 [1690873512].mp3"
  ];

  script = pkgs.writeText "fc05.liq" ''
    settings.harbor.bind_addrs := ["${config.lab.site.internalIp}"]

    excluded = ${builtins.toJSON excluded}

    # the archive keeps a yt-dlp .json next to each track, which would count toward max_fail
    # and stop the playlist
    def playable(r) =
      uri = request.uri(r)
      not string.contains(suffix=".json", uri) and not list.mem(path.basename(uri), excluded)
    end

    # randomize plays every file once per shuffled round
    music = playlist(
      mode="randomize",
      reload_mode="watch",
      check_next=playable,
      ${builtins.toJSON library}
    )

    # played files, newest first, the head is the current track
    history = ref([])
    music.on_track(
      synchronous=true,
      fun (m) -> history := list.prefix(50, [m["filename"], ...history()])
    )

    # goes ahead of the shuffle, so next returns to the track back left. set_queue fails to
    # resolve requests that are already resolved, so the prefetched ones are made again
    def back() =
      if
        list.length(history()) >= 2
      then
        let [current, previous, ...older] = history()
        history := older
        pending = music.queue()
        music.set_queue(
          [
            request.create(previous),
            request.create(current),
            ...list.map(fun (r) -> request.create(request.uri(r)), pending)
          ]
        )
        list.iter(request.destroy, pending)
        music.skip()
      end
    end

    harbor.http.register(
      port=${toString radio.control.port},
      ${builtins.toJSON radio.control.previous},
      fun (_, _) -> back()
    )
    harbor.http.register(
      port=${toString radio.control.port},
      ${builtins.toJSON radio.control.next},
      fun (_, _) -> music.skip()
    )

    output.harbor(
      %mp3(bitrate=192),
      port=${toString port},
      mount=${builtins.toJSON radio.mount},
      mksafe(music)
    )
  '';
in {
  lab.topology = {
    provides = [caps.radio.name];
    routes = [
      {
        host = "${radio.subdomain}.${config.lab.site.domain}";
        inherit port;
      }
    ];
  };

  networking.firewall.extraInputRules = fleet.allow-from [topo.pbxHostIp] [radio.control.port];

  lab.storage.mounts.music.gatedServices = ["radio-fc05"];

  services.liquidsoap.streams.radio-fc05 = script;
  # library directories are group media and not world-readable
  systemd.services.radio-fc05.serviceConfig.SupplementaryGroups = [config.lab.media.group];
}
