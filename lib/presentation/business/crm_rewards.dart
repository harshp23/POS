import 'package:flutter/material.dart';

import '../../data/api/api_client.dart';
import '../master/master_ui.dart';
import '../staff/staff_ui.dart';
import '../vinii_theme.dart';
import 'business_ui.dart';
import 'crm_common.dart';

/// Customers & CRM → Loyalty (points rules, tiers and the points ledger)
/// and Wallet (store credit and its ledger).

typedef _LoyaltyData = (Map<String, dynamic>, List<Map<String, dynamic>>);
typedef _WalletData = (
  Map<String, dynamic>,
  List<Map<String, dynamic>>,
  List<Map<String, dynamic>>
);

Widget _input(String label, TextEditingController c,
        {Key? key, String? hint, bool number = false, String? prefix}) =>
    StaffField(
      label: label,
      child: TextField(
        key: key,
        controller: c,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        style: const TextStyle(fontSize: 13.5),
        decoration: staffInput(hint: hint, prefix: prefix),
      ),
    );

// ── loyalty ────────────────────────────────────────────────────────────────

class CrmLoyaltyTab extends StatelessWidget {
  const CrmLoyaltyTab({super.key, required this.api});
  final ProviyaaApiClient api;

  Future<_LoyaltyData> _load() async {
    final r = await Future.wait<dynamic>([
      api.get('v1/crm/loyalty'),
      api.get('v1/crm/loyalty/ledger'),
    ]);
    return (jsonMap(r[0]), jsonList(r[1]));
  }

  @override
  Widget build(BuildContext context) => ApiLoader<_LoyaltyData>(
        load: _load,
        builder: (context, data, reload) {
          final (d, ledger) = data;
          final settings = jsonMap(d['settings']);
          final enabled = settings['enabled'] != false;

          Future<void> manualEntry() async {
            final saved = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) => _LoyaltyEntryDialog(
                  api: api,
                  minRedeem: numOf(settings['min_redeem_points']).toInt()),
            );
            if (saved == true && context.mounted) {
              showStaffNotice(context, 'Loyalty entry posted');
              reload();
            }
          }

          return BusinessPage(
            title: 'Loyalty Program Settings',
            subtitle: 'Configure point generation rules, member tiers, and '
                'track the points ledger.',
            badge: enabled ? 'ACTIVE SYSTEM' : 'PAUSED',
            actions: [
              MasterButton(
                  key: const Key('crm-loyalty-manual'),
                  label: 'Manual entry',
                  icon: Icons.edit_note,
                  onPressed: manualEntry),
            ],
            children: [
              KpiGrid(columns: 4, cards: [
                MasterStatCard(
                    label: 'LOYALTY MEMBERS',
                    value: crmCount(d['members']),
                    caption:
                        '${crmShare(d['members'], d['profiles'])} of customer base'),
                MasterStatCard(
                    label: 'POINTS ISSUED',
                    value: crmCount(d['points_issued']),
                    caption: 'Total historical earned'),
                MasterStatCard(
                    label: 'POINTS REDEEMED',
                    value: crmCount(d['points_redeemed']),
                    caption: 'Total historical used'),
                MasterStatCard(
                    label: 'REDEEM LIABILITY',
                    value: crmMoney(d['liability']),
                    caption:
                        '${crmCount(d['points_outstanding'])} points outstanding'),
              ]),
              _LoyaltyRulesForm(
                api: api,
                settings: settings,
                pools: jsonList(d['tier_pools']),
                onSaved: reload,
              ),
              const SizedBox(height: 20),
              MasterSection(
                title: 'Loyalty distribution ledger',
                subtitle: 'Latest 200 entries',
                child: MasterTable(
                  minWidth: 820,
                  columns: const [
                    MasterColumn('Date', flex: 16),
                    MasterColumn('Customer', flex: 16),
                    MasterColumn('Type', flex: 9),
                    MasterColumn('Points', flex: 8),
                    MasterColumn('Balance', flex: 8),
                    MasterColumn('Note', flex: 22),
                  ],
                  rows: [
                    for (final e in ledger)
                      [
                        MasterCellText(fmtDateTime(e['created_at'])),
                        MasterCellText(textOf(e['customer_name']), bold: true),
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
                  footer: ledger.isEmpty
                      ? const StaffEmptyState(
                          icon: Icons.loyalty_outlined,
                          title: 'No points yet',
                          message: 'Points are credited automatically when a '
                              "saved customer's bill is paid (matched by "
                              'phone number).',
                        )
                      : null,
                ),
              ),
            ],
          );
        },
      );
}

