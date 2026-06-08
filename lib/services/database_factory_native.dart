/// Native platforms (mobile/desktop) use sqflite's default factory, so there's
/// nothing to configure here. This file exists only as the non-web branch of
/// the conditional export in `database_factory.dart`.
void configureWebDatabaseFactory() {}
