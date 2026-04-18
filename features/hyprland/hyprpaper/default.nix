{ shared, ... }:

let
  imagePath = toString (shared.wallpapers + "/andrei-castanha-cCWKt_dHMvQ-unsplash-rotate.jpg");
in
{
  services.hyprpaper = {
    enable = true;
    settings = {
      splash = false;
      preload = [ imagePath ];
      # hyprpaper 0.8+ expects wallpaper { } blocks, not wallpaper=mon,path
      wallpaper = [
        {
          monitor = "";
          path = imagePath;
          fit_mode = "cover";
        }
      ];
    };
  };
}
