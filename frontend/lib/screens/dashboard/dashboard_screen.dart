import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/account_provider.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/exchange_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final summaryAsync = ref.watch(monthlySummaryProvider(null));
    final recentTxAsync = ref.watch(transactionsProvider(const TransactionFilters(pageSize: 5)));
    final breakdownAsync = ref.watch(categoryBreakdownProvider((null, null)));
    final ratesAsync = ref.watch(exchangeRatesProvider);
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(accountsProvider);
              ref.invalidate(monthlySummaryProvider(null));
              ref.invalidate(transactionsProvider(const TransactionFilters(pageSize: 5)));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(accountsProvider);
          ref.invalidate(monthlySummaryProvider(null));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Net worth
            accountsAsync.when(
              loading: () => const Card(child: Padding(padding: EdgeInsets.all(24), child: LinearProgressIndicator())),
              error: (_, __) => const SizedBox(),
              data: (accounts) {
                final baseCurrency = settingsAsync.valueOrNull?.baseCurrency ?? 'USD';
                final rates = ratesAsync.valueOrNull ?? {};
                double netWorth = 0;
                for (final a in accounts) {
                  final converted = rates.isNotEmpty
                      ? convertAmount(rates, a.balance, a.currency, baseCurrency, baseCurrency)
                      : null;
                  netWorth += converted ?? a.balance;
                }
                return Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Net Worth',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer)),
                        Text(
                          CurrencyFormatter.format(netWorth, baseCurrency),
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: accounts.take(4).map((a) => Chip(
                            label: Text('${a.name}: ${CurrencyFormatter.formatCompact(a.balance, a.currency)}',
                                style: const TextStyle(fontSize: 11)),
                          )).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Monthly summary
            summaryAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox(),
              data: (summary) => Row(
                children: [
                  _MiniStat(label: 'Income', value: summary.income, color: Colors.green),
                  const SizedBox(width: 8),
                  _MiniStat(label: 'Expenses', value: summary.expenses, color: Colors.red),
                  const SizedBox(width: 8),
                  _MiniStat(label: 'Savings', value: summary.savings,
                      color: summary.savings >= 0 ? Colors.blue : Colors.orange),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Mini pie chart
            breakdownAsync.when(
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
              data: (cats) {
                if (cats.isEmpty) return const SizedBox();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Spending This Month',
                                style: Theme.of(context).textTheme.titleSmall),
                            const Spacer(),
                            TextButton(
                              onPressed: () => context.go('/analytics'),
                              child: const Text('See all'),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 150,
                          child: PieChart(
                            PieChartData(
                              sections: cats.take(5).map((c) {
                                Color color;
                                try {
                                  color = Color(int.parse(c.color.replaceFirst('#', '0xFF')));
                                } catch (_) {
                                  color = Colors.grey;
                                }
                                return PieChartSectionData(
                                  color: color,
                                  value: c.total,
                                  title: c.percentage > 10 ? '${c.percentage.toStringAsFixed(0)}%' : '',
                                  radius: 55,
                                  titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                );
                              }).toList(),
                              sectionsSpace: 1,
                              centerSpaceRadius: 30,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Recent transactions
            Row(
              children: [
                Text('Recent Transactions', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/transactions'),
                  child: const Text('See all'),
                ),
              ],
            ),
            recentTxAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox(),
              data: (paginated) => Column(
                children: paginated.items.map((tx) => ListTile(
                  dense: true,
                  title: Text(tx.description ?? tx.type, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(DateFormatter.formatDate(tx.date)),
                  trailing: Text(
                    '${tx.type == "expense" ? "-" : "+"}${CurrencyFormatter.format(tx.amount, tx.currency)}',
                    style: TextStyle(
                      color: tx.type == 'expense' ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () => context.go('/transactions/${tx.id}'),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                CurrencyFormatter.formatCompact(value, 'USD'),
                style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
