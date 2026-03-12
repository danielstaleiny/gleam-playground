{ }:

let
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-unstable";
  pkgs = import nixpkgs { config = {}; overlays = []; };
  erlang = pkgs.beam27Packages.erlang;
  elixir = pkgs.beam27Packages.elixir;
  rebar3 = pkgs.beam27Packages.rebar3;
  gleam = pkgs.gleam;
in
pkgs.mkShell {
  buildInputs = [
    erlang
    elixir
    rebar3
    gleam
  ];

  shellHook = ''
    echo "Erlang, Elixir, and Gleam development environment"
    echo "================================================"
    echo "Erlang version: $(erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell)"
    echo "Elixir version: $(elixir --version)"
    echo "Elixir version: $(rebar3 --version)"
    echo "Gleam version: $(gleam --version)"
    echo ""
    echo "To start Erlang shell, type: erl"
    echo "To start Elixir shell, type: iex"
    echo "To start a new Gleam project, type: gleam new project_name"
    echo "================================================"
  '';
}
