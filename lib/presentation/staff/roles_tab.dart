import 'package:flutter/material.dart';

import '../../data/staff_repository.dart';
import '../../domain/access.dart';
import '../../domain/vendor_account.dart' show BranchLocation;
import '../master/master_ui.dart';
import '../vinii_theme.dart';
import 'staff_ui.dart';

String panelLabel(String panel) =>
    panel == 'pos' ? 'POS terminal' : 'Vendor panel';

/// Roles & permissions tab: "Staff access" (who can sign in, with which
/// role — v1/staff managment/login-users-roles.png) and "Roles" (the role
/// catalogue — staff-roles-permissions.png).
class RolesTab extends StaffTabWidget {
  const RolesTab(
      {super.key,
      required super.repository,
      super.refreshToken,
      super.branches,
      super.defaultBranchId});

  @override
  State<RolesTab> createState() => RolesTabState();
}

class RolesTabState extends State<RolesTab> with StaffLoadState<RolesTab> {
  /// 0 = Staff access, 1 = Roles.
  int _view = 0;
  List<StaffLogin> _logins = const [];
  RolesOverview _overview = const RolesOverview(roles: [], baseRoles: []);
  List<StaffMember> _staff = const [];
  String? _roleFilter;
  final _selected = <String>{};

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  Future<void> fetch() async {
    final r = await Future.wait<Object>(
        [repo.logins(), repo.roles(), repo.employees()]);
    final firstLoad = !loaded;
    _logins = r[0] as List<StaffLogin>;
    _overview = r[1] as RolesOverview;
    _staff = r[2] as List<StaffMember>;
    _selected.removeWhere((id) => !_logins.any((l) => l.userId == id));
    // A restaurant with no roles yet lands on the catalogue's empty state.
    if (firstLoad && _overview.roles.isEmpty) _view = 1;
  }

  List<StaffRole> get _roles => _overview.roles;

