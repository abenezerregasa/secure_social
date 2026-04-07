import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricResult {
  final bool ok;
  final String? error; // readable reason
  const BiometricResult({required this.ok, this.error});
}

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  /// More detailed: tells you WHY it failed.
  Future<BiometricResult> authenticate({
    String reason = 'Confirm fingerprint to continue',
  }) async {
    try {
      // Extra checks that catch 90% of cases:
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        return const BiometricResult(ok: false, error: 'Device does not support biometrics.');
      }

      final available = await _auth.getAvailableBiometrics();
      if (available.isEmpty) {
        return const BiometricResult(ok: false, error: 'No biometrics enrolled. Add a fingerprint in Settings.');
      }

      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (!ok) {
        return const BiometricResult(ok: false, error: 'Biometric was cancelled or did not match.');
      }

      return const BiometricResult(ok: true);
    } on PlatformException catch (e) {
      // This is gold for debugging:
      return BiometricResult(ok: false, error: 'Biometric error: ${e.code}');
    } catch (e) {
      return BiometricResult(ok: false, error: 'Biometric error: $e');
    }
  }
}