part of 'settings_screen.dart';

// The Settings "system" pages: overview, KDS & patch engine, operations
// centre, subscription and system update.

String _cycleLabel(int months) => switch (months) {
      1 => 'Monthly',
      3 => 'Quarterly',
      6 => 'Half yearly',
      12 => 'Yearly',
      _ => '$months months',
    };

/// "6d 14h" / "3h 20m" / "12m".
String _uptime(num seconds) {
  final s = seconds.toInt();
  final d = s ~/ 86400;
  final h = (s % 86400) ~/ 3600;
  final m = (s % 3600) ~/ 60;
  if (d > 0) return '${d}d ${h}h';
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

/// Replaces an ISO timestamp inside a server detail line with a readable one.
String _prettyDetail(String s) {
  final m = RegExp(r'\d{4}-\d{2}-\d{2}T[\d:.]+Z').firstMatch(s);
  return m == null ? s : s.replaceFirst(m.group(0)!, fmtDateTime(m.group(0)));
}

/// One open alert (critical / warning / info).
class _AlertBox extends StatelessWidget {
  const _AlertBox(this.alert);
  final Map<String, dynamic> alert;

  @override
  Widget build(BuildContext context) {
    final level = textOf(alert['level'], 'info');
    final (bg, border, tone) = switch (level) {
      'critical' => (ViniiColors.redTint, const Color(0xFFFCA5A5), PillTone.red),
      'warning' => (
          ViniiColors.amberTint,
          const Color(0xFFFCD34D),
          PillTone.amber
        ),
      _ => (ViniiColors.blueTint, const Color(0xFF93C5FD), PillTone.blue),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MasterStatusPill(humanize(level), tone: tone),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(textOf(alert['title']),
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: ViniiColors.textPrimaryLight)),
            const SizedBox(height: 2),
            Text(textOf(alert['detail'], ''), style: MasterStyle.muted),
          ]),
        ),
      ]),
    );
  }
}

// ── system overview ──────────────────────────────────────────────────────

/// Which settings page fixes each checklist item.
const _checklistTabs = <String, SettingsTab>{
  'outlet': SettingsTab.outlet,
  'bill': SettingsTab.billFormat,
  'tables': SettingsTab.order,
  'order_takers': SettingsTab.order,
  'printers': SettingsTab.printers,
  'devices': SettingsTab.devices,
  'notifications': SettingsTab.notifications,
};

const _jumps = <(SettingsTab, String, String, IconData)>[
  (
    SettingsTab.outlet,
    'Outlet profile',
    'Address, contact and business details.',
    Icons.storefront_outlined
  ),
  (
    SettingsTab.operations,
    'Operations centre',
    'Incidents, sync and webhook health.',
    Icons.dashboard_outlined
  ),
  (
    SettingsTab.order,
    'Order settings',
    'Dine-in tables and order takers.',
    Icons.playlist_add_check
  ),
  (
    SettingsTab.subscription,
    'Subscription',
    'Current plan and plan requests.',
    Icons.card_membership
  ),
  (
    SettingsTab.devices,
    'Devices',
    'Registered POS, KDS and peripherals.',
    Icons.devices_outlined
  ),
  (
    SettingsTab.printers,
    'Printers',
    'Receipt and KOT printers.',
    Icons.print_outlined
  ),
];

class _SystemOverviewTab extends StatefulWidget {
  const _SystemOverviewTab({required this.api, required this.onOpen});
  final ProviyaaApiClient api;
  final ValueChanged<SettingsTab> onOpen;

  @override
  State<_SystemOverviewTab> createState() => _SystemOverviewTabState();
}

class _SystemOverviewTabState extends State<_SystemOverviewTab> {
  final _loader = GlobalKey<ApiLoaderState<Map<String, dynamic>>>();
  bool _diagRunning = false;
  DateTime? _diagAt;

  Future<Map<String, dynamic>> _load() async {
    try {
      return jsonMap(await widget.api.get('v1/settings/overview'));
    } finally {
      // The loader rebuilds when this future settles, so the result line
      // under "Run Diagnostic" picks these up.
      if (_diagRunning) {
        _diagRunning = false;
        _diagAt = DateTime.now();
      }
    }
  }

