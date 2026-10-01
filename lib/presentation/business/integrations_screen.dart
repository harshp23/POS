import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/api/api_client.dart';
import '../master/master_ui.dart';
import '../staff/staff_ui.dart';
import '../vinii_theme.dart';
import 'business_ui.dart';

/// Integrations (v1/Integration/*.png): connected apps, the sync-job queue,
/// outgoing webhooks, partner API keys and their logs — all read from and
/// written to /v1/integrations.
///
/// What is not live says so on screen: connecting an app only sends a
/// request (the Proviyaa team links it), sync jobs fail with the reason
/// because no provider adapter exists yet, webhooks only send test pings,
/// the partner API behind the keys is not open yet, and there are no
/// inbound webhooks.

enum IntegrationsTab { overview, apps, sync, webhooks, apiKeys, logs }

const _tabLabels = <IntegrationsTab, String>{
  IntegrationsTab.overview: 'Overview',
  IntegrationsTab.apps: 'Connected apps',
  IntegrationsTab.sync: 'Sync engine',
  IntegrationsTab.webhooks: 'Webhooks',
  IntegrationsTab.apiKeys: 'API keys',
  IntegrationsTab.logs: 'Logs',
};

/// App categories in the order the connected-apps page groups them.
const _categories = <(String, String)>[
  ('delivery', 'Delivery'),
  ('payments', 'Payments'),
  ('communication', 'Communication'),
  ('ecommerce', 'E-commerce'),
  ('accounting', 'Accounting'),
];

class IntegrationsScreen extends StatefulWidget {
  const IntegrationsScreen(
      {super.key,
      required this.api,
      this.initialTab = IntegrationsTab.overview,
      this.category});
  final ProviyaaApiClient api;
  final IntegrationsTab initialTab;

  /// Connected apps filtered to one category ('delivery', 'payments', …)
  /// when opened from the sidebar's Zomato / Swiggy / Payment entries.
  final String? category;

  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends State<IntegrationsScreen> {
  late IntegrationsTab _tab = _startTab(widget);
  late String? _category = widget.category;

  /// A category only means something on the connected-apps page, so a
  /// category with the default tab opens that page.
  static IntegrationsTab _startTab(IntegrationsScreen w) =>
      w.category != null && w.initialTab == IntegrationsTab.overview
          ? IntegrationsTab.apps
          : w.initialTab;

  @override
  void didUpdateWidget(covariant IntegrationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab ||
        oldWidget.category != widget.category) {
      _tab = _startTab(widget);
      _category = widget.category;
    }
  }

  void _open(IntegrationsTab tab) => setState(() => _tab = tab);

  Widget _body() {
    final api = widget.api;
    return switch (_tab) {
      IntegrationsTab.overview => _OverviewTab(api: api, onOpen: _open),
      IntegrationsTab.apps => _AppsTab(
          api: api,
          category: _category,
          onCategory: (c) => setState(() => _category = c)),
      IntegrationsTab.sync => _SyncTab(api: api),
      IntegrationsTab.webhooks => _WebhooksTab(api: api),
      IntegrationsTab.apiKeys => _ApiKeysTab(api: api),
      IntegrationsTab.logs => _LogsTab(api: api),
    };
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: ViniiColors.lightPageBg,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionTabBar(
            tabs: [for (final t in IntegrationsTab.values) _tabLabels[t]!],
            selected: _tab.index,
            keyPrefix: 'integrations-tab',
            onSelect: (i) => _open(IntegrationsTab.values[i]),
          ),
          Expanded(child: KeyedSubtree(key: ValueKey(_tab), child: _body())),
        ]),
      );
}

// ── helpers ──────────────────────────────────────────────────────────────

int _n(dynamic v) => numOf(v).toInt();

List<String> _strings(dynamic v) =>
    v is List ? [for (final e in v) '$e'] : const <String>[];

String _plural(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : (many ?? '${one}s')}';

String _duration(int ms) => ms < 1000
    ? '$ms ms'
    : '${(ms / 1000).toStringAsFixed(ms < 10000 ? 1 : 0)} sec';

/// Form labels of the fields the integrations server may reject.
const _fieldLabels = <String, String>{
  'name': 'Name',
  'url': 'HTTPS URL',
  'events': 'Events',
  'active': 'Active',
  'scopes': 'Scopes',
  'expires_in_days': 'Expires',
  'account_ref': 'Account / merchant ID',
  'note': 'Note',
  'provider': 'App',
  'resource': 'Resource',
  'mode': 'Mode',
  'direction': 'Direction',
};

/// The server's message, with each invalid field named as on the form.
String _errorText(Object e) => fieldErrorText(e, _fieldLabels);

/// A webhook event as a label ("order.created" → "Order created"); the code
/// is what is sent and stored.
String _eventLabel(dynamic code) => switch ('${code ?? ''}') {
      'order.created' => 'Order created',
      'order.status_changed' => 'Order status changed',
      'order.paid' => 'Order paid',
      'kot.created' => 'KOT created',
      'inventory.low_stock' => 'Low stock',
      'customer.created' => 'Customer created',
      'settlement.completed' => 'Settlement completed',
      'test.ping' => 'Test ping',
      final other => humanize(other),
    };

/// An API scope as a label ("orders:read" → "Orders – read").
String _scopeLabel(dynamic scope) {
  final s = '${scope ?? ''}';
  final i = s.indexOf(':');
  if (i < 0) return humanize(s);
  final access = s.substring(i + 1);
  final verb = switch (access) {
    'read' => 'read',
    'write' => 'write',
    _ => humanize(access).toLowerCase(),
  };
  return '${humanize(s.substring(0, i))} – $verb';
}

/// A connected app's status as a label.
String _appStatusLabel(dynamic status) => switch ('${status ?? ''}') {
      'not_connected' || '' => 'Not connected',
      'pending' => 'Pending',
      'connected' => 'Connected',
      'error' => 'Error',
      'disconnected' => 'Disconnected',
      final other => humanize(other),
    };

/// A sync job's resource / mode / direction as a label.
String _syncWord(dynamic v) => switch ('${v ?? ''}') {
      'inbound' => 'Inbound',
      'outbound' => 'Outbound',
      'full' => 'Full sync',
      'delta' => 'Changes only',
      'manual' => 'Manual',
      'pull' => 'Pull',
      final other => humanize(other),
    };

/// A snackbar that stays long enough to read a server message.
void _say(BuildContext context, String message, {bool error = false}) {
  final m = ScaffoldMessenger.maybeOf(context);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(SnackBar(
    content: Text(message),
    behavior: SnackBarBehavior.floating,
    width: 540,
    backgroundColor: error ? ViniiColors.redSolid : null,
    duration: const Duration(seconds: 6),
  ));
}

