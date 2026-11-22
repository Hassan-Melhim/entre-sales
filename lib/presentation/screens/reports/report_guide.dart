import 'package:flutter/material.dart';

import '../../../domain/business_rules.dart';
import '../../theme/app_tokens.dart';

/// The Reports manual: what each figure means and what it is good for.
Future<void> showReportGuide(BuildContext context) => showDialog<void>(
      context: context,
      builder: (context) => const _ReportGuideDialog(),
    );

class _Entry {
  final String name;
  final String means;
  final String useful;
  const _Entry(this.name, this.means, this.useful);
}

class _Group {
  final String title;
  final List<_Entry> entries;
  const _Group(this.title, this.entries);
}

String get _resident => '${BusinessRules.spainResidentArtistTaxPercent.toStringAsFixed(0)}%';

final _groups = [
  _Group('Money', [
    const _Entry(
      'Total sales',
      'Everything customers paid in the period, VAT included, after discounts and minus refunds.',
      'The size of the business: the money that came through the till and the card terminal.',
    ),
    const _Entry(
      'Store profit',
      'Total sales − Taxes − Artist payouts. What Entre Salas keeps. The line under it is the margin: '
          'store profit as a share of sales before VAT.',
      'The number that pays rent and wages. If the margin drops, check discounts and the resident tax.',
    ),
    _Entry(
      'Artist payouts',
      'The artists\' shares: the price before tax × (100% − commission), for every unit sold, minus refunds. '
          'Discounts are absorbed by the store, so they don\'t lower this. The Spain-resident tax is not '
          'included here: it is counted under Taxes.',
      'What has to be transferred to artists for the period; the Invoices screen splits it per artist.',
    ),
    _Entry(
      'Taxes',
      'VAT charged on the sales (minus refunds) + the Spain-resident artist tax ($_resident on the payout of '
          'resident artists, worked out per artist). The line under it shows the two parts.',
      'What to set aside for the tax office and for resident artists, so it isn\'t mistaken for profit.',
    ),
    const _Entry(
      'Refunds and Discounts',
      'Shown when there were any: the money refunded to customers, and the money taken off by discounts.',
      'A high refund amount can point to a product problem; discounts show what promotions cost.',
    ),
  ]),
  const _Group('Sales', [
    _Entry('Sales', 'The number of receipts (one per checkout).', 'How many customers bought something.'),
    _Entry('Units sold', 'Items sold, minus items refunded.', 'How much stock leaves the shelf.'),
    _Entry(
      'Average sale',
      'Total sales ÷ number of sales.',
      'Tells whether people buy small things or bigger pieces. Raise it with displays near the till or bundles.',
    ),
    _Entry(
      'Items per sale',
      'Units sold ÷ number of sales.',
      'Whether customers pick one thing or several; useful to judge how well products are grouped.',
    ),
    _Entry(
      'Avg days to sell',
      'For items sold in the period: the days between their arrival in the store and the sale, on average.',
      'How quickly stock turns over; compare categories in "Turnover by category".',
    ),
  ]),
  const _Group('Charts and tables', [
    _Entry('Revenue over time / Best hours / By weekday', 'Total sales split by time.',
        'Plan opening hours, staff and when to set up new displays.'),
    _Entry('By category / By artist gender / By artist', 'Total sales per group, with units and store profit.',
        'See what sells and how sales are spread across artists.'),
    _Entry(
      'Store profit by artist',
      'The store profit each artist\'s sales left, after taxes and their payout. Worked out per sale line, '
          'so the total can differ from the headline by a few cents.',
      'Which artists actually earn the store money, not just which sell most. Helps with commissions and '
          'shelf space.',
    ),
    _Entry(
      'Cash and card',
      'Number and amount of sales per payment method, as rung up (refunds not taken off).',
      'Check the cash in the till against the Cash total, and the terminal statement against Card.',
    ),
    _Entry(
      'Workshops and events',
      'Sales made while a workshop or event session was running (from the calendar) vs. at other times, '
          'with the average sale of each.',
      'Shows whether events bring in sales, and whether event visitors spend more or less.',
    ),
    _Entry('Best-selling products', 'The 15 products with the highest sales in the period.',
        'Know what to reorder or ask the artist for more of.'),
    _Entry(
      'Turnover by category',
      'Sell-through = units sold in the period ÷ (sold + still in stock), and the average days to sell.',
      'Low sell-through means too much stock for what sells; consider fewer pieces or a new display.',
    ),
    _Entry('Fastest sellers / Longest on display', 'Days from arrival to sale, and unsold items by days in the store.',
        'Spot hits early, and items to move, discount or return to the artist.'),
    _Entry(
      'Stock on the shelf (today)',
      'Everything in stock right now (not just the period), at today\'s prices and rates, as if it all sold '
          'without discount: shelf value with VAT, the store profit and artist payouts still to come.',
      'How much money is sitting on the shelves, and which artists take up the most of it.',
    ),
  ]),
  const _Group('Good to know', [
    _Entry(
      'The period',
      'Every figure follows the period chosen at the top (day, month, quarter, year, all time or a range), '
          'except Stock on the shelf.',
      'Use the arrows next to the period to step back or forward one day, month, quarter or year.',
    ),
    _Entry(
      'Refunds',
      'A refund counts in the period it was made, not the period of the original sale.',
      'Same as the artist invoices, so the two always match.',
    ),
    _Entry('Downloads', 'CSV opens in Excel or Numbers; PDF is ready to print or send.',
        'Keep the monthly PDF for the accountant.'),
  ]),
];

class _ReportGuideDialog extends StatelessWidget {
  const _ReportGuideDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline);
    return AlertDialog(
      title: const Text('What the figures mean'),
      content: SizedBox(
        width: AppSizes.dialogLarge,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Total sales = Store profit + Artist payouts + Taxes.',
              style: muted,
            ),
            for (final g in _groups) ...[
              const SizedBox(height: AppSpacing.l),
              Text(g.title, style: theme.textTheme.titleMedium),
              for (final e in g.entries)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.name, style: theme.textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(e.means),
                      const SizedBox(height: AppSpacing.xxs),
                      Text.rich(TextSpan(children: [
                        TextSpan(
                            text: 'Useful for: ',
                            style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
                        TextSpan(text: e.useful),
                      ])),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}