  void _runDiagnostic() {
    setState(() => _diagRunning = true);
    _loader.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) => ApiLoader<Map<String, dynamic>>(
        key: _loader,
        load: _load,
        builder: (context, d, reload) {
          final alerts = jsonList(d['alerts']);
          final critical = alerts.where((a) => a['level'] == 'critical').length;
          final printers = jsonMap(d['printers']);
          final plan = d['plan'] is Map ? jsonMap(d['plan']) : null;
          final checklist = jsonList(d['checklist']);
          final done = checklist.where((c) => c['done'] == true).length;
          return MasterPage(children: [
            KpiGrid(cards: [
              MasterStatCard(
                  label: 'REGISTERED DEVICES',
                  value: '${_n(d['devices'])}',
                  caption: 'POS terminals, KDS screens and peripherals'),
              MasterStatCard(
                  label: 'PRINTERS',
                  value: '${_n(printers['active'])}/${_n(printers['total'])}',
                  caption: 'active / configured'),
              MasterStatCard(
                label: 'OPEN ALERTS',
                value: '${alerts.length}',
                caption: '$critical critical · ${alerts.length - critical} '
                    'others',
                valueColor: critical > 0
                    ? ViniiColors.redSolid
                    : ViniiColors.textPrimaryLight,
                captionColor: critical > 0
                    ? ViniiColors.redSolid
                    : ViniiColors.textMutedLight,
              ),
              MasterStatCard(
                label: 'PLAN',
                value: plan == null
                    ? 'No plan'
                    : (plan['days_remaining'] == null
                        ? 'Active'
                        : '${_n(plan['days_remaining'])}d'),
                caption: plan == null
                    ? 'No active plan on file'
                    : '${textOf(plan['plan_name'])}'
                        '${plan['days_remaining'] == null ? '' : ' · until renewal'}',
              ),
            ]),
            _Split(
              leftFlex: 3,
              rightFlex: 2,
              left: MasterSection(
                title: 'Configuration checklist',
                subtitle: '$done of ${checklist.length} done',
                child: MasterGrid(
                  columns: 2,
                  minItemWidth: 220,
                  spacing: 12,
                  children: [for (final c in checklist) _checkItem(c)],
                ),
              ),
              right: _components(jsonList(d['components'])),
            ),
            const SizedBox(height: 20),
            MasterSection(
              title: 'Module Configuration & State',
              child: MasterTable(
                minWidth: 400,
                columns: const [
                  MasterColumn('Module Name', flex: 3),
                  MasterColumn('Status', flex: 2),
                ],
                rows: [
                  for (final m in jsonList(d['modules']))
                    [
                      MasterCellText(textOf(m['name']), bold: true),
                      StatusPill(textOf(m['status'], '')),
                    ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            _Split(
              leftFlex: 3,
              rightFlex: 2,
              left: MasterSection(
                title: 'Open alerts',
                trailing: MasterStatusPill('${alerts.length}',
                    tone: alerts.isEmpty ? PillTone.green : PillTone.red),
                child: alerts.isEmpty
                    ? const Text('No open alerts.', style: MasterStyle.body)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [for (final a in alerts) _AlertBox(a)]),
              ),
              right: MasterSection(
                title: 'Jump to',
                child: MasterGrid(
                  columns: 2,
                  minItemWidth: 150,
                  spacing: 10,
                  children: [for (final j in _jumps) _jumpTile(j)],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _diagnosticCard(d),
          ]);
        },
      );

  Widget _checkItem(Map<String, dynamic> c) {
    final ok = c['done'] == true;
    final target = _checklistTabs['${c['key']}'];
    final item = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(ok ? Icons.check_circle : Icons.cancel,
          size: 18, color: ok ? ViniiColors.greenSolid : ViniiColors.redSolid),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(textOf(c['title']),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ViniiColors.textPrimaryLight)),
          const SizedBox(height: 2),
          Text(textOf(c['detail'], ''), style: MasterStyle.muted),
        ]),
      ),
    ]);
    if (target == null) return item;
    return InkWell(
      key: Key('settings-check-${c['key']}'),
      borderRadius: BorderRadius.circular(6),
      onTap: () => widget.onOpen(target),
      child: item,
    );
  }

  Widget _components(List<Map<String, dynamic>> components) {
    final allLive = components.every((c) => c['status'] == 'live');
    return MasterSection(
      title: 'Component health',
      subtitle: allLive
          ? 'All components are live.'
          : 'Some components are idle or need setup.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final c in components)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: const BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: MasterStyle.cardBorder))),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(textOf(c['name']),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: ViniiColors.textPrimaryLight)),
                      if (textOf(c['detail'], '').isNotEmpty)
                        Text(_prettyDetail(textOf(c['detail'], '')),
                            style: MasterStyle.muted),
                    ]),
              ),
              const SizedBox(width: 8),
              StatusPill(textOf(c['status'], '')),
            ]),
          ),
      ]),
    );
  }

  Widget _jumpTile((SettingsTab, String, String, IconData) j) => Material(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: Key('settings-jump-${j.$1.name}'),
          borderRadius: BorderRadius.circular(10),
          onTap: () => widget.onOpen(j.$1),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(j.$4, size: 18, color: ViniiColors.greenSolid),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(j.$2,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: ViniiColors.textPrimaryLight)),
                ),
              ]),
              const SizedBox(height: 6),
              Text(j.$3, style: MasterStyle.muted),
            ]),
          ),
        ),
      );

  Widget _diagnosticCard(Map<String, dynamic> d) {
    final at = _diagAt;
    final alerts = jsonList(d['alerts']).length;
    return MasterCard(
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('System Diagnostic Test',
                      style: MasterStyle.sectionTitle),
                  const SizedBox(height: 4),
                  const Text(
                      'Re-runs the server checks: database round trip, '
                      'devices, printers, integrations and alerts.',
                      style: MasterStyle.muted),
                  if (_diagRunning) ...[
                    const SizedBox(height: 8),
                    const Text('Running…', style: MasterStyle.body),
                  ] else if (at != null) ...[
                    const SizedBox(height: 8),
                    Text(
                        'Database answered in '
                        '${staffNumText(numOf(d['db_latency_ms']))} ms · '
                        '$alerts open alert${alerts == 1 ? '' : 's'} · '
                        'checked ${fmtDateTime(at.toIso8601String())}',
                        key: const Key('settings-diagnostic-result'),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ViniiColors.emeraldText)),
                  ],
                ]),
          ),
          MasterButton(
              key: const Key('settings-run-diagnostic'),
              label: _diagRunning ? 'Running…' : 'Run Diagnostic',
              icon: Icons.refresh,
              kind: MasterButtonKind.primary,
              onPressed: _diagRunning ? null : _runDiagnostic),
        ],
      ),
    );
  }
}