/// Shows a value the server returns only once (a key or signing secret).
Future<void> _showSecret(BuildContext context,
        {required String title,
        required String message,
        required String value,
        Key? valueKey}) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StaffDialog(
        title: title,
        width: 560,
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          MasterBanner(tone: PillTone.amber, message: message),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: MasterStyle.cardBorder),
            ),
            child: SelectableText(value,
                key: valueKey,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: ViniiColors.textPrimaryLight)),
          ),
        ]),
        actions: [
          MasterButton(
            key: const Key('secret-copy'),
            label: 'Copy',
            icon: Icons.copy,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) {
                showStaffNotice(context, 'Copied to the clipboard.');
              }
            },
          ),
          MasterButton(
              key: const Key('secret-done'),
              label: 'Done',
              kind: MasterButtonKind.primary,
              onPressed: () => Navigator.pop(context)),
        ],
      ),
    );

/// Two cards side by side, stacked on narrow windows.
class _Split extends StatelessWidget {
  const _Split({required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 860) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [left, const SizedBox(height: 20), right]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: left),
          const SizedBox(width: 20),
          Expanded(child: right),
        ]);
      });
}

/// Small grey chip (events, scopes, capabilities).
class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: MasterStyle.cardBorder),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: ViniiColors.textSecondaryLight)),
      );
}

/// "Label ........ value" row with a divider.
class _KvRow extends StatelessWidget {
  const _KvRow(this.label, this.value, {this.valueColor, this.last = false});
  final String label;
  final String value;
  final Color? valueColor;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: last
            ? null
            : const BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: MasterStyle.cardBorder))),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ViniiColors.textPrimaryLight))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 13,
                    color: valueColor ?? ViniiColors.textSecondaryLight)),
          ),
        ]),
      );
}

/// Full-width green (or red outline) button, as on the app cards.
class _WideButton extends StatelessWidget {
  const _WideButton(
      {super.key,
      required this.label,
      required this.icon,
      required this.onPressed,
      this.danger = false});
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 38,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          label: Text(label),
          style: FilledButton.styleFrom(
            backgroundColor: danger ? Colors.white : ViniiColors.brandGreen,
            foregroundColor: danger ? ViniiColors.redSolid : Colors.black,
            side: danger
                ? const BorderSide(color: Color(0xFFFCA5A5))
                : BorderSide.none,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      );
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, color: ViniiColors.textMutedLight)),
      );
}

const _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(10)),
  border: Border.fromBorderSide(BorderSide(color: MasterStyle.cardBorder)),
);

const _rowDivider = BoxDecoration(
    border: Border(bottom: BorderSide(color: MasterStyle.cardBorder)));

// ── overview ─────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.api, required this.onOpen});
  final ProviyaaApiClient api;
  final ValueChanged<IntegrationsTab> onOpen;

  @override
  Widget build(BuildContext context) => ApiLoader<Map<String, dynamic>>(
        load: () async => jsonMap(await api.get('v1/integrations/overview')),
        builder: (context, d, reload) {
          final rate = d['sync_success_rate'];
          final failed = _n(d['sync_failed']);
          final pending = _n(d['pending']);
          final attention = jsonList(d['attention']);
          final pipelines = jsonList(d['pipelines']);
          return MasterPage(children: [
            KpiGrid(cards: [
              MasterStatCard(
                label: 'CONNECTED APPLICATIONS',
                value: '${_n(d['connected'])} Active',
                caption: _plural(pending, 'pending request'),
                captionColor: pending > 0
                    ? ViniiColors.amberSolid
                    : ViniiColors.emeraldText,
              ),
              MasterStatCard(
                label: 'SYNC ENGINE SUCCESS RATE',
                value: rate == null ? '—' : '${staffNumText(numOf(rate))}%',
                caption: '$failed sync failed recently',
                captionColor: failed > 0
                    ? ViniiColors.amberSolid
                    : ViniiColors.textMutedLight,
              ),
              MasterStatCard(
                label: 'ACTIVE WEBHOOK ENDPOINTS',
                value: _plural(_n(d['webhook_endpoints']), 'Endpoint'),
                caption:
                    '${_n(d['deliveries_today'])} successful deliveries today',
              ),
              MasterStatCard(
                label: 'ACTIVE API KEYS',
                value: _plural(_n(d['api_keys']), 'Key'),
                caption: 'Not revoked or expired',
                captionColor: ViniiColors.emeraldText,
              ),
            ]),
            _Split(
              left: MasterSection(
                title: 'System Attention Log',
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (attention.isEmpty)
                        const _EmptyLine('Nothing needs attention.')
                      else
                        for (final a in attention) _AttentionBox(a),
                      const SizedBox(height: 14),
                      const Text('Integration Pipeline Health',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: ViniiColors.textPrimaryLight)),
                      const SizedBox(height: 6),
                      if (pipelines.isEmpty)
                        const _EmptyLine(
                            'No app is connected or waiting to be linked.')
                      else
                        for (final p in pipelines)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(children: [
                              Expanded(
                                  child: Text(textOf(p['name']),
                                      style: MasterStyle.body)),
                              StatusPill(textOf(p['status'], ''),
                                  label: _appStatusLabel(p['status'])),
                            ]),
                          ),
                    ]),
              ),
              right: MasterSection(
                title: 'Platform Integration State',
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                          'Every sync job and webhook delivery is logged (see Logs). '
                          'No provider adapter is live yet: a connection request '
                          'stays pending until the Proviyaa team links it.',
                          style: MasterStyle.body),
                      const SizedBox(height: 10),
                      _KvRow('Sync queue', '${_n(d['sync_queued'])} queued'),
                      _KvRow('Failed sync jobs', '$failed',
                          valueColor:
                              failed > 0 ? ViniiColors.redSolid : null),
                      _KvRow('Connection requests this month',
                          '${_n(d['requested_this_month'])}'),
                      const _KvRow('API key storage',
                          'SHA-256 hashes; full key shown once',
                          last: true),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        MasterButton(
                            label: 'Connected apps',
                            onPressed: () => onOpen(IntegrationsTab.apps)),
                        MasterButton(
                            label: 'Sync engine',
                            onPressed: () => onOpen(IntegrationsTab.sync)),
                        MasterButton(
                            label: 'Logs',
                            onPressed: () => onOpen(IntegrationsTab.logs)),
                      ]),
                    ]),
              ),
            ),
          ]);
        },
      );
}

