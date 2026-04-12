{ ... }:

{
  systemd.services.bind-ddcci-displays = {
    description = "Create DDCCI backlight devices";
    after = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      for bus in 4 8 9; do
        nd="/sys/bus/i2c/devices/i2c-$bus/new_device"
        if [[ ! -e "$nd" ]]; then
          echo "bind-ddcci-displays: skip i2c-$bus (no $nd)" >&2
          continue
        fi
        if echo ddcci 0x37 > "$nd"; then
          echo "bind-ddcci-displays: bound ddcci on i2c-$bus" >&2
        else
          echo "bind-ddcci-displays: bind failed on i2c-$bus (exit $?)" >&2
        fi
      done
    '';
  };
}
