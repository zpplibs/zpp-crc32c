## zpp-crc32c
crc32c lib for zig

### Fetch deps
```sh
git submodule update --init
```

### Build
```sh
./build.sh
```

### Run
```sh
./build.sh run -- hello world
./build.sh run-c -- hello world
```

### Run the tests
```sh
./test.sh
```

### Dist (cross-compilation)
```sh
./build.sh dist
```

### Release
```sh
./build.sh dist VERSION GITHUB_TOKEN
```

### Clean
```sh
./build.sh clean
```

### Tag
```sh
./build.sh tag v$VERSION
```
