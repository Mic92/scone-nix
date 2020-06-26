{ stdenv, fetchFromGitHub }:
stdenv.mkDerivation {
  name = "iperf-3.7";
  src = fetchFromGitHub {
    owner = "Mic92";
    repo = "iperf-3.7";
    rev = "47cf215e90a6809952b4a618be08852a5c3d4433";
    sha256 = "1796ldhmfpxrg206c12yhhpbx9p3rpc0sg9igln24w1dgms3yy7i";
  };
  configureFlags = [
    "--enable-static"
    "--disable-shared"
    "--disable-profiling"
  ];
}
