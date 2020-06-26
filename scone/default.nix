{ buildPackages
, runCommand
, stdenv
, skopeo
, oci-image-tool
, cacert
, lib
, autoPatchelfHook
, buildFHSUserEnv
, gcc7
, libredirect
, makeWrapper
, zlib
, gcc
, glibc
, utillinux
, wrapCCWith
, wrapBintoolsWith
, binutils-unwrapped
, overrideCC
}:
let
  unpackDockerImage = let
    fixName = name: builtins.replaceStrings ["/" ":"] ["-" "-"] name;
  in
    { imageName
      # To find the digest of an image, you can use skopeo:
      # see doc/functions.xml
    , imageDigest
    , sha256
    , os ? "linux"
    , arch ? buildPackages.go.GOARCH

      # This is used to set name to the pulled image
    , finalImageName ? imageName
      # This used to set a tag to the pulled image
    , finalImageTag ? "latest"

    , name ? fixName "docker-image-${finalImageName}-${finalImageTag}"
    # username when logging in to the registry
    , username ? null
    # password when logging in to the registry
    , password ? null
    }:

    runCommand name {
      inherit imageDigest;
      imageName = finalImageName;
      imageTag = finalImageTag;
      impureEnvVars = stdenv.lib.fetchers.proxyImpureEnvVars;
      outputHashMode = "recursive";
      outputHashAlgo = "sha256";
      outputHash = sha256;

      nativeBuildInputs = [ skopeo oci-image-tool ];
      SSL_CERT_FILE = "${cacert.out}/etc/ssl/certs/ca-bundle.crt";

      sourceURL = "docker://${imageName}@${imageDigest}";
      destNameTag = "${finalImageName}:${finalImageTag}";
    } ''
      skopeo \
        ${lib.optionalString (username != null && password != null)
           "--src-creds=${lib.escapeShellArg username}:${lib.escapeShellArg password}"} \
        --insecure-policy \
        --tmpdir=$TMPDIR \
        --override-os ${os} \
        --override-arch ${arch} \
        copy "$sourceURL" "oci:image:${finalImageTag}"
      oci-image-tool unpack \
        --ref name=${finalImageTag} image $out
  '';

  scone-image = unpackDockerImage {
    imageName = "sconecuratedimages/crosscompilers";
    imageDigest = "sha256:ce9d91ab44ae80a839797f08810943a42c44e14862ea3ada2e81c611c658dccc";
    sha256 = "0xmq7kmar0v4v2mjh09c5kz36sfkgnlfwn0g01yc7cvmsl24svax";
    finalImageTag = "1.0.0";
    finalImageName = "scone";
    username = builtins.getEnv "DOCKER_USER";
    password = builtins.getEnv "DOCKER_PASSWORD";
  };
  gcc-nolibc = wrapCCWith {
    inherit (gcc) cc;
    bintools = wrapBintoolsWith {
      bintools = binutils-unwrapped;
      libc = null;
    };
    extraBuildCommands = ''
      sed -i '2i if ! [[ $@ == *'musl-gcc.specs'* ]]; then exec ${gcc}/bin/gcc -L${glibc}/lib -L${glibc.static}/lib "$@"; fi' \
        $out/bin/gcc

      sed -i '2i if ! [[ $@ == *'musl-gcc.specs'* ]]; then exec ${gcc}/bin/g++ -L${glibc}/lib -L${glibc.static}/lib "$@"; fi' \
        $out/bin/g++

      sed -i '2i if ! [[ $@ == *'musl-gcc.spec'* ]]; then exec ${gcc}/bin/cpp "$@"; fi' \
        $out/bin/cpp
    '';
  };
in rec {
  scone-unwrapped = stdenv.mkDerivation {
    name = "scone-unwrapped";
    dontUnpack = true;

    passthru = {
      isGNU = true;
      hardeningUnsupportedFlags = [ "pie" ];
    };

    installPhase = ''
      mkdir -p $out/{opt,usr/lib/,bin}
      cp -r ${scone-image}/opt/scone $out/opt/scone
      chmod -R +w $out/opt/scone

      for path in $(grep -I -l -R /opt/scone "$out/opt/scone" | xargs readlink -f | sort -u); do
        substituteInPlace "$path" \
          --replace "/opt/scone" "$out/opt/scone"
      done

      for i in gcc cc cpp; do
        makeWrapper $out/opt/scone/bin/scone-gcc $out/bin/$i \
          --set REALGCC ${gcc-nolibc}/bin/gcc \
          --prefix PATH : ${utillinux}/bin
      done
      for i in g++ c++; do
        makeWrapper $out/opt/scone/bin/scone-g++ $out/bin/$i \
          --set REALGCC ${gcc-nolibc}/bin/gcc \
          --prefix PATH : ${utillinux}/bin
      done

      ln -s $out/opt/scone/cross-compiler/x86_64-linux-musl/lib $out/lib
    '';
    nativeBuildInputs = [
      autoPatchelfHook makeWrapper
    ];
  };
  scone = wrapCCWith {
    cc = scone-unwrapped;
    bintools = wrapBintoolsWith {
      bintools = binutils-unwrapped;
      libc = scone-unwrapped;
    };
  };
  sconeStdenv = overrideCC stdenv scone;

  # for nix-shell
  sconeEnv = sconeStdenv.mkDerivation {
    name = "scone-env";
    hardeningDisable = [ "all" ];
  };
}
