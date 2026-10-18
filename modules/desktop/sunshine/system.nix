{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.sunshine;
  jq = lib.getExe pkgs.jq;
  steam = "${config.programs.steam.package}/bin/steam";
  hyprctl = "${config.programs.hyprland.package}/bin/hyprctl";
  kscreen-doctor = "${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor";
  krfb = pkgs.kdePackages.krfb;
  krfb-virtualmonitor = "${krfb}/bin/krfb-virtualmonitor";
  systemd = "${config.systemd.package}/bin";

  # keeps the desktop readable from couch distance on a 4k client
  clientScale = ''
    scale=1
    [ "$SUNSHINE_CLIENT_WIDTH" -ge 3840 ] && scale=2
  '';

  # each session makes a virtual output at the mode moonlight asked for and turns the
  # physical monitors off, so big picture and new windows land on the stream.
  # sunshine's capture method has to be the one that can see that compositor's virtual outputs
  sessions = {
    # wlr screencopy sees hyprland's headless outputs
    Hyprland = rec {
      capture = "wlr";
      output = "SUNSHINE-1";
      displayOn = pkgs.writeShellScript "sunshine-display-on-hyprland" ''
        set -eu
        ${clientScale}
        mode="$SUNSHINE_CLIENT_WIDTH"x"$SUNSHINE_CLIENT_HEIGHT"@"$SUNSHINE_CLIENT_FPS"
        physical=$(${hyprctl} -j monitors | ${jq} -r '.[] | select(.name != "${output}") | .name')
        ${hyprctl} output create headless ${output}
        ${hyprctl} eval "hl.monitor({ output = '${output}', mode = '$mode', position = 'auto', scale = $scale })"
        for m in $physical; do
          ${hyprctl} eval "hl.monitor({ output = '$m', disabled = true })"
        done
      '';
      # reload drops the runtime monitor rules, so the physical monitors come back however the
      # config declares them. the headless output goes after, so its windows have somewhere to land
      displayOff = pkgs.writeShellScript "sunshine-display-off-hyprland" ''
        ${hyprctl} reload
        ${hyprctl} output remove ${output}
      '';
    };

    # kwin's screencast protocol sees the virtual monitor krfb asks kwin for
    KDE = rec {
      capture = "kwin";
      output = "Virtual-Sunshine";
      disabled = "$XDG_RUNTIME_DIR/sunshine-disabled-outputs";
      displayOn = pkgs.writeShellScript "sunshine-display-on-plasma" ''
        set -eu
        ${clientScale}
        w=$SUNSHINE_CLIENT_WIDTH
        h=$SUNSHINE_CLIENT_HEIGHT
        fps=$SUNSHINE_CLIENT_FPS
        ${kscreen-doctor} -j | ${jq} -r '.outputs[] | select(.enabled) | .name' > "${disabled}"
        # krfb also serves the monitor over vnc. nothing connects to it, the firewall keeps the
        # port closed, and it needs a password regardless
        ${systemd}/systemd-run --user --collect --unit=sunshine-virtual-monitor \
          ${krfb-virtualmonitor} --name Sunshine --resolution "$w"x"$h" --port 5904 \
            --password "$(head -c 24 /dev/urandom | base64)"
        # kwin adds the output a moment after krfb starts. give up after 5s so a dead krfb
        # fails the connect instead of hanging it
        for _ in $(seq 50); do
          ${kscreen-doctor} -j | ${jq} -e '.outputs[] | select(.name == "${output}")' > /dev/null && break
          sleep 0.1
        done
        ${kscreen-doctor} -j | ${jq} -e '.outputs[] | select(.name == "${output}")' > /dev/null
        ${kscreen-doctor} output.${output}.addCustomMode."$w"."$h"."$((fps * 1000))".full
        # the added mode lands slightly off the requested rate (119.93 for 120), so it can't be
        # selected as WxH@fps. its id changes between runs too, pick the closest one now
        mode=$(${kscreen-doctor} -j | ${jq} -r --argjson w "$w" --argjson h "$h" --argjson fps "$fps" '
          .outputs[] | select(.name == "${output}") | .modes
          | map(select(.size.width == $w and .size.height == $h))
          | min_by((.refreshRate - $fps) | fabs) | .id')
        ${kscreen-doctor} output.${output}.mode."$mode" output.${output}.scale."$scale"
        args=""
        while read -r m; do
          args="$args output.$m.disable"
        done < "${disabled}"
        ${kscreen-doctor} $args
      '';
      # kwin keeps a disabled output's mode, scale and position, so enabling restores them
      displayOff = pkgs.writeShellScript "sunshine-display-off-plasma" ''
        args=""
        while read -r m; do
          args="$args output.$m.enable"
        done < "${disabled}"
        ${kscreen-doctor} $args
        ${systemd}/systemctl --user stop sunshine-virtual-monitor
        rm -f "${disabled}"
      '';
    };
  };

  appsFormat = pkgs.formats.json {};
  settingsFormat = pkgs.formats.keyValue {};

  configFor = name: session: let
    display = {
      do = "${session.displayOn}";
      undo = "${session.displayOff}";
    };
  in
    settingsFormat.generate "sunshine-${name}.conf" {
      inherit (cfg.settings) port;
      inherit (session) capture;
      sunshine_name = config.networking.hostName;
      output_name = session.output;
      file_apps = appsFormat.generate "sunshine-apps-${name}.json" {
        apps = [
          {
            name = "Desktop";
            image-path = "desktop.png";
            prep-cmd = [display];
          }
          {
            name = "Big Picture";
            image-path = "steam.png";
            # undo runs in reverse, so big picture closes before the monitors come back
            prep-cmd = [
              display
              {
                do = "";
                undo = "${steam} steam://close/bigpicture";
              }
            ];
            detached = ["${steam} steam://open/bigpicture"];
          }
        ];
      };
    };

  # only one session runs at a time, and each sets XDG_CURRENT_DESKTOP before graphical-session.target
  launcher = pkgs.writeShellScript "sunshine-session" ''
    case "$XDG_CURRENT_DESKTOP" in
    ${lib.concatStrings (lib.mapAttrsToList (name: session: ''
        ${name}) exec ${lib.getExe cfg.package} ${configFor name session} ;;
      '')
      sessions)}
      *) echo "sunshine: no config for session '$XDG_CURRENT_DESKTOP'" >&2; exit 1 ;;
    esac
  '';
in {
  # the module also turns on avahi publishing (mkDefault) so moonlight can discover this host,
  # and creates sink-sunshine-* virtual sinks that become the default output while streaming
  services.sunshine = {
    enable = true;
    # the default build sets SUNSHINE_ENABLE_CUDA=false, and nvenc needs cuda
    package = pkgs.sunshine.override {cudaSupport = true;};
    openFirewall = true;
  };

  # kwin only lets krfb make virtual monitors if it finds krfb's desktop file declaring
  # X-KDE-Wayland-Interfaces=zkde_screencast_unstable_v1, matched by its Exec path
  environment.systemPackages = [krfb];

  # the module's unit takes a single config file, the launcher picks the session's
  systemd.user.services.sunshine.serviceConfig.ExecStart = lib.mkForce "${launcher}";
}
