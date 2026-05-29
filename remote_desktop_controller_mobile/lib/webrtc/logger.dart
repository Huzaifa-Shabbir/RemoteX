class Logger {
  static void log(String tag, dynamic msg) {
    // suppressed to reduce log spam in production
  }

  static void error(String tag, dynamic msg) {
    // keep errors visible
    // ignore: avoid_print
    print("❌ [$tag] $msg");
  }
}
