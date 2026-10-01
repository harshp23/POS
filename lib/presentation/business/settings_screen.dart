import 'package:flutter/material.dart';

import '../../data/api/api_client.dart';
import '../../domain/vendor_account.dart' show BranchLocation;
import '../master/master_ui.dart';
import '../staff/staff_ui.dart';
import '../vinii_theme.dart';
import 'business_ui.dart';

part 'settings_system.dart';

/// Settings (v1/settings/*.png): the restaurant's outlet profile, order
/// settings (tables, order takers), devices, printers, bill format,
/// notifications and subscription, plus the system pages (overview, KDS,
/// operations centre, updates). Everything reads and writes /v1/settings
/// (tables through /v1/operations, order takers through /v1/staff).
///
/// Nothing here pretends to reach hardware: a test print answers that no
/// print agent is installed, KDS settings are saved preferences, plans are
/// requested rather than paid, and there is no update server.

enum SettingsTab {
  outlet,
  order,
  devices,
  printers,
  billFormat,
  notifications,
  subscription,
  overview,
  kds,
  operations,
  updates,
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen(
      {super.key,
      required this.api,
      this.initialTab = SettingsTab.outlet,
      this.branches = const []});
  final ProviyaaApiClient api;
  final SettingsTab initialTab;

  /// The restaurant's branches: devices and printers are placed in one,
  /// and the bill's "Branch / Outlet" line is picked from them.
  final List<BranchLocation> branches;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _TabMeta {
  const _TabMeta({
    required this.caption,
    required this.label,
    required this.icon,
    required this.crumb,
    required this.title,
    required this.subtitle,
  });
  final String caption;
  final String label;
  final IconData icon;
  final String crumb;
  final String title;
  final String subtitle;
}

const _meta = <SettingsTab, _TabMeta>{
  SettingsTab.outlet: _TabMeta(
      caption: 'OVERVIEW',
      label: 'Outlet settings',
      icon: Icons.storefront_outlined,
      crumb: 'System',
      title: 'Outlet settings',
      subtitle: 'Configure restaurant profile, address, business category, '
          'and description details.'),
  SettingsTab.order: _TabMeta(
      caption: 'RELIABILITY',
      label: 'Order settings',
      icon: Icons.playlist_add_check,
      crumb: 'System',
      title: 'Order settings',
      subtitle:
          'Dine-in tables and order-taking staff used by Captain Order and POS.'),
  SettingsTab.devices: _TabMeta(
      caption: 'HARDWARE',
      label: 'Devices',
      icon: Icons.devices_outlined,
      crumb: 'Hardware',
      title: 'Devices Configuration',
      subtitle: 'Register and map local peripherals, terminal hardware, '
          'scanners and cash drawers.'),
  SettingsTab.printers: _TabMeta(
      caption: 'HARDWARE',
      label: 'Printer Setup',
      icon: Icons.print_outlined,
      crumb: 'Hardware',
      title: 'Printers Setup',
      subtitle: 'The receipt and KOT printers at your counters and kitchen.'),
  SettingsTab.billFormat: _TabMeta(
      caption: 'BILLING',
      label: 'Bill Format',
      icon: Icons.receipt_long_outlined,
      crumb: 'System',
      title: 'Bill Settings',
      subtitle: 'Customize the bill header, footer and print options the POS '
          'uses.'),
  SettingsTab.notifications: _TabMeta(
      caption: 'ALERTS',
      label: 'Notifications',
      icon: Icons.notifications_none,
      crumb: 'System',
      title: 'Notification Settings',
      subtitle: 'Choose which alerts you get and how they reach you.'),
  SettingsTab.subscription: _TabMeta(
      caption: 'BILLING',
      label: 'Subscription',
      icon: Icons.card_membership,
      crumb: 'System',
      title: 'Subscription & Billing',
      subtitle: 'Your current plan, usage, and plan requests.'),
  SettingsTab.overview: _TabMeta(
      caption: 'OVERVIEW',
      label: 'System Overview',
      icon: Icons.show_chart,
      crumb: 'System',
      title: 'Overview',
      subtitle: 'Live platform status, configuration checklist and open '
          'alerts.'),
  SettingsTab.kds: _TabMeta(
      caption: 'RELIABILITY',
      label: 'KDS & Patch Engine',
      icon: Icons.desktop_windows_outlined,
      crumb: 'System',
      title: 'KDS & Patch Engine',
      subtitle: 'Kitchen display preferences and the KDS screens you have '
          'registered.'),
  SettingsTab.operations: _TabMeta(
      caption: 'RELIABILITY',
      label: 'Operations Centre',
      icon: Icons.dashboard_outlined,
      crumb: 'System',
      title: 'Operations Centre',
      subtitle: 'Reliability monitoring, incident log and third-party sync '
          'status.'),
  SettingsTab.updates: _TabMeta(
      caption: 'ENGINE',
      label: 'System Update',
      icon: Icons.system_update_alt,
      crumb: 'System',
      title: 'Updates',
      subtitle: 'The server version you are running and your update '
          'preferences.'),
};

const _restaurantTabs = [
  SettingsTab.outlet,
  SettingsTab.order,
  SettingsTab.devices,
  SettingsTab.printers,
  SettingsTab.billFormat,
  SettingsTab.notifications,
  SettingsTab.subscription,
];

const _systemTabs = [
  SettingsTab.overview,
  SettingsTab.kds,
  SettingsTab.operations,
  SettingsTab.subscription,
  SettingsTab.updates,
];

class _SettingsScreenState extends State<SettingsScreen> {
  late SettingsTab _tab = widget.initialTab;

  /// Which row of tab cards shows. Subscription sits in both groups, so it
  /// keeps whichever group is showing.
  late bool _system = _systemTabs.contains(widget.initialTab);

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _tab = widget.initialTab;
      if (_tab != SettingsTab.subscription) {
        _system = _systemTabs.contains(_tab);
      }
    }
  }

  void _select(SettingsTab tab) => setState(() {
        _tab = tab;
        if (tab != SettingsTab.subscription) {
          _system = _systemTabs.contains(tab);
        }
      });

  void _showGroup(bool system) {
    if (system == _system) return;
    setState(() {
      _system = system;
      _tab = system ? SettingsTab.overview : SettingsTab.outlet;
    });
  }

  String _label(SettingsTab t) => t == SettingsTab.subscription && _system
      ? 'Subscription Details'
      : _meta[t]!.label;

  Widget _body() {
    final api = widget.api;
    final branches = widget.branches;
    return switch (_tab) {
      SettingsTab.outlet => _OutletTab(api: api),
      SettingsTab.order => _OrderTab(api: api),
      SettingsTab.devices => _DevicesTab(api: api, branches: branches),
      SettingsTab.printers => _PrintersTab(api: api, branches: branches),
      SettingsTab.billFormat => _BillTab(api: api, branches: branches),
      SettingsTab.notifications => _NotificationsTab(api: api),
      SettingsTab.subscription => _SubscriptionTab(api: api),
      SettingsTab.overview => _SystemOverviewTab(api: api, onOpen: _select),
      SettingsTab.kds =>
        _KdsTab(api: api, onOpen: _select, branches: branches),
      SettingsTab.operations => _OperationsTab(api: api),
      SettingsTab.updates => _UpdatesTab(api: api),
    };
  }

  Widget _header() {
    final m = _meta[_tab]!;
    const crumb =
        TextStyle(fontSize: 12.5, color: ViniiColors.textSecondaryLight);
    const chevron = Icon(Icons.chevron_right,
        size: 14, color: ViniiColors.textMutedLight);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Settings', style: crumb),
              chevron,
              Text(m.crumb, style: crumb),
              chevron,
              Text(_label(_tab),
                  style: crumb.copyWith(
                      fontWeight: FontWeight.w600,
                      color: ViniiColors.textPrimaryLight)),
            ],
          ),
        ),
        StaffPills(
          options: const ['Restaurant', 'System'],
          selected: _system ? 1 : 0,
          keyPrefix: 'settings-group',
          onSelect: (i) => _showGroup(i == 1),
        ),
      ]),
      const SizedBox(height: 8),
      Text('System · ${m.title}', style: MasterStyle.title),
      const SizedBox(height: 4),
      Text(m.subtitle, style: MasterStyle.subtitle),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 12, children: [
        for (final t in _system ? _systemTabs : _restaurantTabs) _tabCard(t),
      ]),
    ]);
  }

  Widget _tabCard(SettingsTab t) {
    final m = _meta[t]!;
    final selected = t == _tab;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: Key('settings-tab-${t.name}'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => _select(t),
        child: Container(
          width: 158,
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color:
                    selected ? ViniiColors.brandGreen : MasterStyle.cardBorder,
                width: selected ? 1.5 : 1),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(m.caption,
                    style: const TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w600,
                        color: ViniiColors.textSecondaryLight)),
                const SizedBox(height: 4),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(m.icon,
                      size: 16,
                      color: selected
                          ? ViniiColors.greenSolid
                          : ViniiColors.textPrimaryLight),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_label(t),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ViniiColors.textPrimaryLight)),
                  ),
                ]),
              ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: ViniiColors.lightPageBg,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(32, 20, 32, 16),
            decoration: const BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: MasterStyle.cardBorder))),
            child: _header(),
          ),
          Expanded(child: KeyedSubtree(key: ValueKey(_tab), child: _body())),
        ]),
      );
}

