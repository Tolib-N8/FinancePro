import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../config/constants.dart';
import '../../../core/api/endpoints.dart';
import '../../../providers/api_client_provider.dart';

class AccountFormDialog extends ConsumerStatefulWidget {
  final VoidCallback? onSaved;

  const AccountFormDialog({super.key, this.onSaved});

  @override
  ConsumerState<AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends ConsumerState<AccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController(text: '0');
  String _type = 'bank';
  String _currency = 'USD';
  String _color = '#4A90E2';
  bool _saving = false;

  static const _currencies = [
    'USD', 'EUR', 'GBP', 'CNY', 'JPY', 'CHF', 'CAD',
    'AUD', 'INR', 'TRY', 'RUB', 'KRW', 'BRL', 'SEK',
    'NOK', 'DKK', 'PLN', 'HUF', 'CZK', 'MXN', 'SGD',
    'UZS', 'TJS',
  ];

  static const _colors = [
    '#4A90E2', '#2ECC71', '#E74C3C', '#F39C12',
    '#9B59B6', '#1ABC9C', '#E67E22', '#34495E',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Account'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Account Name'),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: AppConstants.accountTypes
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(AppConstants.accountTypeLabels[t] ?? t),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _balanceController,
                      decoration: const InputDecoration(labelText: 'Initial Balance'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    child: DropdownButtonFormField<String>(
                      value: _currency,
                      decoration: const InputDecoration(labelText: 'Currency'),
                      items: _currencies
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setState(() => _currency = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Color', style: Theme.of(context).textTheme.labelMedium),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _colors.map((c) {
                  final color = Color(int.parse(c.replaceFirst('#', '0xFF')));
                  return InkWell(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: _color == c
                            ? Border.all(color: Colors.black, width: 2)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final client = await ref.read(apiClientProvider.future);
      await client.post(Endpoints.accounts, data: {
        'name': _nameController.text.trim(),
        'type': _type,
        'currency': _currency,
        'balance': double.tryParse(_balanceController.text) ?? 0.0,
        'color': _color,
        'icon': 'account_balance',
      });
      widget.onSaved?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
