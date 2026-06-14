{
  # greaseweazle-nix — MIT licensed, authored by Synthesizer.repair
  # https://synthesizer.repair
  description = "Interactive environment for the Greaseweazle floppy/flux tooling";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        # The Greaseweazle host tool (`gw`) for reading/writing floppies at the
        # raw flux level. nixpkgs exposes it as the `greaseweazle` package.
        #
        # `gw info` unconditionally calls api.github.com to check for newer
        # firmware. In a pinned/offline dev env that call only ever times out
        # with a noisy FATAL ERROR, so we neuter the automatic check. Explicit
        # `gw update` (which fetches firmware on demand) is left untouched.
        greaseweazle = pkgs.greaseweazle.overridePythonAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            substituteInPlace $(find . -path '*greaseweazle/tools/info.py') \
              --replace-fail "latest_version = latest_firmware()" \
                             "latest_version = (0, 0) # network check disabled"
          '';
        });

        # Extra tools that are handy when wrangling disk images alongside `gw`.
        extras = [
          pkgs.python3            # gw is python; useful for ad-hoc scripting
          pkgs.usbutils           # lsusb, to confirm the device is enumerated
          pkgs.minicom            # poke the serial port directly if needed
        ];
      in
      {
        # `nix run` and `nix run .#gw` both launch the Greaseweazle CLI.
        packages.default = greaseweazle;
        packages.greaseweazle = greaseweazle;

        apps.default = {
          type = "app";
          program = "${greaseweazle}/bin/gw";
        };
        apps.gw = self.apps.${system}.default;

        devShells.default = pkgs.mkShell {
          packages = [ greaseweazle ] ++ extras;

          # Greaseweazle's USB CDC port. Override per-shell with e.g.
          #   GW_DEVICE=/dev/ttyACM1 nix develop
          GW_DEVICE = "/dev/ttyACM0";

          shellHook = ''
            echo "┌──────────────────────────────────────────────────────────┐"
            echo "│  Greaseweazle dev shell (host tools ${greaseweazle.version})"
            echo "└──────────────────────────────────────────────────────────┘"
            echo
            echo "  gw <command>     read, write, erase, convert disk images"
            echo "  gw --help        list all subcommands"
            echo "  gw info          query the connected Greaseweazle"
            echo
            if [ -e "$GW_DEVICE" ]; then
              echo "  device: $GW_DEVICE present"
            else
              echo "  device: $GW_DEVICE NOT found — plug in the Greaseweazle"
              echo "          (auto-detection still works if it lives elsewhere)"
            fi
            echo
          '';
        };
      }
    );
}
