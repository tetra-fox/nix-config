# impermanence

[impermanence](https://github.com/nix-community/impermanence) wiring. `/` is a tmpfs, so a reboot drops everything that isn't listed in `environment.persistence.main`. listed paths are bind mounts into the persistent volume at `/persist`.

every nixos host has the module through the base profile, switched off. a site turns it on for all of its hosts:

```nix
environment.persistence.main.enable = true;
```

the disk layout follows that flag, see `modules/platform/disko/proxmox-vm.nix`. `/persist` is the same ext4 partition a classic host mounts at `/`, with the same files at the same paths, so `/var/lib/foo` lives at `/persist/var/lib/foo`.

## declaring state

a module lists what it writes next to the service, whether or not the host it lands on has persistence on:

```nix
environment.persistence.main.directories = ["/var/lib/myapp"];
```

already covered for every host: `/var/log`, `/var/lib/systemd`, `/var/lib/private` (all `DynamicUser` state), `/var/tmp`, the site's `lab.site.dataDir`, `/etc/machine-id`. ssh host keys and userborn's passwd files are read straight from `/persist/etc`, not bound.

home directories and `/root` are not kept.

## moving an existing host onto it

nothing is copied, the old root becomes `/persist` as it is.

```sh
colmena apply boot --on <host>
ssh <host> sudo reboot
```

`switch` and `test` refuse to run until the host has booted with `/persist` mounted. to go back, boot the previous generation from the systemd-boot menu.

a path that was missed is not lost, it is still on the volume under `/persist`. add it to the module and deploy.

## gotchas

- on the first boot of a fresh install the `createPersistentStorageDirs` activation snippet logs chown errors and reports failure. the directories are created correctly. upstream: https://github.com/nix-community/impermanence/pull/334
- systemd logs `Failed unmounting /nix` at shutdown, the store is still in use at that point
- the root tmpfs is capped at half the host's ram
