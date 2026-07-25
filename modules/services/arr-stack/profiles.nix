# the managed quality profiles, built from one resolution list so recyclarr creates
# exactly the set cleanup-profiles keeps, no drift. names[0] is the profile cleanup
# reassigns orphans onto
rec {
  # descending, recyclarr walks this to stack each profile with the resolutions below it
  resolutions = ["2160p" "1080p" "720p" "sd"];

  # best-* tops out at the disc tier for its resolution, webdl-* at a web release
  names = map (r: "best-${r}") resolutions ++ map (r: "webdl-${r}") resolutions;
}