class _LoyaltyRulesForm extends StatefulWidget {
  const _LoyaltyRulesForm(
      {required this.api,
      required this.settings,
      required this.pools,
      required this.onSaved});
  final ProviyaaApiClient api;
  final Map<String, dynamic> settings;

  /// Tiers sorted by spend, each with its current `customers` count.
  final List<Map<String, dynamic>> pools;
  final VoidCallback onSaved;

  @override
  State<_LoyaltyRulesForm> createState() => _LoyaltyRulesFormState();
}

class _LoyaltyRulesFormState extends State<_LoyaltyRulesForm> {
  String _num(String key) => staffNumText(numOf(widget.settings[key]));

  late bool _enabled = widget.settings['enabled'] != false;
  late final _earnPer = TextEditingController(text: _num('earn_per_amount'));
  late final _points = TextEditingController(text: _num('points_per_earn'));
  late final _value = TextEditingController(text: _num('point_value'));
  late final _minRedeem =
      TextEditingController(text: _num('min_redeem_points'));
  late final _maxPct = TextEditingController(text: _num('max_redeem_pct'));
  late final _expiry = TextEditingController(text: _num('expiry_days'));
  late final List<(TextEditingController, TextEditingController)> _tiers = [
    for (final t in (widget.pools.isNotEmpty
        ? widget.pools
        : jsonList(widget.settings['tiers'])))
      (
        TextEditingController(text: '${t['name'] ?? ''}'),
        TextEditingController(text: staffNumText(numOf(t['min_spend']))),
      ),
  ];
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_earnPer, _points, _value, _minRedeem, _maxPct, _expiry]) {
      c.dispose();
    }
    for (final (a, b) in _tiers) {
      a.dispose();
      b.dispose();
    }
    super.dispose();
  }

  void _addTier() {
    if (_tiers.length >= 6) return;
    setState(() => _tiers.add((TextEditingController(), TextEditingController())));
  }

  void _removeTier(int i) {
    if (_tiers.length <= 1) return;
    final (a, b) = _tiers.removeAt(i);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      a.dispose();
      b.dispose();
    });
  }

  String _pool(int i) {
    final name = _tiers[i].$1.text.trim().toLowerCase();
    for (final p in widget.pools) {
      if ('${p['name'] ?? ''}'.trim().toLowerCase() == name) {
        final n = numOf(p['customers']).toInt();
        return '$n customer${n == 1 ? '' : 's'}';
      }
    }
    return 'Save to count';
  }

  Future<void> _save() async {
    double? d(TextEditingController c) => double.tryParse(c.text.trim());
    int? whole(TextEditingController c) => int.tryParse(c.text.trim());
    final earnPer = d(_earnPer);
    final points = whole(_points);
    final value = d(_value);
    final minRedeem = whole(_minRedeem);
    final maxPct = d(_maxPct);
    final expiry = whole(_expiry);
    String? problem;
    if (earnPer == null || earnPer <= 0) {
      problem = '"Earn per ₹ spent" must be more than 0.';
    } else if (points == null || points < 0) {
      problem = '"Points earned" must be a whole number.';
    } else if (value == null || value < 0) {
      problem = '"₹ value of 1 point" must be a number.';
    } else if (minRedeem == null || minRedeem < 0) {
      problem = '"Minimum points to redeem" must be a whole number.';
    } else if (maxPct == null || maxPct < 0 || maxPct > 100) {
      problem = '"Max % of bill redeemable" must be between 0 and 100.';
    } else if (expiry == null || expiry < 0) {
      problem = '"Points expiry (days)" must be a whole number.';
    }
    final tiers = <Map<String, dynamic>>[];
    for (final (n, s) in _tiers) {
      final name = n.text.trim();
      final spend = d(s);
      if (name.isEmpty || spend == null || spend < 0) {
        problem ??= 'Every tier needs a name and a minimum lifetime spend.';
        continue;
      }
      tiers.add({'name': name, 'min_spend': spend});
    }
    if (tiers.isEmpty) problem ??= 'Keep at least one tier.';
    if (problem != null) {
      showStaffError(context, problem);
      return;
    }
    setState(() => _saving = true);
    final done = await runAction<bool>(context, () async {
      await widget.api.put('v1/crm/loyalty', {
        'enabled': _enabled,
        'earn_per_amount': earnPer,
        'points_per_earn': points,
        'point_value': value,
        'min_redeem_points': minRedeem,
        'max_redeem_pct': maxPct,
        'expiry_days': expiry,
        'tiers': tiers,
      });
      return true;
    }, success: 'Loyalty rules saved');
    if (!mounted) return;
    setState(() => _saving = false);
    if (done == true) widget.onSaved();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MasterSection(
          title: 'Point generation rules',
          subtitle: 'How points are earned on paid POS, QR and online bills '
              'of saved customers, and what they are worth.',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            BizToggle(
                key: const Key('loyalty-enabled'),
                label: 'Loyalty program active',
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v)),
            const SizedBox(height: 16),
            MasterGrid(columns: 3, minItemWidth: 200, children: [
              _input('Earn per ₹ spent', _earnPer,
                  key: const Key('loyalty-earn-per'),
                  hint: '100',
                  number: true),
              _input('Points earned', _points,
                  key: const Key('loyalty-points'), hint: '5', number: true),
              _input('₹ value of 1 point', _value,
                  key: const Key('loyalty-point-value'),
                  hint: '1',
                  number: true),
              _input('Minimum points to redeem', _minRedeem,
                  key: const Key('loyalty-min-redeem'),
                  hint: '100',
                  number: true),
              _input('Max % of bill redeemable', _maxPct,
                  key: const Key('loyalty-max-pct'), hint: '20', number: true),
              _input('Points expiry (days)', _expiry,
                  key: const Key('loyalty-expiry'), hint: '365', number: true),
            ]),
            const SizedBox(height: 14),
            const Text(
                'Points are credited automatically for paid bills of saved '
                'customers (matched by phone). The minimum to redeem applies to '
                'manual redemptions here; the expiry and the max % of a bill '
                'are saved with your rules but are not applied automatically '
                'yet.',
                style: MasterStyle.muted),
          ]),
        ),
        const SizedBox(height: 20),
        MasterSection(
          title: 'Tier system rules',
          subtitle: 'A customer is in the highest tier whose minimum lifetime '
              'spend they have reached.',
          trailing: _tiers.length < 6
              ? MasterButton(
                  key: const Key('loyalty-add-tier'),
                  label: 'Add tier',
                  icon: Icons.add,
                  onPressed: _addTier)
              : null,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < _tiers.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _input('Tier name', _tiers[i].$1,
                            key: Key('loyalty-tier-name-$i'),
                            hint: 'e.g. Gold'),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 5,
                        child: _input('Min lifetime spend (₹)', _tiers[i].$2,
                            key: Key('loyalty-tier-spend-$i'),
                            hint: '0',
                            number: true),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 3,
                        child: StaffField(
                          label: 'Current pool',
                          child: Container(
                            height: 44,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(_pool(i),
                                overflow: TextOverflow.ellipsis,
                                style: MasterStyle.body),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: StaffIconAction(
                            icon: Icons.delete_outline,
                            tooltip: 'Remove tier',
                            color: ViniiColors.redSolid,
                            onPressed:
                                _tiers.length > 1 ? () => _removeTier(i) : null),
                      ),
                    ]),
              ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: MasterButton(
                  key: const Key('crm-loyalty-save'),
                  label: _saving ? 'Saving…' : 'Save loyalty rules',
                  icon: Icons.save_outlined,
                  kind: MasterButtonKind.primary,
                  onPressed: _saving ? null : _save),
            ),
          ]),
        ),
      ]);
}