  /// "Add New Staff" in the page header: a new app login.
  Future<void> addLogin() async {
    if (_view != 0) setState(() => _view = 0);
    final created = await showDialog<StaffLogin>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LoginDialog(
          repository: repo,
          roles: _roles,
          staff: _staff,
          logins: _logins,
          branches: widget.branches,
          defaultBranchId: widget.defaultBranchId),
    );
    if (created == null || !mounted) return;
    await reload();
    if (mounted) showStaffNotice(context, 'Login created for ${created.email}');
  }

  Future<void> _patch(StaffLogin l, Map<String, Object?> patch,
          {String? success}) =>
      act(() => repo.updateLogin(l.userId, patch), success: success);

  /// The login's home branch by name.
  String _branchOf(StaffLogin l) =>
      staffBranchName(l.locationId, l.locationName, widget.branches);

  /// The Branch cell: a picker for the home branch when the branches are
  /// known, else the branch's name.
  Widget _branchCell(StaffLogin l) {
    final branches = widget.branches;
    if (branches.isEmpty || l.isOwner) return MasterCellText(_branchOf(l));
    final current = l.locationId ?? '';
    return StaffSelect<String>(
      key: Key('access-branch-${l.userId}'),
      dense: true,
      value: current,
      items: [
        ...staffBranchItems(branches, noneLabel: 'All branches'),
        if (current.isNotEmpty && !branches.any((b) => b.id == current))
          (current, _branchOf(l)),
      ],
      onChanged: busy
          ? null
          : (v) {
              final next = v ?? '';
              if (next == current) return;
              if (next.isEmpty &&
                  branches.length > 1 &&
                  staffBranchBoundRoles.contains(l.posRole)) {
                showStaffError(
                    context,
                    'A ${l.displayRole} login works at one branch — pick '
                    'the branch instead of all branches.');
                return;
              }
              final name = next.isEmpty
                  ? 'every branch'
                  : staffBranchName(next, null, branches);
              _patch(l, {'location_id': next.isEmpty ? null : next},
                  success: '${l.fullName} now works at $name');
            },
    );
  }

  Future<void> _bulkStatus(bool active) async {
    final ids = [
      for (final l in _logins)
        if (_selected.contains(l.userId) && !l.isOwner) l.userId
    ];
    if (ids.isEmpty) return;
    final ok = await act(() async {
      for (final id in ids) {
        await repo.updateLogin(id, {'status': active ? 'Active' : 'Inactive'});
      }
    },
        success:
            '${ids.length} login(s) ${active ? 'activated' : 'deactivated'}');
    if (ok && mounted) setState(_selected.clear);
  }

  Future<void> _seedRoles() => act(repo.seedDefaultRoles,
      success: 'Default roles added — edit them any time');

  Future<void> _editRole([StaffRole? role]) async {
    final saved = await showDialog<StaffRole>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          RoleDialog(repository: repo, overview: _overview, existing: role),
    );
    if (saved == null || !mounted) return;
    await reload();
    if (mounted) {
      showStaffNotice(context,
          role == null ? 'Created ${saved.name}' : 'Saved ${saved.name}');
    }
  }

  Future<void> _deleteRole(StaffRole role) async {
    final ok = await staffConfirm(context,
        title: 'Delete ${role.name}?',
        message: role.staffCount > 0
            ? '${role.staffCount} login(s) use this role. Move them to another '
                'role first — the server will refuse otherwise.'
            : 'Nobody uses this role. It will be removed from the catalogue.');
    if (!ok || !mounted) return;
    await act(() => repo.deleteRole(role.id), success: 'Deleted ${role.name}');
  }

  Future<void> _details(StaffLogin l) {
    final role = _roles.where((r) => r.id == l.roleId).firstOrNull;
    final screens = role?.screens ?? PosRoles.defaultScreens(l.posRole);
    final panel = role?.panel ?? PosRoles.panelFor(l.posRole);
    return showDialog<void>(
      context: context,
      builder: (context) => StaffDialog(
        title: l.fullName,
        subtitle: l.email,
        width: 560,
        actions: [
          MasterButton(
              label: 'Close',
              kind: MasterButtonKind.primary,
              onPressed: () => Navigator.pop(context)),
        ],
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 24, runSpacing: 12, children: [
            MasterKeyValue('Role', l.displayRole),
            MasterKeyValue(
                'Based on',
                l.posRoleName.trim().isNotEmpty
                    ? l.posRoleName
                    : posRoleLabel(l.posRole)),
            MasterKeyValue('Works on', panelLabel(panel)),
            MasterKeyValue('Branch', _branchOf(l)),
            MasterKeyValue('Status', l.status),
            MasterKeyValue(
                'Linked staff',
                l.staffName == null
                    ? 'Not linked'
                    : staffPickLabel(l.staffName!, l.staffCode)),
            MasterKeyValue('Last login', staffDateTime(l.lastLoginAt)),
          ]),
          const SizedBox(height: 18),
          Text('Screens this role opens (${screens.length})',
              style: MasterStyle.sectionTitle),
          const SizedBox(height: 10),
          ..._groupedScreens(screens),
        ]),
      ),
    );
  }

  static List<Widget> _groupedScreens(Set<String> screens) {
    final groups = <String, List<AppScreen>>{};
    for (final s in Screens.all) {
      if (screens.contains(s.id)) groups.putIfAbsent(s.group, () => []).add(s);
    }
    if (groups.isEmpty) {
      return const [Text('No screens.', style: MasterStyle.muted)];
    }
    return [
      for (final g in groups.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g.key.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w700,
                    color: ViniiColors.textSecondaryLight)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final s in g.value)
                StaffChip(Screens.byId[s.id]?.label ?? s.id,
                    color: ViniiColors.textPrimaryLight,
                    tint: const Color(0xFFF3F4F6)),
            ]),
          ]),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) => StaffTabPage(children: [
        StaffPills(
            keyPrefix: 'roles-view',
            options: const ['Staff access', 'Roles'],
            selected: _view,
            onSelect: (i) => setState(() => _view = i)),
        const SizedBox(height: 16),
        guarded(() => _view == 0 ? _access() : _catalogue()),
      ]);

  // ── staff access ───────────────────────────────────────────────────────

  Widget _access() {
    final roleNames = <String>[];
    for (final l in _logins) {
      if (!roleNames.contains(l.displayRole)) roleNames.add(l.displayRole);
    }
    final rows = [
      for (final l in _logins)
        if (_roleFilter == null || l.displayRole == _roleFilter) l
    ];
    Widget chip(String label, String? value) {
      final on = _roleFilter == value;
      return Material(
        color: on ? ViniiColors.brandGreen : Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: Key('access-filter-${value ?? 'all'}'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _roleFilter = value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: on ? ViniiColors.brandGreen : kStaffBorder),
            ),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: ViniiColors.textPrimaryLight)),
          ),
        ),
      );
    }

    final linkedElsewhere = {
      for (final l in _logins)
        if (l.staffId != null) l.staffId!: l.userId
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        chip('All staff', null),
        for (final n in roleNames) chip(n, n),
      ]),
      if (_selected.isNotEmpty) ...[
        const SizedBox(height: 12),
        MasterBanner(
          tone: PillTone.blue,
          message: '${_selected.length} login(s) selected',
          trailing: Wrap(spacing: 8, children: [
            MasterButton(label: 'Activate', onPressed: () => _bulkStatus(true)),
            MasterButton(
                label: 'Deactivate',
                kind: MasterButtonKind.dangerOutline,
                onPressed: () => _bulkStatus(false)),
            MasterButton(
                label: 'Clear',
                kind: MasterButtonKind.text,
                onPressed: () => setState(_selected.clear)),
          ]),
        ),
      ],
      const SizedBox(height: 14),
      if (_roles.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: MasterBanner(
            tone: PillTone.amber,
            title: 'No staff roles yet',
            message: 'Logins need a staff role. Seed the defaults or create a '
                'custom role in the Roles view.',
            trailing: MasterButton(
                key: const Key('access-seed-roles'),
                label: 'Seed default roles',
                onPressed: busy ? null : _seedRoles),
          ),
        ),
      MasterTable(
        minWidth: 1240,
        columns: const [
          MasterColumn('', flex: 3),
          MasterColumn('Staff details', flex: 20),
          MasterColumn('Staff code', flex: 9),
          MasterColumn('Phone number', flex: 11),
          MasterColumn('Role', flex: 13),
          MasterColumn('Branch', flex: 13),
          MasterColumn('Linked staff', flex: 14),
          MasterColumn('Delivery', flex: 6),
          MasterColumn('Status', flex: 10),
          MasterColumn('Actions', flex: 5, alignEnd: true),
        ],
        rows: [
          for (final l in rows)
            [
              Checkbox(
                key: Key('access-select-${l.userId}'),
                value: _selected.contains(l.userId),
                activeColor: ViniiColors.greenSolid,
                onChanged: l.isOwner
                    ? null
                    : (v) => setState(() => v == true
                        ? _selected.add(l.userId)
                        : _selected.remove(l.userId)),
              ),
              MasterCellTitle(l.fullName, subtitle: l.email),
              MasterCellText((l.staffCode ?? '').isEmpty ? '—' : l.staffCode!),
              MasterCellText(l.phoneNumber.isEmpty ? '—' : l.phoneNumber),
              l.isOwner
                  ? StaffChip(l.displayRole,
                      color: ViniiColors.textPrimaryLight,
                      tint: const Color(0xFFF3F4F6))
                  : StaffSelect<String>(
                      key: Key('access-role-${l.userId}'),
                      dense: true,
                      value: l.roleId,
                      hint: l.displayRole,
                      items: [for (final r in _roles) (r.id, r.name)],
                      onChanged: busy
                          ? null
                          : (v) {
                              if (v == null || v == l.roleId) return;
                              final name =
                                  _roles.firstWhere((r) => r.id == v).name;
                              _patch(l, {'role_id': v},
                                  success: '${l.fullName} is now $name');
                            },
                    ),
              _branchCell(l),
              StaffSelect<String>(
                key: Key('access-link-${l.userId}'),
                dense: true,
                value: l.staffId ?? '',
                items: [
                  ('', 'Not linked'),
                  for (final s in _staff)
                    if (linkedElsewhere[s.id] == null ||
                        linkedElsewhere[s.id] == l.userId)
                      (s.id, staffPickLabel(s.fullName, s.staffCode)),
                ],
                onChanged: busy
                    ? null
                    : (v) {
                        if ((v ?? '') == (l.staffId ?? '')) return;
                        _patch(l, {'staff_id': (v ?? '').isEmpty ? null : v},
                            success: (v ?? '').isEmpty
                                ? 'Unlinked ${l.fullName}'
                                : 'Linked ${l.fullName}');
                      },
              ),
              StaffSwitch(
                key: Key('access-delivery-${l.userId}'),
                value: l.deliveryEnabled,
                onChanged:
                    busy ? null : (v) => _patch(l, {'delivery_enabled': v}),
              ),
              Row(mainAxisSize: MainAxisSize.min, children: [
                StaffSwitch(
                  key: Key('access-status-${l.userId}'),
                  value: l.isActive,
                  onChanged: l.isOwner || busy
                      ? null
                      : (v) => _patch(l, {'status': v ? 'Active' : 'Inactive'},
                          success:
                              '${l.fullName} ${v ? 'activated' : 'deactivated'}'),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(l.status,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: l.isActive
                              ? kStaffGreen
                              : ViniiColors.textMutedLight)),
                ),
              ]),
              StaffIconAction(
                  key: Key('access-view-${l.userId}'),
                  tooltip: 'Screens this login opens',
                  icon: Icons.visibility_outlined,
                  color: ViniiColors.textPrimaryLight,
                  onPressed: () => _details(l)),
            ]
        ],
        footer: rows.isEmpty
            ? const StaffEmptyState(
                icon: Icons.key_outlined,
                title: 'No logins',
                message: 'Use Add New Staff to give someone an app login.',
              )
            : null,
      ),
    ]);
  }

  // ── role catalogue ─────────────────────────────────────────────────────

  Widget _catalogue() {
    final roles = _roles;
    final missingDefaults = const [
      'Restaurant Admin',
      'Branch Manager',
      'Cashier',
      'Captain',
      'Kitchen (KOT)',
    ].where((n) => !roles.any((r) => r.name.toLowerCase() == n.toLowerCase()));
    final header = Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kStaffBorder))),
      child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            const Text('Roles & Permissions',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ViniiColors.textPrimaryLight)),
            Wrap(
                spacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (roles.isNotEmpty && missingDefaults.isNotEmpty)
                    MasterButton(
                        label: 'Seed default roles',
                        icon: Icons.download_outlined,
                        onPressed: busy ? null : _seedRoles),
                  if (roles.isNotEmpty)
                    MasterButton(
                        key: const Key('roles-create-top'),
                        label: 'Create Custom Role',
                        icon: Icons.add,
                        kind: MasterButtonKind.primary,
                        onPressed: () => _editRole()),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: kStaffBorder)),
                    child: Text(
                        '${roles.length} ROLE${roles.length == 1 ? '' : 'S'}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: ViniiColors.textSecondaryLight)),
                  ),
                ]),
          ]),
    );
    Widget body;
    if (roles.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: Column(children: [
          StaffEmptyState(
            icon: Icons.shield_outlined,
            bigIcon: true,
            title: 'No roles yet',
            message: "Your restaurant doesn't have any roles configured. Seed "
                'the default roles to get started quickly, or create a '
                'custom role that opens only the screens you tick.',
            actions: [
              MasterButton(
                  key: const Key('roles-seed'),
                  label: busy ? 'Seeding…' : 'Seed default roles',
                  icon: Icons.download_outlined,
                  onPressed: busy ? null : _seedRoles),
              MasterButton(
                  key: const Key('roles-create'),
                  label: 'Create Custom Role',
                  icon: Icons.add,
                  kind: MasterButtonKind.primary,
                  onPressed: () => _editRole()),
            ],
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: ViniiColors.amberTint,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.search, size: 16, color: Color(0xFFB45309)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                          TextSpan(children: [
                            TextSpan(
                                text: 'Tip: ',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            TextSpan(
                                text: 'Seeding default roles (Restaurant Admin, '
                                    'Branch Manager, Cashier, Captain, Kitchen) is recommended '
                                    'before assigning staff. You can edit '
                                    'permissions after seeding.'),
                          ]),
                          style: TextStyle(
                              fontSize: 12.5, color: Color(0xFF92400E))),
                    ),
                  ]),
            ),
          ),
        ]),
      );
    } else {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: MasterTable(
          minWidth: 950,
          columns: const [
            MasterColumn('Role', flex: 18),
            MasterColumn('Based on', flex: 16),
            MasterColumn('Panel', flex: 11),
            MasterColumn('Staff', flex: 7),
            MasterColumn('Screens', flex: 8),
            MasterColumn('Actions', flex: 8, alignEnd: true),
          ],
          rows: [
            for (final r in roles)
              [
                Row(children: [
                  Flexible(
                    child: MasterCellTitle(r.name,
                        subtitle: r.description.isEmpty ? null : r.description),
                  ),
                  if (r.isDefault) ...[
                    const SizedBox(width: 8),
                    const StaffChip('Default', color: ViniiColors.graySolid),
                  ],
                ]),
                MasterCellText(r.baseRoleName.isEmpty
                    ? posRoleLabel(r.baseRole)
                    : r.baseRoleName),
                StaffChip(panelLabel(r.panel),
                    color: r.panel == 'pos'
                        ? kStaffPurple
                        : ViniiColors.blueSolid),
                MasterCellText('${r.staffCount}'),
                MasterCellText(
                    '${r.screens.length} screen${r.screens.length == 1 ? '' : 's'}'),
                Wrap(children: [
                  StaffIconAction(
                      key: Key('role-edit-${r.id}'),
                      tooltip: 'Edit',
                      icon: Icons.edit_note,
                      onPressed: () => _editRole(r)),
                  StaffIconAction(
                      key: Key('role-delete-${r.id}'),
                      tooltip: 'Delete',
                      icon: Icons.delete_outline,
                      color: ViniiColors.redSolid,
                      onPressed: busy ? null : () => _deleteRole(r)),
                ]),
              ]
          ],
        ),
      );
    }
    return MasterCard(
      padding: EdgeInsets.zero,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [header, body]),
    );
  }
}

