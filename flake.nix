{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devshell.url = "github:numtide/devshell";
  };

  outputs = inputs@{ flake-parts, ...  }: flake-parts.lib.mkFlake { inherit inputs; } (top@{ config, withSystem, moduleWithSystem, ... }: {
    systems = [
      "x86_64-linux"
    ];
    imports = [
      inputs.devshell.flakeModule
    ];
    perSystem = { config, pkgs, ... }: {
      devshells.default = {
        packages = with pkgs; [
          zig
          zls
        ];
      };

      packages.default = pkgs.stdenv.mkDerivation {
        name = "hellcomp";
        src = ./.;

        nativeBuildInputs = with pkgs; [
          zig
        ];

        buildPhase = ''
            mkdir -p $out/cache $out/global-cache
            zig build --release=fast --cache-dir $out/cache --global-cache-dir $out/global-cache
            rm -rf $out/cache $out/global-cache
        '';

        installPhase = ''
          mkdir -p $out/bin
          cp zig-out/bin/* $out/bin/
        '';
      };
    };
  }
);
}
