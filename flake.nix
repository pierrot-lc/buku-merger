{
  description = "Gleam devshell";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = false;
      };
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
  in {
    devShell.${system} = shell;
  };
}