// ── KDS & patch engine ───────────────────────────────────────────────────

class _KdsTab extends StatelessWidget {
  const _KdsTab(
      {required this.api, required this.onOpen, this.branches = const []});
  final ProviyaaApiClient api;
  final ValueChanged<SettingsTab> onOpen;
  final List<BranchLocation> branches;

  @override
  Widget build(BuildContext context) => MasterPage(children: [
        ApiLoader<Map<String, dynamic>>(
          load: () async => jsonMap(await api.get('v1/settings/kds')),
          builder: (context, d, reload) => _KdsForm(api: api, initial: d),
        ),
        const SizedBox(height: 20),
        MasterSection(
          title: 'Paired KDS Devices',
          subtitle: 'KDS screens registered in Devices.',
          trailing: MasterButton(
              key: const Key('kds-open-devices'),
              label: 'Manage devices',
              icon: Icons.open_in_new,
              onPressed: () => onOpen(SettingsTab.devices)),
          child: ApiLoader<List<Map<String, dynamic>>>(
            load: () async => jsonList(await api.get('v1/settings/devices',
                query: const {'device_type': 'kds'})),
            builder: (context, rows, reload) => rows.isEmpty
                ? const StaffEmptyState(
                    icon: Icons.desktop_windows_outlined,
                    title: 'No KDS screens paired yet.',
                    message: 'Register a KDS screen in Devices to list it '
                        'here.')
                : MasterTable(
                    minWidth: 640,
                    columns: [
                      const MasterColumn('Device', flex: 3),
                      const MasterColumn('IP', flex: 2),
                      MasterColumn(
                          hasManyBranches(branches)
                              ? 'Station / Branch'
                              : 'Station',
                          flex: 2),
                      const MasterColumn('Status', flex: 2),
                      const MasterColumn('Last seen', flex: 2),
                    ],
                    rows: [
                      for (final k in rows)
                        [
                          MasterCellTitle(textOf(k['name']),
                              subtitle: textOf(k['model'], '').isEmpty
                                  ? null
                                  : textOf(k['model'], '')),
                          MasterCellText(textOf(k['ip'])),
                          _stationCell(k, branches),
                          StatusPill(
                              k['active'] != false ? 'active' : 'inactive',
                              label: k['active'] != false
                                  ? 'Active'
                                  : 'Inactive'),
                          MasterCellText(k['last_seen_at'] == null
                              ? '—'
                              : fmtDateTime(k['last_seen_at'])),
                        ],
                    ],
                  ),
          ),
        ),
      ]);
}

class _KdsForm extends StatefulWidget {
  const _KdsForm({required this.api, required this.initial});
  final ProviyaaApiClient api;
  final Map<String, dynamic> initial;

  @override
  State<_KdsForm> createState() => _KdsFormState();
}

