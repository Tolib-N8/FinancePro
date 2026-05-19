import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/api/endpoints.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/api_client_provider.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'By Category'),
            Tab(text: 'Trends'),
            Tab(text: 'Forecast'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _OverviewTab(),
          _CategoryTab(),
          _TrendsTab(),
          _ForecastTab(),
        ],
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(monthlySummaryProvider(null));

    return summaryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (summary) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _SummaryCard(
                label: 'Income',
                value: CurrencyFormatter.format(summary.income, 'USD'),
                color: Colors.green,
                icon: Icons.arrow_downward,
              ),
              const SizedBox(width: 12),
              _SummaryCard(
                label: 'Expenses',
                value: CurrencyFormatter.format(summary.expenses, 'USD'),
                color: Colors.red,
                icon: Icons.arrow_upward,
              ),
              const SizedBox(width: 12),
              _SummaryCard(
                label: 'Savings',
                value: CurrencyFormatter.format(summary.savings, 'USD'),
                color: summary.savings >= 0 ? Colors.blue : Colors.orange,
                icon: Icons.savings,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('This Month: ${summary.month}',
              style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: color, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTab extends ConsumerWidget {
  const _CategoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakdownAsync = ref.watch(categoryBreakdownProvider((null, null)));

    return breakdownAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (categories) {
        if (categories.isEmpty) {
          return const Center(child: Text('No expense data yet'));
        }
        return Row(
          children: [
            Expanded(
              child: PieChart(
                PieChartData(
                  sections: categories.take(8).map((c) {
                    Color color;
                    try {
                      color =
                          Color(int.parse(c.color.replaceFirst('#', '0xFF')));
                    } catch (_) {
                      color = Colors.grey;
                    }
                    return PieChartSectionData(
                      color: color,
                      value: c.total,
                      title: '${c.percentage.toStringAsFixed(0)}%',
                      radius: 80,
                      titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            SizedBox(
              width: 200,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: categories
                    .map((c) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Color(int.parse(
                                      c.color.replaceFirst('#', '0xFF'))),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(c.categoryName,
                                      style: const TextStyle(fontSize: 12))),
                              Text(
                                  CurrencyFormatter.formatCompact(
                                      c.total, 'USD'),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TrendsTab extends ConsumerWidget {
  const _TrendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(monthlyTrendProvider(12));

    return trendAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (trends) {
        if (trends.isEmpty) {
          return const Center(child: Text('Not enough data yet'));
        }

        final maxVal = trends
            .map((t) => t.income > t.expenses ? t.income : t.expenses)
            .reduce((a, b) => a > b ? a : b);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: BarChart(
            BarChartData(
              maxY: maxVal * 1.2,
              barGroups: trends.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                        toY: e.value.income, color: Colors.green, width: 8),
                    BarChartRodData(
                        toY: e.value.expenses, color: Colors.red, width: 8),
                  ],
                );
              }).toList(),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= trends.length) return const SizedBox();
                      return Text(trends[i].month.substring(5),
                          style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) => Text(
                      CurrencyFormatter.formatCompact(v, 'USD'),
                      style: const TextStyle(fontSize: 9),
                    ),
                  ),
                ),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: false),
            ),
          ),
        );
      },
    );
  }
}

class _ForecastTab extends ConsumerWidget {
  const _ForecastTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecastAsync = ref.watch(forecastProvider(null));

    return forecastAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.psychology_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Not enough data for forecast yet'),
            const SizedBox(height: 8),
            Text('$e',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
      data: (forecast) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.purple),
                      const SizedBox(width: 8),
                      Text('AI Forecast — ${forecast.month}',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      if (forecast.confidence != null)
                        Chip(
                          label: Text(forecast.confidence!.toUpperCase()),
                          backgroundColor:
                              _confidenceColor(forecast.confidence!)
                                  .withValues(alpha: 0.15),
                        ),
                    ],
                  ),
                  if (forecast.totalPredicted != null) ...[
                    const SizedBox(height: 12),
                    Text('Total predicted expenses',
                        style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      CurrencyFormatter.format(forecast.totalPredicted!, 'USD'),
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('By Category', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...forecast.predictions.entries.map((e) => Card(
                child: ListTile(
                  title: Text(e.key),
                  trailing: Text(
                    CurrencyFormatter.format(
                        (e.value as num).toDouble(), 'USD'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              )),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Forecast'),
            onPressed: () async {
              try {
                final client = await ref.read(apiClientProvider.future);
                await client.post(Endpoints.analyticsRefreshForecast);
                ref.invalidate(forecastProvider(null));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Forecast refreshed')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Refresh failed: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Color _confidenceColor(String confidence) {
    switch (confidence) {
      case 'high':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }
}