class _AttentionBox extends StatelessWidget {
  const _AttentionBox(this.item);
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final webhook = item['kind'] == 'webhook';
    final error = textOf(item['error'], '');
    const ink = Color(0xFF92400E);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.warning_amber_rounded,
            size: 20, color: ViniiColors.amberSolid),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                '${textOf(item['source'])} — '
                '${webhook ? 'webhook delivery failed' : 'sync failed'}',
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700, color: ink)),
            const SizedBox(height: 3),
            Text(
                '${webhook ? 'Event' : 'Resource'}: '
                '${webhook ? _eventLabel(item['detail']) : _syncWord(item['detail'])}'
                ' · ${fmtDateTime(item['at'])}',
                style: const TextStyle(fontSize: 12.5, color: ink)),
            if (error.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(error,
                  style: const TextStyle(
                      fontSize: 12.5, color: ViniiColors.textPrimaryLight)),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ── connected apps ───────────────────────────────────────────────────────

class _AppsTab extends StatelessWidget {
  const _AppsTab(
      {required this.api, required this.category, required this.onCategory});
  final ProviyaaApiClient api;
  final String? category;
  final ValueChanged<String?> onCategory;

  @override
  Widget build(BuildContext context) {
    final cat = category;
    final options = <String?>[null, for (final c in _categories) c.$1];
    var selected = options.indexOf(cat);
    if (selected < 0) selected = 0;
    return MasterPage(children: [
      StaffPills(
        options: ['All apps', for (final c in _categories) c.$2],
        selected: selected,
        keyPrefix: 'integrations-category',
        onSelect: (i) => onCategory(options[i]),
      ),
      const SizedBox(height: 16),
      const InfoNote(
          'Connecting an app sends a request to the Proviyaa team, who link it '
          'with your partner credentials. It shows "pending" until then and '
          '"connected" once it is live.'),
      ApiLoader<List<Map<String, dynamic>>>(
        key: ValueKey('apps-$cat'),
        load: () async => jsonList(await api.get('v1/integrations/apps',
            query: cat == null ? null : {'category': cat})),
        builder: (context, apps, reload) =>
            _AppGroups(api: api, apps: apps, reload: reload),
      ),
    ]);
  }
}

class _AppGroups extends StatelessWidget {
  const _AppGroups(
      {required this.api, required this.apps, required this.reload});
  final ProviyaaApiClient api;
  final List<Map<String, dynamic>> apps;
  final VoidCallback reload;

  static IconData _icon(String key, String category) {
    switch (key) {
      case 'zomato':
      case 'swiggy':
        return Icons.delivery_dining;
      case 'razorpay':
        return Icons.credit_card;
      case 'phonepe_business':
        return Icons.phone_android;
      case 'paytm_business':
      case 'google_pay_business':
        return Icons.account_balance_wallet_outlined;
      case 'whatsapp_business':
        return Icons.chat_bubble_outline;
      case 'sms_gateway':
        return Icons.sms_outlined;
      case 'email_smtp':
        return Icons.alternate_email;
      case 'push_notifications':
        return Icons.notifications_none;
      case 'google_calendar':
        return Icons.event_outlined;
      case 'google_drive':
        return Icons.folder_open;
      case 'amazon_marketplace':
        return Icons.shopping_bag_outlined;
      case 'tally_prime':
        return Icons.receipt_long_outlined;
    }
    switch (category) {
      case 'delivery':
        return Icons.delivery_dining;
      case 'payments':
        return Icons.payments_outlined;
      case 'communication':
        return Icons.forum_outlined;
      case 'ecommerce':
        return Icons.storefront_outlined;
      case 'accounting':
        return Icons.calculate_outlined;
    }
    return Icons.extension_outlined;
  }

  Future<void> _connect(BuildContext context, Map<String, dynamic> app) async {
    final key = '${app['key']}';
    final name = textOf(app['name'], humanize(key));
    final values = await showStaffPrompt(
      context,
      title: 'Connect $name',
      subtitle: 'Sends a connection request to the Proviyaa team',
      fields: [
        StaffPromptField('account_ref', 'Account / merchant ID',
            key: const Key('connect-account'),
            initial: textOf(app['account_ref'], ''),
            hint: 'Your $name partner or merchant ID'),
        const StaffPromptField('note', 'Note for the Proviyaa team (optional)',
            key: Key('connect-note'), maxLines: 3),
      ],
      note: const MasterBanner(
          tone: PillTone.blue,
          message: 'Nothing is linked when you send this. The Proviyaa team '
              'connects the app with your partner credentials; it shows '
              '"pending" until then.'),
      confirmLabel: 'Send request',
      confirmKey: const Key('connect-save'),
      width: 480,
      validate: (v) => (v['account_ref'] ?? '').isEmpty
          ? 'Enter your account / merchant ID.'
          : null,
    );
    if (values == null || !context.mounted) return;
    final out = await runAction(
        context,
        () => api.postEnvelope('v1/integrations/apps/$key/connect', {
              'account_ref': values['account_ref'] ?? '',
              'note': values['note'] ?? '',
            }));
    if (out == null || !context.mounted) return;
    _say(context, textOf(out['message'], '$name connection requested.'));
    reload();
  }

  Future<void> _disconnect(
      BuildContext context, Map<String, dynamic> app) async {
    final key = '${app['key']}';
    final name = textOf(app['name'], humanize(key));
    final ok = await staffConfirm(context,
        title: 'Disconnect $name?',
        message: 'The request or link for $name is marked disconnected. '
            'You can send a new request later.',
        confirmLabel: 'Disconnect');
    if (!ok || !context.mounted) return;
    final done = await runAction<bool>(context, () async {
      await api.post('v1/integrations/apps/$key/disconnect');
      return true;
    }, success: '$name disconnected.');
    if (done == true && context.mounted) reload();
  }

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) {
      return const MasterCard(
        child: StaffEmptyState(
            icon: Icons.extension_outlined,
            title: 'No apps in this category'),
      );
    }
    final known = {for (final c in _categories) c.$1};
    bool inGroup(Map<String, dynamic> a, String group) => group == 'other'
        ? !known.contains(a['category'])
        : a['category'] == group;
    final groups = <(String, String)>[
      ..._categories,
      if (apps.any((a) => !known.contains(a['category']))) ('other', 'Other'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final g in groups)
        if (apps.any((a) => inGroup(a, g.$1))) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Text(g.$2.toUpperCase(),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: ViniiColors.textSecondaryLight)),
          ),
          MasterGrid(columns: 3, minItemWidth: 260, children: [
            for (final a in apps.where((x) => inGroup(x, g.$1)))
              _AppCard(
                app: a,
                icon: _icon('${a['key']}', '${a['category']}'),
                onConnect: () => _connect(context, a),
                onDisconnect: () => _disconnect(context, a),
              ),
          ]),
          const SizedBox(height: 22),
        ],
    ]);
  }
}

