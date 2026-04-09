import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/utils/currency_formatter.dart';
import '../../providers/account_provider.dart';
import '../../providers/exchange_provider.dart';
import '../../providers/settings_provider.dart';
import 'widgets/account_card.dart';
import 'widgets/account_form_dialog.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final ratesAsync = ref.watch(exchangeRatesProvider);
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(accountsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAccount(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 8),
              Text('Failed to load accounts', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('$e', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(accountsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (accounts) {
          if (accounts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No accounts yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('Tap + to add your first account',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final baseCurrency = settingsAsync.valueOrNull?.baseCurrency ?? 'USD';
          final rates = ratesAsync.valueOrNull ?? {};
          double totalBalance = 0;
          for (final a in accounts) {
            final converted = rates.isNotEmpty
                ? convertAmount(rates, a.balance, a.currency, baseCurrency, baseCurrency)
                : null;
            totalBalance += converted ?? a.balance;
          }

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primaryContainer,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: Colors.white, size: 32),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Net Worth',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.white70)),
                        Text(
                          CurrencyFormatter.format(totalBalance, baseCurrency),
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 320,
                    childAspectRatio: 1.6,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: accounts.length,
                  itemBuilder: (context, i) => AccountCard(
                    account: accounts[i],
                    onTap: () => context.go('/accounts/${accounts[i].id}'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddAccount(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AccountFormDialog(
        onSaved: () => ref.invalidate(accountsProvider),
      ),
    );
  }
}
