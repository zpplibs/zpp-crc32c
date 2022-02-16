# zpp-crc32c version history

## v0.1.0 - 2022-02-16
 
### Added
-  Bindings for [crc32c](https://github.com/google/crc32c)
```zig
pub fn extend(crc: u32, data: []const u8) u32

pub fn value(data: []const u8) u32
```