/// Create / edit a staff role: name, the built-in role it's based on, and
/// the screens it opens (limited to what that base may be granted).
class RoleDialog extends StatefulWidget {
  const RoleDialog(
      {super.key,
      required this.repository,
      required this.overview,
      this.existing});
  final StaffRepository repository;
  final RolesOverview overview;
  final StaffRole? existing;

  @override
  State<RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends State<RoleDialog> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _description =
      TextEditingController(text: widget.existing?.description);
  late String _base = widget.existing?.baseRole ??
      (_bases.any((b) => b.key == 'location_manager')
          ? 'location_manager'
          : _bases.first.key);
  late Set<String> _screens = widget.existing != null
      ? {...widget.existing!.screens}
      : {..._info(_base)?.defaultScreens ?? const <String>{}};
  bool _saving = false;
  String? _error;

  /// Owner-level roles aren't handed out through custom roles.
  List<BaseRoleInfo> get _bases => [
        for (final b in widget.overview.baseRoles)
          if (b.key != 'org_owner' || widget.existing?.baseRole == 'org_owner')
            b
      ];

  BaseRoleInfo? _info(String key) =>
      widget.overview.baseRoles.where((b) => b.key == key).firstOrNull;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _setBase(String key) => setState(() {
        _base = key;
        final info = _info(key);
        _screens = {
          for (final s in info?.defaultScreens ?? const <String>{})
            if (info!.grantable.contains(s)) s
        };
      });

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the role a name.');
      return;
    }
    final grantable = _info(_base)?.grantable ?? const <String>{};
    final screens = {
      for (final s in _screens)
        if (grantable.contains(s)) s
    };
    if (screens.isEmpty) {
      setState(() => _error = 'Tick at least one screen.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final existing = widget.existing;
      final saved = existing == null
          ? await widget.repository.createRole(
              name: name,
              baseRole: _base,
              screens: screens,
              description: _description.text.trim())
          : await widget.repository.updateRole(existing.id,
              name: name,
              baseRole: _base,
              screens: screens,
              description: _description.text.trim());
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) setState(() => _error = staffErrorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info(_base);
    final grantable = info?.grantable ?? const <String>{};
    final groups = <String, List<AppScreen>>{};
    for (final s in Screens.all) {
      if (grantable.contains(s.id)) {
        groups.putIfAbsent(s.group, () => []).add(s);
      }
    }
    return StaffDialog(
      title: widget.existing == null ? 'Create Custom Role' : 'Edit Role',
      subtitle: 'The base role decides what the server lets this role do; '
          'the screens decide what it sees.',
      width: 760,
      error: _error,
      actions: [
        MasterButton(
            label: 'Cancel',
            onPressed: _saving ? null : () => Navigator.pop(context)),
        MasterButton(
            key: const Key('role-save'),
            label: _saving
                ? 'Saving…'
                : (widget.existing == null ? 'Create Role' : 'Save'),
            kind: MasterButtonKind.primary,
            onPressed: _saving ? null : _save),
      ],
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        StaffFormRow(children: [
          StaffField(
            label: 'Role name',
            required: true,
            child: TextField(
                key: const Key('role-name'),
                controller: _name,
                style: const TextStyle(fontSize: 13.5),
                decoration: staffInput(hint: 'e.g. Night Manager')),
          ),
          StaffField(
            label: 'Based on',
            child: StaffSelect<String>(
              key: const Key('role-base'),
              value: _base,
              items: [
                for (final b in _bases)
                  (b.key, '${b.name} · ${panelLabel(b.panel)}')
              ],
              onChanged: (v) {
                if (v != null && v != _base) _setBase(v);
              },
            ),
          ),
        ]),
        StaffFormRow(children: [
          StaffField(
            label: 'Description',
            child: TextField(
                key: const Key('role-description'),
                controller: _description,
                style: const TextStyle(fontSize: 13.5),
                decoration: staffInput(hint: 'Optional')),
          ),
        ]),
        Row(children: [
          Expanded(
            child: Text(
                'Screens (${_screens.where(grantable.contains).length} of '
                '${grantable.length}) · ${panelLabel(info?.panel ?? 'vendor')}',
                style: MasterStyle.sectionTitle),
          ),
          TextButton(
              onPressed: () => setState(() => _screens = {...grantable}),
              child: const Text('Select all')),
          TextButton(
              onPressed: () => setState(() => _screens = {}),
              child: const Text('Clear')),
          TextButton(
              onPressed: () => _setBase(_base), child: const Text('Defaults')),
        ]),
        const SizedBox(height: 6),
        for (final g in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(g.key.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w700,
                    color: ViniiColors.textSecondaryLight)),
          ),
          Wrap(spacing: 4, runSpacing: 0, children: [
            for (final s in g.value)
              SizedBox(
                width: 225,
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => setState(() => _screens.contains(s.id)
                      ? _screens.remove(s.id)
                      : _screens.add(s.id)),
                  child: Row(children: [
                    Checkbox(
                      key: Key('role-screen-${s.id}'),
                      value: _screens.contains(s.id),
                      activeColor: ViniiColors.greenSolid,
                      visualDensity: VisualDensity.compact,
                      onChanged: (v) => setState(() => v == true
                          ? _screens.add(s.id)
                          : _screens.remove(s.id)),
                    ),
                    Flexible(
                      child: Text(s.label,
                          overflow: TextOverflow.ellipsis,
                          style: MasterStyle.body),
                    ),
                  ]),
                ),
              ),
          ]),
        ],
      ]),
    );
  }
}