class _KdsFormState extends State<_KdsForm> {
  late bool _enabled = _bool(widget.initial['enabled']);
  late final _ip =
      TextEditingController(text: textOf(widget.initial['server_ip'], ''));
  late final _port = TextEditingController(
      text: '${_n(widget.initial['port']) == 0 ? 8787 : _n(widget.initial['port'])}');
  late final _subnet =
      TextEditingController(text: textOf(widget.initial['subnet'], ''));
  late final _channel =
      TextEditingController(text: textOf(widget.initial['channel'], ''));
  late bool _autoSync = _bool(widget.initial['auto_sync'], true);
  late bool _autoRoute = _bool(widget.initial['auto_route'], true);
  late bool _offline = _bool(widget.initial['offline_billing']);
  late dynamic _updatedAt = widget.initial['updated_at'];
  late bool _saved = widget.initial['saved'] == true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _ip.dispose();
    _port.dispose();
    _subnet.dispose();
    _channel.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final port = int.tryParse(_port.text.trim());
    if (port == null || port < 1024 || port > 65535) {
      setState(() => _error = 'Port must be a number from 1024 to 65535.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.put('v1/settings/kds', {
        'enabled': _enabled,
        'server_ip': _ip.text.trim(),
        'port': port,
        'subnet': _subnet.text.trim(),
        'channel': _channel.text.trim(),
        'auto_sync': _autoSync,
        'auto_route': _autoRoute,
        'offline_billing': _offline,
      });
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
        _updatedAt = DateTime.now().toIso8601String();
      });
      _say(context, 'KDS preferences saved.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) => MasterSection(
        title: 'Local Server Configuration',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ViniiColors.lightGreenTint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Activate Local KDS Patch Service',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: ViniiColors.textPrimaryLight)),
                      SizedBox(height: 2),
                      Text(
                          'Stream tickets to paired screens on this subnet '
                          'without internet, once the local agent exists.',
                          style: MasterStyle.muted),
                    ]),
              ),
              StaffSwitch(
                  key: const Key('kds-enabled'),
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v)),
            ]),
          ),
          const SizedBox(height: 16),
          MasterGrid(columns: 4, minItemWidth: 170, spacing: 14, children: [
            BizTextField(
                key: const Key('kds-ip'),
                label: 'Server IP',
                controller: _ip,
                hint: 'e.g. 192.168.1.10'),
            BizTextField(
                key: const Key('kds-port'),
                label: 'Port',
                controller: _port,
                number: true,
                decimal: false),
            BizTextField(
                key: const Key('kds-subnet'),
                label: 'Subnet',
                controller: _subnet,
                hint: 'e.g. 192.168.1.0/24'),
            BizTextField(
                key: const Key('kds-channel'),
                label: 'Broadcast Channel',
                controller: _channel,
                hint: 'kds (default)'),
          ]),
          const SizedBox(height: 6),
          const Text(
              'Broadcast Channel is the name KDS screens listen on. Leave it '
              'as "kds" unless your screens were set up with another name.',
              style: MasterStyle.muted),
          const SizedBox(height: 16),
          MasterGrid(columns: 3, minItemWidth: 220, spacing: 12, children: [
            BizToggle(
                key: const Key('kds-auto-sync'),
                label: 'Auto-sync when back online',
                value: _autoSync,
                onChanged: (v) => setState(() => _autoSync = v)),
            BizToggle(
                key: const Key('kds-auto-route'),
                label: 'Auto-route KOTs to printers',
                value: _autoRoute,
                onChanged: (v) => setState(() => _autoRoute = v)),
            BizToggle(
                key: const Key('kds-offline-billing'),
                label: 'Allow offline billing',
                value: _offline,
                onChanged: (v) => setState(() => _offline = v)),
          ]),
          const SizedBox(height: 16),
          const InfoNote(
              'The local KDS agent is not part of this release, so these are '
              'saved preferences only: nothing is broadcast on your network '
              'yet, and there is no test ticket or live feed.',
              tone: PillTone.amber),
          _SaveBar(
            buttonKey: const Key('kds-save'),
            saving: _saving,
            onSave: _save,
            error: _error,
            status: _savedStatus(_updatedAt, _saved),
          ),
        ]),
      );
}