// ── helpers (shared with settings_system.dart) ───────────────────────────

int _n(dynamic v) => numOf(v).toInt();

bool _bool(dynamic v, [bool fallback = false]) => v is bool ? v : fallback;

List<String> _strings(dynamic v) =>
    v is List ? [for (final e in v) '$e'] : const <String>[];

String _pick(dynamic v, List<String> allowed, String fallback) =>
    allowed.contains(v) ? '$v' : fallback;

int _inRange(int v, int min, int max, int fallback) =>
    v < min || v > max ? fallback : v;

/// Form labels of the fields the settings server may reject.
const _fieldLabels = <String, String>{
  'name': 'Name',
  'phone': 'Phone',
  'cuisine': 'Cuisine Type',
  'email': 'Email',
  'address': 'Address',
  'business_category': 'Business Category',
  'description': 'Description',
  'logo_url': 'Logo image URL',
  'store_name': 'Store Name on Bill',
  'branch_label': 'Branch / Outlet',
  'gstin': 'GSTIN',
  'fssai': 'FSSAI Licence',
  'bill_prefix': 'Bill Prefix',
  'paper_size': 'Paper Size',
  'footer': 'Footer',
  'server_ip': 'Server IP',
  'port': 'Port',
  'subnet': 'Subnet',
  'channel': 'Broadcast Channel',
  'recipients': 'Recipients',
  'device_type': 'Type',
  'station': 'Station',
  'ip': 'IP address',
  'mac': 'MAC address',
  'connection': 'Connection',
  'firmware': 'Firmware',
  'model': 'Model',
  'printer_type': 'Type',
  'paper_mm': 'Paper width',
  'density': 'Density',
  'copies': 'Copies',
  'auto_cut': 'Auto cut',
  'active': 'Active',
  'location_id': 'Branch',
  'window': 'Preferred Maintenance Window',
  'label': 'Table name / number',
  'seats': 'Seats',
  'area_id': 'Area',
};

/// The server's message, with each invalid field named as on the form
/// ([labels] overrides a label for one form).
String _errorText(Object e, [Map<String, String> labels = const {}]) =>
    fieldErrorText(e, {..._fieldLabels, ...labels});

/// The station of a counter device or printer, next to the kitchen stations.
const _counterStation = 'Counter / Billing';

/// Kitchen station names (Operations → kitchen stations); empty when they
/// cannot be read.
Future<List<String>> _stationNames(ProviyaaApiClient api) async {
  try {
    final rows = jsonList(await api
        .get('v1/operations/kitchen-stations', query: const {'limit': '500'}));
    return distinctText([for (final r in rows) r['name']]);
  } catch (_) {
    return const [];
  }
}

/// Station choices: none, the counter, the kitchen stations, and [current]
/// when it is something else (an older free-text value).
List<(String, String)> _stationItems(List<String> stations, String current) {
  final items = <(String, String)>[
    ('', 'No station'),
    (_counterStation, _counterStation),
    for (final s in stations)
      if (s != _counterStation) (s, s),
  ];
  if (current.isNotEmpty && !items.any((i) => i.$1 == current)) {
    items.add((current, current));
  }
  return items;
}

/// A record's branch id ('' → null).
String? _locationOf(Map<String, dynamic> row) {
  final s = textOf(row['location_id'], '');
  return s.isEmpty ? null : s;
}

/// "Tandoor" with the branch under it when the restaurant has branches.
Widget _stationCell(Map<String, dynamic> row, List<BranchLocation> branches) {
  final station = textOf(row['station'], '');
  return MasterCellTitle(station.isEmpty ? 'No station' : station,
      subtitle: hasManyBranches(branches)
          ? branchLabel(branches, row['location_id'])
          : null);
}

/// A snackbar that stays long enough to read a server message.
void _say(BuildContext context, String message, {bool error = false}) {
  final m = ScaffoldMessenger.maybeOf(context);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(SnackBar(
    content: Text(message),
    behavior: SnackBarBehavior.floating,
    width: 540,
    backgroundColor: error ? ViniiColors.redSolid : null,
    duration: const Duration(seconds: 7),
  ));
}

const _connections = <(String, String)>[
  ('lan', 'LAN'),
  ('wifi', 'Wi-Fi'),
  ('usb', 'USB'),
  ('bluetooth', 'Bluetooth'),
];

String _connLabel(dynamic v) {
  for (final c in _connections) {
    if (c.$1 == v) return c.$2;
  }
  return humanize(v);
}

/// Two cards side by side, stacked on narrow windows.
class _Split extends StatelessWidget {
  const _Split(
      {required this.left,
      required this.right,
      this.leftFlex = 1,
      this.rightFlex = 1});
  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 860) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [left, const SizedBox(height: 20), right]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: leftFlex, child: left),
          const SizedBox(width: 20),
          Expanded(flex: rightFlex, child: right),
        ]);
      });
}

/// Save button, the server's error and when the section was last saved.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.buttonKey,
    required this.saving,
    required this.onSave,
    required this.status,
    this.error,
    this.label = 'Save',
  });
  final Key buttonKey;
  final bool saving;
  final VoidCallback onSave;
  final String status;
  final String? error;
  final String label;

  @override
  Widget build(BuildContext context) {
    final err = error;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (err != null) ...[
        MasterBanner(tone: PillTone.red, message: err),
        const SizedBox(height: 14),
      ],
      Wrap(
        spacing: 14,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          MasterButton(
              key: buttonKey,
              label: saving ? 'Saving…' : label,
              icon: Icons.save_outlined,
              kind: MasterButtonKind.primary,
              onPressed: saving ? null : onSave),
          Text(status, style: MasterStyle.muted),
        ],
      ),
    ]);
  }
}

String _savedStatus(dynamic updatedAt, bool saved) {
  if (updatedAt != null && fmtDateTime(updatedAt) != '—') {
    return 'Last saved ${fmtDateTime(updatedAt)}';
  }
  return saved ? 'Saved' : 'Not saved yet — these are the defaults.';
}

// ── outlet settings ──────────────────────────────────────────────────────

/// Cuisines offered as chips in Outlet settings (plus any already saved).
const _cuisineChoices = [
  'North Indian',
  'South Indian',
  'Chinese',
  'Continental',
  'Italian',
  'Mughlai',
  'Fast Food',
  'Cafe',
  'Beverages',
  'Desserts',
  'Bakery',
  'Street Food',
  'Biryani',
  'Seafood',
];

const _businessCategories = [
  'Fine Dining',
  'Casual Dining',
  'QSR / Cafe',
  'Cloud Kitchen',
  'Bar & Lounge',
  'Bakery / Desserts',
  'Other',
];

class _OutletTab extends StatelessWidget {
  const _OutletTab({required this.api});
  final ProviyaaApiClient api;

  @override
  Widget build(BuildContext context) => ApiLoader<Map<String, dynamic>>(
        load: () async => jsonMap(await api.get('v1/settings/outlet')),
        builder: (context, d, reload) => _OutletForm(api: api, initial: d),
      );
}

class _OutletForm extends StatefulWidget {
  const _OutletForm({required this.api, required this.initial});
  final ProviyaaApiClient api;
  final Map<String, dynamic> initial;

  @override
  State<_OutletForm> createState() => _OutletFormState();
}

class _OutletFormState extends State<_OutletForm> {
  late final _logo = _ctl('logo_url');
  late final _name = _ctl('name');
  late final _phone = _ctl('phone');
  late final _email = _ctl('email');

  late final List<String> _cuisineOptions = distinctText([
    ..._cuisineChoices,
    ...textOf(widget.initial['cuisine'], '').split(','),
  ]);

  /// Picked cuisines (spelled as in [_cuisineOptions]), saved as
  /// "Cafe, Continental".
  late Set<String> _cuisines = {
    for (final saved in textOf(widget.initial['cuisine'], '').split(','))
      for (final o in _cuisineOptions)
        if (saved.trim().isNotEmpty &&
            o.toLowerCase() == saved.trim().toLowerCase())
          o
  };
  late final _address = _ctl('address');
  late final _description = _ctl('description');
  late String _category = _pick(
      widget.initial['business_category'], _businessCategories, 'Casual Dining');
  late dynamic _updatedAt = widget.initial['updated_at'];
  bool _saving = false;
  String? _error;

  TextEditingController _ctl(String key) =>
      TextEditingController(text: textOf(widget.initial[key], ''));

