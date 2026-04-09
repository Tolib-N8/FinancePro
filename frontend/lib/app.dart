import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'config/router.dart';
import 'config/theme.dart';
import 'providers/lock_provider.dart';
import 'screens/lock/lock_screen.dart';

class FinanceProApp extends ConsumerWidget {
  const FinanceProApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLocked = ref.watch(lockProvider);

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

    return MaterialApp.router(
      title: 'FinancePro',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
