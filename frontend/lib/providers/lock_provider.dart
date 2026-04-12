import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pinKey = 'app_pin';
const _pinVersionKey = 'app_pin_version';
const _autoLockKey = 'auto_lock_minutes';
const _currentPinVersion = 2; // v2 = SHA-256 hashed

String _hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();

/// true = app is locked and requires PIN entry
final lockProvider = StateNotifierProvider<LockNotifier, bool>((ref) {
  return LockNotifier();
});

/// Auto-lock timeout in minutes (0 = disabled)
final autoLockMinutesProvider = StateProvider<int>((ref) => 5);

class LockNotifier extends StateNotifier<bool> {
  LockNotifier() : super(false) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final version = prefs.getInt(_pinVersionKey) ?? 0;

    // Migrate plain-text PIN (v0) → clear it, user must re-set
    if (version < _currentPinVersion) {
      final oldPin = prefs.getString(_pinKey);
      if (oldPin != null && oldPin.isNotEmpty) {
        await prefs.remove(_pinKey);
        await prefs.remove(_pinVersionKey);
        state = false;
        return;
      }
    }

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
    final stored = prefs.getString(_pinKey);
    if (stored != null && stored == _hashPin(pin)) {
      state = false;
      return true;
    }
    return false;
  }

  void lock() => state = true;

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, _hashPin(pin));
    await prefs.setInt(_pinVersionKey, _currentPinVersion);
    state = false; // don't lock immediately after setting
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_pinKey);
    return stored != null && stored == _hashPin(pin);
  }

  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    await prefs.remove(_pinVersionKey);
    state = false;
  }

  Future<int> getAutoLockMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_autoLockKey) ?? 5;
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoLockKey, minutes);
  }
}