class _AppCard extends StatelessWidget {
  const _AppCard(
      {required this.app,
      required this.icon,
      required this.onConnect,
      required this.onDisconnect});
  final Map<String, dynamic> app;
  final IconData icon;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final key = '${app['key'] ?? ''}';
    final status = textOf(app['status'], 'not_connected');
    final caps = _strings(app['capabilities']);
    final category = '${app['category'] ?? ''}';
    final categoryLabel = _categories
        .where((c) => c.$1 == category)
        .map((c) => c.$2)
        .firstOrNull;
    final linked =
        status == 'pending' || status == 'connected' || status == 'error';
    final account = textOf(app['account_ref'], '');
    final error = textOf(app['last_error'], '');
    return MasterCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: MasterStyle.cardBorder),
            ),
            child: Icon(icon, size: 20, color: ViniiColors.textPrimaryLight),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(textOf(app['name'], humanize(key)),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: ViniiColors.textPrimaryLight)),
              if (categoryLabel != null) ...[
                const SizedBox(height: 2),
                Text(categoryLabel,
                    overflow: TextOverflow.ellipsis,
                    style: MasterStyle.muted.copyWith(fontSize: 11)),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            StatusPill(status, label: _appStatusLabel(status)),
            if (app['beta'] == true) ...[
              const SizedBox(height: 4),
              const MasterStatusPill('Beta', tone: PillTone.purple),
            ],
          ]),
        ]),
        if (caps.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final c in caps) _Tag(c)]),
        ],
        const SizedBox(height: 12),
        Text(textOf(app['description'], ''), style: MasterStyle.body),
        if (account.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Account: $account', style: MasterStyle.muted),
        ],
        if (status == 'pending' && app['requested_at'] != null) ...[
          const SizedBox(height: 2),
          Text(
              'Requested ${fmtDate(app['requested_at'])} · waiting for the '
              'Proviyaa team',
              style: MasterStyle.muted),
        ],
        if (error.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(error,
              style: const TextStyle(
                  fontSize: 12.5, color: ViniiColors.redSolid)),
        ],
        const SizedBox(height: 14),
        linked
            ? _WideButton(
                key: Key('disconnect-$key'),
                label: 'Disconnect',
                icon: Icons.link_off,
                danger: true,
                onPressed: onDisconnect)
            : _WideButton(
                key: Key('connect-$key'),
                label: 'Connect',
                icon: Icons.link,
                onPressed: onConnect),
      ]),
    );
  }
}

// ── sync engine ──────────────────────────────────────────────────────────

typedef _SyncData = ({
  List<Map<String, dynamic>> jobs,
  int queued,
  List<Map<String, dynamic>> apps
});

class _SyncTab extends StatefulWidget {
  const _SyncTab({required this.api});
  final ProviyaaApiClient api;

  @override
  State<_SyncTab> createState() => _SyncTabState();
}

class _SyncTabState extends State<_SyncTab> {
  final _loader = GlobalKey<ApiLoaderState<_SyncData>>();
  String _status = 'all';
  bool _running = false;

  Future<_SyncData> _load() async {
    final api = widget.api;
    final res = await Future.wait<dynamic>([
      api.get('v1/integrations/sync-jobs',
          query: _status == 'all' ? null : {'status': _status}),
      api.get('v1/integrations/sync-jobs', query: const {'status': 'queued'}),
      api.get('v1/integrations/apps'),
    ]);
    return (
      jobs: jsonList(res[0]),
      queued: jsonList(res[1]).length,
      apps: jsonList(res[2]),
    );
  }

  void _reload() => _loader.currentState?.reload();

  Future<void> _queue(List<Map<String, dynamic>> apps) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => _QueueSyncDialog(api: widget.api, apps: apps));
    if (ok != true || !mounted) return;
    _say(context, 'Sync job queued. Run the queue to process it.');
    _reload();
  }

  Future<void> _run() async {
    setState(() => _running = true);
    final out = await runAction(
        context,
        () async =>
            jsonMap(await widget.api.post('v1/integrations/sync-jobs/run')));
    if (!mounted) return;
    setState(() => _running = false);
    if (out == null) return;
    final ran = _n(out['ran']);
    _say(
        context,
        ran == 0
            ? 'Nothing was queued.'
            : 'Ran $ran: ${_n(out['failed'])} failed, '
                '${_n(out['succeeded'])} succeeded.',
        error: _n(out['failed']) > 0);
    _reload();
  }

  @override
  Widget build(BuildContext context) => ApiLoader<_SyncData>(
        key: _loader,
        load: _load,
        builder: (context, d, reload) => MasterPage(children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              MasterButton(
                  key: const Key('sync-queue'),
                  label: 'Queue sync',
                  icon: Icons.add,
                  kind: MasterButtonKind.primary,
                  onPressed: () => _queue(d.apps)),
              MasterButton(
                  key: const Key('sync-run'),
                  label: _running ? 'Running…' : 'Run queue (${d.queued})',
                  icon: Icons.play_arrow_outlined,
                  onPressed: _running ? null : _run),
              MasterFilterButton(
                label: 'Status: ${_status == 'all' ? 'All' : humanize(_status)}',
                options: const ['All', 'Queued', 'Running', 'Success', 'Failed'],
                onSelected: (v) {
                  setState(() => _status = v.toLowerCase());
                  _reload();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          const InfoNote(
              'No provider adapter is live yet. Running the queue marks each '
              'job failed with the reason (for example, that the app is not '
              'connected) instead of pretending to sync.',
              tone: PillTone.amber),
          MasterSection(
            title: 'Background queue',
            subtitle: _status == 'all'
                ? 'Latest 200 jobs'
                : '${humanize(_status)} jobs',
            child: d.jobs.isEmpty
                ? const StaffEmptyState(
                    icon: Icons.sync,
                    title: 'No sync jobs',
                    message: 'Queue a sync to add a job for one of your apps.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [for (final j in d.jobs) _JobRow(j)]),
          ),
        ]),
      );
}

class _JobRow extends StatelessWidget {
  const _JobRow(this.job);
  final Map<String, dynamic> job;

  @override
  Widget build(BuildContext context) {
    final status = textOf(job['status'], 'queued');
    final error = textOf(job['error'], '');
    final attempts = _n(job['attempts']);
    final max = _n(job['max_attempts']);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: _rowDivider,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 96,
          child: Align(
              alignment: Alignment.centerLeft,
              child: StatusPill(status, label: humanize(status))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                    textOf(job['provider_name'],
                        humanize(textOf(job['provider'], ''))),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ViniiColors.textPrimaryLight)),
                Text(
                    '${_syncWord(job['resource'])} • ${_syncWord(job['mode'])} • '
                    '${_syncWord(job['direction'])}',
                    style: MasterStyle.muted),
              ],
            ),
            const SizedBox(height: 3),
            Text(
                attempts == 0
                    ? 'Not run yet • try 0/$max'
                    : '${_duration(_n(job['duration_ms']))} • try $attempts/$max',
                style: MasterStyle.muted),
            if (error.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(error,
                  style: const TextStyle(
                      fontSize: 12.5, color: ViniiColors.redSolid)),
            ],
          ]),
        ),
        const SizedBox(width: 12),
        Text(fmtDateTime(job['finished_at'] ?? job['created_at']),
            style: MasterStyle.muted),
      ]),
    );
  }
}

class _QueueSyncDialog extends StatefulWidget {
  const _QueueSyncDialog({required this.api, required this.apps});
  final ProviyaaApiClient api;
  final List<Map<String, dynamic>> apps;

  @override
  State<_QueueSyncDialog> createState() => _QueueSyncDialogState();
}

