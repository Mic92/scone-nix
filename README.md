# Scone examples with nix 

```console
$ git clone github.com/Mic92/scone-nix
$ cd scone-nix
```

Export your docker registry credentials

```console
$ export DOCKER_USER=<yourloginname>
$ export DOCKER_PASSWORD=<yourpassword>
```

## Build example package:

```console
$ nix-build -A iperf3-scone
```

## Get the scone compiler

```console
$ nix-shell -A sconeEnv
nix-shell> cc --version
x86_64-linux-musl-gcc (GCC) 8.2.0
```
