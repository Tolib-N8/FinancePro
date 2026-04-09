import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/constants.dart';
import '../../providers/lock_provider.dart';

class ShellScreen extends ConsumerWidget {
  final Widget child;

  const ShellScreen({super.key, required this.child});

  static const _destinations = [
    _NavDestination('/dashboard', Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
    _NavDestination('/accounts', Icons.account_balance_outlined, Icons.account_balance, 'Accounts'),
    _NavDestination('/transactions', Icons.receipt_long_outlined, Icons.receipt_long, 'Transactions'),
    _NavDestination('/analytics', Icons.bar_chart_outlined, Icons.bar_chart, 'Analytics'),
    _NavDestination('/chat', Icons.chat_outlined, Icons.chat, 'Assistant'),
    _NavDestination('/settings', Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  void _lock(BuildContext context, WidgetRef ref) async {
    final hasPin = await ref.read(lockProvider.notifier).hasPin();
    if (hasPin) {
      ref.read(lockProvider.notifier).lock();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set a PIN in Settings first')),
      );
    }
  }

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (var i = 0; i < _destinations.length; i++) {
      if (location.startsWith(_destinations[i].route)) return i;
    }
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    context.go(_destinations[index].route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
          context.go('/transactions/new');
        },
      },
      child: Focus(
        autofocus: true,
        child: _buildLayout(context, ref),
      ),
    );
  }

  Widget _buildLayout(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppConstants.navBreakpoint;
        final selectedIndex = _selectedIndex(context);

        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (i) => _onTap(context, i),
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        Icon(Icons.account_balance_wallet,
                            color: Theme.of(context).colorScheme.primary, size: 32),
                        const SizedBox(height: 4),
                        Text('Finance', style: Theme.of(context).textTheme.labelSmall),
                        Text('Pro', style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        )),
                      ],
                    ),
                  ),
                  trailing: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: IconButton(
                      icon: const Icon(Icons.lock_outline),
                      tooltip: 'Lock app',
                      onPressed: () => _lock(context, ref),
                    ),
                  ),
                  destinations: _destinations
                      .map((d) => NavigationRailDestination(
                            icon: Icon(d.icon),
                            selectedIcon: Icon(d.selectedIcon),
                            label: Text(d.label),
                          ))
                      .toList(),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: child),
              ],
            ),
          );
        } else {
          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.lock_outline),
                  tooltip: 'Lock app',
                  onPressed: () => _lock(context, ref),
                ),
              ],
            ),
            body: child,
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (i) => _onTap(context, i),
              destinations: _destinations
                  .map((d) => NavigationDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: d.label,
                      ))
                  .toList(),
            ),
          );
        }
      },
    );
  }
}

class _NavDestination {
  final String route;
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavDestination(this.route, this.icon, this.selectedIcon, this.label);
}
