import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

class NetworkManager extends GetxController {
  static NetworkManager get instance => Get.find();

  final Connectivity _connectivity = Connectivity();

  /// Returns true if the device has an active network interface AND can reach the internet.
  /// This combines:
  /// 1. Quick network interface check (WiFi/mobile) via connectivity_plus
  /// 2. Actual internet reachability check via HTTP request
  ///
  /// This dual approach ensures reliability on both emulators and physical devices.
  /// - On physical devices: Usually fast as connectivity_plus is reliable
  /// - On emulators: Falls back to actual reachability check if connectivity_plus fails
  ///
  /// If this returns false, show "No Internet" and stop.
  /// If this returns true but a remote call fails, let the exception handler
  /// show the error — do not do a second check.
  Future<bool> isConnected() async {
    try {
      // First, quick check for network interface availability
      final connectivityResult = await _connectivity.checkConnectivity();
      final hasNetworkInterface = !connectivityResult.contains(
        ConnectivityResult.none,
      );

      if (!hasNetworkInterface) {
        return false;
      }

      // Second, verify actual internet reachability
      // This is the key fix for emulator issues
      final hasInternetAccess = await _checkInternetReachability();

      return hasInternetAccess;
    } catch (_) {
      return false;
    }
  }

  /// Performs actual internet reachability check by making a simple HTTP request.
  /// Uses reliable endpoints that should be accessible from most networks.
  /// Timeout is set to 5 seconds to avoid long waits on slow networks.
  Future<bool> _checkInternetReachability() async {
    try {
      // Try multiple reliable endpoints in case one is down
      final endpoints = [
        'https://www.google.com',
        'https://www.cloudflare.com',
        'https://www.apple.com',
      ];

      for (final endpoint in endpoints) {
        try {
          await http
              .head(Uri.parse(endpoint))
              .timeout(const Duration(seconds: 5));

          // Any response (even 4xx/5xx) means we have internet connectivity
          return true;
        } catch (_) {
          // Try next endpoint
          continue;
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Quick check for network interface only (no actual internet reachability).
  /// Use this when you need instant feedback and will handle network errors separately.
  /// Returns true if device has WiFi/mobile enabled, regardless of actual internet access.
  Future<bool> hasNetworkInterface() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return !result.contains(ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }
}
