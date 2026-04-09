import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../providers/lock_provider.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen>
    with SingleTickerProviderStateMixin {
  String _entered = '';
  bool _error = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  final FocusNode _focusNode = FocusNode();

  static const _pinLength = 4;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onKey(String digit) {
    if (_entered.length >= _pinLength) return;
    setState(() {
      _entered += digit;
      _error = false;
    });
    if (_entered.length == _pinLength) {
      _checkPin();
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _checkPin() async {
    final ok = await ref.read(lockProvider.notifier).unlock(_entered);
    if (!ok) {
      HapticFeedback.heavyImpact();
      setState(() => _error = true);
      _shakeController.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _entered = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is! KeyDownEvent) return;
          final label = event.logicalKey.keyLabel;
          if (label.length == 1 && RegExp(r'[0-9]').hasMatch(label)) {
            _onKey(label);
          } else if (event.logicalKey == LogicalKeyboardKey.backspace ||
                     event.logicalKey == LogicalKeyboardKey.delete) {
            _onBackspace();
          }
        },
        child: SafeArea(
          child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Icon(
                  Icons.account_balance_wallet,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  'FinancePro',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter your PIN',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 40),

                // PIN dots
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    final offset = _error
                        ? 12 * (_shakeAnimation.value < 0.5
                            ? _shakeAnimation.value * 2
                            : (1 - _shakeAnimation.value) * 2)
                        : 0.0;
                    return Transform.translate(
                      offset: Offset(offset * (_shakeAnimation.value > 0.5 ? -1 : 1) * 8, 0),
                      child: child,
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pinLength, (i) {
                      final filled = i < _entered.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _error
                              ? Colors.red
                              : filled
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                          border: Border.all(
                            color: _error
                                ? Colors.red
                                : filled
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline,
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                if (_error)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Wrong PIN',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
                    ),
                  ),

                const SizedBox(height: 40),

                // Numpad
                _NumPad(onKey: _onKey, onBackspace: _onBackspace),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class _NumPad extends StatelessWidget {
  final void Function(String) onKey;
  final VoidCallback onBackspace;

  const _NumPad({required this.onKey, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '<'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              if (key.isEmpty) return const SizedBox(width: 80, height: 64);
              if (key == '<') {
                return _PadButton(
                  onTap: onBackspace,
                  child: const Icon(Icons.backspace_outlined, size: 22),
                );
              }
              return _PadButton(
                onTap: () => onKey(key),
                child: Text(key, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w400)),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _PadButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _PadButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 64,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(40),
          child: Center(child: child),
        ),
      ),
    );
  }
}
