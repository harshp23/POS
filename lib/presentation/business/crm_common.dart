import 'package:flutter/material.dart';

import '../../data/api/api_client.dart';
import '../master/master_ui.dart';
import '../staff/staff_ui.dart';
import '../vinii_theme.dart';
import 'business_ui.dart';

/// Pieces shared by the Customers & CRM tabs (crm_screen.dart and the
/// crm_*.dart tab files). Everything here renders server data; nothing is
/// stored locally.

// ── formatting ─────────────────────────────────────────────────────────────

/// "Vaishnavi Karkera" from a customer row (first_name / last_name), a
/// dashboard brief (name) or a ledger row (customer_name).
String crmName(Map<String, dynamic> c) {
  final full = '${c['first_name'] ?? ''} ${c['last_name'] ?? ''}'.trim();
  if (full.isNotEmpty) return full;
  return textOf(c['name'] ?? c['customer_name'], 'Unnamed customer');
}

/// "VK" for the avatar.
String crmInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  final first = parts.first.substring(0, 1);
  final second = parts.length > 1 ? parts[1].substring(0, 1) : '';
  return (first + second).toUpperCase();
}

/// ₹1,240 — paise only when present.
String crmMoney(dynamic v) => staffMoney(numOf(v));

/// A count or plain number without trailing zeros.
String crmCount(dynamic v) => staffNumText(numOf(v));

/// "12.5%".
String crmPct(dynamic v) => '${staffNumText(numOf(v))}%';

/// Share of [part] in [whole] as "40%" (0% when [whole] is 0).
String crmShare(dynamic part, dynamic whole) {
  final w = numOf(whole);
  if (w <= 0) return '0%';
  return '${(numOf(part) / w * 100).round()}%';
}

/// "+5" / "−100" (or "+₹500" / "−₹200" with [money]).
String crmSigned(dynamic v, {bool money = false}) {
  final n = numOf(v);
  final body = money ? staffMoney(n.abs()) : staffNumText(n.abs());
  return n < 0 ? '−$body' : '+$body';
}

/// A YYYY-MM-DD date column as a local calendar day.
DateTime? crmDay(dynamic v) {
  final s = '${v ?? ''}'.trim();
  if (s.length < 10) return null;
  return DateTime.tryParse(s.substring(0, 10));
}

/// A customer's tags.
List<String> crmTags(Map<String, dynamic> c) {
  final t = c['tags'];
  if (t is! List) return const [];
  return [
    for (final x in t)
      if ('$x'.trim().isNotEmpty) '$x'.trim()
  ];
}

/// Order / feedback channel as a label.
String crmChannelLabel(dynamic channel) => switch ('${channel ?? ''}') {
      'dine_in' => 'Dine-in',
      'takeaway' => 'Takeaway',
      'pickup' => 'Pickup',
      'delivery' => 'Delivery',
      'online' => 'QR / online ordering',
      'qr' => 'QR ordering',
      'swiggy' => 'Swiggy',
      'zomato' => 'Zomato',
      final other => humanize(other),
    };

/// Customers as select items ("Name · phone"), narrowed by [query]
/// (name or phone). The selected customer always stays in the list.
List<(String, String)> crmCustomerItems(
    List<Map<String, dynamic>> customers, String query, String? selectedId) {
  final q = query.trim().toLowerCase();
  return [
    for (final c in customers)
      if (q.isEmpty ||
          '${c['id']}' == selectedId ||
          crmName(c).toLowerCase().contains(q) ||
          '${c['phone'] ?? ''}'.contains(q))
        ('${c['id']}', '${crmName(c)} · ${textOf(c['phone'])}'),
  ];
}

/// Tone of a loyalty / wallet ledger entry type.
PillTone crmEntryTone(String type) => switch (type) {
      'earn' || 'topup' || 'refund' => PillTone.green,
      'redeem' => PillTone.amber,
      'adjust' => PillTone.blue,
      _ => PillTone.gray,
    };

/// A loyalty / wallet ledger entry type as the entry forms name it.
String crmEntryTypeLabel(dynamic type) => switch ('${type ?? ''}') {
      'earn' => 'Earn',
      'topup' => 'Top-up',
      'redeem' => 'Redeem',
      'refund' => 'Refund',
      'adjust' => 'Adjust',
      final other => humanize(other),
    };

/// A wallet payment method as the wallet form names it.
String crmWalletMethodLabel(dynamic method) => switch ('${method ?? ''}') {
      'cash' => 'Cash',
      'upi' => 'UPI',
      'card' => 'Card',
      'bank' => 'Bank transfer',
      'adjustment' => 'Adjustment',
      final other => humanize(other),
    };

/// A bill's status in the words the POS uses.
String crmOrderStatusLabel(dynamic status) => switch ('${status ?? ''}') {
      'new' => 'New',
      'in_billing' => 'In billing',
      'sent_to_kitchen' || 'preparing' => 'Preparing',
      'ready' => 'Ready',
      'awaiting_payment' => 'Awaiting payment',
      'paid' => 'Paid',
      'delivered' => 'Delivered',
      'cancelled' => 'Cancelled',
      final other => humanize(other),
    };