class _QueueSyncDialogState extends State<_QueueSyncDialog> {
  String? _provider;
  String _resource = 'menu';
  String _mode = 'delta';
  String _direction = 'inbound';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final linked = widget.apps.where(
        (a) => a['status'] == 'connected' || a['status'] == 'pending');
    final first = linked.isNotEmpty
        ? linked.first
        : (widget.apps.isNotEmpty ? widget.apps.first : null);
    _provider = first == null ? null : '${first['key']}';
  }

  Future<void> _save() async {
    final provider = _provider;
    if (provider == null) {
      setState(() => _error = 'Pick an app.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.post('v1/integrations/sync-jobs', {
        'provider': provider,
        'resource': _resource,
        'mode': _mode,
        'direction': _direction,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) => StaffDialog(
        title: 'Queue sync',
        subtitle: 'Adds a job to the background queue',
        error: _error,
        actions: [
          MasterButton(
              label: 'Cancel', onPressed: () => Navigator.pop(context)),
          MasterButton(
              key: const Key('sync-queue-save'),
              label: _busy ? 'Queuing…' : 'Queue job',
              kind: MasterButtonKind.primary,
              onPressed: _busy ? null : _save),
        ],
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          StaffField(
            label: 'App',
            required: true,
            child: StaffSelect<String>(
              key: const Key('sync-app'),
              value: _provider,
              hint: 'Pick an app',
              items: [
                for (final a in widget.apps)
                  (
                    '${a['key']}',
                    '${textOf(a['name'], humanize(textOf(a['key'], '')))} '
                        '(${_appStatusLabel(a['status'])})'
                  ),
              ],
              onChanged: (v) => setState(() => _provider = v),
            ),
          ),
          const SizedBox(height: 14),
          StaffFormRow(children: [
            StaffField(
              label: 'Resource',
              child: StaffSelect<String>(
                key: const Key('sync-resource'),
                value: _resource,
                items: const [
                  ('menu', 'Menu'),
                  ('inventory', 'Inventory'),
                  ('orders', 'Orders'),
                  ('payments', 'Payments'),
                  ('customers', 'Customers'),
                  ('settlements', 'Settlements'),
                ],
                onChanged: (v) => setState(() => _resource = v ?? _resource),
              ),
            ),
            StaffField(
              label: 'Mode',
              child: StaffSelect<String>(
                key: const Key('sync-mode'),
                value: _mode,
                items: const [
                  ('full', 'Full sync'),
                  ('delta', 'Changes only'),
                  ('manual', 'Manual'),
                  ('pull', 'Pull'),
                ],
                onChanged: (v) => setState(() => _mode = v ?? _mode),
              ),
            ),
          ]),
          StaffFormRow(children: [
            StaffField(
              label: 'Direction',
              child: StaffSelect<String>(
                key: const Key('sync-direction'),
                value: _direction,
                items: const [
                  ('inbound', 'Inbound (app → Proviyaa)'),
                  ('outbound', 'Outbound (Proviyaa → app)'),
                ],
                onChanged: (v) =>
                    setState(() => _direction = v ?? _direction),
              ),
            ),
          ]),
          const MasterBanner(
              tone: PillTone.amber,
              message: 'A job for an app that is not connected fails with '
                  'that reason when the queue runs.'),
        ]),
      );
}

// ── webhooks ─────────────────────────────────────────────────────────────

class _WebhooksTab extends StatefulWidget {
  const _WebhooksTab({required this.api});
  final ProviyaaApiClient api;

  @override
  State<_WebhooksTab> createState() => _WebhooksTabState();
}

class _WebhooksTabState extends State<_WebhooksTab> {
  final _loader = GlobalKey<ApiLoaderState<Map<String, dynamic>>>();
  int _sub = 0;

  void _reload() => _loader.currentState?.reload();

  Future<void> _edit(
      List<String> events, Map<String, dynamic>? existing) async {
    final out = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _WebhookDialog(
            api: widget.api, events: events, existing: existing));
    if (out == null || !mounted) return;
    _reload();
    final secret = textOf(out['signing_secret'], '');
    if (existing == null && secret.isNotEmpty) {
      await _showSecret(context,
          title: 'Signing secret',
          message: 'Copy it now; it is not shown again. Your endpoint uses it '
              'to check the X-Proviyaa-Signature header (HMAC-SHA256 of the '
              'request body).',
          value: secret,
          valueKey: const Key('webhook-secret-value'));
    } else {
      _say(context, 'Endpoint saved.');
    }
  }

  Future<void> _test(String id, String name) async {
    final out = await runAction(
        context,
        () async => jsonMap(
            await widget.api.post('v1/integrations/webhooks/$id/test')));
    if (out == null || !mounted) return;
    final ok = out['status'] == 'success';
    final http = out['http_status'];
    _say(
        context,
        ok
            ? 'Test delivered to $name: HTTP $http in '
                '${_n(out['duration_ms'])} ms.'
            : 'Test to $name failed${http == null ? '' : ' (HTTP $http)'}: '
                '${textOf(out['error'], 'no response')}',
        error: !ok);
    _reload();
  }

  Future<void> _delete(String id, String name) async {
    final ok = await staffConfirm(context,
        title: 'Delete "$name"?',
        message: 'Proviyaa stops sending to this endpoint. Its delivery '
            'history is kept.');
    if (!ok || !mounted) return;
    final done = await runAction<bool>(context, () async {
      await widget.api.delete('v1/integrations/webhooks/$id');
      return true;
    }, success: 'Endpoint deleted.');
    if (done == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => ApiLoader<Map<String, dynamic>>(
        key: _loader,
        load: () => widget.api.getEnvelope('v1/integrations/webhooks'),
        builder: (context, env, reload) {
          final endpoints = jsonList(env['data']);
          final events = _strings(env['events']);
          final counts = jsonMap(env['counts']);
          return MasterPage(children: [
            StaffPills(
              options: [
                'Endpoints (${endpoints.length})',
                'Deliveries (${_n(counts['deliveries'])})',
                'Dead Letter (${_n(counts['dead_letter'])})',
              ],
              selected: _sub,
              keyPrefix: 'webhook-tab',
              onSelect: (i) => setState(() => _sub = i),
            ),
            const SizedBox(height: 16),
            if (_sub == 0)
              ..._endpoints(endpoints, events)
            else
              _Deliveries(
                  key: ValueKey('deliveries-$_sub'),
                  api: widget.api,
                  failedOnly: _sub == 2),
          ]);
        },
      );

  List<Widget> _endpoints(
          List<Map<String, dynamic>> endpoints, List<String> events) =>
      [
        Wrap(spacing: 10, runSpacing: 10, children: [
          MasterButton(
              key: const Key('webhook-add'),
              label: 'Outgoing endpoint',
              icon: Icons.add,
              kind: MasterButtonKind.primary,
              onPressed: () => _edit(events, null)),
        ]),
        const SizedBox(height: 16),
        const InfoNote(
            '"Send test" really delivers a signed test ping to your URL. '
            'Order, KOT and stock events are not sent automatically yet.',
            tone: PillTone.amber),
        MasterSection(
          title: 'Outgoing',
          subtitle: 'HTTPS endpoints on public hosts, signed with HMAC-SHA256.',
          child: endpoints.isEmpty
              ? const StaffEmptyState(
                  icon: Icons.webhook,
                  title: 'No outgoing endpoints',
                  message: 'Add an HTTPS endpoint to receive order, KOT and '
                      'stock events.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final e in endpoints) _endpointCard(e, events)],
                ),
        ),
        const SizedBox(height: 20),
        const MasterSection(
          title: 'Incoming',
          child: MasterBanner(
              tone: PillTone.amber,
              message: 'Inbound webhooks are not available yet: there is no '
                  'public URL for aggregators or payment providers to call.'),
        ),
      ];

  Widget _endpointCard(Map<String, dynamic> e, List<String> events) {
    final id = '${e['id']}';
    final name = textOf(e['name'], 'Endpoint');
    final active = e['active'] != false;
    final lastStatus = textOf(e['last_status'], '');
    final hint = textOf(e['signing_secret_hint'], '');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(name,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ViniiColors.textPrimaryLight)),
            StatusPill(active ? 'active' : 'paused',
                label: active ? 'Active' : 'Paused'),
          ],
        ),
        const SizedBox(height: 4),
        Text(textOf(e['url']),
            style: MasterStyle.muted.copyWith(fontSize: 12.5)),
        const SizedBox(height: 10),
        Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final ev in _strings(e['events'])) _Tag(_eventLabel(ev))
            ]),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              MasterButton(
                  key: Key('webhook-test-$name'),
                  label: 'Send test',
                  icon: Icons.send_outlined,
                  onPressed: () => _test(id, name)),
              MasterButton(
                  key: Key('webhook-edit-$name'),
                  label: 'Edit',
                  onPressed: () => _edit(events, e)),
              MasterButton(
                  key: Key('webhook-delete-$name'),
                  label: 'Delete',
                  kind: MasterButtonKind.dangerOutline,
                  onPressed: () => _delete(id, name)),
            ]),
            Text(
                e['last_tried_at'] == null
                    ? 'Never tried${hint.isEmpty ? '' : ' · secret $hint'}'
                    : 'Last tried ${fmtDateTime(e['last_tried_at'])}'
                        '${lastStatus.isEmpty ? '' : ' · $lastStatus'}',
                style: MasterStyle.muted),
          ],
        ),
      ]),
    );
  }
}