class _LoyaltyEntryDialog extends StatefulWidget {
  const _LoyaltyEntryDialog({required this.api, required this.minRedeem});
  final ProviyaaApiClient api;
  final int minRedeem;

  @override
  State<_LoyaltyEntryDialog> createState() => _LoyaltyEntryDialogState();
}

class _LoyaltyEntryDialogState extends State<_LoyaltyEntryDialog> {
  final _points = TextEditingController();
  final _note = TextEditingController();
  List<Map<String, dynamic>>? _customers;
  String _search = '';
  String? _customerId;
  String _type = 'earn';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _points.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      final list = jsonList(await widget.api.get('v1/crm/customers'));
      if (mounted) setState(() => _customers = list);
    } catch (e) {
      if (mounted) {
        setState(() {
          _customers = const [];
          _error = apiErrorText(e);
        });
      }
    }
  }

  Future<void> _save() async {
    final points = int.tryParse(_points.text.trim());
    String? problem;
    if (_customerId == null) {
      problem = 'Pick a customer.';
    } else if (points == null || points == 0) {
      problem = 'Enter the points as a whole number (not 0).';
    } else if (_type != 'adjust' && points < 0) {
      problem = 'Enter a positive number; the entry type sets the direction.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.post('v1/crm/loyalty/entries', {
        'customer_id': _customerId,
        'entry_type': _type,
        'points': points,
        'note': _note.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = apiErrorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = _customers;
    final selected = customers
        ?.where((c) => '${c['id']}' == _customerId)
        .firstOrNull;
    return StaffDialog(
      title: 'Manual loyalty entry',
      subtitle: 'Earn adds points, redeem takes them off, adjust does either '
          '(use a negative number to remove).',
      width: 600,
      error: _error,
      actions: [
        MasterButton(
            label: 'Cancel',
            onPressed: _saving ? null : () => Navigator.pop(context)),
        MasterButton(
            key: const Key('loyalty-entry-save'),
            label: _saving ? 'Posting…' : 'Post entry',
            kind: MasterButtonKind.primary,
            onPressed: _saving || customers == null ? null : _save),
      ],
      body: customers == null
          ? const StaffLoading()
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              StaffFormRow(children: [
                StaffField(
                  label: 'Search customer',
                  child: TextField(
                    key: const Key('loyalty-entry-search'),
                    style: const TextStyle(fontSize: 13.5),
                    decoration: staffInput(hint: 'Name or phone'),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                StaffField(
                  label: 'Customer',
                  required: true,
                  child: StaffSelect<String>(
                    key: const Key('loyalty-entry-customer'),
                    value: _customerId,
                    hint: customers.isEmpty
                        ? 'No customers yet'
                        : 'Select customer',
                    items: crmCustomerItems(customers, _search, _customerId),
                    onChanged: (v) => setState(() => _customerId = v),
                  ),
                ),
              ]),
              StaffFormRow(children: [
                StaffField(
                  label: 'Entry type',
                  child: StaffSelect<String>(
                    key: const Key('loyalty-entry-type'),
                    value: _type,
                    items: const [
                      ('earn', 'Earn'),
                      ('redeem', 'Redeem'),
                      ('adjust', 'Adjust'),
                    ],
                    onChanged: (v) => setState(() => _type = v ?? 'earn'),
                  ),
                ),
                _input('Points', _points,
                    key: const Key('loyalty-entry-points'),
                    hint: _type == 'adjust' ? 'e.g. -20 or 20' : 'e.g. 50',
                    number: true),
              ]),
              StaffFormRow(children: [
                _input('Note', _note,
                    key: const Key('loyalty-entry-note'),
                    hint: 'e.g. Birthday bonus'),
              ]),
              if (selected != null)
                Text(
                    '${crmName(selected)} has ${crmCount(selected['points'])} '
                    'points.',
                    style: MasterStyle.body),
              if (_type == 'redeem')
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                      'Your rules allow redeeming at least ${widget.minRedeem} '
                      'points at a time.',
                      style: MasterStyle.muted),
                ),
            ]),
    );
  }
}