// ── operations centre ────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.lines, this.status});
  final String title;
  final List<(String, String)> lines;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final s = status;
    return MasterCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ViniiColors.textPrimaryLight)),
          ),
          if (s != null && s.isNotEmpty) StatusPill(s),
        ]),
        const SizedBox(height: 10),
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${l.$1}: ',
                  style: const TextStyle(
                      fontSize: 12.5, color: ViniiColors.textSecondaryLight)),
              Flexible(
                child: Text(l.$2,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: ViniiColors.textPrimaryLight)),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _OperationsTab extends StatelessWidget {
  const _OperationsTab({required this.api});
  final ProviyaaApiClient api;

  static Widget _hubText(String label, String value) => Text.rich(
        TextSpan(children: [
          TextSpan(
              text: '$label: ',
              style: const TextStyle(color: Color(0xFF9CA3AF))),
          TextSpan(
              text: value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ]),
        style: const TextStyle(fontSize: 13),
      );

  @override
  Widget build(BuildContext context) => ApiLoader<Map<String, dynamic>>(
        load: () async =>
            jsonMap(await api.get('v1/settings/operations-centre')),
        builder: (context, d, reload) {
          final db = jsonMap(d['database']);
          final sync = jsonMap(d['sync']);
          final printers = jsonMap(d['printers']);
          final kitchen = jsonMap(d['kitchen']);
          final integ = jsonMap(d['integrations']);
          final hooks = jsonMap(d['webhooks']);
          final alerts = jsonList(d['alerts']);
          final incidents = jsonList(d['incidents']);
          final aggregators = jsonList(d['aggregators']);
          final latency = '${staffNumText(numOf(db['latency_ms']))} ms';
          return MasterPage(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0B0F),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 20,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: ViniiColors.sidebarSelectedTint,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Reliability Hub',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ViniiColors.brandGreen)),
                  ),
                  _hubText('Active webhooks', '${_n(hooks['active'])}'),
                  _hubText('Sync', humanize(sync['status'])),
                  _hubText('Database', latency),
                  MasterButton(
                      key: const Key('ops-refresh'),
                      label: 'Refresh',
                      icon: Icons.refresh,
                      onPressed: reload),
                ],
              ),
            ),
            const SizedBox(height: 20),
            MasterGrid(columns: 3, minItemWidth: 240, children: [
              _MetricCard(
                  title: 'Database',
                  status: textOf(db['status'], ''),
                  lines: [('Latency', latency)]),
              _MetricCard(
                title: 'Sync engine',
                status: textOf(sync['status'], ''),
                lines: [
                  (
                    'Last device sync',
                    sync['last_sync'] == null
                        ? 'None yet'
                        : fmtDateTime(sync['last_sync'])
                  ),
                  ('Changes (24 h)', '${_n(sync['changes_24h'])}'),
                  ('Rejected (24 h)', '${_n(sync['rejected_24h'])}'),
                ],
              ),
              _MetricCard(
                title: 'Printers',
                status: textOf(printers['status'], ''),
                lines: [
                  ('Total', '${_n(printers['total'])}'),
                  ('Active', '${_n(printers['active'])}'),
                ],
              ),
              _MetricCard(
                title: 'Kitchen clusters',
                lines: [
                  ('KDS screens', '${_n(kitchen['total'])}'),
                  ('Active', '${_n(kitchen['active'])}'),
                ],
              ),
              _MetricCard(
                title: 'Integration sync',
                lines: [
                  ('Connected apps', '${_n(integ['connected'])}'),
                  ('Pending requests', '${_n(integ['pending'])}'),
                  ('Queued jobs', '${_n(integ['queued_jobs'])}'),
                  ('Failed (24 h)', '${_n(integ['failed_24h'])}'),
                ],
              ),
              _MetricCard(
                title: 'Webhook queue',
                status: textOf(hooks['status'], ''),
                lines: [
                  ('Active endpoints', '${_n(hooks['active'])}'),
                  ('Failed (24 h)', '${_n(hooks['failed_24h'])}'),
                ],
              ),
            ]),
            const SizedBox(height: 20),
            MasterSection(
              title: 'Open alerts',
              trailing: MasterStatusPill('${alerts.length}',
                  tone: alerts.isEmpty ? PillTone.green : PillTone.red),
              child: alerts.isEmpty
                  ? const Text('No open alerts.', style: MasterStyle.body)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [for (final a in alerts) _AlertBox(a)]),
            ),
            const SizedBox(height: 20),
            MasterSection(
              title: 'Operational Incident Log',
              subtitle: 'The latest failed syncs, failed webhook deliveries '
                  'and rejected device changes.',
              child: incidents.isEmpty
                  ? const Text('No incidents recorded.',
                      style: MasterStyle.body)
                  : MasterTable(
                      minWidth: 720,
                      columns: const [
                        MasterColumn('Timestamp', flex: 2),
                        MasterColumn('Module / Service', flex: 2),
                        MasterColumn('Type', flex: 2),
                        MasterColumn('Incident Details', flex: 5),
                      ],
                      rows: [
                        for (final i in incidents)
                          [
                            MasterCellText(fmtDateTime(i['at'])),
                            MasterCellText(textOf(i['source']), bold: true),
                            MasterStatusPill(textOf(i['kind'], 'Incident')),
                            Text(textOf(i['detail']),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: MasterStyle.body),
                          ],
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            MasterSection(
              title: 'Third-Party Online Platforms Integration Status',
              child: aggregators.isEmpty
                  ? const MasterBanner(
                      tone: PillTone.blue,
                      message: 'No delivery platform is linked. Request Zomato '
                          'or Swiggy in Integrations → Connected apps.')
                  : MasterGrid(columns: 2, minItemWidth: 260, children: [
                      for (final a in aggregators) _aggregator(a),
                    ]),
            ),
          ]);
        },
      );

  Widget _aggregator(Map<String, dynamic> a) {
    final connected = a['is_connected'] == true;
    final accepting = a['is_accepting'] == true;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MasterStyle.cardBorder),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF97316),
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              const Icon(Icons.delivery_dining, size: 20, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(textOf(a['display_name'], humanize(a['channel'])),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ViniiColors.textPrimaryLight)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              MasterStatusPill(connected ? 'Connected' : 'Not connected',
                  tone: connected ? PillTone.green : PillTone.gray),
              if (connected)
                MasterStatusPill(accepting ? 'Accepting' : 'Paused',
                    tone: accepting ? PillTone.green : PillTone.amber),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ── subscription ─────────────────────────────────────────────────────────

class _SubscriptionTab extends StatefulWidget {
  const _SubscriptionTab({required this.api});
  final ProviyaaApiClient api;

  @override
  State<_SubscriptionTab> createState() => _SubscriptionTabState();
}

class _SubscriptionTabState extends State<_SubscriptionTab> {
  final _loader = GlobalKey<ApiLoaderState<Map<String, dynamic>>>();

  void _reload() => _loader.currentState?.reload();

  Future<void> _choose(Map<String, dynamic> p) async {
    final name = textOf(p['name']);
    final months = _n(p['months']);
    final ok = await staffConfirm(context,
        title: 'Request $name?',
        message: '${inr(p['price'], decimals: 0)} + '
            '${staffNumText(numOf(p['gst_pct']))}% GST for $months '
            'month${months == 1 ? '' : 's'}. This sends a request to the '
            'Proviyaa team, who will contact you to activate the plan. No '
            'payment is taken here.',
        confirmLabel: 'Send request',
        danger: false);
    if (!ok || !mounted) return;
    final out = await runAction(
        context,
        () => widget.api.postEnvelope(
            'v1/settings/subscription/requests', {'plan_key': '${p['key']}'}));
    if (out == null || !mounted) return;
    _say(context,
        textOf(out['message'], '$name requested. No payment was taken.'));
    _reload();
  }

  Future<void> _cancel(Map<String, dynamic> r) async {
    final ok = await staffConfirm(context,
        title: 'Cancel this request?',
        message: 'The request for ${textOf(r['plan_name'])} is withdrawn.',
        confirmLabel: 'Cancel request');
    if (!ok || !mounted) return;
    final done = await runAction<bool>(context, () async {
      await widget.api
          .post('v1/settings/subscription/requests/${r['id']}/cancel');
      return true;
    }, success: 'Request cancelled.');
    if (done == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => ApiLoader<Map<String, dynamic>>(
        key: _loader,
        load: () async => jsonMap(await widget.api.get('v1/settings/subscription')),
        builder: (context, d, reload) {
          final current = d['current'] is Map ? jsonMap(d['current']) : null;
          final plans = jsonList(d['plans']);
          final requests = jsonList(d['requests']);
          final open = [
            for (final r in requests)
              if (r['status'] == 'requested') r,
          ];
          final usage = jsonMap(d['usage']);
          return MasterPage(children: [
            Row(children: [
              const Icon(Icons.card_membership,
                  size: 20, color: ViniiColors.greenSolid),
              const SizedBox(width: 8),
              Text('Plans & Billing',
                  style: MasterStyle.sectionTitle.copyWith(fontSize: 18)),
            ]),
            const SizedBox(height: 4),
            const Text(
                'Choose a plan to send a request; the Proviyaa team activates '
                'it and invoices you. No payment is taken in the panel.',
                style: MasterStyle.muted),
            const SizedBox(height: 16),
            _currentCard(current),
            for (final r in open) ...[
              const SizedBox(height: 12),
              _openRequest(r),
            ],
            const SizedBox(height: 24),
            const Text('Available plans', style: MasterStyle.sectionTitle),
            const SizedBox(height: 12),
            if (plans.isEmpty)
              const Text('No plans are offered right now.',
                  style: MasterStyle.body)
            else
              MasterGrid(columns: 4, minItemWidth: 200, children: [
                for (final p in plans) _planCard(p, current),
              ]),
            const SizedBox(height: 24),
            MasterSection(
              title: 'Usage',
              child: MasterGrid(columns: 2, minItemWidth: 220, children: [
                MasterStatCard(
                    label: 'ACTIVE DEVICES / TERMINALS',
                    value: '${_n(usage['terminals'])}',
                    caption: 'POS terminals and KDS screens registered'),
                MasterStatCard(
                    label: 'ORDER TAKERS',
                    value: '${_n(usage['order_takers'])}',
                    caption: 'Active captain and cashier logins'),
              ]),
            ),
            const SizedBox(height: 20),
            MasterSection(
              title: 'Payment & Invoice History',
              subtitle: 'Plan requests and activations. The panel takes no '
                  'online payment.',
              child: requests.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                          child:
                              Text('No payments yet', style: MasterStyle.muted)),
                    )
                  : MasterTable(
                      minWidth: 640,
                      columns: const [
                        MasterColumn('Date', flex: 2),
                        MasterColumn('Plan', flex: 3),
                        MasterColumn('Period', flex: 3),
                        MasterColumn('Status', flex: 2),
                        MasterColumn('Amount', flex: 2, alignEnd: true),
                      ],
                      rows: [
                        for (final r in requests)
                          [
                            MasterCellText(fmtDate(r['created_at'])),
                            MasterCellTitle(textOf(r['plan_name']),
                                subtitle: _cycleLabel(_n(r['cycle_months']))),
                            MasterCellText(r['starts_on'] == null
                                ? '—'
                                : '${fmtDate(r['starts_on'])} – '
                                    '${fmtDate(r['ends_on'])}'),
                            StatusPill(textOf(r['status'], '')),
                            MasterCellText(inr(r['price']), bold: true),
                          ],
                      ],
                    ),
            ),
          ]);
        },
      );

  Widget _currentCard(Map<String, dynamic>? c) {
    const caption = TextStyle(
        fontSize: 11.5,
        letterSpacing: 0.4,
        fontWeight: FontWeight.w600,
        color: ViniiColors.textSecondaryLight);
    if (c == null) {
      return const MasterCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('CURRENT PLAN', style: caption),
          SizedBox(height: 8),
          Text('No active plan on file',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: ViniiColors.textPrimaryLight)),
          SizedBox(height: 4),
          Text(
              'Choose a plan below. The Proviyaa team activates it and tells '
              'you when it is live.',
              style: MasterStyle.muted),
        ]),
      );
    }
    final premium = '${c['plan_key'] ?? ''}'.startsWith('premium');
    final months = _n(c['cycle_months']);
    final days = c['days_remaining'];
    return MasterCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('CURRENT PLAN', style: caption),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(textOf(c['plan_name']),
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: ViniiColors.textPrimaryLight)),
            MasterStatusPill(premium ? 'PREMIUM' : 'STANDARD',
                tone: premium ? PillTone.green : PillTone.gray),
            MasterStatusPill(_cycleLabel(months), tone: PillTone.gray),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(spacing: 40, runSpacing: 12, children: [
          MasterKeyValue('Duration', '$months month${months == 1 ? '' : 's'}'),
          MasterKeyValue('Start Date', fmtDate(c['starts_on'])),
          MasterKeyValue('End Date', fmtDate(c['ends_on'])),
          MasterKeyValue(
              'Days remaining', days == null ? '—' : '${_n(days)} days'),
          MasterKeyValue('Price (before GST)', inr(c['price'])),
        ]),
      ]),
    );
  }

  Widget _openRequest(Map<String, dynamic> r) => MasterCard(
        borderColor: const Color(0xFFFCD34D),
        color: ViniiColors.amberTint,
        padding: const EdgeInsets.all(16),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const StatusPill('requested', label: 'Requested'),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(textOf(r['plan_name']),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: ViniiColors.textPrimaryLight)),
                      Text(
                          'Requested ${fmtDate(r['created_at'])} · '
                          '${inr(r['price'])} + GST · waiting for the Proviyaa '
                          'team; no payment was taken.',
                          style: MasterStyle.muted),
                    ]),
              ),
            ]),
            MasterButton(
                key: Key('plan-cancel-${r['plan_key']}'),
                label: 'Cancel request',
                kind: MasterButtonKind.dangerOutline,
                onPressed: () => _cancel(r)),
          ],
        ),
      );

  Widget _planCard(Map<String, dynamic> p, Map<String, dynamic>? current) {
    final key = '${p['key']}';
    final premium = textOf(p['tier'], '').toLowerCase() == 'premium';
    final months = _n(p['months']);
    final features = _strings(p['features']);
    final isCurrent = current != null && current['plan_key'] == key;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: premium ? ViniiColors.brandGreen : MasterStyle.cardBorder,
            width: premium ? 1.5 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 6, runSpacing: 4, children: [
          MasterStatusPill(textOf(p['tier']).toUpperCase(),
              tone: premium ? PillTone.green : PillTone.gray),
          MasterStatusPill(_cycleLabel(months), tone: PillTone.gray),
        ]),
        const SizedBox(height: 6),
        Text(textOf(p['name']), style: MasterStyle.muted),
        const SizedBox(height: 4),
        Text(inr(p['price'], decimals: 0),
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: premium
                    ? ViniiColors.emeraldText
                    : ViniiColors.textPrimaryLight)),
        Text('+ ${staffNumText(numOf(p['gst_pct']))}% GST',
            style: MasterStyle.muted),
        const Divider(height: 24, color: MasterStyle.cardBorder),
        Row(children: [
          const Expanded(
            child: Text('FEATURES INCLUDED',
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w600,
                    color: ViniiColors.textSecondaryLight)),
          ),
          Text('${features.length}',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ViniiColors.greenSolid)),
        ]),
        const SizedBox(height: 8),
        for (final f in features)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              const Icon(Icons.check, size: 14, color: ViniiColors.greenSolid),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(f,
                      style: const TextStyle(
                          fontSize: 12.5,
                          color: ViniiColors.textPrimaryLight))),
            ]),
          ),
        const SizedBox(height: 14),
        SizedBox(
          height: 36,
          child: FilledButton(
            key: Key('plan-choose-$key'),
            onPressed: isCurrent ? null : () => _choose(p),
            style: FilledButton.styleFrom(
              backgroundColor:
                  premium ? ViniiColors.brandGreen : const Color(0xFFF3F4F6),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            child: Text(isCurrent ? 'Current plan' : 'Choose plan'),
          ),
        ),
      ]),
    );
  }
}

