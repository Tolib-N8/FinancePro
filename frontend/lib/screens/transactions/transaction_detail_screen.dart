import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/api/endpoints.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/account_provider.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/api_client_provider.dart';
import '../../providers/transaction_provider.dart';

class TransactionDetailScreen extends ConsumerStatefulWidget {
  final String txId;

  const TransactionDetailScreen({super.key, required this.txId});

  @override
  ConsumerState<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends ConsumerState<TransactionDetailScreen> {
  final _commentController = TextEditingController();
  bool _uploadingReceipt = false;
  String? _loadingReceiptId;

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(transactionDetailProvider(widget.txId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.go('/transactions/${widget.txId}/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: txAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tx) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Amount card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      '${tx.type == "expense" ? "-" : "+"}${CurrencyFormatter.format(tx.amount, tx.currency)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: tx.type == 'expense' ? Colors.red : Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Chip(
                      label: Text(tx.type.toUpperCase()),
                      backgroundColor: tx.type == 'expense'
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Details
            Card(
              child: Column(
                children: [
                  _DetailRow(icon: Icons.calendar_today, label: 'Date', value: DateFormatter.formatDate(tx.date)),
                  if (tx.description != null)
                    _DetailRow(icon: Icons.notes, label: 'Description', value: tx.description!),
                  if (tx.category != null)
                    _DetailRow(
                      icon: Icons.label,
                      label: 'Category',
                      value: tx.category!.name,
                      suffix: tx.aiCategorized
                          ? const Chip(
                              label: Text('AI', style: TextStyle(fontSize: 10)),
                              padding: EdgeInsets.zero,
                            )
                          : null,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Receipts
            Row(
              children: [
                Text('Receipts', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                _uploadingReceipt
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton.filled(
                        icon: const Icon(Icons.attach_file, size: 18),
                        tooltip: 'Attach receipt',
                        onPressed: () => _uploadReceipt(tx.id),
                      ),
              ],
            ),
            const SizedBox(height: 4),
            if (tx.receipts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('No receipts attached', style: TextStyle(color: Colors.grey)),
              ),
            ...tx.receipts.map((r) {
              final isImage = r.mimeType.startsWith('image/');
              final ocrLabel = r.ocrStatus == 'done'
                  ? (r.merchant != null
                      ? '${r.merchant}${r.totalAmount != null ? " · ${r.totalAmount!.toStringAsFixed(2)} ${r.currency ?? ""}" : ""}'
                      : 'OCR complete')
                  : r.ocrStatus == 'processing'
                      ? 'Processing OCR...'
                      : 'Pending OCR';
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: Icon(
                      isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined,
                      color: Colors.blue,
                      size: 20,
                    ),
                  ),
                  title: Text(r.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(ocrLabel, style: const TextStyle(fontSize: 12)),
                  onTap: isImage && _loadingReceiptId != r.id
                      ? () => _viewReceiptImage(r.id, r.fileName)
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isImage)
                        _loadingReceiptId == r.id
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                icon: const Icon(Icons.open_in_full, size: 18),
                                tooltip: 'View',
                                onPressed: () => _viewReceiptImage(r.id, r.fileName),
                              ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => _deleteReceipt(r.id),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),

            // Comments
            Row(
              children: [
                Text('Comments', style: Theme.of(context).textTheme.titleMedium),
                if (tx.comments.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('${tx.comments.length}',
                        style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (tx.comments.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('No comments yet', style: TextStyle(color: Colors.grey)),
              ),
            ...tx.comments.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(Icons.person,
                            size: 16,
                            color: Theme.of(context).colorScheme.onPrimaryContainer),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.body),
                              const SizedBox(height: 2),
                              Text(
                                DateFormatter.formatDate(c.createdAt),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16),
                        color: Colors.grey,
                        onPressed: () => _deleteComment(c.id),
                        padding: const EdgeInsets.only(left: 4),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      isDense: true,
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _addComment(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.send, size: 18),
                  onPressed: _addComment,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _viewReceiptImage(String receiptId, String fileName) async {
    setState(() => _loadingReceiptId = receiptId);
    try {
      final client = await ref.read(apiClientProvider.future);
      final response = await client.dio.get<Uint8List>(
        Endpoints.receiptFile(receiptId),
        options: Options(responseType: ResponseType.bytes),
      );
      if (!mounted) return;
      setState(() => _loadingReceiptId = null);

      final bytes = response.data!;
      showDialog(
        context: context,
        builder: (dialogCtx) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(8),
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton.filled(
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(fileName,
                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _loadingReceiptId = null);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load image: $e')));
      }
    }
  }

  Future<void> _uploadReceipt(String txId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    setState(() => _uploadingReceipt = true);
    try {
      final client = await ref.read(apiClientProvider.future);
      // Upload receipt
      final uploadResp = await client.post(
        Endpoints.receiptUpload,
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(file.path!, filename: file.name),
        }),
      );
      final receiptId = uploadResp.data['id'] as String;
      // Link to transaction
      await client.post(Endpoints.linkReceipt(receiptId, txId));
      ref.invalidate(transactionDetailProvider(widget.txId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt uploaded — OCR running in background')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _uploadingReceipt = false);
    }
  }

  Future<void> _deleteReceipt(String receiptId) async {
    try {
      final client = await ref.read(apiClientProvider.future);
      await client.delete(Endpoints.receipt(receiptId));
      ref.invalidate(transactionDetailProvider(widget.txId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;
    try {
      final client = await ref.read(apiClientProvider.future);
      await client.post(
        Endpoints.transactionComments(widget.txId),
        data: {'body': _commentController.text.trim()},
      );
      _commentController.clear();
      ref.invalidate(transactionDetailProvider(widget.txId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      final client = await ref.read(apiClientProvider.future);
      await client.delete(Endpoints.transactionComment(widget.txId, commentId));
      ref.invalidate(transactionDetailProvider(widget.txId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final client = await ref.read(apiClientProvider.future);
              await client.delete(Endpoints.transaction(widget.txId));
              ref.invalidate(transactionsProvider);
              ref.invalidate(accountsProvider);
              ref.invalidate(monthlySummaryProvider);
              ref.invalidate(categoryBreakdownProvider);
              if (context.mounted) context.go('/transactions');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? suffix;

  const _DetailRow({required this.icon, required this.label, required this.value, this.suffix});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label, style: Theme.of(context).textTheme.bodySmall),
      subtitle: Text(value),
      trailing: suffix,
      dense: true,
    );
  }
}