class _Deliveries extends StatelessWidget {
  const _Deliveries(
      {super.key, required this.api, required this.failedOnly});
  final ProviyaaApiClient api;
  final bool failedOnly;

  @override
  Widget build(BuildContext context) =>
      ApiLoader<List<Map<String, dynamic>>>(
        load: () async => jsonList(await api.get(
            'v1/integrations/webhooks/deliveries',
            query: failedOnly ? const {'status': 'failed'} : null)),
        builder: (context, rows, reload) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (failedOnly)
              const InfoNote(
                  'Failed deliveries are kept here. There is no automatic '
                  'retry yet: fix the endpoint and use "Send test".',
                  tone: PillTone.amber),
            if (rows.isEmpty)
              MasterCard(
                child: StaffEmptyState(
                  icon: Icons.inbox_outlined,
                  title: failedOnly
                      ? 'No failed deliveries'
                      : 'No deliveries yet',
                  message: failedOnly
                      ? null
                      : 'Use "Send test" on an endpoint to try a delivery.',
                ),
              )
            else
              MasterTable(
                minWidth: 900,
                columns: const [
                  MasterColumn('Date', flex: 2),
                  MasterColumn('Endpoint', flex: 2),
                  MasterColumn('Event', flex: 2),
                  MasterColumn('Status'),
                  MasterColumn('HTTP'),
                  MasterColumn('Error', flex: 3),
                  MasterColumn('Duration', alignEnd: true),
                ],
                rows: [
                  for (final r in rows)
                    [
                      MasterCellText(fmtDateTime(r['created_at'])),
                      MasterCellTitle(
                          textOf(r['endpoint_name'], 'Deleted endpoint'),
                          subtitle: textOf(r['url'], '').isEmpty
                              ? null
                              : textOf(r['url'], '')),
                      MasterCellText(_eventLabel(r['event'])),
                      StatusPill(textOf(r['status'], '')),
                      MasterCellText(r['http_status'] == null
                          ? '—'
                          : '${r['http_status']}'),
                      MasterCellText(textOf(r['error']),
                          color: textOf(r['error'], '').isEmpty
                              ? null
                              : ViniiColors.redSolid),
                      MasterCellText('${_n(r['duration_ms'])} ms'),
                    ],
                ],
              ),
          ],
        ),
      );
}

class _WebhookDialog extends StatefulWidget {
  const _WebhookDialog(
      {required this.api, required this.events, this.existing});
  final ProviyaaApiClient api;
  final List<String> events;
  final Map<String, dynamic>? existing;

  @override
  State<_WebhookDialog> createState() => _WebhookDialogState();
}

class _WebhookDialogState extends State<_WebhookDialog> {
  late final _name =
      TextEditingController(text: textOf(widget.existing?['name'], ''));
  late final _url =
      TextEditingController(text: textOf(widget.existing?['url'], ''));
  /// A new endpoint starts with order.created ticked.
  late final Set<String> _events = widget.existing == null
      ? {if (widget.events.contains('order.created')) 'order.created'}
      : _strings(widget.existing?['events']).toSet();
  late bool _active = widget.existing?['active'] != false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Name the endpoint.');
      return;
    }
    if (_events.isEmpty) {
      setState(() => _error = 'Pick at least one event.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final body = {
      'name': _name.text.trim(),
      'url': _url.text.trim(),
      'events': [
        for (final e in widget.events)
          if (_events.contains(e)) e
      ],
      'active': _active,
    };
    try {
      final existing = widget.existing;
      final out = existing == null
          ? jsonMap(await widget.api.post('v1/integrations/webhooks', body))
          : jsonMap(await widget.api
              .patch('v1/integrations/webhooks/${existing['id']}', body));
      if (!mounted) return;
      Navigator.pop(context, out);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final creating = widget.existing == null;
    return StaffDialog(
      title: creating ? 'Add outgoing endpoint' : 'Edit endpoint',
      subtitle: 'Proviyaa POSTs signed JSON to this URL',
      error: _error,
      actions: [
        MasterButton(label: 'Cancel', onPressed: () => Navigator.pop(context)),
        MasterButton(
            key: const Key('webhook-save'),
            label: _busy ? 'Saving…' : (creating ? 'Add endpoint' : 'Save'),
            kind: MasterButtonKind.primary,
            onPressed: _busy ? null : _save),
      ],
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BizTextField(
            key: const Key('webhook-name'),
            label: 'Name',
            required: true,
            controller: _name,
            hint: 'e.g. Order events to our ERP'),
        const SizedBox(height: 14),
        BizTextField(
            key: const Key('webhook-url'),
            label: 'HTTPS URL',
            required: true,
            controller: _url,
            hint: 'https://example.com/hooks/orders'),
        const SizedBox(height: 14),
        const Text('Events',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: ViniiColors.textPrimaryLight)),
        const SizedBox(height: 4),
        Wrap(children: [
          for (final ev in widget.events)
            SizedBox(
              width: 240,
              child: CheckboxListTile(
                key: Key('webhook-event-$ev'),
                value: _events.contains(ev),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: ViniiColors.greenSolid,
                title: Text(_eventLabel(ev),
                    style: const TextStyle(fontSize: 13)),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _events.add(ev);
                  } else {
                    _events.remove(ev);
                  }
                }),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        BizToggle(
            label: 'Active',
            value: _active,
            onChanged: (v) => setState(() => _active = v)),
        if (creating) ...[
          const SizedBox(height: 12),
          const MasterBanner(
              tone: PillTone.blue,
              message: 'A signing secret is created and shown once after '
                  'you add the endpoint.'),
        ],
      ]),
    );
  }
}

