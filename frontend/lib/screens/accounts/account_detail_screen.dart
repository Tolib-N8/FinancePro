import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/utils/currency_formatter.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';
import '../transactions/widgets/transaction_tile.dart';

class AccountDetailScreen extends ConsumerWidget {
  final String accountId;

  const AccountDetailScreen({super.key, required this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(accountDetailProvider(accountId));
    final txAsync = ref.watch(transactionsProvider(TransactionFilters(accountId: accountId)));

    return Scaffold(
      appBar: AppBar(
        title: accountAsync.when(
          data: (a) => Text(a.name),
          loading: () => const Text('Account'),
          error: (_, __) => const Text('Account'),
        ),
      ),
      body: accountAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (account) => Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(int.parse(account.color.replaceFirst('#', '0xFF'))),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance, color: Colors.white, size: 40),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(account.type.replaceAll('_', ' '),
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(
                        CurrencyFormatter.format(account.balance, account.currency),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text('Transactions', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                    onPressed: () => context.go('/transactions/new'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: txAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (paginated) => ListView.builder(
                  itemCount: paginated.items.length,
                  itemBuilder: (context, i) => TransactionTile(
                    transaction: paginated.items[i],
                    onTap: () => context.go('/transactions/${paginated.items[i].id}'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
