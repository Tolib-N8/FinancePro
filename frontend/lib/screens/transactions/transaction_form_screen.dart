import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/endpoints.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/account_provider.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/api_client_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/exchange_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';

// Frankfurter.app supported currencies (ECB)
const List<String> _commonCurrencies = [
  'USD', 'EUR', 'GBP', 'CNY', 'JPY', 'CHF', 'CAD',
  'AUD', 'INR', 'TRY', 'RUB', 'KRW', 'BRL', 'SEK',
  'NOK', 'DKK', 'PLN', 'HUF', 'CZK', 'MXN', 'SGD',
  'UZS', 'TJS',
];

class TransactionFormScreen extends ConsumerStatefulWidget {
  final String? txId;

  const TransactionFormScreen({super.key, this.txId});

  @override
  ConsumerState<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  String _type = 'expense';
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  String _currency = 'USD';       // currency of the transaction (what user enters)
  String _accountCurrency = 'USD'; // currency of the selected account
  DateTime _date = DateTime.now();
  bool _saving = false;
  bool _loaded = false;
  PlatformFile? _receiptFile;

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final ratesAsync = ref.watch(exchangeRatesProvider);
    final settingsAsync = ref.watch(settingsProvider);

    // Load existing transaction for edit
    if (widget.txId != null && !_loaded) {
      final txAsync = ref.watch(transactionDetailProvider(widget.txId!));
      txAsync.whenData((tx) {
        if (!_loaded) {
          _amountController.text = tx.amount.toString();
          _descController.text = tx.description ?? '';
          _type = tx.type;
          _accountId = tx.accountId;
          _toAccountId = tx.toAccountId;
          _categoryId = tx.categoryId;
          _currency = tx.currency;
          _date = DateTime.parse(tx.date);
          // Set account currency from accounts list
          final accounts = ref.read(accountsProvider).valueOrNull ?? [];
          final acc = accounts.where((a) => a.id == tx.accountId).firstOrNull;
          if (acc != null) _accountCurrency = acc.currency;
          _loaded = true;
        }
      });
    }

    final baseCurrency = settingsAsync.valueOrNull?.baseCurrency ?? 'USD';
    final amount = double.tryParse(_amountController.text) ?? 0;
    final rates = ratesAsync.valueOrNull ?? {};

