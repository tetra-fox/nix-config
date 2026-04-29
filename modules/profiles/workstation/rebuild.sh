#!/usr/bin/env bash
# `rebuild` system binary. usage:
#   rebuild                                # local switch (default action)
#   rebuild boot                           # local boot (action as positional)
#   rebuild --action test                  # local test (action as flag)
#   rebuild --target-host mesa-svc-01      # deploy switch to that host
#   rebuild boot --target-host mesa-svc-01 # deploy boot to that host
#   rebuild --target-host admin@1.2.3.4    # explicit user@ip target
#
# when --target-host is given:
#   - bare hostname gets `admin@` prepended (servers use admin)
#   - flake attr derives from the hostname (override with --flake-attr)
#   - --build-host=localhost and --sudo are added automatically
#
# works as user (auto-elevates with sudo) AND via `sudo rebuild`
# (resolves invoker's home via $SUDO_USER).
set -e

if [ -n "$SUDO_USER" ]; then
  user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
  user_home=$HOME
fi
flake="$user_home/Documents/git/nix-config"
if [ ! -f "$flake/flake.nix" ]; then
  echo "rebuild: no flake.nix at $flake - clone the nix-config repo there first" >&2
  exit 1
fi

action=""
target_host=""
flake_attr=""
passthrough=()
while [ $# -gt 0 ]; do
  case "$1" in
    --target-host)    target_host="$2"; shift 2 ;;
    --target-host=*)  target_host="${1#--target-host=}"; shift ;;
    --flake-attr)     flake_attr="$2"; shift 2 ;;
    --flake-attr=*)   flake_attr="${1#--flake-attr=}"; shift ;;
    --action)         action="$2"; shift 2 ;;
    --action=*)       action="${1#--action=}"; shift ;;
    -*)               passthrough+=("$1"); shift ;;
    *)
      # first bare positional becomes the action; later bare positionals
      # pass through to nixos-rebuild as-is.
      if [ -z "$action" ]; then
        action="$1"
      else
        passthrough+=("$1")
      fi
      shift
      ;;
  esac
done

action="${action:-switch}"

if [ -n "$target_host" ]; then
  case "$target_host" in
    *@*) ;;
    *)   target_host="admin@$target_host" ;;
  esac
  if [ -z "$flake_attr" ]; then
    flake_attr="${target_host#*@}"
  fi
  # remote deploy: run as the invoking user (not local sudo) so ssh uses
  # our agent. --sudo tells nixos-rebuild to elevate on the *remote*. if
  # we wrapped in sudo here, ssh would run as root locally and try to
  # connect as root@<target>, which has no key.
  exec nixos-rebuild "$action" \
    --flake "$flake#$flake_attr" \
    --target-host "$target_host" \
    --build-host localhost \
    --sudo \
    "${passthrough[@]}"
else
  # local rebuild: sudo for the activation step. preserve SSH_AUTH_SOCK so
  # nix can fetch private flake inputs (nix-secrets etc.) over ssh during
  # eval - sudo strips the agent socket by default.
  exec sudo --preserve-env=SSH_AUTH_SOCK nixos-rebuild "$action" --flake "$flake#$(hostname)" "${passthrough[@]}"
fi
