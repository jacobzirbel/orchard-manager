/// `sqflite_common_ffi_web` is a web-only package — importing it directly
/// would fail to compile for Android/iOS/desktop. `dart.library.js_interop`
/// is only available when compiling for the web, so the conditional export
/// picks the right implementation per platform.
export 'database_factory_native.dart'
    if (dart.library.js_interop) 'database_factory_web.dart';