// ── system update ────────────────────────────────────────────────────────

const _windows = <(String, String)>[
  ('00:00-02:00', '12:00 AM – 2:00 AM'),
  ('02:00-05:00', '2:00 AM – 5:00 AM (Non-peak)'),
  ('05:00-07:00', '5:00 AM – 7:00 AM'),
  ('14:00-16:00', '2:00 PM – 4:00 PM'),
];

const _streams = <(String, String)>[
  ('stable', 'Stable (Recommended)'),
  ('beta', 'Beta stream testing'),
  ('nightly', 'Nightly developer build'),
];

class _UpdatesTab extends StatefulWidget {
  const _UpdatesTab({required this.api});
  final ProviyaaApiClient api;

  @override
  State<_UpdatesTab> createState() => _UpdatesTabState();
}

class _UpdatesTabState extends State<_UpdatesTab> {
  final _version = GlobalKey<ApiLoaderState<Map<String, dynamic>>>();
  DateTime? _checkedAt;

  void _check() {
    setState(() => _checkedAt = DateTime.now());
    _version.currentState?.reload();
  }

  static Widget _tile(String label, String value, String caption) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: MasterStyle.label),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: ViniiColors.textPrimaryLight)),
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(caption, style: MasterStyle.muted),
          ],
        ]),
      );

  Widget _software() => MasterSection(
        title: 'Active System Software',
        child: ApiLoader<Map<String, dynamic>>(
          key: _version,
          load: () async => jsonMap(await widget.api.get('v1/settings/version')),
          builder: (context, v, reload) {
            final checked = _checkedAt;
            final server = textOf(v['server'], 'unknown');
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MasterGrid(
                      columns: 3,
                      minItemWidth: 150,
                      spacing: 12,
                      children: [
                        _tile('Server version',
                            server == 'unknown' ? 'Unknown' : 'v$server',
                            'Proviyaa server'),
                        _tile('Server uptime',
                            _uptime(numOf(v['uptime_seconds'])),
                            'Since the last restart'),
                        _tile('Started at', fmtDate(v['started_at']),
                            fmtDateTime(v['started_at'])),
                      ]),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      MasterButton(
                          key: const Key('updates-check'),
                          label: 'Check for updates',
                          icon: Icons.refresh,
                          kind: MasterButtonKind.primary,
                          onPressed: _check),
                      if (checked != null)
                        Text(
                            'Last checked '
                            '${fmtDateTime(checked.toIso8601String())}',
                            style: MasterStyle.muted),
                    ],
                  ),
                  if (checked != null) ...[
                    const SizedBox(height: 12),
                    const MasterBanner(
                        key: Key('updates-check-note'),
                        tone: PillTone.blue,
                        message: 'The web panel loads the latest version when '
                            'you reload the page; there is no separate update '
                            'server yet.'),
                  ],
                ]);
          },
        ),
      );

  @override
  Widget build(BuildContext context) => MasterPage(children: [
        _Split(
          leftFlex: 3,
          rightFlex: 2,
          left: _software(),
          right: ApiLoader<Map<String, dynamic>>(
            load: () async =>
                jsonMap(await widget.api.get('v1/settings/updates')),
            builder: (context, d, reload) =>
                _UpdatesForm(api: widget.api, initial: d),
          ),
        ),
      ]);
}

