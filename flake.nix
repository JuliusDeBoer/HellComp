{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs
  }: let
    system = "x86_64-linux";

    pkgs = import nixpkgs {
      inherit system;
    };
  in {
    packages.${system}.default = pkgs.stdenv.mkDerivation {
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
    devShell.${system} = pkgs.mkShell {
      buildInputs = with pkgs; [
        zig
        zls
      ];
    };
  };
}
