import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/api/endpoints.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/account_provider.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/api_client_provider.dart';
import '../../providers/transaction_provider.dart';
import '../transactions/widgets/transaction_tile.dart';

class AccountDetailScreen extends ConsumerStatefulWidget {
  final String accountId;

  const AccountDetailScreen({super.key, required this.accountId});

  @override
  ConsumerState<AccountDetailScreen> createState() =>
      _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  bool _importingStatement = false;

  @override
  Widget build(BuildContext context) {
    final accountAsync = ref.watch(accountDetailProvider(widget.accountId));
    final txFilters = TransactionFilters(accountId: widget.accountId);
    final txAsync = ref.watch(transactionsProvider(txFilters));

    return Scaffold(
      appBar: AppBar(
        title: accountAsync.when(
          data: (a) => Text(a.name),
          loading: () => const Text('Account'),
          error: (_, __) => const Text('Account'),
        ),
        actions: [
          _importingStatement
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.upload_file_outlined),
                  tooltip: 'Import statement',
                  onPressed: _importStatement,
                ),
        ],
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
                color:
                    Color(int.parse(account.color.replaceFirst('#', '0xFF'))),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance,
                      color: Colors.white, size: 40),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(account.type.replaceAll('_', ' '),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                      Text(
                        CurrencyFormatter.format(
                            account.balance, account.currency),
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
                  Text('Transactions',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: const Text('Import Statement'),
                    onPressed: _importingStatement ? null : _importStatement,
                  ),
                  const SizedBox(width: 8),
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
                    onTap: () =>
                        context.go('/transactions/${paginated.items[i].id}'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importStatement() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt', 'xlsx', 'pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    setState(() => _importingStatement = true);

    try {
      final client = await ref.read(apiClientProvider.future);
      final MultipartFile multipart;
      if (file.path != null) {
        multipart =
            await MultipartFile.fromFile(file.path!, filename: file.name);
      } else if (file.bytes != null) {
        multipart = MultipartFile.fromBytes(file.bytes!, filename: file.name);
      } else {
        throw Exception('Unable to read selected file');
      }

      final response = await client.post(
        Endpoints.importStatement(widget.accountId),
        data: FormData.fromMap({'file': multipart}),
      );

      ref.invalidate(accountDetailProvider(widget.accountId));
      ref.invalidate(accountsProvider);
      ref.invalidate(transactionsProvider(
          TransactionFilters(accountId: widget.accountId)));
      ref.invalidate(monthlySummaryProvider(null));
      ref.invalidate(categoryBreakdownProvider((null, null)));
      ref.invalidate(monthlyTrendProvider(12));
      ref.invalidate(forecastProvider(null));

      if (!mounted) return;
      final data = response.data as Map<String, dynamic>;
      final parsed = data['parsed_count'] ?? 0;
      final imported = data['imported_count'] ?? 0;
      final duplicates = data['skipped_duplicates'] ?? 0;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Statement Imported'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Parsed: $parsed'),
              Text('Imported: $imported'),
              Text('Skipped duplicates: $duplicates'),
              const SizedBox(height: 12),
              const Text(
                'Supported formats: CSV, TXT, XLSX, PDF, JPG, PNG, WEBP',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importingStatement = false);
    }
  }
}
