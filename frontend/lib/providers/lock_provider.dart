import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pinKey = 'app_pin';

/// true = app is locked and requires PIN entry
final lockProvider = StateNotifierProvider<LockNotifier, bool>((ref) {
  return LockNotifier();
});

class LockNotifier extends StateNotifier<bool> {
  LockNotifier() : super(false) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString(_pinKey);
    state = pin != null && pin.isNotEmpty;
  }

  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString(_pinKey);
    return pin != null && pin.isNotEmpty;
  }

  Future<bool> unlock(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_pinKey) == pin) {
      state = false;
      return true;
    }
    return false;
  }

  void lock() => state = true;

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
    state = false; // don't lock immediately after setting
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinKey) == pin;
  }

  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    state = false;
  }
}
