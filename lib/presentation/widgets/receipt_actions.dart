import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/export/export_file.dart';
import '../../data/export/pdf_service.dart';
import '../../data/files/browser_share.dart';
import '../../domain/models/sale_order.dart';
import '../providers.dart';
import '../theme/app_tokens.dart';
import 'app_messenger.dart';
import 'file_delivery.dart';

/// "Email receipt" and "Download PDF" for one sale. The PDF is made as soon
/// as this appears, so tapping "Email receipt" can open the share sheet
/// straight away (browsers only allow that directly after a tap).
class ReceiptActions extends ConsumerStatefulWidget {
  final SaleOrder order;
  const ReceiptActions({super.key, required this.order});

  @override
  ConsumerState<ReceiptActions> createState() => _ReceiptActionsState();
}

class _ReceiptActionsState extends ConsumerState<ReceiptActions> {
  late final Future<ExportFile> _pdf = _make();

  Future<ExportFile> _make() async => PdfService.receipt(widget.order, await ref.read(storeInfoProvider.future));

  Future<void> _email(ExportFile file) async {
    if (!canShareFile(file)) {
      // No share sheet here (e.g. Firefox): download it to attach by hand.
      await deliverExport(file);
      showAppMessage('This browser can\'t attach files to an email. The receipt was downloaded: '
          'attach it to an email to the customer.');
      return;
    }
    try {
      await shareFile(
        file,
        title: 'Receipt ${widget.order.number}',
        text: 'Thank you for your purchase at Entre Salas. Your receipt is attached.',
      );
    } catch (e) {
      showAppMessage('Could not open the share sheet: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ExportFile>(
      future: _pdf,
      builder: (context, snap) {
        final file = snap.data;
        final preparing = snap.connectionState != ConnectionState.done;
        if (snap.hasError) {
          return Text('Could not make the receipt: ${snap.error}',
              style: TextStyle(color: Theme.of(context).colorScheme.error));
        }
        return Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: [
            FilledButton.tonalIcon(
              onPressed: file == null ? null : () => _email(file),
              icon: preparing
                  ? const SizedBox.square(
                      dimension: AppSizes.iconSmall, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.forward_to_inbox_outlined),
              label: const Text('Email receipt'),
            ),
            OutlinedButton.icon(
              onPressed: file == null ? null : () => deliverExport(file),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Download PDF'),
            ),
          ],
        );
      },
    );
  }
}

/// A dialog with the receipt actions for a past sale.
Future<void> showReceiptDialog(BuildContext context, SaleOrder order) => showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Receipt ${order.number}'),
        content: ReceiptActions(order: order),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