    // Preview: show converted amount in account's currency (if differs from tx currency)
    final needsConversion = amount > 0 &&
        _currency.toUpperCase() != _accountCurrency.toUpperCase() &&
        rates.isNotEmpty;
    final convertedAmount = needsConversion
        ? convertAmount(rates, amount, _currency, _accountCurrency, baseCurrency)
        : null;
    final rateUnavailable = needsConversion && convertedAmount == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.txId == null ? 'New Transaction' : 'Edit Transaction'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type selector
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'income', label: Text('Income'), icon: Icon(Icons.arrow_downward)),
                ButtonSegment(value: 'expense', label: Text('Expense'), icon: Icon(Icons.arrow_upward)),
                ButtonSegment(value: 'transfer', label: Text('Transfer'), icon: Icon(Icons.swap_horiz)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),

            // Amount + currency
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid number';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _commonCurrencies.contains(_currency) ? _currency : null,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items: _commonCurrencies
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _currency = v ?? _currency),
                  ),
                ),
              ],
            ),

            // Conversion preview
            if (ratesAsync.isLoading && amount > 0)
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 4),
                child: SizedBox(height: 10, width: 10, child: CircularProgressIndicator(strokeWidth: 1.5)),
              )
            else if (convertedAmount != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Row(
                  children: [
                    const Icon(Icons.currency_exchange, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '$amount $_currency → ${convertedAmount.toStringAsFixed(2)} $_accountCurrency',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              )
            else if (rateUnavailable)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  'Rate for $_currency not available',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange),
                ),
              ),

            const SizedBox(height: 12),

            // Date picker
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(DateFormatter.toApiDate(_date)),
              ),
            ),
            const SizedBox(height: 12),

            // Account selector
            accountsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox(),
              data: (accounts) => DropdownButtonFormField<String>(
                value: _accountId,
                decoration: const InputDecoration(
                  labelText: 'Account',
                  prefixIcon: Icon(Icons.account_balance),
                ),
                items: accounts.map((a) => DropdownMenuItem(
                  value: a.id,
                  child: Row(
                    children: [
                      Text(a.name),
                      const SizedBox(width: 8),
                      Text(
                        a.currency,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                )).toList(),
                onChanged: (v) {
                  setState(() {
                    _accountId = v;
                    if (v != null) {
                      final acc = accounts.firstWhere((a) => a.id == v);
                      _accountCurrency = acc.currency;
                    }
                  });
                },
                validator: (v) => v == null ? 'Required' : null,
              ),
            ),
            const SizedBox(height: 12),

            // To Account (only for transfers)
            if (_type == 'transfer')
              accountsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox(),
                data: (accounts) => DropdownButtonFormField<String>(
                  value: _toAccountId,
                  decoration: const InputDecoration(
                    labelText: 'To Account',
                    prefixIcon: Icon(Icons.account_balance_outlined),
                  ),
                  items: accounts
                      .where((a) => a.id != _accountId)
                      .map((a) => DropdownMenuItem(
                            value: a.id,
                            child: Row(
                              children: [
                                Text(a.name),
                                const SizedBox(width: 8),
                                Text(a.currency,
                                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _toAccountId = v),
                  validator: (v) => _type == 'transfer' && v == null ? 'Required' : null,
                ),
              ),
            if (_type == 'transfer') const SizedBox(height: 12),

            // Category selector
            categoriesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox(),
              data: (categories) => DropdownButtonFormField<String>(
                value: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Category (optional — AI will auto-fill)',
                  prefixIcon: Icon(Icons.label),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Auto (AI)')),
                  ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
            ),
            const SizedBox(height: 12),

            // Description
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.notes),
                hintText: 'e.g. Grocery store, Salary...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            // Receipt attachment
            InkWell(
              onTap: _picking,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _receiptFile != null ? Icons.receipt_long : Icons.attach_file,
                      color: _receiptFile != null
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _receiptFile != null ? _receiptFile!.name : 'Attach receipt (optional)',
                        style: TextStyle(
                          color: _receiptFile != null
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_receiptFile != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _receiptFile = null),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(widget.txId == null ? 'Create Transaction' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _picking() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'heic'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _receiptFile = result.files.first);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account')),
      );
      return;
    }
    if (_type == 'transfer' && _toAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a destination account')),
      );
      return;
    }
    setState(() => _saving = true);

    try {
      final client = await ref.read(apiClientProvider.future);
      final data = {
        'type': _type,
        'amount': double.parse(_amountController.text),
        'currency': _currency,
        'date': DateFormatter.toApiDate(_date),
        'account_id': _accountId,
        if (_type == 'transfer' && _toAccountId != null) 'to_account_id': _toAccountId,
        'description': _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        if (_categoryId != null) 'category_id': _categoryId,
      };

      String? savedTxId;
      if (widget.txId == null) {
        final resp = await client.post(Endpoints.transactions, data: data);
        savedTxId = resp.data['id'] as String?;
      } else {
        await client.put(Endpoints.transaction(widget.txId!), data: data);
        savedTxId = widget.txId;
      }

      // Upload receipt if selected
      if (_receiptFile != null && savedTxId != null) {
        final MultipartFile multipart;
        if (_receiptFile!.path != null) {
          multipart = await MultipartFile.fromFile(_receiptFile!.path!, filename: _receiptFile!.name);
        } else {
          multipart = MultipartFile.fromBytes(_receiptFile!.bytes!, filename: _receiptFile!.name);
        }
        final uploadResp = await client.post(
          Endpoints.receiptUpload,
          data: FormData.fromMap({'file': multipart}),
        );
        final receiptId = uploadResp.data['id'] as String;
        await client.post(Endpoints.linkReceipt(receiptId, savedTxId));
      }

      ref.invalidate(transactionsProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(monthlySummaryProvider);
      ref.invalidate(categoryBreakdownProvider);

      if (mounted) context.go('/transactions');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