  @override
  void dispose() {
    for (final c in [_logo, _name, _phone, _email, _address, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final out = jsonMap(await widget.api.put('v1/settings/outlet', {
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'cuisine': [
          for (final c in _cuisineOptions)
            if (_cuisines.contains(c)) c
        ].join(', '),
        'email': _email.text.trim(),
        'address': _address.text.trim(),
        'business_category': _category,
        'description': _description.text.trim(),
        'logo_url': _logo.text.trim(),
      }));
      if (!mounted) return;
      setState(() {
        _saving = false;
        _updatedAt = out['updated_at'];
      });
      _say(context, 'Outlet settings saved.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _errorText(e, const {'name': 'Restaurant Name'});
      });
    }
  }

  Future<void> _addCuisine() async {
    final v = await showStaffPrompt(
      context,
      title: 'Add a cuisine',
      fields: const [
        StaffPromptField('name', 'Cuisine',
            key: Key('outlet-cuisine-other'), hint: 'e.g. Thai'),
      ],
      confirmLabel: 'Add',
      validate: (v) =>
          (v['name'] ?? '').trim().isEmpty ? 'Enter the cuisine.' : null,
    );
    final name = (v?['name'] ?? '').trim();
    if (name.isEmpty || !mounted) return;
    setState(() {
      final known = _cuisineOptions
          .where((c) => c.toLowerCase() == name.toLowerCase())
          .firstOrNull;
      if (known == null) _cuisineOptions.add(name);
      _cuisines = {..._cuisines, known ?? name};
    });
  }

  @override
  Widget build(BuildContext context) {
    final logo = _logo.text.trim();
    return MasterPage(children: [
      Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: MasterCard(
            padding: const EdgeInsets.all(28),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Restaurant Logo', style: MasterStyle.sectionTitle),
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 80,
                      height: 80,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: MasterStyle.cardBorder),
                      ),
                      child: logo.isEmpty
                          ? const Icon(Icons.restaurant_outlined,
                              color: ViniiColors.textMutedLight)
                          : Image.network(logo,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.broken_image_outlined,
                                  color: ViniiColors.textMutedLight)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            BizTextField(
                                key: const Key('outlet-logo'),
                                label: 'Logo image URL',
                                controller: _logo,
                                hint: 'https://…/logo.png',
                                onChanged: (_) => setState(() {})),
                            const SizedBox(height: 6),
                            const Text(
                                'Paste an image URL (JPG or PNG; square works '
                                'best). Uploading a file is not available here.',
                                style: MasterStyle.muted),
                          ]),
                    ),
                  ]),
                  const SizedBox(height: 22),
                  StaffFormRow(children: [
                    BizTextField(
                        key: const Key('outlet-name'),
                        label: 'Restaurant Name',
                        required: true,
                        controller: _name),
                    BizTextField(
                        key: const Key('outlet-phone'),
                        label: 'Phone',
                        required: true,
                        controller: _phone),
                  ]),
                  StaffFormRow(children: [
                    BizTextField(
                        key: const Key('outlet-email'),
                        label: 'Email',
                        required: true,
                        controller: _email),
                    const SizedBox.shrink(),
                  ]),
                  StaffField(
                    label: 'Cuisine Type',
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        BizChipSelect(
                          key: const Key('outlet-cuisine'),
                          keyPrefix: 'outlet-cuisine',
                          options: [for (final c in _cuisineOptions) (c, c)],
                          selected: _cuisines,
                          onChanged: (v) => setState(() => _cuisines = v),
                        ),
                        ActionChip(
                          key: const Key('outlet-cuisine-add'),
                          label: const Text('+ Other'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: kStaffBorder),
                          labelStyle: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: ViniiColors.blueSolid),
                          onPressed: _addCuisine,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  BizTextField(
                      key: const Key('outlet-address'),
                      label: 'Address',
                      required: true,
                      controller: _address),
                  const SizedBox(height: 14),
                  StaffField(
                    label: 'Business Category',
                    required: true,
                    child: StaffSelect<String>(
                      key: const Key('outlet-category'),
                      value: _category,
                      items: [for (final c in _businessCategories) (c, c)],
                      onChanged: (v) =>
                          setState(() => _category = v ?? _category),
                    ),
                  ),
                  const SizedBox(height: 14),
                  BizTextField(
                      key: const Key('outlet-description'),
                      label: 'Description',
                      controller: _description,
                      maxLines: 4),
                  const SizedBox(height: 20),
                  _SaveBar(
                    buttonKey: const Key('outlet-save'),
                    label: 'Save Changes',
                    saving: _saving,
                    onSave: _save,
                    error: _error,
                    status: _updatedAt == null
                        ? 'Not saved yet — these values come from your account.'
                        : 'Last saved ${fmtDateTime(_updatedAt)}',
                  ),
                ]),
          ),
        ),
      ),
    ]);
  }
}

// ── order settings ───────────────────────────────────────────────────────

typedef _TablesData = ({
  List<Map<String, dynamic>> tables,
  Map<String, String> areas
});

class _OrderTab extends StatefulWidget {
  const _OrderTab({required this.api});
  final ProviyaaApiClient api;

  @override
  State<_OrderTab> createState() => _OrderTabState();
}

class _OrderTabState extends State<_OrderTab> {
  final _tables = GlobalKey<ApiLoaderState<_TablesData>>();
  int _sub = 0;

  void _reload() => _tables.currentState?.reload();

  Future<_TablesData> _loadTables() async {
    final tables = jsonList(await widget.api
        .get('v1/operations/dining-tables', query: const {'limit': '500'}));
    var areas = <String, String>{};
    try {
      areas = {
        for (final a in jsonList(await widget.api
            .get('v1/operations/dining-areas', query: const {'limit': '500'})))
          '${a['id']}': textOf(a['name'], ''),
      };
    } catch (_) {
      // Area names are a nicety; the tables still show without them.
    }
    return (tables: tables, areas: areas);
  }

  Future<void> _tableDialog(Map<String, dynamic>? t) async {
    final body = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _TableDialog(api: widget.api, existing: t));
    if (body == null || !mounted) return;
    final done = await runAction<bool>(context, () async {
      if (t == null) {
        await widget.api.post('v1/operations/dining-tables', body);
      } else {
        await widget.api.patch('v1/operations/dining-tables/${t['id']}', body);
      }
      return true;
    }, success: t == null ? 'Table added.' : 'Table updated.');
    if (done == true && mounted) _reload();
  }

  Future<void> _patchTable(
      String id, Map<String, dynamic> patch, String success) async {
    final done = await runAction<bool>(context, () async {
      await widget.api.patch('v1/operations/dining-tables/$id', patch);
      return true;
    }, success: success);
    if (done == true && mounted) _reload();
  }

  Future<void> _deleteTable(String id, String label) async {
    final ok = await staffConfirm(context,
        title: 'Delete $label?',
        message: 'The table is removed from order taking. Past orders keep '
            'their table name.');
    if (!ok || !mounted) return;
    final done = await runAction<bool>(context, () async {
      await widget.api.delete('v1/operations/dining-tables/$id');
      return true;
    }, success: '$label deleted.');
    if (done == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => MasterPage(children: [
        StaffPills(
          options: const ['Tables', 'Order Takers'],
          selected: _sub,
          keyPrefix: 'order-tab',
          onSelect: (i) => setState(() => _sub = i),
        ),
        const SizedBox(height: 16),
        if (_sub == 0) _tablesSection() else _orderTakers(),
      ]);

  Widget _tablesSection() => MasterSection(
        title: 'Restaurant Tables',
        subtitle: 'Dine-in tables used by Captain Order and the POS.',
        trailing: MasterButton(
            key: const Key('table-add'),
            label: 'Add Table',
            icon: Icons.add,
            kind: MasterButtonKind.primary,
            onPressed: () => _tableDialog(null)),
        child: ApiLoader<_TablesData>(
          key: _tables,
          load: _loadTables,
          builder: (context, d, reload) => d.tables.isEmpty
              ? const StaffEmptyState(
                  icon: Icons.event_seat_outlined,
                  title: 'No tables yet',
                  message: 'Add your dine-in tables so captains can take '
                      'orders against them.')
              : MasterGrid(columns: 4, minItemWidth: 230, children: [
                  for (final t in d.tables) _tableCard(t, d.areas),
                ]),
        ),
      );

  Widget _tableCard(Map<String, dynamic> t, Map<String, String> areas) {
    final id = '${t['id']}';
    final label = textOf(t['label'], 'Table');
    final active = t['is_active'] != false;
    final area = areas['${t['area_id']}'] ?? '';
    final occupancy = t['status'];
    return MasterCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: ViniiColors.textPrimaryLight)),
              const SizedBox(height: 2),
              Text('Seats: ${_n(t['seats'])}${area.isEmpty ? '' : ' · $area'}',
                  style: MasterStyle.muted),
            ]),
          ),
          if (occupancy is String && occupancy.isNotEmpty)
            StatusPill(occupancy),
        ]),
        const Divider(height: 24, color: MasterStyle.cardBorder),
        Row(children: [
          StaffSwitch(
            key: Key('table-active-$label'),
            value: active,
            onChanged: (v) => _patchTable(id, {'is_active': v},
                v ? '$label is active.' : '$label is inactive.'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(active ? 'Active' : 'Inactive',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active
                        ? ViniiColors.textPrimaryLight
                        : ViniiColors.textMutedLight)),
          ),
          StaffIconAction(
              key: Key('table-edit-$label'),
              icon: Icons.edit_outlined,
              tooltip: 'Edit',
              onPressed: () => _tableDialog(t)),
          StaffIconAction(
              key: Key('table-delete-$label'),
              icon: Icons.delete_outline,
              tooltip: 'Delete',
              color: ViniiColors.redSolid,
              onPressed: () => _deleteTable(id, label)),
        ]),
      ]),
    );
  }

  Widget _orderTakers() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const InfoNote('Order takers are staff logins with the Captain role. '
            'Add order takers in Staff & Users → Staff.'),
        ApiLoader<List<Map<String, dynamic>>>(
          load: () async => [
            for (final l in jsonList(await widget.api.get('v1/staff/logins')))
              if (l['pos_role'] == 'captain') l,
          ],
          builder: (context, rows, reload) => rows.isEmpty
              ? const MasterCard(
                  child: StaffEmptyState(
                    icon: Icons.person_add_outlined,
                    title: 'No order takers yet',
                    message: 'Add a staff login with the Captain role in '
                        'Staff & Users → Staff.',
                  ),
                )
              : MasterTable(
                  minWidth: 760,
                  columns: const [
                    MasterColumn('Name', flex: 2),
                    MasterColumn('Email', flex: 3),
                    MasterColumn('Phone', flex: 2),
                    MasterColumn('Role', flex: 2),
                    MasterColumn('Status'),
                    MasterColumn('Last login', flex: 2),
                  ],
                  rows: [
                    for (final l in rows)
                      [
                        MasterCellTitle(
                            textOf(l['full_name'], textOf(l['email']))),
                        MasterCellText(textOf(l['email'])),
                        MasterCellText(textOf(l['phone_number'])),
                        MasterCellText(textOf(l['role_name'],
                            textOf(l['pos_role_name'], 'Captain'))),
                        StatusPill(textOf(l['status'], 'Active').toLowerCase(),
                            label: textOf(l['status'], 'Active')),
                        MasterCellText(l['last_login_at'] == null
                            ? 'Never'
                            : fmtDateTime(l['last_login_at'])),
                      ],
                  ],
                ),
        ),
      ]);
}

