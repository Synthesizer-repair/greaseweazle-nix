# greaseweazle-nix

A reproducible Nix flake dev environment that exposes the
[Greaseweazle](https://github.com/keirf/Greaseweazle) host tool (`gw`) for
reading, writing, and converting physical floppy disks at the raw flux level.

## Prerequisites

- Nix with flakes enabled (`nix-command flakes` experimental features)
- A Greaseweazle device connected over USB
- Your user in the `dialout` group (so `gw` can open the serial port without
  `sudo`)

## Usage

### With direnv (recommended)

```sh
direnv allow      # one-time, authorises .envrc
```

The shell is now provisioned automatically every time you enter the directory.

### Without direnv

```sh
nix develop       # drop into the dev shell
# or, run the tool directly without a shell:
nix run . -- info
```

## Common commands

```sh
gw info                          # identify the connected device
gw read disk.scp                 # read a disk to a Supercard Pro flux image
gw read --format ibm.1440 a.img  # read a 1.44MB PC floppy to a sector image
gw write disk.scp                # write a flux image back to a floppy
gw convert in.scp out.hfe        # convert between image formats
gw --help                        # full subcommand list
```

The connected device's serial port is exported as `$GW_DEVICE`
(default `/dev/ttyACM0`). `gw` auto-detects the device, but you can point it
explicitly with `gw --device "$GW_DEVICE" ...` if you have multiple serial
adapters attached.

## Notes

- This environment pins `nixpkgs` via `flake.lock`; run `nix flake update` to
  refresh to newer Greaseweazle releases.
- Captured images (`*.scp`, `*.hfe`, `*.img`, ...) are git-ignored by default —
  see `.gitignore`.

## Offline firmware-check patch

Upstream `gw info` unconditionally queries `api.github.com` on every run to see
whether newer device firmware exists. There is no flag or environment variable
to disable it. In a pinned, reproducible (and frequently offline) Nix dev
environment that request just hangs for its 5-second timeout and then prints a
noisy `** FATAL ERROR: HTTPSConnectionPool ... Read timed out` after the device
info has already been reported.

`flake.nix` therefore applies a small `postPatch` override to the
`greaseweazle` package that neuters the automatic check in `info.py` (the
`latest_firmware()` result is replaced with a no-op), so `gw info` runs fast and
clean with no network access.

The explicit `gw update` command — which downloads firmware from GitHub on
demand — is intentionally left untouched, so you can still update firmware when
you actually want to (and have connectivity).

## License

[MIT](LICENSE) © [Synthesizer.repair](https://synthesizer.repair)
