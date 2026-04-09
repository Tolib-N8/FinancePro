import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../providers/transaction_provider.dart';
import 'widgets/transaction_tile.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String? _typeFilter;
  String? _search;
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final filters = TransactionFilters(type: _typeFilter, search: _search);
    final txAsync = ref.watch(transactionsProvider(filters));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search transactions...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _search = null);
                            },
                          )
                        : null,
                    isDense: true,
                  ),
                  onSubmitted: (v) => setState(() => _search = v.isEmpty ? null : v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final type in [null, 'income', 'expense', 'transfer'])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(type?.toUpperCase() ?? 'ALL'),
                          selected: _typeFilter == type,
                          onSelected: (_) => setState(() => _typeFilter = type),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/transactions/new'),
        child: const Icon(Icons.add),
      ),
      body: txAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load: $e'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(transactionsProvider(filters)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (paginated) {
          if (paginated.items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No transactions found', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      '${paginated.total} transactions',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: paginated.items.length,
                  itemBuilder: (context, i) => TransactionTile(
                    transaction: paginated.items[i],
                    onTap: () => context.go('/transactions/${paginated.items[i].id}'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
