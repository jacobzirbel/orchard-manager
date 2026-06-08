# orchard_manager

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Building for web

`sqflite` has no browser implementation, so the web build uses
`sqflite_common_ffi_web` (sqlite3 compiled to WASM, persisted in IndexedDB —
see `lib/services/database_factory_web.dart`). That package needs its WASM
binary and shared-worker script copied into `web/` before building. Run this
once (and again after upgrading `sqflite_common_ffi_web`):

```sh
dart run sqflite_common_ffi_web:setup
flutter build web --release
```
