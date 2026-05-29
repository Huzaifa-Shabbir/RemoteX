// Simple logging helper to control noisy output
const bool kEnableVerboseLogs = false;

void logInfo(String msg) {
  print('[INFO] $msg');
}

void logDebug(String msg) {
  if (kEnableVerboseLogs) print('[DEBUG] $msg');
}

void logError(String msg) {
  print('[ERROR] $msg');
}

