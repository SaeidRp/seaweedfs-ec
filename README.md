# SeaweedFS EC Multi-Configuration Docker Builder

Build custom [SeaweedFS](https://github.com/seaweedfs/seaweedfs) Docker images with configurable Erasure Coding (EC) settings. Each EC config has its own Dockerfile and patch for easy, reproducible builds.

## Features
- Multiple EC configs (auto-detected)
- One Dockerfile per EC config
- Multi-platform images (AMD64, ARM64)
- Automated version updates & builds (GitHub Actions)
- Easy to add new EC configs

## Available EC Configurations

| Config   | Data | Parity | Total | Overhead | Fault Tolerance | Use Case                       |
|----------|------|--------|-------|----------|-----------------|--------------------------------|
| EC 9,3   | 9    | 3      | 12    | 33%      | 3 drives        | High perf, moderate redundancy |
| EC 10,2  | 10   | 2      | 12    | 20%      | 2 drives        | Efficient, balanced            |

## Project Structure
```
seaweedfs_ec/
├── Dockerfile.ec93           # EC 9,3
├── Dockerfile.ec102          # EC 10,2
├── patches/
│   ├── ec-9-3.patch
│   └── ec-10-2.patch
├── Makefile
└── .github/workflows/
```

## Quick Usage

### Build & Run
```sh
# List configs
make list-configs

# Build default (EC 9,3)
make build

# Build specific
make build EC_CONFIG=10-2

## Contributing
We welcome contributions of new EC configurations! Please:

- Test your configuration thoroughly
- Update documentation with use cases and performance characteristics
- Follow the naming convention: `EC X,Y` where X=data shards, Y=parity shards

## License
MIT

## Credits
- [SeaweedFS](https://github.com/seaweedfs/seaweedfs)
- [RocksDB](https://rocksdb.org/)