/// "Add table" / "Edit T1": name, seats and dining area. Returns the body
/// to save, or null when cancelled.
class _TableDialog extends StatefulWidget {
  const _TableDialog({required this.api, this.existing});
  final ProviyaaApiClient api;
  final Map<String, dynamic>? existing;

  @override
  State<_TableDialog> createState() => _TableDialogState();
}

class _TableDialogState extends State<_TableDialog> {
  Map<String, dynamic> get _e => widget.existing ?? const <String, dynamic>{};

  late final _label = TextEditingController(text: textOf(_e['label'], ''));
  late final _seats = TextEditingController(
      text: widget.existing == null ? '4' : '${_n(_e['seats'])}');
  late String _area = textOf(_e['area_id'], '');

  /// Dining areas (id, name); null while loading.
  List<(String, String)>? _areas;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  @override
  void dispose() {
    _label.dispose();
    _seats.dispose();
    super.dispose();
  }

  Future<void> _loadAreas() async {
    try {
      final rows = jsonList(await widget.api
          .get('v1/operations/dining-areas', query: const {'limit': '500'}));
      if (!mounted) return;
      setState(() => _areas = [
            for (final a in rows)
              if (textOf(a['name'], '').isNotEmpty)
                ('${a['id']}', textOf(a['name'], '')),
          ]);
    } catch (_) {
      if (mounted) setState(() => _areas = const []);
    }
  }

  void _save() {
    final label = _label.text.trim();
    final seats = int.tryParse(_seats.text.trim());
    if (label.isEmpty) {
      setState(() => _error = 'Enter the table name.');
      return;
    }
    if (seats == null || seats < 1 || seats > 99) {
      setState(() => _error = 'Seats must be a whole number from 1 to 99.');
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'label': label,
      'seats': seats,
      if (_areas != null) 'area_id': _area.isEmpty ? null : _area,
    });
  }

  @override
  Widget build(BuildContext context) {
    final areas = _areas;
    final known = areas == null || areas.any((a) => a.$1 == _area);
    return StaffDialog(
      title: widget.existing == null
          ? 'Add table'
          : 'Edit ${textOf(_e['label'], 'table')}',
      width: 480,
      error: _error,
      actions: [
        MasterButton(label: 'Cancel', onPressed: () => Navigator.pop(context)),
        MasterButton(
            key: const Key('table-save'),
            label: widget.existing == null ? 'Add table' : 'Save',
            kind: MasterButtonKind.primary,
            onPressed: _save),
      ],
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        StaffFormRow(children: [
          BizTextField(
              key: const Key('table-label'),
              label: 'Table name / number',
              controller: _label,
              hint: 'e.g. T1 or Sofa 2'),
          BizTextField(
              key: const Key('table-seats'),
              label: 'Seats',
              controller: _seats,
              number: true,
              decimal: false),
        ]),
        StaffField(
          label: 'Area',
          child: StaffSelect<String>(
            key: const Key('table-area'),
            value: areas == null ? null : _area,
            hint: 'Loading areas…',
            items: [
              ('', areas != null && areas.isEmpty ? 'No areas yet' : 'No area'),
              ...?areas,
              if (!known && _area.isNotEmpty) (_area, 'Another area'),
            ],
            onChanged:
                areas == null ? null : (v) => setState(() => _area = v ?? ''),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
            'Areas (for example Indoor, Terrace) group tables for captains.',
            style: MasterStyle.muted),
      ]),
    );
  }
}

// ── devices ──────────────────────────────────────────────────────────────

class _DeviceType {
  const _DeviceType(this.key, this.title, this.caption, this.icon, this.noun);
  final String key;
  final String title;
  final String caption;
  final IconData icon;

  /// Singular, as in "No KDS screens registered yet".
  final String noun;
}

const _deviceTypes = [
  _DeviceType('kds', 'KDS Screens', 'Kitchen display screens by station',
      Icons.desktop_windows_outlined, 'KDS screen'),
  _DeviceType('pos_terminal', 'POS Terminals',
      'Billing counters and order-taking devices', Icons.point_of_sale,
      'POS terminal'),
  _DeviceType('receipt_printer', 'Receipt Printers',
      'Customer bills & receipts printing', Icons.print_outlined,
      'receipt printer'),
  _DeviceType('kot_printer', 'KOT Printers',
      'Kitchen order tickets by preparation station', Icons.receipt_outlined,
      'KOT printer'),
  _DeviceType('cash_drawer', 'Cash Drawers',
      'Drawers triggered via billing printer', Icons.lock_outline,
      'cash drawer'),
  _DeviceType('scanner', 'Scanners', 'Barcode and QR scanners',
      Icons.qr_code_scanner, 'scanner'),
];

class _DevicesTab extends StatefulWidget {
  const _DevicesTab({required this.api, this.branches = const []});
  final ProviyaaApiClient api;
  final List<BranchLocation> branches;

