{
  description = "Flake for tari";

  inputs = {
    nixpks.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    rust-overlay,
    flake-utils,
    naersk,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        overlays = [(import rust-overlay)];
        pkgs = import nixpkgs {
          inherit system overlays;
          config.allowUnfree = true;
        };
        rust = pkgs.rust-bin.selectLatestNightlyWith (
          toolchain:
            toolchain.default.override {
              extensions = [
                "rust-src"
                "rust-analyzer"
                "miri"
              ];
              targets = ["x86_64-unknown-linux-gnu"];
            }
        );
        naerskLib = pkgs.callPackage naersk {
          cargo = rust;
          rustc = rust;
        };
        build_inputs = with pkgs; [
          openssl
          perl
          protobuf
          clang
          pkg-config
          cmake
          rust
          libudev-zero
          automake
          autoconf
          cargo-nextest
          libtool
          randomx
          sqlite
        ];
        tooling = with pkgs; [
          deadnix # Dead code detection for nix
          statix # Highlights nix antipatterns
          taplo # Toml toolkit with formatter
        ];
      in
        with pkgs; {
          packages = {
            minotari_node = naerskLib.buildPackage {
              pname = "minotari_node";
              src = ./.;
              buildInputs = build_inputs;
            };
            minotari_miner = naerskLib.buildPackage{
              pname = "minotari_miner";
              src = ./.;
              buildInputs = build_inputs;
            };
            minotari_console_wallet = naerskLib.buildPackage{
              pname = "minotari_console_wallet";
              src = ./.;
              buildInputs = build_inputs;
            };
          };
          config.allowUnfree = true;
          devShells.default = mkShell {
            buildInputs = build_inputs ++ tooling;
            CUDA_PATH = "${pkgs.cudatoolkit}";
            RUST_BACKTRACE = "full";
            LD_LIBRARY_PATH = "${lib.makeLibraryPath (build_inputs)}";
            RUSTFLAGS = "-L ${pkgs.randomx}/lib";
          };
        }
    );
}