// ── wallet ─────────────────────────────────────────────────────────────────

class CrmWalletTab extends StatelessWidget {
  const CrmWalletTab({super.key, required this.api});
  final ProviyaaApiClient api;

  Future<_WalletData> _load() async {
    final r = await Future.wait<dynamic>([
      api.get('v1/crm/wallet'),
      api.get('v1/crm/wallet/ledger'),
      api.get('v1/crm/customers'),
    ]);
    return (jsonMap(r[0]), jsonList(r[1]), jsonList(r[2]));
  }

  @override
  Widget build(BuildContext context) => ApiLoader<_WalletData>(
        load: _load,
        builder: (context, data, reload) {
          final (summary, ledger, customers) = data;
          final active = numOf(summary['active_wallets']).toInt();
          return BusinessPage(
            title: 'Customer Wallet',
            subtitle: 'Prepaid store credit: top-ups, redemptions and '
                "adjustments on each customer's ledger.",
            badge: '$active ACTIVE WALLET${active == 1 ? '' : 'S'}',
            children: [
              KpiGrid(columns: 4, cards: [
                MasterStatCard(
                    label: 'WALLET FLOAT',
                    value: crmMoney(summary['float']),
                    caption: 'Total customer credit pool'),
                MasterStatCard(
                    label: 'ACTIVE WALLETS',
                    value: '$active',
                    caption: 'Customers holding a balance'),
                MasterStatCard(
                    label: 'TOP-UP VOLUME (30D)',
                    value: crmMoney(summary['topups_30d']),
                    caption: 'Credited in the last 30 days'),
                MasterStatCard(
                    label: 'REDEMPTIONS (30D)',
                    value: crmMoney(summary['redemptions_30d']),
                    caption: 'Spent from wallets in 30 days'),
              ]),
              _WalletEntryForm(api: api, customers: customers, onPosted: reload),
              const SizedBox(height: 20),
              MasterSection(
                title: 'Wallet ledger',
                subtitle: 'Latest 200 entries',
                child: MasterTable(
                  minWidth: 900,
                  columns: const [
                    MasterColumn('Date', flex: 15),
                    MasterColumn('Customer', flex: 18),
                    MasterColumn('Type', flex: 9),
                    MasterColumn('Method', flex: 9),
                    MasterColumn('Amount', flex: 10),
                    MasterColumn('Balance', flex: 10),
                    MasterColumn('Note', flex: 18),
                  ],
                  rows: [
                    for (final e in ledger)
                      [
                        MasterCellText(fmtDateTime(e['created_at'])),
                        MasterCellTitle(textOf(e['customer_name']),
                            subtitle: textOf(e['phone'])),
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
                  footer: ledger.isEmpty
                      ? const StaffEmptyState(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'No wallet activity yet.',
                          message: 'Posted customer top-ups and redemptions '
                              'will be listed here.',
                        )
                      : null,
                ),
              ),
            ],
          );
        },
      );
}

class _WalletEntryForm extends StatefulWidget {
  const _WalletEntryForm(
      {required this.api, required this.customers, required this.onPosted});
  final ProviyaaApiClient api;
  final List<Map<String, dynamic>> customers;
  final VoidCallback onPosted;

  @override
  State<_WalletEntryForm> createState() => _WalletEntryFormState();
}

class _WalletEntryFormState extends State<_WalletEntryForm> {
  static const _types = [
    ('topup', 'Top-up'),
    ('redeem', 'Redeem'),
    ('refund', 'Refund'),
    ('adjust', 'Adjust'),
  ];
  static const _methods = [
    ('cash', 'Cash'),
    ('upi', 'UPI'),
    ('card', 'Card'),
    ('bank', 'Bank transfer'),
    ('adjustment', 'Adjustment'),
  ];

  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _search = '';
  String? _customerId;
  String _type = 'topup';
  String _method = 'cash';
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final amount = double.tryParse(_amount.text.trim());
    final customer = widget.customers
        .where((c) => '${c['id']}' == _customerId)
        .firstOrNull;
    if (customer == null) {
      showStaffError(context, 'Pick a customer.');
      return;
    }
    if (amount == null || amount == 0) {
      showStaffError(context, 'Enter an amount.');
      return;
    }
    if (_type != 'adjust' && amount < 0) {
      showStaffError(context,
          'Enter a positive amount; the entry type sets the direction.');
      return;
    }
    setState(() => _busy = true);
    final typeLabel =
        _types.firstWhere((t) => t.$1 == _type, orElse: () => _types.first).$2;
    final done = await runAction<bool>(context, () async {
      await widget.api.post('v1/crm/wallet/entries', {
        'customer_id': customer['id'],
        'entry_type': _type,
        'amount': amount,
        'method': _method,
        'note': _note.text.trim(),
      });
      return true;
    },
        success: '$typeLabel of ${staffMoney(amount.abs())} posted for '
            '${crmName(customer)}');
    if (!mounted) return;
    setState(() => _busy = false);
    if (done == true) {
      _amount.clear();
      _note.clear();
      widget.onPosted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.customers
        .where((c) => '${c['id']}' == _customerId)
        .firstOrNull;
    return MasterSection(
      title: 'Post a wallet entry',
      subtitle: 'Add or deduct store credit on a customer\'s wallet ledger.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MasterGrid(columns: 3, minItemWidth: 220, children: [
          StaffField(
            label: 'Search customer',
            child: TextField(
              key: const Key('wallet-search'),
              style: const TextStyle(fontSize: 13.5),
              decoration: staffInput(hint: 'Name or phone'),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          StaffField(
            label: 'Customer',
            child: StaffSelect<String>(
              key: const Key('wallet-customer'),
              value: _customerId,
              hint: widget.customers.isEmpty
                  ? 'No customers yet'
                  : 'Select customer',
              items: crmCustomerItems(widget.customers, _search, _customerId),
              onChanged: (v) => setState(() => _customerId = v),
            ),
          ),
          StaffField(
            label: 'Entry type',
            child: StaffSelect<String>(
              key: const Key('wallet-type'),
              value: _type,
              items: _types,
              onChanged: (v) => setState(() {
                _type = v ?? 'topup';
                if (_type == 'adjust') _method = 'adjustment';
                if (_type != 'adjust' && _method == 'adjustment') {
                  _method = 'cash';
                }
              }),
            ),
          ),
          _input('Amount (₹)', _amount,
              key: const Key('wallet-amount'),
              hint: _type == 'adjust' ? 'e.g. -50 or 50' : '0.00',
              number: true),
          StaffField(
            label: 'Payment method',
            child: StaffSelect<String>(
              key: const Key('wallet-method'),
              value: _method,
              items: _methods,
              onChanged: (v) => setState(() => _method = v ?? 'cash'),
            ),
          ),
          _input('Note', _note,
              key: const Key('wallet-note'),
              hint: 'e.g. Compensation, promotional top-up'),
        ]),
        const SizedBox(height: 14),
        Wrap(
            spacing: 14,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              MasterButton(
                  key: const Key('crm-wallet-post'),
                  label: _busy ? 'Posting…' : 'Post entry',
                  icon: Icons.account_balance_wallet_outlined,
                  kind: MasterButtonKind.primary,
                  onPressed: _busy ? null : _post),
              if (selected != null)
                Text(
                    '${crmName(selected)} has '
                    '${crmMoney(selected['wallet'])} in the wallet.',
                    style: MasterStyle.body),
              if (_type == 'adjust')
                const Text('Adjust: a positive amount adds, a negative one '
                    'deducts.',
                    style: MasterStyle.muted),
            ]),
      ]),
    );
  }
}