  @override
  State<_DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<_DevicesTab> {
  final _loader = GlobalKey<ApiLoaderState<List<Map<String, dynamic>>>>();

  void _reload() => _loader.currentState?.reload();

  Future<void> _edit(Map<String, dynamic>? existing, String? type) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => _DeviceDialog(
            api: widget.api,
            existing: existing,
            presetType: type,
            branches: widget.branches));
    if (ok != true || !mounted) return;
    _say(context, existing == null ? 'Device registered.' : 'Device updated.');
    _reload();
  }

  Future<void> _patch(
      String id, Map<String, dynamic> body, String success) async {
    final done = await runAction<bool>(context, () async {
      await widget.api.patch('v1/settings/devices/$id', body);
      return true;
    }, success: success);
    if (done == true && mounted) _reload();
  }

  Future<void> _delete(String id, String name) async {
    final ok = await staffConfirm(context,
        title: 'Remove $name?',
        message: 'The device is removed from this list.');
    if (!ok || !mounted) return;
    final done = await runAction<bool>(context, () async {
      await widget.api.delete('v1/settings/devices/$id');
      return true;
    }, success: '$name removed.');
    if (done == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) =>
      ApiLoader<List<Map<String, dynamic>>>(
        key: _loader,
        load: () async => jsonList(await widget.api
            .get('v1/settings/devices', query: const {'limit': '500'})),
        builder: (context, devices, reload) => MasterPage(children: [
          Row(children: [
            Expanded(
              child: Text(
                  '${devices.length} registered '
                  'device${devices.length == 1 ? '' : 's'}',
                  style: MasterStyle.sectionTitle),
            ),
            MasterButton(
                key: const Key('device-add'),
                label: 'Register device',
                icon: Icons.add,
                kind: MasterButtonKind.primary,
                onPressed: () => _edit(null, null)),
          ]),
          const SizedBox(height: 14),
          const InfoNote('Devices are registered by hand. Status and details '
              'are what you enter here — the panel does not ping your '
              'hardware.'),
          for (final type in _deviceTypes) ...[
            _section(type, [
              for (final d in devices)
                if (d['device_type'] == type.key) d,
            ]),
            const SizedBox(height: 16),
          ],
        ]),
      );

  Widget _section(_DeviceType type, List<Map<String, dynamic>> rows) =>
      MasterCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(type.icon, size: 20, color: ViniiColors.textPrimaryLight),
            const SizedBox(width: 10),
            Text(type.title, style: MasterStyle.sectionTitle),
            const SizedBox(width: 10),
            Expanded(
              child: Text(type.caption,
                  overflow: TextOverflow.ellipsis, style: MasterStyle.muted),
            ),
            TextButton.icon(
              key: Key('device-add-${type.key}'),
              onPressed: () => _edit(null, type.key),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
            ),
          ]),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            Text('No ${type.noun}s registered yet.',
                style: const TextStyle(
                    fontSize: 13, color: ViniiColors.textMutedLight))
          else
            MasterTable(
              minWidth: 900,
              columns: [
                const MasterColumn('Device', flex: 3),
                MasterColumn(
                    hasManyBranches(widget.branches)
                        ? 'Station / Branch'
                        : 'Station',
                    flex: 2),
                const MasterColumn('IP', flex: 2),
                const MasterColumn('MAC', flex: 2),
                const MasterColumn('Connection', flex: 2),
                const MasterColumn('Firmware'),
                const MasterColumn('Status', flex: 2),
                const MasterColumn('Last seen', flex: 2),
                const MasterColumn('Active', flex: 2),
                const MasterColumn('Actions', flex: 2),
              ],
              rows: [for (final d in rows) _row(d)],
            ),
        ]),
      );

  List<Widget> _row(Map<String, dynamic> d) {
    final id = '${d['id']}';
    final name = textOf(d['name'], 'Device');
    final active = d['active'] != false;
    final model = textOf(d['model'], '');
    return [
      MasterCellTitle(name, subtitle: model.isEmpty ? null : model),
      _stationCell(d, widget.branches),
      MasterCellText(textOf(d['ip'])),
      MasterCellText(textOf(d['mac'])),
      MasterCellText(_connLabel(d['connection'])),
      MasterCellText(textOf(d['firmware'])),
      StatusPill(active ? 'active' : 'inactive',
          label: active ? 'Active' : 'Inactive'),
      MasterCellText(
          d['last_seen_at'] == null ? '—' : fmtDateTime(d['last_seen_at'])),
      StaffSwitch(
        key: Key('device-active-$name'),
        value: active,
        onChanged: (v) => _patch(id, {'active': v},
            v ? '$name is active.' : '$name is inactive.'),
      ),
      Wrap(children: [
        StaffIconAction(
            key: Key('device-edit-$name'),
            icon: Icons.edit_outlined,
            tooltip: 'Edit',
            onPressed: () => _edit(d, null)),
        StaffIconAction(
            key: Key('device-delete-$name'),
            icon: Icons.delete_outline,
            tooltip: 'Remove',
            color: ViniiColors.redSolid,
            onPressed: () => _delete(id, name)),
      ]),
    ];
  }
}

class _DeviceDialog extends StatefulWidget {
  const _DeviceDialog(
      {required this.api,
      this.existing,
      this.presetType,
      this.branches = const []});
  final ProviyaaApiClient api;
  final Map<String, dynamic>? existing;
  final String? presetType;
  final List<BranchLocation> branches;

  @override
  State<_DeviceDialog> createState() => _DeviceDialogState();
}

class _DeviceDialogState extends State<_DeviceDialog> {
  Map<String, dynamic> get _e => widget.existing ?? const <String, dynamic>{};

  late final _name = _ctl('name');
  late String _station = textOf(_e['station'], '');
  late String? _branch = widget.existing == null
      ? defaultBranchId(widget.branches)
      : _locationOf(_e);
  List<String> _stations = const [];
  late final _ip = _ctl('ip');
  late final _mac = _ctl('mac');
  late final _firmware = _ctl('firmware');
  late final _model = _ctl('model');
  late String _type = _pick(_e['device_type'] ?? widget.presetType,
      [for (final t in _deviceTypes) t.key], 'pos_terminal');
  late String _connection = _pick(
      _e['connection'], [for (final c in _connections) c.$1], 'lan');
  bool _busy = false;
  String? _error;

  TextEditingController _ctl(String key) =>
      TextEditingController(text: textOf(_e[key], ''));

  @override
  void initState() {
    super.initState();
    _stationNames(widget.api).then((s) {
      if (mounted) setState(() => _stations = s);
    });
  }

  /// A new device of a one-branch restaurant belongs to that branch; with
  /// several branches the picker decides.
  bool get _sendBranch =>
      hasManyBranches(widget.branches) ||
      (widget.existing == null && widget.branches.length == 1);

  @override
  void dispose() {
    for (final c in [_name, _ip, _mac, _firmware, _model]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Name the device.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'device_type': _type,
      'station': _station,
      if (_sendBranch) 'location_id': _branch,
      'ip': _ip.text.trim(),
      'mac': _mac.text.trim(),
      'connection': _connection,
      'firmware': _firmware.text.trim(),
      'model': _model.text.trim(),
    };
    try {
      final existing = widget.existing;
      if (existing == null) {
        await widget.api.post('v1/settings/devices', body);
      } else {
        await widget.api.patch('v1/settings/devices/${existing['id']}', body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _errorText(e, const {'name': 'Device name'});
      });
    }
  }

  @override
  Widget build(BuildContext context) => StaffDialog(
        title: widget.existing == null ? 'Register device' : 'Edit device',
        width: 620,
        error: _error,
        actions: [
          MasterButton(
              label: 'Cancel', onPressed: () => Navigator.pop(context)),
          MasterButton(
              key: const Key('device-save'),
              label: _busy ? 'Saving…' : 'Save',
              kind: MasterButtonKind.primary,
              onPressed: _busy ? null : _save),
        ],
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          StaffFormRow(children: [
            BizTextField(
                key: const Key('device-name'),
                label: 'Device name',
                required: true,
                controller: _name,
                hint: 'e.g. KDS Tandoor'),
            StaffField(
              label: 'Type',
              required: true,
              child: StaffSelect<String>(
                key: const Key('device-type'),
                value: _type,
                items: [for (final t in _deviceTypes) (t.key, humanize(t.noun))],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
            ),
          ]),
          if (hasManyBranches(widget.branches))
            StaffFormRow(children: [
              BizBranchSelect(
                selectKey: const Key('device-branch'),
                branches: widget.branches,
                value: _branch,
                onChanged: (v) => setState(() => _branch = v),
              ),
              const SizedBox.shrink(),
            ]),
          StaffFormRow(children: [
            StaffField(
              label: 'Station',
              child: StaffSelect<String>(
                key: const Key('device-station'),
                value: _station,
                items: _stationItems(_stations, _station),
                onChanged: (v) => setState(() => _station = v ?? ''),
              ),
            ),
            StaffField(
              label: 'Connection',
              child: StaffSelect<String>(
                key: const Key('device-connection'),
                value: _connection,
                items: _connections,
                onChanged: (v) =>
                    setState(() => _connection = v ?? _connection),
              ),
            ),
          ]),
          StaffFormRow(children: [
            BizTextField(
                key: const Key('device-ip'),
                label: 'IP address',
                controller: _ip,
                hint: 'e.g. 192.168.1.32'),
            BizTextField(
                key: const Key('device-mac'),
                label: 'MAC address',
                controller: _mac,
                hint: 'e.g. 4C:3F:8F:22:B1:09'),
          ]),
          StaffFormRow(children: [
            BizTextField(
                key: const Key('device-firmware'),
                label: 'Firmware',
                controller: _firmware),
            BizTextField(
                key: const Key('device-model'),
                label: 'Model',
                controller: _model),
          ]),
        ]),
      );
}

// ── printers ─────────────────────────────────────────────────────────────

const _printerTypes = <(String, String)>[
  ('receipt', 'Receipt'),
  ('kot', 'KOT'),
  ('label', 'Label'),
];

String _printerTypeLabel(dynamic v) {
  for (final t in _printerTypes) {
    if (t.$1 == v) return t.$2;
  }
  return humanize(v);
}