PillTone crmOrderStatusTone(dynamic status) => switch ('${status ?? ''}') {
      'paid' || 'delivered' => PillTone.green,
      'awaiting_payment' => PillTone.amber,
      'cancelled' => PillTone.red,
      'sent_to_kitchen' || 'preparing' || 'ready' => PillTone.blue,
      _ => PillTone.gray,
    };

/// Every tag used on [customers], most used first.
List<String> crmAllTags(List<Map<String, dynamic>> customers) {
  final counts = <String, int>{};
  final spelling = <String, String>{};
  for (final c in customers) {
    for (final t in crmTags(c)) {
      final k = t.toLowerCase();
      counts[k] = (counts[k] ?? 0) + 1;
      spelling.putIfAbsent(k, () => t);
    }
  }
  final keys = counts.keys.toList()
    ..sort((a, b) {
      final byCount = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
  return [for (final k in keys) spelling[k] ?? k];
}

// ── widgets ────────────────────────────────────────────────────────────────

/// Small grey "SILVER" tier chip (nothing when the tier is empty).
class CrmTierChip extends StatelessWidget {
  const CrmTierChip(this.tier, {super.key});
  final String tier;

  @override
  Widget build(BuildContext context) => tier.trim().isEmpty
      ? const SizedBox.shrink()
      : StaffChip(tier.trim().toUpperCase(),
          color: ViniiColors.graySolid, tint: ViniiColors.grayTint);
}

/// Uppercase section heading with an optional line under it and an
/// optional action on the right.
class CrmHeading extends StatelessWidget {
  const CrmHeading(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 13.5,
                          letterSpacing: 0.3,
                          fontWeight: FontWeight.w700,
                          color: ViniiColors.textPrimaryLight)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!, style: MasterStyle.muted),
                  ],
                ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ]),
      );
}

/// One customer as a bordered line: avatar, name + tier, caption, amount.
class CrmCustomerLine extends StatelessWidget {
  const CrmCustomerLine(
      {super.key,
      required this.name,
      required this.caption,
      required this.trailing,
      this.tier = '',
      this.onTap});
  final String name;
  final String caption;
  final String trailing;
  final String tier;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: MasterStyle.cardBorder),
            ),
            child: Row(children: [
              StaffAvatar(initials: crmInitials(name), size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: ViniiColors.textPrimaryLight)),
                        ),
                        const SizedBox(width: 8),
                        CrmTierChip(tier),
                      ]),
                      const SizedBox(height: 2),
                      Text(caption,
                          overflow: TextOverflow.ellipsis,
                          style: MasterStyle.muted),
                    ]),
              ),
              const SizedBox(width: 12),
              Text(trailing,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ViniiColors.textPrimaryLight)),
            ]),
          ),
        ),
      );
}

/// Count badge on a segment card (green when anyone is in it).
class CrmCountPill extends StatelessWidget {
  const CrmCountPill(this.count, {super.key});
  final num count;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        decoration: BoxDecoration(
          color: count > 0 ? ViniiColors.successPillBg : ViniiColors.grayTint,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(staffNumText(count),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: count > 0
                    ? ViniiColors.emeraldText
                    : ViniiColors.graySolid)),
      );
}

// ── customer profile ───────────────────────────────────────────────────────

/// Read-only profile of one customer: figures, recent bills and the
/// loyalty / wallet ledgers (GET v1/crm/customers/:id).
Future<void> showCrmCustomerDetail(
        BuildContext context, ProviyaaApiClient api, String id) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StaffDialog(
        title: 'Customer profile',
        width: 820,
        actions: [
          MasterButton(
              key: const Key('customer-detail-close'),
              label: 'Close',
              kind: MasterButtonKind.primary,
              onPressed: () => Navigator.pop(dialogContext)),
        ],
        body: ApiLoader<Map<String, dynamic>>(
          load: () async => jsonMap(await api.get('v1/crm/customers/$id')),
          builder: (context, c, _) => _CustomerDetailBody(c),
        ),
      ),
    );

class _CustomerDetailBody extends StatelessWidget {
  const _CustomerDetailBody(this.c);
  final Map<String, dynamic> c;

