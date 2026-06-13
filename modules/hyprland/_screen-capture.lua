hl.bind("CTRL + SHIFT + 3", hl.dsp.exec_cmd("hyprshot -m output -m active -z --clipboard-only"))
hl.bind("CTRL + SHIFT + 4", hl.dsp.exec_cmd("hyprshot -m region -z --clipboard-only"))
-- NVIDIA often only advertises block-linear dmabufs, so wf-recorder is used here instead of wl-screenrec
hl.bind("CTRL + SHIFT + 5", hl.dsp.exec_cmd([[wf-recorder -g "$(slurp)" --audio -f "$HOME/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).mp4"]]))