// ── API keys ─────────────────────────────────────────────────────────────

class _ApiKeysTab extends StatefulWidget {
  const _ApiKeysTab({required this.api});
  final ProviyaaApiClient api;

  @override
  State<_ApiKeysTab> createState() => _ApiKeysTabState();
}

class _ApiKeysTabState extends State<_ApiKeysTab> {
  final _loader = GlobalKey<ApiLoaderState<Map<String, dynamic>>>();

  void _reload() => _loader.currentState?.reload();

  Future<void> _generate(List<String> scopes) async {
    final out = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _ApiKeyDialog(api: widget.api, scopes: scopes));
    if (out == null || !mounted) return;
    _reload();
    await _showSecret(context,
        title: 'Your new API key',
        message: 'Copy it now; it is not shown again. Proviyaa keeps only a '
            'hash of it.',
        value: textOf(out['key'], ''),
        valueKey: const Key('api-key-value'));
  }

  Future<void> _rotate(String id, String name) async {
    final ok = await staffConfirm(context,
        title: 'Rotate "$name"?',
        message: 'The current key stops working now and a new key with the '
            'same scopes replaces it. Give the new key to the partner system.',
        confirmLabel: 'Rotate',
        danger: false);
    if (!ok || !mounted) return;
    final out = await runAction(
        context,
        () async => jsonMap(
            await widget.api.post('v1/integrations/api-keys/$id/rotate')));
    if (out == null || !mounted) return;
    _reload();
    await _showSecret(context,
        title: 'New key for $name',
        message: 'The old key is revoked. Copy the new one now; it is not '
            'shown again.',
        value: textOf(out['key'], ''),
        valueKey: const Key('api-key-value'));
  }

  Future<void> _revoke(String id, String name) async {
    final ok = await staffConfirm(context,
        title: 'Revoke "$name"?',
        message: 'The key stops working at once. This cannot be undone.',
        confirmLabel: 'Revoke');
    if (!ok || !mounted) return;
    final done = await runAction<bool>(context, () async {
      await widget.api.post('v1/integrations/api-keys/$id/revoke');
      return true;
    }, success: 'Key revoked.');
    if (done == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => ApiLoader<Map<String, dynamic>>(
        key: _loader,
        load: () => widget.api.getEnvelope('v1/integrations/api-keys'),
        builder: (context, env, reload) {
          final keys = jsonList(env['data']);
          final scopes = _strings(env['scopes']);
          final audit = jsonList(env['audit']);
          return MasterPage(children: [
            MasterCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const Icon(Icons.vpn_key_outlined,
                          size: 22, color: ViniiColors.textPrimaryLight),
                      const SizedBox(width: 10),
                      const Expanded(
                          child: Text('API keys',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: ViniiColors.textPrimaryLight))),
                      MasterButton(
                          key: const Key('api-key-generate'),
                          label: 'Generate key',
                          icon: Icons.add,
                          kind: MasterButtonKind.primary,
                          onPressed: () => _generate(scopes)),
                    ]),
                    const SizedBox(height: 12),
                    const Text(
                        'Scoped keys let partner systems read from and write to '
                        'Proviyaa through the integrations API. Keys are stored '
                        'as hashes — the full value is shown only once, when it '
                        'is created.',
                        style: MasterStyle.body),
                    const SizedBox(height: 12),
                    const MasterBanner(
                        tone: PillTone.amber,
                        message: 'The partner API these keys unlock is not live '
                            'yet. You can prepare keys now; no request can use '
                            'them until it is.'),
                    const SizedBox(height: 16),
                    if (keys.isEmpty)
                      const StaffEmptyState(
                          icon: Icons.vpn_key_outlined,
                          title: 'No API keys yet',
                          message: 'Generate a key for each partner system.')
                    else
                      for (final k in keys) _keyCard(k),
                  ]),
            ),
            const SizedBox(height: 20),
            MasterSection(
              title: 'Key audit trail',
              child: audit.isEmpty
                  ? const Text('No key activity recorded.',
                      style: MasterStyle.body)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [for (final a in audit) _auditRow(a)]),
            ),
          ]);
        },
      );

  Widget _keyCard(Map<String, dynamic> k) {
    final id = '${k['id']}';
    final name = textOf(k['name'], 'Key');
    final status = textOf(k['status'], 'active');
    final expires = k['expires_at'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ViniiColors.textPrimaryLight)),
                StatusPill(status, label: humanize(status)),
                Text('${textOf(k['prefix'], '')}****',
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                        color: ViniiColors.textMutedLight)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
              k['last_used_at'] == null
                  ? 'Never used'
                  : 'Last used ${fmtDate(k['last_used_at'])}',
              style: MasterStyle.muted),
        ]),
        const SizedBox(height: 10),
        Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in _strings(k['scopes'])) _Tag(_scopeLabel(s))
            ]),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
                [
                  if (status == 'revoked')
                    'Revoked ${fmtDate(k['revoked_at'])}'
                  else if (expires == null)
                    'Never expires'
                  else
                    '${status == 'expired' ? 'Expired' : 'Expires'} '
                        '${fmtDate(expires)}',
                  'created ${fmtDate(k['created_at'])}',
                ].join(' · '),
                style: MasterStyle.muted),
            if (status == 'active')
              Wrap(spacing: 8, runSpacing: 8, children: [
                MasterButton(
                    key: Key('api-key-rotate-$name'),
                    label: 'Rotate',
                    icon: Icons.autorenew,
                    onPressed: () => _rotate(id, name)),
                MasterButton(
                    key: Key('api-key-revoke-$name'),
                    label: 'Revoke',
                    icon: Icons.delete_outline,
                    kind: MasterButtonKind.dangerOutline,
                    onPressed: () => _revoke(id, name)),
              ]),
          ],
        ),
      ]),
    );
  }

  Widget _auditRow(Map<String, dynamic> a) {
    final keyName = textOf(jsonMap(a['details'])['name'], '');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: _rowDivider,
      child: Row(children: [
        const Icon(Icons.history, size: 16, color: ViniiColors.textMutedLight),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: textOf(a['action']),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (keyName.isNotEmpty) TextSpan(text: ' · $keyName'),
              TextSpan(
                  text: ' by ${textOf(a['actor_name'], 'someone')}',
                  style: const TextStyle(color: ViniiColors.textMutedLight)),
            ]),
            style: MasterStyle.body,
          ),
        ),
        const SizedBox(width: 12),
        Text(fmtDateTime(a['created_at']), style: MasterStyle.muted),
      ]),
    );
  }
}

