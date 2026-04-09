import 'package:flutter/material.dart';

import '../../../core/models/transaction.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';

class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;

  const TransactionTile({super.key, required this.transaction, this.onTap});

  Color get _amountColor {
    switch (transaction.type) {
      case 'income':
        return Colors.green;
      case 'expense':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData get _typeIcon {
    switch (transaction.type) {
      case 'income':
        return Icons.arrow_downward;
      case 'expense':
        return Icons.arrow_upward;
      default:
        return Icons.swap_horiz;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: _amountColor.withOpacity(0.15),
        child: Icon(_typeIcon, color: _amountColor, size: 18),
      ),
      title: Text(
        transaction.description ?? transaction.type,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Text(
            DateFormatter.formatDate(transaction.date),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (transaction.category != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Color(int.parse(
                        (transaction.category!.color).replaceFirst('#', '0xFF')))
                    .withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                transaction.category!.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
              ),
            ),
          ],
          if (transaction.aiCategorized) ...[
            const SizedBox(width: 4),
            Icon(Icons.auto_awesome, size: 10, color: Colors.purple.withOpacity(0.6)),
          ],
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${transaction.type == "expense" ? "-" : "+"}${CurrencyFormatter.format(transaction.amount, transaction.currency)}',
            style: TextStyle(
              color: _amountColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          if (transaction.amountBase != null &&
              transaction.amountBase!.toStringAsFixed(2) != transaction.amount.toStringAsFixed(2))
            Text(
              '≈ ${transaction.amountBase!.toStringAsFixed(2)} base',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
        ],
      ),
    );
  }
}