  static Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Text(text, style: MasterStyle.sectionTitle),
      );

  @override
  Widget build(BuildContext context) {
    final name = crmName(c);
    final email = '${c['email'] ?? ''}'.trim();
    final tags = crmTags(c);
    final address = '${c['address'] ?? ''}'.trim();
    final notes = '${c['notes'] ?? ''}'.trim();
    final orders = jsonList(c['recent_orders']);
    final points = jsonList(c['loyalty_ledger']);
    final wallet = jsonList(c['wallet_ledger']);
    final allows = [
      if (c['allow_whatsapp'] == true) 'WhatsApp',
      if (c['allow_sms'] == true) 'SMS',
      if (c['allow_email'] == true) 'Email',
      if (c['allow_push'] == true) 'Push',
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        StaffAvatar(initials: crmInitials(name), size: 48),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: ViniiColors.textPrimaryLight)),
                  ),
                  const SizedBox(width: 8),
                  CrmTierChip('${c['tier'] ?? ''}'),
                ]),
                const SizedBox(height: 3),
                Text(
                    [textOf(c['phone']), if (email.isNotEmpty) email]
                        .join(' · '),
                    style: MasterStyle.subtitle),
              ]),
        ),
      ]),
      const SizedBox(height: 18),
      Wrap(spacing: 28, runSpacing: 14, children: [
        MasterKeyValue('Paid orders', crmCount(c['orders'])),
        MasterKeyValue('Total spent', crmMoney(c['spent'])),
        MasterKeyValue('Loyalty points', crmCount(c['points'])),
        MasterKeyValue('Wallet balance', crmMoney(c['wallet'])),
        MasterKeyValue('Last order', fmtDateTime(c['last_order_at'])),
        MasterKeyValue('Joined', fmtDate(c['created_at'])),
        MasterKeyValue('Prefers', crmChannelLabel(c['preferred_dining'])),
        MasterKeyValue('Birthday', fmtDate(c['date_of_birth'])),
        MasterKeyValue('Anniversary', fmtDate(c['anniversary'])),
        MasterKeyValue('GST number', textOf(c['gst_number'])),
        MasterKeyValue('Cancelled orders', crmCount(c['cancelled'])),
        MasterKeyValue(
            'Messages allowed', allows.isEmpty ? 'None' : allows.join(', ')),
      ]),
      if (tags.isNotEmpty) ...[
        const SizedBox(height: 14),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final t in tags) StaffChip(t, color: ViniiColors.blueSolid),
        ]),
      ],
      if (address.isNotEmpty) ...[
        const SizedBox(height: 14),
        MasterKeyValue('Address', address),
      ],
      if (notes.isNotEmpty) ...[
        const SizedBox(height: 14),
        MasterKeyValue('Notes', notes),
      ],
      _title('Recent bills'),
      MasterTable(
        minWidth: 640,
        columns: const [
          MasterColumn('Bill', flex: 10),
          MasterColumn('Channel', flex: 14),
          MasterColumn('Status', flex: 12),
          MasterColumn('Total', flex: 10, alignEnd: true),
          MasterColumn('Date', flex: 18),
        ],
        rows: [
          for (final o in orders)
            [
              MasterCellText('#${textOf(o['number'], '—')}', bold: true),
              MasterCellText(crmChannelLabel(o['channel'])),
              MasterStatusPill(crmOrderStatusLabel(o['status']),
                  tone: crmOrderStatusTone(o['status'])),
              MasterCellText(crmMoney(o['total'])),
              MasterCellText(fmtDateTime(o['created_at'])),
            ]
        ],
        footer: orders.isEmpty
            ? const Text(
                'No bills with this phone number yet. Bills are linked to the '
                'profile by the customer phone entered at billing.',
                style: MasterStyle.muted)
            : null,
      ),
      _title('Loyalty points'),
      MasterTable(
        minWidth: 640,
        columns: const [
          MasterColumn('Date', flex: 16),
          MasterColumn('Type', flex: 9),
          MasterColumn('Points', flex: 8),
          MasterColumn('Balance', flex: 8),
          MasterColumn('Note', flex: 20),
        ],
        rows: [
          for (final e in points)
            [
              MasterCellText(fmtDateTime(e['created_at'])),
              MasterStatusPill(crmEntryTypeLabel(e['entry_type']),
                  tone: crmEntryTone('${e['entry_type'] ?? ''}')),
              MasterCellText(crmSigned(e['points']),
                  bold: true,
                  color: numOf(e['points']) < 0
                      ? ViniiColors.redSolid
                      : ViniiColors.greenSolid),
              MasterCellText(crmCount(e['balance_after'])),
              MasterCellText(textOf(e['note'])),
            ]
        ],
        footer: points.isEmpty
            ? const Text('No points yet.', style: MasterStyle.muted)
            : null,
      ),
      _title('Wallet'),
      MasterTable(
        minWidth: 640,
        columns: const [
          MasterColumn('Date', flex: 16),
          MasterColumn('Type', flex: 9),
          MasterColumn('Method', flex: 9),
          MasterColumn('Amount', flex: 10),
          MasterColumn('Balance', flex: 10),
          MasterColumn('Note', flex: 16),
        ],
        rows: [
          for (final e in wallet)
            [
              MasterCellText(fmtDateTime(e['created_at'])),
              MasterStatusPill(crmEntryTypeLabel(e['entry_type']),
                  tone: crmEntryTone('${e['entry_type'] ?? ''}')),
              MasterCellText(crmWalletMethodLabel(e['method'])),
              MasterCellText(crmSigned(e['amount'], money: true),
                  bold: true,
                  color: numOf(e['amount']) < 0
                      ? ViniiColors.redSolid
                      : ViniiColors.greenSolid),
              MasterCellText(crmMoney(e['balance_after'])),
              MasterCellText(textOf(e['note'])),
            ]
        ],
        footer: wallet.isEmpty
            ? const Text('No wallet activity yet.', style: MasterStyle.muted)
            : null,
      ),
    ]);
  }
}
