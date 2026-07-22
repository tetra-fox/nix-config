#!/usr/bin/env bash
# `nix-purge` system binary. runs the same whether invoked as yourself or under
# sudo: every profile on the machine gets collected either way, so a headless
# box only needs the one `sudo nix-purge`.

case "${1:-}" in
  "") ;;
  -h | --help)
    echo "usage: nix-purge   # delete old generations, drop nix caches and build logs, prune boot entries, optimise the store"
    exit 0
    ;;
  *)
    echo "nix-purge: unknown argument $1" >&2
    exit 1
    ;;
esac

sudo=(sudo)
if [ "$(id -u)" -eq 0 ]; then
  sudo=()
fi

# nix-collect-garbage only searches the profile directories belonging to
# whoever ran it, plus the legacy /nix/var/nix/profiles tree; see the "locations
# searched for profiles" section of nix-collect-garbage(1). every other user's
# profiles live in their own $XDG_STATE_HOME/nix/profiles, so a root-only run
# leaves them untouched. the store already tracks each generation link as a gc
# root, so enumerate them from there instead of guessing at home directories.
# nix-env rather than `nix profile wipe-history` because the latter is still
# experimental and these profiles are a mix of nix-env and nix profile manifests.
# enumeration is captured up front: a failure inside <(...) is invisible to
# set -e, this way a dead daemon aborts the run instead of silently skipping it
profiles=$(
  "${sudo[@]}" nix-store --gc --print-roots \
    | awk '{ sub(/ -> .*/, "") }
           /-[0-9]+-link$/ && !/^\/nix\/var\/nix\/profiles\// {
             sub(/-[0-9]+-link$/, ""); print
           }' \
    | sort -u
)
failed=0
while read -r profile; do
  [ -n "$profile" ] || continue
  echo "nix-purge: collecting $profile" >&2
  # one broken profile should not abort the machine-wide purge; surfaced
  # through the exit code once everything else has run
  "${sudo[@]}" nix-env --delete-generations old --profile "$profile" || failed=1
done <<<"$profiles"

# nix's eval and tarball cache, which lives outside the store where no gc
# reaches it. cleared before the collection below so the flake registry it roots
# goes with it. under sudo the cache worth clearing is the invoking user's
if [ -n "${SUDO_USER:-}" ]; then
  cache=$(sudo -Hu "$SUDO_USER" sh -c 'echo "${XDG_CACHE_HOME:-$HOME/.cache}"')
else
  cache=${XDG_CACHE_HOME:-$HOME/.cache}
fi
rm -rf "$cache/nix"

# root accumulates its own copy of the same cache from sudo rebuilds. ~root
# rather than /root because darwin keeps root's home at /var/root
root_cache=~root/.cache
"${sudo[@]}" rm -rf "$root_cache/nix"

# build logs are never garbage collected and grow without bound. dropping the
# lot also loses `nix log` output for paths still in the store
"${sudo[@]}" rm -rf /nix/var/log/nix/drvs

# system and root generations, then the single store gc that frees everything
# the steps above unrooted
echo "nix-purge: collecting system generations" >&2
"${sudo[@]}" nix-collect-garbage -d

# nixos only: rewrite the boot entries so the menu stops offering generations
# that were just deleted. nix-darwin has no such binary
if [ -x /run/current-system/bin/switch-to-configuration ]; then
  echo "nix-purge: pruning bootloader entries" >&2
  "${sudo[@]}" /run/current-system/bin/switch-to-configuration boot
fi

echo "nix-purge: optimising the store" >&2
"${sudo[@]}" nix store optimise

if [ "$failed" -ne 0 ]; then
  echo "nix-purge: one or more profiles failed to collect" >&2
  exit 1
fi
