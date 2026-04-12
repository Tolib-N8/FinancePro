import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../providers/exchange_provider.dart';
import '../../providers/lock_provider.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _urlController;
  late final TextEditingController _keyController;
  late final TextEditingController _currencyController;
  bool _obscureKey = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _keyController = TextEditingController();
    _currencyController = TextEditingController();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settings) {
          if (_urlController.text.isEmpty) {
            _urlController.text = settings.apiBaseUrl;
            _keyController.text = settings.apiKey;
            _currencyController.text = settings.baseCurrency;
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Connection', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _urlController,
                        decoration: const InputDecoration(
                          labelText: 'API Base URL',
                          hintText: 'http://localhost:8000',
                          prefixIcon: Icon(Icons.link),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _keyController,
                        obscureText: _obscureKey,
                        decoration: InputDecoration(
                          labelText: 'API Key',
                          prefixIcon: const Icon(Icons.key),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _obscureKey = !_obscureKey),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Preferences', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _currencyController,
                        decoration: const InputDecoration(
                          labelText: 'Base Currency',
                          hintText: 'USD',
                          prefixIcon: Icon(Icons.currency_exchange),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              _PinCard(),
              const SizedBox(height: 12),
              _CurrencyConverterCard(baseCurrency: settings.baseCurrency),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : () async {
                  setState(() => _saving = true);
                  await ref.read(settingsProvider.notifier).save(
                    apiBaseUrl: _urlController.text.trim(),
                    apiKey: _keyController.text.trim(),
                    baseCurrency: _currencyController.text.trim().toUpperCase(),
                  );
                  ref.invalidate(settingsProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Settings saved')),
                    );
                  }
                  setState(() => _saving = false);
                },
                icon: const Icon(Icons.save),
                label: const Text('Save Settings'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── PIN Management ──────────────────────────────────────────────────────────

class _PinCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PinCard> createState() => _PinCardState();
}

class _PinCardState extends ConsumerState<_PinCard> {
  bool? _hasPin;
  int _autoLockMinutes = 5;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final has = await ref.read(lockProvider.notifier).hasPin();
    final minutes = await ref.read(lockProvider.notifier).getAutoLockMinutes();
    if (mounted) setState(() { _hasPin = has; _autoLockMinutes = minutes; });
  }

  Future<void> _showPinDialog({
    required String title,
    String? confirmTitle,
    bool requireCurrent = false,
  }) async {
    final notifier = ref.read(lockProvider.notifier);

    // Step 1: verify current PIN if needed
    if (requireCurrent) {
      final current = await _inputPin(context, 'Enter current PIN');
      if (current == null) return;
      final ok = await notifier.verifyPin(current);
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Wrong PIN')),
          );
        }
        return;
      }
    }

    // Step 2: enter new PIN
    final newPin = await _inputPin(context, title);
    if (newPin == null) return;
    if (newPin.length < 4) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('PIN must be 4 digits')));
      }
      return;
    }

    // Step 3: confirm new PIN
    final confirm = await _inputPin(context, confirmTitle ?? 'Confirm PIN');
    if (confirm == null) return;
    if (newPin != confirm) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('PINs do not match')));
      }
      return;
    }

    await notifier.setPin(newPin);
    _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('PIN saved')));
    }
  }

  Future<void> _removePin() async {
    final notifier = ref.read(lockProvider.notifier);
    final current = await _inputPin(context, 'Enter current PIN to remove');
    if (current == null) return;
    final ok = await notifier.verifyPin(current);
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Wrong PIN')));
      }
      return;
    }
    await notifier.removePin();
    _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('PIN removed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasPin == null) return const SizedBox();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 20),
                const SizedBox(width: 8),
                Text('App Lock', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (_hasPin!)
                  Chip(
                    label: const Text('ON', style: TextStyle(fontSize: 11)),
                    backgroundColor: Colors.green.withOpacity(0.15),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _hasPin!
                  ? 'App is protected with a PIN'
                  : 'Set a PIN to protect the app on startup',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!_hasPin!)
                  FilledButton.icon(
                    onPressed: () => _showPinDialog(
                      title: 'Set new PIN',
                      confirmTitle: 'Confirm new PIN',
                    ),
                    icon: const Icon(Icons.lock, size: 18),
                    label: const Text('Set PIN'),
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: () => _showPinDialog(
                      title: 'Enter new PIN',
                      confirmTitle: 'Confirm new PIN',
                      requireCurrent: true,
                    ),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Change PIN'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _removePin,
                    icon: const Icon(Icons.lock_open, size: 18, color: Colors.red),
                    label: const Text('Remove', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ],
            ),
            if (_hasPin!) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 18),
                  const SizedBox(width: 8),
                  const Text('Auto-lock after:'),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _autoLockMinutes,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Off')),
                      DropdownMenuItem(value: 1, child: Text('1 min')),
                      DropdownMenuItem(value: 3, child: Text('3 min')),
                      DropdownMenuItem(value: 5, child: Text('5 min')),
                      DropdownMenuItem(value: 10, child: Text('10 min')),
                      DropdownMenuItem(value: 15, child: Text('15 min')),
                      DropdownMenuItem(value: 30, child: Text('30 min')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      await ref.read(lockProvider.notifier).setAutoLockMinutes(v);
                      setState(() => _autoLockMinutes = v);
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows a compact 4-digit PIN entry dialog. Returns the entered PIN or null if cancelled.
Future<String?> _inputPin(BuildContext context, String title) {
  String pin = '';
  final focusNode = FocusNode();
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        WidgetsBinding.instance.addPostFrameCallback((_) => focusNode.requestFocus());
        return KeyboardListener(
          focusNode: focusNode,
          onKeyEvent: (event) {
            if (event is! KeyDownEvent) return;
            final label = event.logicalKey.keyLabel;
            if (label.length == 1 && RegExp(r'[0-9]').hasMatch(label)) {
              if (pin.length < 4) {
                setState(() => pin += label);
                if (pin.length == 4) Navigator.of(ctx).pop(pin);
              }
            } else if (event.logicalKey == LogicalKeyboardKey.backspace ||
                       event.logicalKey == LogicalKeyboardKey.delete) {
              if (pin.isNotEmpty) setState(() => pin = pin.substring(0, pin.length - 1));
            } else if (event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.of(ctx).pop(null);
            }
          },
          child: AlertDialog(
          title: Text(title),
          content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < pin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? Theme.of(ctx).colorScheme.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: Theme.of(ctx).colorScheme.outline,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            // mini numpad
            for (final row in [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
              ['', '0', '<'],
            ])
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.map((k) {
                  if (k.isEmpty) return const SizedBox(width: 64, height: 48);
                  return SizedBox(
                    width: 64,
                    height: 48,
                    child: TextButton(
                      onPressed: () {
                        if (k == '<') {
                          if (pin.isNotEmpty) setState(() => pin = pin.substring(0, pin.length - 1));
                        } else if (pin.length < 4) {
                          setState(() => pin += k);
                          if (pin.length == 4) {
                            Navigator.of(ctx).pop(pin);
                          }
                        }
                      },
                      child: k == '<'
                          ? const Icon(Icons.backspace_outlined, size: 18)
                          : Text(k, style: const TextStyle(fontSize: 20)),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
        ],
        ),  // AlertDialog
        );  // KeyboardListener
      },
    ),
  );
}

// ─── Currency Converter ───────────────────────────────────────────────────────

class _CurrencyConverterCard extends ConsumerStatefulWidget {
  final String baseCurrency;
  const _CurrencyConverterCard({required this.baseCurrency});

  @override
  ConsumerState<_CurrencyConverterCard> createState() => _CurrencyConverterCardState();
}

class _CurrencyConverterCardState extends ConsumerState<_CurrencyConverterCard> {
  final _amountCtrl = TextEditingController(text: '1');
  String _from = 'USD';
  String _to = 'EUR';

  @override
  Widget build(BuildContext context) {
    final ratesAsync = ref.watch(exchangeRatesProvider);
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final rates = ratesAsync.valueOrNull ?? {};
    final result = rates.isNotEmpty && amount > 0
        ? convertAmount(rates, amount, _from, _to, widget.baseCurrency)
        : null;
    final unavailable = rates.isNotEmpty && amount > 0 && result == null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Currency Converter', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    decoration: const InputDecoration(labelText: 'Amount', isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                _CurrencyDropdown(value: _from, onChanged: (v) => setState(() => _from = v)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, size: 18),
                ),
                _CurrencyDropdown(value: _to, onChanged: (v) => setState(() => _to = v)),
              ],
            ),
            const SizedBox(height: 12),
            if (ratesAsync.isLoading)
              const LinearProgressIndicator()
            else if (result != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.currency_exchange, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${_amountCtrl.text} $_from = ${result.toStringAsFixed(4)} $_to',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              )
            else if (unavailable)
              Text('Rate not available for $_from → $_to', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange))
            else
              Text('Enter amount to convert', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _CurrencyDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _CurrencyDropdown({required this.value, required this.onChanged});

  static const _currencies = [
    'USD', 'EUR', 'GBP', 'CNY', 'JPY', 'CHF', 'CAD',
    'AUD', 'INR', 'TRY', 'RUB', 'KRW', 'BRL', 'SEK',
    'NOK', 'DKK', 'PLN', 'HUF', 'CZK', 'MXN', 'SGD',
  ];

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: value,
      isDense: true,
      items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
      onChanged: (v) => onChanged(v ?? value),
    );
  }
}