class _PrintersTab extends StatefulWidget {
  const _PrintersTab({required this.api, this.branches = const []});
  final ProviyaaApiClient api;
  final List<BranchLocation> branches;

  @override
  State<_PrintersTab> createState() => _PrintersTabState();
}

class _PrintersTabState extends State<_PrintersTab> {
  final _loader = GlobalKey<ApiLoaderState<List<Map<String, dynamic>>>>();

  void _reload() => _loader.currentState?.reload();

  Future<void> _edit(Map<String, dynamic>? existing) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => _PrinterDialog(
            api: widget.api, existing: existing, branches: widget.branches));
    if (ok != true || !mounted) return;
    _say(context, existing == null ? 'Printer added.' : 'Printer updated.');
    _reload();
  }

  Future<void> _patch(
      String id, Map<String, dynamic> body, String success) async {
    final done = await runAction<bool>(context, () async {
      await widget.api.patch('v1/settings/printers/$id', body);
      return true;
    }, success: success);
    if (done == true && mounted) _reload();
  }

  Future<void> _delete(String id, String name) async {
    final ok = await staffConfirm(context,
        title: 'Remove $name?',
        message: 'The printer is removed from this list.');
    if (!ok || !mounted) return;
    final done = await runAction<bool>(context, () async {
      await widget.api.delete('v1/settings/printers/$id');
      return true;
    }, success: '$name removed.');
    if (done == true && mounted) _reload();
  }

  /// The server answers honestly that nothing can print yet; show that.
  Future<void> _test(String id, String name) async {
    try {
      await widget.api.post('v1/settings/printers/$id/test');
      if (!mounted) return;
      _say(context, 'Test print sent to $name.');
    } catch (e) {
      if (!mounted) return;
      _say(context, apiErrorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => MasterPage(children: [
        MasterSection(
          title: 'Windows print setup',
          trailing: const MasterStatusPill('Print agent not in this release',
              tone: PillTone.amber),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                    'A browser cannot send a receipt straight to a thermal '
                    'printer: it always shows its own print dialog, and it can '
                    'never open a raw port for KOTs or the cash drawer.',
                    style: MasterStyle.body),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                      'Raw printing needs a local print agent on the counter PC. '
                      'That agent is not part of this release, so there is '
                      'nothing to download or detect here yet. The printers '
                      'below are saved so your setup is on record; "Test Print" '
                      'tells you plainly that nothing was printed.',
                      style: MasterStyle.body),
                ),
              ]),
        ),
        const SizedBox(height: 20),
        MasterSection(
          title: 'Configured Printers',
          trailing: MasterButton(
              key: const Key('printer-add'),
              label: 'Add Printer',
              icon: Icons.add,
              kind: MasterButtonKind.primary,
              onPressed: () => _edit(null)),
          child: ApiLoader<List<Map<String, dynamic>>>(
            key: _loader,
            load: () async => jsonList(await widget.api
                .get('v1/settings/printers', query: const {'limit': '500'})),
            builder: (context, rows, reload) => rows.isEmpty
                ? const StaffEmptyState(
                    icon: Icons.print_outlined,
                    title: 'No printers configured',
                    message: 'Add the receipt and KOT printers at your '
                        'counters and kitchen.')
                : MasterTable(
                    minWidth: 860,
                    columns: [
                      const MasterColumn('Printer', flex: 3),
                      const MasterColumn('Type', flex: 2),
                      MasterColumn(
                          hasManyBranches(widget.branches)
                              ? 'Station / Branch'
                              : 'Station',
                          flex: 2),
                      const MasterColumn('Address', flex: 3),
                      const MasterColumn('Paper / Density', flex: 2),
                      const MasterColumn('Copies'),
                      const MasterColumn('Auto cut', flex: 2),
                      const MasterColumn('Status', flex: 2),
                      const MasterColumn('Actions', flex: 4),
                    ],
                    rows: [for (final p in rows) _row(p)],
                  ),
          ),
        ),
      ]);

  List<Widget> _row(Map<String, dynamic> p) {
    final id = '${p['id']}';
    final name = textOf(p['name'], 'Printer');
    final active = p['active'] != false;
    return [
      MasterCellTitle(name,
          subtitle: '${_connLabel(p['connection'])} connection'),
      MasterCellText(_printerTypeLabel(p['printer_type'])),
      _stationCell(p, widget.branches),
      MasterCellText(textOf(p['address'])),
      MasterCellText('${_n(p['paper_mm'])}mm / D${_n(p['density'])}'),
      MasterCellText('${_n(p['copies'])}'),
      StaffSwitch(
        key: Key('printer-autocut-$name'),
        value: p['auto_cut'] != false,
        onChanged: (v) => _patch(
            id, {'auto_cut': v}, 'Auto cut ${v ? 'on' : 'off'} for $name.'),
      ),
      StatusPill(active ? 'active' : 'inactive',
          label: active ? 'Active' : 'Inactive'),
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        TextButton(
          key: Key('printer-test-$name'),
          onPressed: () => _test(id, name),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: ViniiColors.textPrimaryLight,
            textStyle:
                const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          child: const Text('Test Print'),
        ),
        StaffIconAction(
            key: Key('printer-edit-$name'),
            icon: Icons.edit_outlined,
            tooltip: 'Edit',
            onPressed: () => _edit(p)),
        StaffIconAction(
            key: Key('printer-delete-$name'),
            icon: Icons.delete_outline,
            tooltip: 'Remove',
            color: ViniiColors.redSolid,
            onPressed: () => _delete(id, name)),
      ]),
    ];
  }
}

class _PrinterDialog extends StatefulWidget {
  const _PrinterDialog(
      {required this.api, this.existing, this.branches = const []});
  final ProviyaaApiClient api;
  final Map<String, dynamic>? existing;
  final List<BranchLocation> branches;

  @override
  State<_PrinterDialog> createState() => _PrinterDialogState();
}

class _PrinterDialogState extends State<_PrinterDialog> {
  Map<String, dynamic> get _e => widget.existing ?? const <String, dynamic>{};

  late final _name = TextEditingController(text: textOf(_e['name'], ''));
  late String _station = textOf(_e['station'], '');
  late String? _branch = widget.existing == null
      ? defaultBranchId(widget.branches)
      : _locationOf(_e);
  List<String> _stations = const [];
  late final _address =
      TextEditingController(text: textOf(_e['address'], ''));
  late String _type = _pick(
      _e['printer_type'], [for (final t in _printerTypes) t.$1], 'receipt');
  late String _connection =
      _pick(_e['connection'], const ['lan', 'usb', 'bluetooth'], 'lan');
  late int _paper = _n(_e['paper_mm']) == 58 ? 58 : 80;
  late int _density = _inRange(_n(_e['density']), 1, 15, 8);
  late int _copies = _inRange(_n(_e['copies']), 1, 5, 1);
  late bool _autoCut = _e['auto_cut'] != false;
  late bool _active = _e['active'] != false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _stationNames(widget.api).then((s) {
      if (mounted) setState(() => _stations = s);
    });
  }

  /// A new printer of a one-branch restaurant belongs to that branch; with
  /// several branches the picker decides.
  bool get _sendBranch =>
      hasManyBranches(widget.branches) ||
      (widget.existing == null && widget.branches.length == 1);

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Name the printer.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'printer_type': _type,
      'station': _station,
      if (_sendBranch) 'location_id': _branch,
      'connection': _connection,
      'address': _address.text.trim(),
      'paper_mm': _paper,
      'density': _density,
      'copies': _copies,
      'auto_cut': _autoCut,
      'active': _active,
    };
    try {
      final existing = widget.existing;
      if (existing == null) {
        await widget.api.post('v1/settings/printers', body);
      } else {
        await widget.api.patch('v1/settings/printers/${existing['id']}', body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _errorText(e, const {'name': 'Printer name'});
      });
    }
  }

  @override
  Widget build(BuildContext context) => StaffDialog(
        title: widget.existing == null ? 'Add printer' : 'Edit printer',
        width: 620,
        error: _error,
        actions: [
          MasterButton(
              label: 'Cancel', onPressed: () => Navigator.pop(context)),
          MasterButton(
              key: const Key('printer-save'),
              label: _busy ? 'Saving…' : 'Save',
              kind: MasterButtonKind.primary,
              onPressed: _busy ? null : _save),
        ],
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          StaffFormRow(children: [
            BizTextField(
                key: const Key('printer-name'),
                label: 'Printer name',
                required: true,
                controller: _name,
                hint: 'e.g. Counter receipt'),
            StaffField(
              label: 'Type',
              child: StaffSelect<String>(
                key: const Key('printer-type'),
                value: _type,
                items: _printerTypes,
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
            ),
          ]),
          if (hasManyBranches(widget.branches))
            StaffFormRow(children: [
              BizBranchSelect(
                selectKey: const Key('printer-branch'),
                branches: widget.branches,
                value: _branch,
                onChanged: (v) => setState(() => _branch = v),
              ),
              const SizedBox.shrink(),
            ]),
          StaffFormRow(children: [
            StaffField(
              label: 'Station',
              child: StaffSelect<String>(
                key: const Key('printer-station'),
                value: _station,
                items: _stationItems(_stations, _station),
                onChanged: (v) => setState(() => _station = v ?? ''),
              ),
            ),
            StaffField(
              label: 'Connection',
              child: StaffSelect<String>(
                key: const Key('printer-connection'),
                value: _connection,
                items: const [
                  ('lan', 'LAN'),
                  ('usb', 'USB'),
                  ('bluetooth', 'Bluetooth'),
                ],
                onChanged: (v) =>
                    setState(() => _connection = v ?? _connection),
              ),
            ),
          ]),
          BizTextField(
              key: const Key('printer-address'),
              label: 'Address',
              controller: _address,
              hint: 'e.g. 192.168.1.13:9100 or the USB device name'),
          const SizedBox(height: 14),
          StaffFormRow(children: [
            StaffField(
              label: 'Paper width',
              child: StaffSelect<int>(
                key: const Key('printer-paper'),
                value: _paper,
                items: const [(58, '58 mm'), (80, '80 mm')],
                onChanged: (v) => setState(() => _paper = v ?? _paper),
              ),
            ),
            StaffField(
              label: 'Density',
              child: StaffSelect<int>(
                key: const Key('printer-density'),
                value: _density,
                items: [for (var i = 1; i <= 15; i++) (i, 'D$i')],
                onChanged: (v) => setState(() => _density = v ?? _density),
              ),
            ),
            StaffField(
              label: 'Copies',
              child: StaffSelect<int>(
                key: const Key('printer-copies'),
                value: _copies,
                items: [for (var i = 1; i <= 5; i++) (i, '$i')],
                onChanged: (v) => setState(() => _copies = v ?? _copies),
              ),
            ),
          ]),
          StaffFormRow(children: [
            BizToggle(
                key: const Key('printer-autocut'),
                label: 'Auto cut',
                value: _autoCut,
                onChanged: (v) => setState(() => _autoCut = v)),
            BizToggle(
                key: const Key('printer-active'),
                label: 'Active',
                value: _active,
                onChanged: (v) => setState(() => _active = v)),
          ]),
        ]),
      );
}

