{
  description = "Gleam devshell";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nix-gleam.url = "github:arnarg/nix-gleam";
  };

  outputs = {
    self,
    nixpkgs,
    nix-gleam,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [
        nix-gleam.overlays.default
      ];
    };

    shell = pkgs.mkShell {
      name = "shell";
      packages = with pkgs; [
        erlang_nox
        gleam
        just
        rebar3
        sqlite
      ];
    };

    package = pkgs.buildGleamApplication {
      src = ./.;

      # Overrides the rebar3 package used, adding
      # plugins using `rebar3WithPlugins`.
      rebar3Package = pkgs.rebar3WithPlugins {
        plugins = with pkgs.beamPackages; [pc];
      };
    };
  in {
    devShell.${system} = shell;
    packages.${system}.default = package;
  };
}
