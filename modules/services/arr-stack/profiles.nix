# shared by recyclarr and cleanup-profiles. names[0] is where orphans get reassigned
rec {
  # descending, each profile stacks the resolutions below it
  resolutions = ["2160p" "1080p" "720p" "sd"];

  names = map (r: "best-${r}") resolutions ++ map (r: "webdl-${r}") resolutions;
}