// ── bill format ──────────────────────────────────────────────────────────

const _billOptions = <(String, String)>[
  ('show_logo', 'Show logo'),
  ('show_customer', 'Show customer details'),
  ('show_cashier', 'Show cashier name'),
  ('show_tax_breakup', 'Show tax breakup'),
  ('show_discount', 'Show discount rate'),
  ('show_qr', 'Show barcode / QR'),
];

class _BillTab extends StatelessWidget {
  const _BillTab({required this.api, this.branches = const []});
  final ProviyaaApiClient api;
  final List<BranchLocation> branches;

  @override
  Widget build(BuildContext context) => ApiLoader<Map<String, dynamic>>(
        load: () async => jsonMap(await api.get('v1/settings/bill-format')),
        builder: (context, d, reload) =>
            _BillForm(api: api, initial: d, branches: branches),
      );
}

class _BillForm extends StatefulWidget {
  const _BillForm(
      {required this.api, required this.initial, this.branches = const []});
  final ProviyaaApiClient api;
  final Map<String, dynamic> initial;
  final List<BranchLocation> branches;

  @override
  State<_BillForm> createState() => _BillFormState();
}

class _BillFormState extends State<_BillForm> {
  late final _store = _ctl('store_name');
  late final _branch = _ctl('branch_label');
  late final _address = _ctl('address');
  late final _phone = _ctl('phone');
  late final _gstin = _ctl('gstin');
  late final _fssai = _ctl('fssai');
  late final _prefix = _ctl('bill_prefix');
  late final _footer = _ctl('footer');
  late String _paper =
      _pick(widget.initial['paper_size'], const ['58mm', '80mm', 'A4'], '80mm');
  late final Map<String, bool> _opts = {
    for (final o in _billOptions)
      o.$1: _bool(widget.initial[o.$1], o.$1 != 'show_cashier'),
  };
  late num _cgst = numOf(widget.initial['cgst_pct']);
  late num _sgst = numOf(widget.initial['sgst_pct']);
  late dynamic _updatedAt = widget.initial['updated_at'];
  bool _saving = false;
  String? _error;

  TextEditingController _ctl(String key) =>
      TextEditingController(text: textOf(widget.initial[key], ''));

