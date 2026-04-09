{ ... }:

{
  services.pipewire = {
    enable = true;
    audio.enable = true; # use pipewire as primary sound server
    wireplumber.enable = true;
  };
}
