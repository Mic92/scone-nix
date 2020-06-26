with import <nixpkgs> {};

let
  inherit (callPackages ./scone/default.nix {}) sconeStdenv sconeEnv;
in {
  iperf3-scone = pkgs.callPackage ./iperf {
    stdenv = sconeStdenv;
  } ;
  inherit sconeStdenv sconeEnv;
}