  @override
  void dispose() {
    for (final c in [
      _store,
      _branch,
      _address,
      _phone,
      _gstin,
      _fssai,
      _prefix,
      _footer
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed(String _) => setState(() {});

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final out = jsonMap(await widget.api.put('v1/settings/bill-format', {
        'store_name': _store.text.trim(),
        'branch_label': _branch.text.trim(),
        'address': _address.text.trim(),
        'phone': _phone.text.trim(),
        'gstin': _gstin.text.trim().toUpperCase(),
        'fssai': _fssai.text.trim(),
        'bill_prefix': _prefix.text.trim(),
        'paper_size': _paper,
        'footer': _footer.text.trim(),
        for (final o in _billOptions) o.$1: _opts[o.$1] ?? false,
      }));
      if (!mounted) return;
      setState(() {
        _saving = false;
        _updatedAt = out['updated_at'];
        if (out.containsKey('cgst_pct')) _cgst = numOf(out['cgst_pct']);
        if (out.containsKey('sgst_pct')) _sgst = numOf(out['sgst_pct']);
      });
      _say(context, 'Bill format saved.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) => MasterPage(children: [
        LayoutBuilder(builder: (context, c) {
          if (c.maxWidth < 860) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [_form(), const SizedBox(height: 20), _preview()]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _form()),
            const SizedBox(width: 20),
            SizedBox(width: 340, child: _preview()),
          ]);
        }),
      ]);

  Widget _form() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MasterSection(
          title: 'Layout Settings',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            StaffFormRow(children: [
              BizTextField(
                  key: const Key('bill-store-name'),
                  label: 'Store Name on Bill',
                  required: true,
                  controller: _store,
                  onChanged: _changed),
              if (widget.branches.isEmpty)
                BizTextField(
                    key: const Key('bill-branch'),
                    label: 'Branch / Outlet',
                    controller: _branch,
                    onChanged: _changed)
              else
                StaffField(
                  label: 'Branch / Outlet',
                  child: StaffSelect<String>(
                    key: const Key('bill-branch'),
                    value: _branch.text.trim(),
                    items: [
                      ('', 'Not printed'),
                      for (final b in widget.branches) (b.name, b.name),
                      if (_branch.text.trim().isNotEmpty &&
                          !widget.branches
                              .any((b) => b.name == _branch.text.trim()))
                        (_branch.text.trim(), _branch.text.trim()),
                    ],
                    onChanged: (v) => setState(() => _branch.text = v ?? ''),
                  ),
                ),
            ]),
            BizTextField(
                key: const Key('bill-address'),
                label: 'Address',
                required: true,
                controller: _address,
                onChanged: _changed),
            const SizedBox(height: 14),
            StaffFormRow(children: [
              BizTextField(
                  key: const Key('bill-phone'),
                  label: 'Phone',
                  required: true,
                  controller: _phone,
                  onChanged: _changed),
              BizTextField(
                  key: const Key('bill-gstin'),
                  label: 'GSTIN (Optional)',
                  controller: _gstin,
                  hint: '15 letters and digits',
                  onChanged: _changed),
            ]),
            StaffFormRow(children: [
              BizTextField(
                  key: const Key('bill-prefix'),
                  label: 'Bill Prefix',
                  controller: _prefix,
                  onChanged: _changed),
              StaffField(
                label: 'Paper Size',
                child: StaffSelect<String>(
                  key: const Key('bill-paper'),
                  value: _paper,
                  items: const [
                    ('58mm', '58mm Thermal'),
                    ('80mm', '80mm Thermal'),
                    ('A4', 'A4'),
                  ],
                  onChanged: (v) => setState(() => _paper = v ?? _paper),
                ),
              ),
            ]),
            StaffFormRow(children: [
              BizTextField(
                  key: const Key('bill-fssai'),
                  label: 'FSSAI Licence (Optional)',
                  controller: _fssai,
                  onChanged: _changed),
              BizTextField(
                  key: const Key('bill-footer'),
                  label: 'Footer',
                  controller: _footer,
                  onChanged: _changed),
            ]),
          ]),
        ),
        const SizedBox(height: 20),
        MasterSection(
          title: 'Print Options',
          child: MasterGrid(
            columns: 2,
            minItemWidth: 220,
            spacing: 12,
            children: [
              for (final o in _billOptions)
                BizToggle(
                  key: Key('bill-${o.$1}'),
                  label: o.$2,
                  value: _opts[o.$1] ?? false,
                  onChanged: (v) => setState(() => _opts[o.$1] = v),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SaveBar(
          buttonKey: const Key('bill-save'),
          saving: _saving,
          onSave: _save,
          error: _error,
          status: _updatedAt == null
              ? 'Not saved yet — these values come from your account.'
              : 'Last saved ${fmtDateTime(_updatedAt)}',
        ),
      ]);

  Widget _line(String left, String right,
      {bool bold = false, bool big = false}) {
    final style = TextStyle(
        fontWeight: bold || big ? FontWeight.w700 : FontWeight.w400,
        fontSize: big ? 13.5 : 11.5);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(left, style: style)),
        if (right.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(right, style: style),
        ],
      ]),
    );
  }

  Widget _preview() {
    const items = <(String, double)>[
      ('Sample item 1', 180.0),
      ('Sample item 2', 220.0),
    ];
    const subtotal = 400.0;
    final cgst = subtotal * _cgst / 100;
    final sgst = subtotal * _sgst / 100;
    final total = subtotal + cgst + sgst;
    final branch = _branch.text.trim();
    final gstin = _gstin.text.trim().toUpperCase();
    final fssai = _fssai.text.trim();
    final footer = _footer.text.trim();
    final paperWidth = switch (_paper) {
      '58mm' => 230.0,
      '80mm' => 300.0,
      _ => double.infinity,
    };
    bool on(String key) => _opts[key] ?? false;
    const muted = TextStyle(color: ViniiColors.textSecondaryLight);
    return MasterCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Row(children: [
          Icon(Icons.visibility_outlined,
              size: 18, color: ViniiColors.greenSolid),
          SizedBox(width: 8),
          Expanded(child: Text('Live Preview', style: MasterStyle.sectionTitle)),
          MasterStatusPill('Sample bill', tone: PillTone.gray),
        ]),
        const SizedBox(height: 6),
        const Text(
            'Header and options come from this form; the items and amounts '
            'are samples.',
            style: MasterStyle.muted),
        const SizedBox(height: 14),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: paperWidth),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MasterStyle.cardBorder),
              ),
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: ViniiColors.textPrimaryLight),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (on('show_logo')) ...[
                        Center(
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: MasterStyle.cardBorder),
                            ),
                            child: const Icon(Icons.restaurant,
                                size: 20, color: ViniiColors.textMutedLight),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(textOf(_store.text, 'Store name'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      if (branch.isNotEmpty)
                        Text(branch,
                            textAlign: TextAlign.center, style: muted),
                      Text(textOf(_address.text, 'Address'),
                          textAlign: TextAlign.center, style: muted),
                      Text('Tel: ${textOf(_phone.text)}',
                          textAlign: TextAlign.center, style: muted),
                      if (gstin.isNotEmpty)
                        Text('GSTIN: $gstin',
                            textAlign: TextAlign.center, style: muted),
                      if (fssai.isNotEmpty)
                        Text('FSSAI: $fssai',
                            textAlign: TextAlign.center, style: muted),
                      const _Dashes(),
                      _line('Bill No: ${_prefix.text.trim()}'
                          '${DateTime.now().year}-001',
                          'Date: ${fmtDate(DateTime.now().toIso8601String())}'),
                      if (on('show_customer'))
                        _line('Customer: Sample guest', ''),
                      if (on('show_cashier'))
                        _line('Cashier: Sample cashier', ''),
                      const _Dashes(),
                      for (final i in items)
                        _line('1x ${i.$1}', inr(i.$2), bold: true),
                      const _Dashes(),
                      _line('Subtotal', inr(subtotal)),
                      if (on('show_discount'))
                        _line('Discount (0%)', inr(0)),
                      if (on('show_tax_breakup')) ...[
                        _line('CGST ${staffNumText(_cgst)}%', inr(cgst)),
                        _line('SGST ${staffNumText(_sgst)}%', inr(sgst)),
                      ] else
                        _line('GST ${staffNumText(_cgst + _sgst)}%',
                            inr(cgst + sgst)),
                      const SizedBox(height: 4),
                      _line('GRAND TOTAL', inr(total), big: true),
                      const _Dashes(),
                      if (on('show_qr'))
                        const Center(
                          child: Icon(Icons.qr_code_2,
                              size: 56, color: ViniiColors.textPrimaryLight),
                        ),
                      if (footer.isNotEmpty)
                        Text(footer,
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Dashed rule on the receipt preview.
class _Dashes extends StatelessWidget {
  const _Dashes();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: LayoutBuilder(builder: (context, c) {
          final count =
              c.maxWidth.isFinite ? (c.maxWidth / 6).floor().clamp(1, 400) : 40;
          return Row(children: [
            for (var i = 0; i < count; i++)
              Expanded(
                child: Container(
                  height: 1,
                  color: i.isEven
                      ? const Color(0xFFD1D5DB)
                      : Colors.transparent,
                ),
              ),
          ]);
        }),
      );
}

// ── notifications ────────────────────────────────────────────────────────

const _alertOptions = <(String, String)>[
  ('low_stock', 'Low stock'),
  ('new_online_order', 'New online order'),
  ('payment_pending', 'Payment pending verification'),
  ('task_overdue', 'Task overdue'),
  ('document_expiry', 'Document expiry'),
  ('daily_summary', 'Daily summary'),
];

const _channelOptions = <(String, String)>[
  ('via_email', 'Email'),
  ('via_whatsapp', 'WhatsApp'),
  ('via_sms', 'SMS'),
  ('via_push', 'Push'),
];

class _NotificationsTab extends StatelessWidget {
  const _NotificationsTab({required this.api});
  final ProviyaaApiClient api;

  @override
  Widget build(BuildContext context) => ApiLoader<Map<String, dynamic>>(
        load: () async => jsonMap(await api.get('v1/settings/notifications')),
        builder: (context, d, reload) =>
            _NotificationsForm(api: api, initial: d),
      );
}

class _NotificationsForm extends StatefulWidget {
  const _NotificationsForm({required this.api, required this.initial});
  final ProviyaaApiClient api;
  final Map<String, dynamic> initial;

  @override
  State<_NotificationsForm> createState() => _NotificationsFormState();
}

class _NotificationsFormState extends State<_NotificationsForm> {
  late final Map<String, bool> _flags = {
    for (final o in [..._alertOptions, ..._channelOptions])
      o.$1: _bool(widget.initial[o.$1]),
  };
  late final _recipients = TextEditingController(
      text: _strings(widget.initial['recipients']).join(', '));
  late dynamic _updatedAt = widget.initial['updated_at'];
  late bool _saved = widget.initial['saved'] == true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _recipients.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final recipients = [
      for (final s in _recipients.text.split(RegExp(r'[,;\s]+')))
        if (s.trim().isNotEmpty) s.trim(),
    ];
    try {
      await widget.api.put('v1/settings/notifications', {
        for (final e in _flags.entries) e.key: e.value,
        'recipients': recipients,
      });
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
        _updatedAt = DateTime.now().toIso8601String();
      });
      _say(context, 'Notification settings saved.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _errorText(e);
      });
    }
  }

  Widget _toggle((String, String) o) => BizToggle(
        key: Key('notify-${o.$1}'),
        label: o.$2,
        value: _flags[o.$1] ?? false,
        onChanged: (v) => setState(() => _flags[o.$1] = v),
      );

  @override
  Widget build(BuildContext context) => MasterPage(children: [
        MasterSection(
          title: 'Alerts',
          subtitle: 'Which events send you a notification.',
          child: MasterGrid(
              columns: 2,
              minItemWidth: 240,
              spacing: 12,
              children: [for (final o in _alertOptions) _toggle(o)]),
        ),
        const SizedBox(height: 20),
        MasterSection(
          title: 'Channels',
          subtitle: 'How notifications reach you.',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            MasterGrid(
                columns: 4,
                minItemWidth: 170,
                spacing: 12,
                children: [for (final o in _channelOptions) _toggle(o)]),
            const SizedBox(height: 14),
            const MasterBanner(
                tone: PillTone.blue,
                message: 'WhatsApp and SMS need a connected provider '
                    '(Integrations → Connected apps). Until one is linked, '
                    'nothing is sent on those channels.'),
          ]),
        ),
        const SizedBox(height: 20),
        MasterSection(
          title: 'Recipients',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            BizTextField(
                key: const Key('notify-recipients'),
                label: 'Email recipients',
                controller: _recipients,
                hint: 'owner@example.com, manager@example.com'),
            const SizedBox(height: 6),
            const Text('Separate addresses with commas. Up to 10.',
                style: MasterStyle.muted),
          ]),
        ),
        const SizedBox(height: 20),
        _SaveBar(
          buttonKey: const Key('notify-save'),
          saving: _saving,
          onSave: _save,
          error: _error,
          status: _savedStatus(_updatedAt, _saved),
        ),
      ]);
}
