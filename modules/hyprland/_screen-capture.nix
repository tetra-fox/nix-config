{pkgs, ...}: {
  programs.hyprshot.enable = true;

  home.packages = with pkgs; [
    wf-recorder
    slurp
  ];

  wayland.windowManager.hyprland.settings.bind = [
    "L_Control&L_Shift,3,exec,hyprshot -m output -m active -z --clipboard-only"
    "L_Control&L_Shift,4,exec,hyprshot -m region -z --clipboard-only"
    # NVIDIA often only advertises block-linear dmabufs, so wf-recorder is used here instead of wl-screenrec
    "L_Control&L_Shift,5,exec,wf-recorder -g \"$(slurp)\" --audio -f \"$HOME/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).mp4\""
  ];
}