/// "Add New Staff" in Staff access: a new app login with a staff role,
/// optionally linked to an employee record.
class _LoginDialog extends StatefulWidget {
  const _LoginDialog(
      {required this.repository,
      required this.roles,
      required this.staff,
      required this.logins,
      this.branches = const [],
      this.defaultBranchId});
  final StaffRepository repository;
  final List<StaffRole> roles;
  final List<StaffMember> staff;
  final List<StaffLogin> logins;
  final List<BranchLocation> branches;
  final String? defaultBranchId;

  @override
  State<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<_LoginDialog> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  late List<StaffRole> _roles = widget.roles;
  String? _roleId;
  String _staffId = '';
  bool _forceChange = true;
  bool _saving = false;
  bool _seeding = false;
  String? _error;

  /// Home branch id; '' = every branch.
  late String _branchId = _startBranch();

  String _startBranch() {
    final branches = widget.branches;
    if (branches.length == 1) return branches.single.id;
    final d = widget.defaultBranchId;
    if (d != null && branches.any((b) => b.id == d)) return d;
    return '';
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _seed() async {
    setState(() => _seeding = true);
    try {
      final roles = await widget.repository.seedDefaultRoles();
      if (mounted) setState(() => _roles = roles);
    } catch (e) {
      if (mounted) setState(() => _error = staffErrorText(e));
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  void _pickStaff(String? id) {
    setState(() => _staffId = id ?? '');
    final s = widget.staff.where((s) => s.id == id).firstOrNull;
    if (s == null) return;
    // The login works where the employee works.
    final home = s.locationId;
    if (home != null && home.isNotEmpty) setState(() => _branchId = home);
    final parts = s.fullName.split(RegExp(r'\s+'));
    if (_first.text.trim().isEmpty) _first.text = parts.first;
    if (_last.text.trim().isEmpty && parts.length > 1) {
      _last.text = parts.sublist(1).join(' ');
    }
    if (_email.text.trim().isEmpty) _email.text = s.email;
    if (_phone.text.trim().isEmpty) _phone.text = s.mobile;
  }

  Future<void> _save() async {
    final email = _email.text.trim();
    String? problem;
    if (_first.text.trim().isEmpty) problem = 'Enter the first name.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      problem ??= 'Enter a valid email.';
    }
    if (_password.text.length < 8) {
      problem ??= 'Password must be at least 8 characters.';
    }
    if (_roleId == null) problem ??= 'Pick a role.';
    final role = _roles.where((r) => r.id == _roleId).firstOrNull;
    if (_branchId.isEmpty &&
        widget.branches.length > 1 &&
        role != null &&
        staffBranchBoundRoles.contains(role.baseRole)) {
      problem ??= 'Pick the home branch — a ${role.name} login works at one '
          'branch.';
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
      final login = await widget.repository.createLogin(StaffLoginDraft(
        email: email,
        password: _password.text,
        roleId: _roleId!,
        firstName: _first.text.trim(),
        lastName: _last.text.trim().isEmpty ? null : _last.text.trim(),
        phoneNumber: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        staffId: _staffId.isEmpty ? null : _staffId,
        locationId: _branchId.isEmpty ? null : _branchId,
        forcePasswordChange: _forceChange,
      ));
      if (mounted) Navigator.pop(context, login);
    } catch (e) {
      if (mounted) setState(() => _error = staffErrorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String label, TextEditingController c,
          {Key? key, bool obscure = false, bool required = false}) =>
      StaffField(
        label: label,
        required: required,
        child: TextField(
            key: key,
            controller: c,
            obscureText: obscure,
            style: const TextStyle(fontSize: 13.5),
            decoration: staffInput()),
      );

  @override
  Widget build(BuildContext context) {
    final linked = {
      for (final l in widget.logins)
        if (l.staffId != null) l.staffId!
    };
    return StaffDialog(
      title: 'Add New Staff',
      subtitle: 'A login for the POS or vendor panel',
      width: 600,
      error: _error,
      actions: [
        MasterButton(
            label: 'Cancel',
            onPressed: _saving ? null : () => Navigator.pop(context)),
        MasterButton(
            key: const Key('login-save'),
            label: _saving ? 'Saving…' : 'Create login',
            kind: MasterButtonKind.primary,
            onPressed: _saving ? null : _save),
      ],
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        StaffFormRow(children: [
          StaffField(
            label: 'Link to staff member',
            child: StaffSelect<String>(
              key: const Key('login-staff'),
              value: _staffId,
              items: [
                ('', 'Not linked'),
                for (final s in widget.staff)
                  if (!linked.contains(s.id))
                    (s.id, staffPickLabel(s.fullName, s.staffCode)),
              ],
              onChanged: _pickStaff,
            ),
          ),
          if (widget.branches.isNotEmpty)
            StaffField(
              label: 'Home branch',
              required: widget.branches.length > 1 &&
                  staffBranchBoundRoles.contains(_roles
                      .where((r) => r.id == _roleId)
                      .firstOrNull
                      ?.baseRole),
              child: StaffSelect<String>(
                key: const Key('login-branch'),
                value: _branchId,
                items: [
                  ...staffBranchItems(widget.branches,
                      noneLabel: 'All branches'),
                  if (_branchId.isNotEmpty &&
                      !widget.branches.any((b) => b.id == _branchId))
                    (
                      _branchId,
                      staffBranchName(_branchId, null, widget.branches)
                    ),
                ],
                onChanged: (v) => setState(() => _branchId = v ?? ''),
              ),
            ),
        ]),
        StaffFormRow(children: [
          _field('First name', _first,
              key: const Key('login-first'), required: true),
          _field('Last name', _last, key: const Key('login-last')),
        ]),
        StaffFormRow(children: [
          _field('Email', _email,
              key: const Key('login-email'), required: true),
          _field('Phone', _phone, key: const Key('login-phone')),
        ]),
        if (_roles.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: MasterBanner(
              tone: PillTone.amber,
              title: 'No staff roles yet',
              message: 'Seed the default roles to pick one here.',
              trailing: MasterButton(
                  key: const Key('login-seed-roles'),
                  label: _seeding ? 'Seeding…' : 'Seed default roles',
                  onPressed: _seeding ? null : _seed),
            ),
          ),
        StaffFormRow(children: [
          StaffField(
            label: 'Role',
            required: true,
            child: StaffSelect<String>(
              key: const Key('login-role'),
              value: _roleId,
              hint: _roles.isEmpty ? 'No roles yet' : 'Select role',
              items: [for (final r in _roles) (r.id, r.name)],
              onChanged:
                  _roles.isEmpty ? null : (v) => setState(() => _roleId = v),
            ),
          ),
          _field('Password', _password,
              key: const Key('login-password'), obscure: true, required: true),
        ]),
        Row(children: [
          Checkbox(
            value: _forceChange,
            activeColor: ViniiColors.greenSolid,
            onChanged: (v) => setState(() => _forceChange = v ?? false),
          ),
          const Flexible(
            child: Text('Ask to change password at first login',
                style: MasterStyle.body),
          ),
        ]),
      ]),
    );
  }
}
