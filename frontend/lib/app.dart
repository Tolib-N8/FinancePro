import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'config/router.dart';
import 'config/theme.dart';
import 'providers/lock_provider.dart';
import 'screens/lock/lock_screen.dart';

class FinanceProApp extends ConsumerStatefulWidget {
  const FinanceProApp({super.key});

  @override
  ConsumerState<FinanceProApp> createState() => _FinanceProAppState();
}

class _FinanceProAppState extends ConsumerState<FinanceProApp> {
  Timer? _autoLockTimer;
  int _autoLockMinutes = 5;

  @override
  void initState() {
    super.initState();
    _loadAutoLockSetting();
  }

  Future<void> _loadAutoLockSetting() async {
    final minutes = await ref.read(lockProvider.notifier).getAutoLockMinutes();
    setState(() => _autoLockMinutes = minutes);
    _resetTimer();
  }

  void _resetTimer() {
    _autoLockTimer?.cancel();
    if (_autoLockMinutes <= 0) return;

    _autoLockTimer = Timer(Duration(minutes: _autoLockMinutes), () async {
      final hasPin = await ref.read(lockProvider.notifier).hasPin();
      if (hasPin) {
        ref.read(lockProvider.notifier).lock();
      }
    });
  }

  void _onUserActivity() {
    final isLocked = ref.read(lockProvider);
    if (!isLocked) _resetTimer();
  }

  @override
  void dispose() {
    _autoLockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = ref.watch(lockProvider);

    // Reload auto-lock setting when lock state changes (e.g. after settings update)
    ref.listen(lockProvider, (prev, next) {
      if (prev == true && next == false) {
        _loadAutoLockSetting();
      }
    });

    if (isLocked) {
      return MaterialApp(
        title: 'FinancePro',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: const LockScreen(),
      );
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onUserActivity(),
      onPointerMove: (_) => _onUserActivity(),
      child: MaterialApp.router(
        title: 'FinancePro',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        routerConfig: appRouter,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