class _ApiKeyDialog extends StatefulWidget {
  const _ApiKeyDialog({required this.api, required this.scopes});
  final ProviyaaApiClient api;
  final List<String> scopes;

  @override
  State<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<_ApiKeyDialog> {
  final _name = TextEditingController();

  /// Starts with the least-privilege read scope ticked.
  late final Set<String> _scopes = {
    if (widget.scopes.contains('orders:read')) 'orders:read'
  };
  int _days = 365;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Name the key.');
      return;
    }
    if (_scopes.isEmpty) {
      setState(() => _error = 'Pick at least one scope.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final out = jsonMap(await widget.api.post('v1/integrations/api-keys', {
        'name': _name.text.trim(),
        'scopes': [
          for (final s in widget.scopes)
            if (_scopes.contains(s)) s
        ],
        'expires_in_days': _days == 0 ? null : _days,
      }));
      if (!mounted) return;
      Navigator.pop(context, out);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) => StaffDialog(
        title: 'Generate API key',
        subtitle: 'The full key is shown once, after it is created',
        error: _error,
        actions: [
          MasterButton(
              label: 'Cancel', onPressed: () => Navigator.pop(context)),
          MasterButton(
              key: const Key('api-key-save'),
              label: _busy ? 'Generating…' : 'Generate key',
              kind: MasterButtonKind.primary,
              onPressed: _busy ? null : _save),
        ],
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          BizTextField(
              key: const Key('api-key-name'),
              label: 'Name',
              required: true,
              controller: _name,
              hint: 'e.g. Accounting export (read only)'),
          const SizedBox(height: 14),
          const Text('Scopes',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: ViniiColors.textPrimaryLight)),
          const SizedBox(height: 4),
          Wrap(children: [
            for (final s in widget.scopes)
              SizedBox(
                width: 240,
                child: CheckboxListTile(
                  key: Key('api-key-scope-$s'),
                  value: _scopes.contains(s),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: ViniiColors.greenSolid,
                  title: Text(_scopeLabel(s),
                      style: const TextStyle(fontSize: 13)),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _scopes.add(s);
                    } else {
                      _scopes.remove(s);
                    }
                  }),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          StaffField(
            label: 'Expires',
            child: StaffSelect<int>(
              key: const Key('api-key-expiry'),
              value: _days,
              items: const [
                (30, 'In 30 days'),
                (90, 'In 90 days'),
                (180, 'In 180 days'),
                (365, 'In 1 year'),
                (0, 'Never'),
              ],
              onChanged: (v) => setState(() => _days = v ?? _days),
            ),
          ),
        ]),
      );
}

// ── logs ─────────────────────────────────────────────────────────────────

class _LogsTab extends StatefulWidget {
  const _LogsTab({required this.api});
  final ProviyaaApiClient api;

  @override
  State<_LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<_LogsTab> {
  final _loader = GlobalKey<ApiLoaderState<Map<String, dynamic>>>();
  int _page = 1;
  String _q = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _q = value.trim();
        _page = 1;
      });
      _loader.currentState?.reload();
    });
  }

  void _go(int page) {
    setState(() => _page = page);
    _loader.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) => MasterPage(children: [
        MasterSection(
          title: 'Historical transactions',
          subtitle: 'Sync jobs that ran and webhook deliveries, newest first.',
          trailing: MasterSearchField(
              key: const Key('logs-search'),
              hint: 'Filter logs…',
              width: 260,
              onChanged: _search),
          child: ApiLoader<Map<String, dynamic>>(
            key: _loader,
            load: () => widget.api.getEnvelope('v1/integrations/logs',
                query: {'page': '$_page', if (_q.isNotEmpty) 'q': _q}),
            builder: (context, env, reload) {
              final rows = jsonList(env['data']);
              final page = _n(env['page']) < 1 ? _page : _n(env['page']);
              final pages = _n(env['pages']) < 1 ? 1 : _n(env['pages']);
              final total = _n(env['total']);
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (rows.isEmpty)
                      StaffEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: _q.isEmpty
                            ? 'No logs yet'
                            : 'No logs match "$_q"',
                        message: _q.isEmpty
                            ? 'Sync jobs that ran and webhook deliveries show '
                                'up here.'
                            : null,
                      )
                    else
                      for (final r in rows) _LogRow(r),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                          child: Text(
                              'Page $page of $pages • ($total logs total)',
                              style: MasterStyle.muted)),
                      MasterButton(
                          key: const Key('logs-prev'),
                          label: 'Previous',
                          onPressed:
                              page > 1 ? () => _go(page - 1) : null),
                      const SizedBox(width: 8),
                      MasterButton(
                          key: const Key('logs-next'),
                          label: 'Next',
                          kind: page < pages
                              ? MasterButtonKind.primary
                              : MasterButtonKind.outline,
                          onPressed:
                              page < pages ? () => _go(page + 1) : null),
                    ]),
                  ]);
            },
          ),
        ),
      ]);
}

class _LogRow extends StatelessWidget {
  const _LogRow(this.row);
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final status = textOf(row['status'], '');
    final error = textOf(row['error'], '');
    final webhook = row['kind'] == 'webhook';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: _rowDivider,
      child: Row(children: [
        SizedBox(
            width: 170,
            child: Text(fmtDateTime(row['at']), style: MasterStyle.body)),
        Expanded(
          flex: 2,
          child: Text(textOf(row['source']),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: ViniiColors.textPrimaryLight)),
        ),
        Expanded(
          flex: 3,
          child: status == 'failed' && error.isNotEmpty
              ? Text(error,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5, color: ViniiColors.redSolid))
              : const SizedBox(),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(
              webhook
                  ? 'Webhook · ${_eventLabel(row['detail'])}'
                  : 'Sync · ${_syncWord(row['detail'])}',
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: MasterStyle.muted.copyWith(fontSize: 12.5)),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 88,
          child: Align(
              alignment: Alignment.centerRight,
              child: StatusPill(status, label: humanize(status))),
        ),
      ]),
    );
  }
}