class _UpdatesForm extends StatefulWidget {
  const _UpdatesForm({required this.api, required this.initial});
  final ProviyaaApiClient api;
  final Map<String, dynamic> initial;

  @override
  State<_UpdatesForm> createState() => _UpdatesFormState();
}

class _UpdatesFormState extends State<_UpdatesForm> {
  late bool _autoInstall = _bool(widget.initial['auto_install']);
  late bool _backup = _bool(widget.initial['backup_before_update'], true);
  late bool _notify = _bool(widget.initial['notify'], true);
  late String _window = _pick(widget.initial['window'],
      [for (final w in _windows) w.$1], '02:00-05:00');
  late String _stream = _pick(
      widget.initial['channel'], [for (final s in _streams) s.$1], 'stable');
  late dynamic _updatedAt = widget.initial['updated_at'];
  late bool _saved = widget.initial['saved'] == true;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.put('v1/settings/updates', {
        'auto_install': _autoInstall,
        'backup_before_update': _backup,
        'notify': _notify,
        'window': _window,
        'channel': _stream,
      });
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
        _updatedAt = DateTime.now().toIso8601String();
      });
      _say(context, 'Update preferences saved.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _errorText(e, const {'channel': 'Update Stream Channel'});
      });
    }
  }

  @override
  Widget build(BuildContext context) => MasterSection(
        title: 'Automatic Update Policies',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          BizToggle(
              key: const Key('updates-auto-install'),
              label: 'Auto-install updates',
              value: _autoInstall,
              onChanged: (v) => setState(() => _autoInstall = v)),
          const SizedBox(height: 8),
          BizToggle(
              key: const Key('updates-backup'),
              label: 'Pre-update system backup',
              value: _backup,
              onChanged: (v) => setState(() => _backup = v)),
          const SizedBox(height: 8),
          BizToggle(
              key: const Key('updates-notify'),
              label: 'Push notification alerts',
              value: _notify,
              onChanged: (v) => setState(() => _notify = v)),
          const SizedBox(height: 16),
          StaffField(
            label: 'Preferred Maintenance Window',
            child: StaffSelect<String>(
              key: const Key('updates-window'),
              value: _window,
              items: _windows,
              onChanged: (v) => setState(() => _window = v ?? _window),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Update Stream Channel',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: ViniiColors.textPrimaryLight)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in _streams)
              ChoiceChip(
                key: Key('updates-channel-${s.$1}'),
                label: Text(s.$2),
                selected: _stream == s.$1,
                selectedColor: ViniiColors.successPillBg,
                onSelected: (_) => setState(() => _stream = s.$1),
              ),
          ]),
          const SizedBox(height: 16),
          const InfoNote(
              'Saved for when automatic updates arrive: there is no update '
              'server yet, so nothing installs on its own.'),
          _SaveBar(
            buttonKey: const Key('updates-save'),
            label: 'Save Preferences',
            saving: _saving,
            onSave: _save,
            error: _error,
            status: _savedStatus(_updatedAt, _saved),
          ),
        ]),
      );
}
