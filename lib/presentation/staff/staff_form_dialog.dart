import 'package:flutter/material.dart';

import '../../data/csv.dart';
import '../../data/staff_repository.dart';
import '../../domain/vendor_account.dart' show BranchLocation;
import '../master/master_ui.dart';
import '../vinii_theme.dart';
import 'staff_ui.dart';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Offered in the Designation field until the restaurant has its own.
const _commonDesignations = [
  'Manager',
  'Captain',
  'Cashier',
  'Chef',
  'Cook',
  'Waiter',
  'Helper',
  'Delivery',
];

/// Offered in the Department field until the restaurant has its own.
const _commonDepartments = [
  'Kitchen',
  'Service',
  'Billing',
  'Operations',
  'Delivery',
  'Management',
];

/// Add Staff / Edit Staff (v1/staff managment/staff-add-modal-v3.png) plus
/// the "App access" section that gives the employee a login with a staff
/// role. Returns the saved employee, or null when cancelled.
///
/// [branches] fills the Branch picker (hidden when empty); a new employee
/// starts at the only branch, else at [defaultBranchId].
Future<StaffMember?> showStaffFormDialog(
        BuildContext context, StaffRepository repository,
        {StaffMember? existing,
        List<BranchLocation> branches = const [],
        String? defaultBranchId}) =>
    showDialog<StaffMember>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StaffFormDialog(
          repository: repository,
          existing: existing,
          branches: branches,
          defaultBranchId: defaultBranchId),
    );

class _StaffFormDialog extends StatefulWidget {
  const _StaffFormDialog(
      {required this.repository,
      this.existing,
      this.branches = const [],
      this.defaultBranchId});
  final StaffRepository repository;
  final StaffMember? existing;
  final List<BranchLocation> branches;
  final String? defaultBranchId;

  @override
  State<_StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends State<_StaffFormDialog> {
  final _form = GlobalKey<FormState>();
  late final StaffMember? _e = widget.existing;
  late final _name = TextEditingController(text: _e?.fullName);
  late final _mobile = TextEditingController(text: _e?.mobile);
  late final _email = TextEditingController(text: _e?.email);
  late final _emergency = TextEditingController(text: _e?.emergencyContact);
  late final _designation = TextEditingController(text: _e?.designation);
  late final _department = TextEditingController(text: _e?.department);
  late final _bank = TextEditingController(text: _e?.bankName);
  late final _account = TextEditingController(text: _e?.accountNumber);
  late final _ifsc = TextEditingController(text: _e?.ifsc);
  late final _upi = TextEditingController(text: _e?.upiId);
  late final _photo = TextEditingController(text: _e?.photoUrl);
  late final _idProof = TextEditingController(text: _e?.idProofUrl);
  late final _address = TextEditingController(text: _e?.address);
  late final _monthly =
      TextEditingController(text: staffNumText(_e?.monthlySalary ?? 0));
  late final _daily =
      TextEditingController(text: staffNumText(_e?.dailyWage ?? 0));
  late final _hourly =
      TextEditingController(text: staffNumText(_e?.hourlyRate ?? 0));
  late final _hours =
      TextEditingController(text: staffNumText(_e?.workingHours ?? 8));
  late final _incentiveValue =
      TextEditingController(text: staffNumText(_e?.incentiveValue ?? 0));
  final _password = TextEditingController();

  late DateTime _joining =
      DateTime.tryParse(_e?.joiningDate ?? '') ?? staffToday();
  late String _salaryType = _e?.salaryType ?? 'monthly';
  late String _compensation = _e?.compensationModel ?? 'salary_incentive';
  late String _incentiveType = _e?.incentiveType ?? 'sales_target';
  late bool _active = _e?.isActive ?? true;

  bool _giveLogin = false;
  String? _roleId;
  bool _forceChange = true;
  List<StaffRole>? _roles;
  String? _rolesError;
  bool _seeding = false;
  bool _saving = false;
  String? _error;

  /// Branch id; '' = the whole restaurant (no single branch).
  late String _branchId = _initialBranch();

  /// Departments and designations already in use, for the suggestions.
  List<String> _departments = const [];
  List<String> _designations = const [];

  bool get _canAddLogin => !(_e?.hasLogin ?? false);

  String _initialBranch() {
    final e = _e;
    if (e != null) return e.locationId ?? '';
    final branches = widget.branches;
    if (branches.length == 1) return branches.single.id;
    final d = widget.defaultBranchId;
    if (d != null && branches.any((b) => b.id == d)) return d;
    return '';
  }

  @override
  void initState() {
    super.initState();
    if (_canAddLogin) _loadRoles();
    _loadSuggestions();
  }

  /// Existing departments / designations; the form works without them.
  Future<void> _loadSuggestions() async {
    try {
      final staff = await widget.repository.employees();
      if (!mounted) return;
      final deps = <String>{};
      final titles = <String>{};
      for (final s in staff) {
        if (s.department.trim().isNotEmpty) deps.add(s.department.trim());
        if (s.designation.trim().isNotEmpty) titles.add(s.designation.trim());
      }
      setState(() {
        _departments = deps.toList()..sort();
        _designations = titles.toList()..sort();
      });
    } catch (_) {}
  }

  List<String> get _departmentOptions =>
      [..._departments, ..._commonDepartments];

  List<String> get _designationOptions => [
        ..._designations,
        for (final r in _roles ?? const <StaffRole>[]) r.name,
        ..._commonDesignations,
      ];

  @override
  void dispose() {
    for (final c in [
      _name,
      _mobile,
      _email,
      _emergency,
      _designation,
      _department,
      _bank,
      _account,
      _ifsc,
      _upi,
      _photo,
      _idProof,
      _address,
      _monthly,
      _daily,
      _hourly,
      _hours,
      _incentiveValue,
      _password,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadRoles() async {
    try {
      final o = await widget.repository.roles();
      if (mounted) setState(() => _roles = o.roles);
    } catch (e) {
      if (mounted) setState(() => _rolesError = staffErrorText(e));
    }
  }

  Future<void> _seedRoles() async {
    setState(() => _seeding = true);
    try {
      final roles = await widget.repository.seedDefaultRoles();
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _rolesError = null;
      });
    } catch (e) {
      if (mounted) setState(() => _rolesError = staffErrorText(e));
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  String? _numValidator(String? v) {
    final n = staffParseNum(v ?? '');
    if (n == null) return 'Enter a number';
    if (n < 0) return 'Cannot be negative';
    return null;
  }

  double _n(TextEditingController c) => staffParseNum(c.text) ?? 0;

  Future<void> _save() async {
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_giveLogin && _roleId == null) {
      setState(() => _error = 'Pick a login role for the app login.');
      return;
    }
    final role = (_roles ?? const <StaffRole>[])
        .where((r) => r.id == _roleId)
        .firstOrNull;
    if (_giveLogin &&
        _branchId.isEmpty &&
        widget.branches.length > 1 &&
        role != null &&
        staffBranchBoundRoles.contains(role.baseRole)) {
      setState(() => _error = 'Pick the branch this person works at — a '
          '${role.name} login works at one branch.');
      return;
    }
    final draft = StaffMember(
      fullName: _name.text.trim(),
      mobile: _mobile.text.trim(),
      email: _email.text.trim(),
      emergencyContact: _emergency.text.trim(),
      designation: _designation.text.trim(),
      department: _department.text.trim(),
      bankName: _bank.text.trim(),
      accountNumber: _account.text.trim(),
      ifsc: _ifsc.text.trim().toUpperCase(),
      upiId: _upi.text.trim(),
      photoUrl: _photo.text.trim(),
      idProofUrl: _idProof.text.trim(),
      address: _address.text.trim(),
      joiningDate: isoDate(_joining),
      salaryType: _salaryType,
      monthlySalary: _n(_monthly),
      dailyWage: _n(_daily),
      hourlyRate: _n(_hourly),
      workingHours: _n(_hours),
      compensationModel: _compensation,
      incentiveType: _incentiveType,
      incentiveValue:
          _compensation == 'salary_incentive' ? _n(_incentiveValue) : 0,
      status: _active ? 'active' : 'inactive',
      locationId: _branchId.isEmpty ? null : _branchId,
      deliveryEnabled: _e?.deliveryEnabled ?? false,
    );
    StaffLoginDraft? login;
    if (_giveLogin) {
      final parts = draft.fullName.split(RegExp(r'\s+'));
      login = StaffLoginDraft(
        email: _email.text.trim(),
        password: _password.text,
        roleId: _roleId!,
        firstName: parts.first,
        lastName: parts.length > 1 ? parts.sublist(1).join(' ') : null,
        phoneNumber: draft.mobile.isEmpty ? null : draft.mobile,
        staffId: _e?.id,
        // The login works where the employee works.
        locationId: _branchId.isEmpty ? null : _branchId,
        forcePasswordChange: _forceChange,
      );
    }
    setState(() => _saving = true);
    try {
      StaffMember saved;
      final existing = _e;
      if (existing == null) {
        saved = await widget.repository.createEmployee(draft, login: login);
      } else {
        saved =
            await widget.repository.updateEmployee(existing.id, draft.toJson());
        if (login != null) await widget.repository.createLogin(login);
      }
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) setState(() => _error = staffErrorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _text(String label, TextEditingController c,
          {Key? key,
          bool required = false,
          String? Function(String?)? validator,
          TextInputType? keyboard,
          int maxLines = 1,
          Widget? suffix,
          bool obscure = false,
          String? hint}) =>
      StaffField(
        label: label,
        required: required,
        child: TextFormField(
          key: key,
          controller: c,
          validator: validator,
          keyboardType: keyboard,
          maxLines: maxLines,
          obscureText: obscure,
          style: const TextStyle(fontSize: 13.5),
          decoration: staffInput(suffix: suffix, hint: hint),
        ),
      );

  Widget _dropdown(String label, String value, List<(String, String)> items,
          ValueChanged<String> onChanged,
          {Key? key}) =>
      StaffField(
        label: label,
        child: DropdownButtonFormField<String>(
          key: key,
          initialValue: value,
          isExpanded: true,
          style: staffDropdownStyle(context, 13.5),
          decoration: staffInput(),
          items: [
            for (final (v, l) in items)
              DropdownMenuItem(
                  value: v, child: Text(l, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      );

  Widget _statusPill(String label, bool on, VoidCallback onTap) => Material(
        color: on ? ViniiColors.brandGreen : Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: on ? ViniiColors.brandGreen : kStaffBorder),
            ),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ViniiColors.textPrimaryLight)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final editing = _e != null;
    return StaffDialog(
      title: editing ? 'Edit Staff' : 'Add Staff',
      width: 620,
      error: _error,
      actions: [
        MasterButton(
            label: 'Cancel',
            onPressed: _saving ? null : () => Navigator.pop(context)),
        MasterButton(
          key: const Key('staff-create'),
          label: _saving ? 'Saving…' : (editing ? 'Save' : 'Create'),
          kind: MasterButtonKind.primary,
          onPressed: _saving ? null : _save,
        ),
      ],
      body: Form(
        key: _form,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          StaffFormRow(children: [
            _text('Name', _name,
                key: const Key('staff-name'),
                required: true,
                suffix: const Icon(Icons.person_outline,
                    size: 18, color: ViniiColors.textMutedLight),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Name is required' : null),
            _text('Mobile', _mobile,
                key: const Key('staff-mobile'), keyboard: TextInputType.phone),
          ]),
          StaffFormRow(children: [
            _text('Email', _email,
                key: const Key('staff-email'),
                keyboard: TextInputType.emailAddress, validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) {
                return _giveLogin ? 'Email is needed for the login' : null;
              }
              return _emailRe.hasMatch(t) ? null : 'Enter a valid email';
            }),
            _text('Emergency Contact', _emergency,
                keyboard: TextInputType.phone),
          ]),
          StaffFormRow(children: [
            StaffField(
              label: 'Designation',
              child: StaffSuggestField(
                fieldKey: const Key('staff-designation'),
                controller: _designation,
                suggestions: _designationOptions,
                hint: 'Pick or type, e.g. Captain',
              ),
            ),
            StaffField(
              label: 'Department',
              child: StaffSuggestField(
                fieldKey: const Key('staff-department'),
                controller: _department,
                suggestions: _departmentOptions,
                hint: 'Pick or type a new one',
              ),
            ),
          ]),
          if (widget.branches.isNotEmpty)
            StaffFormRow(children: [
              StaffField(
                label: 'Branch',
                required: _giveLogin &&
                    widget.branches.length > 1 &&
                    staffBranchBoundRoles.contains((_roles ?? const <StaffRole>[])
                        .where((r) => r.id == _roleId)
                        .firstOrNull
                        ?.baseRole),
                child: StaffSelect<String>(
                  key: const Key('staff-branch'),
                  value: _branchId,
                  items: [
                    ...staffBranchItems(widget.branches),
                    if (_branchId.isNotEmpty &&
                        !widget.branches.any((b) => b.id == _branchId))
                      (
                        _branchId,
                        staffBranchName(
                            _branchId, _e?.locationName, widget.branches)
                      ),
                  ],
                  onChanged: (v) => setState(() => _branchId = v ?? ''),
                ),
              ),
            ]),
          StaffFormRow(children: [
            _text('Bank Name', _bank),
            _text('Account Number', _account, keyboard: TextInputType.number),
          ]),
          StaffFormRow(children: [
            _text('IFSC', _ifsc),
            _text('UPI ID', _upi),
          ]),
          StaffFormRow(children: [
            _text('Photo URL', _photo, keyboard: TextInputType.url),
            _text('ID Proof URL', _idProof, keyboard: TextInputType.url),
          ]),
          StaffFormRow(children: [
            _text('Address', _address, maxLines: 3),
          ]),
          StaffFormRow(children: [
            StaffField(
              label: 'Joining Date',
              child: StaffDateButton(
                  value: _joining,
                  onChanged: (d) => setState(() => _joining = d)),
            ),
            _dropdown(
                'Salary Type',
                _salaryType,
                const [
                  ('monthly', 'Monthly'),
                  ('daily', 'Daily'),
                  ('hourly', 'Hourly'),
                ],
                (v) => setState(() => _salaryType = v),
                key: const Key('staff-salary-type')),
          ]),
          StaffFormRow(children: [
            _text('Monthly Salary', _monthly,
                key: const Key('staff-monthly-salary'),
                keyboard: TextInputType.number,
                validator: _numValidator),
            _text('Daily Wage', _daily,
                keyboard: TextInputType.number, validator: _numValidator),
          ]),
          StaffFormRow(children: [
            _text('Hourly Rate', _hourly,
                keyboard: TextInputType.number, validator: _numValidator),
            _text('Working Hours', _hours, keyboard: TextInputType.number,
                validator: (v) {
              final n = staffParseNum(v ?? '');
              if (n == null || n <= 0 || n > 24) return 'Enter 1–24 hours';
              return null;
            }),
          ]),
          StaffFormRow(children: [
            _dropdown(
                'Compensation Model',
                _compensation,
                const [
                  ('salary_only', 'Salary only'),
                  ('salary_incentive', 'Salary + incentive'),
                ],
                (v) => setState(() => _compensation = v)),
          ]),
          if (_compensation == 'salary_incentive') ...[
            StaffFormRow(children: [
              _dropdown(
                  'Incentive Type',
                  _incentiveType,
                  const [
                    ('sales_target', 'Sales target'),
                    ('fixed_amount', 'Fixed amount'),
                    ('percentage', 'Percentage'),
                  ],
                  (v) => setState(() => _incentiveType = v)),
            ]),
            StaffFormRow(children: [
              _text(
                  _incentiveType == 'percentage'
                      ? 'Incentive Value (% of basic)'
                      : 'Incentive Value',
                  _incentiveValue,
                  keyboard: TextInputType.number,
                  validator: _numValidator),
            ]),
          ],
          StaffField(
            label: 'Status',
            child: Wrap(spacing: 8, children: [
              _statusPill(
                  'Active', _active, () => setState(() => _active = true)),
              _statusPill(
                  'Inactive', !_active, () => setState(() => _active = false)),
            ]),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: kStaffBorder),
          const SizedBox(height: 16),
          _appAccess(),
        ]),
      ),
    );
  }

  Widget _appAccess() {
    final e = _e;
    if (e != null && e.hasLogin) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('App access', style: MasterStyle.sectionTitle),
        const SizedBox(height: 8),
        MasterBanner(
          tone: PillTone.green,
          message: 'Has an app login (${e.loginEmail ?? 'no email'}) '
              '· role ${e.roleName ?? 'not set'} · '
              '${e.loginStatus ?? 'Active'}. Change the role or status '
              'in Roles & permissions → Staff access.',
        ),
      ]);
    }
    final roles = _roles;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('App access', style: MasterStyle.sectionTitle),
            SizedBox(height: 2),
            Text(
                'Give this person a login for the POS / vendor panel. '
                'The role decides which screens they can open.',
                style: MasterStyle.muted),
          ]),
        ),
        const SizedBox(width: 12),
        Text('Give app login',
            style: MasterStyle.body.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Switch(
          key: const Key('staff-login-switch'),
          value: _giveLogin,
          activeThumbColor: Colors.white,
          activeTrackColor: ViniiColors.brandGreen,
          onChanged: (v) => setState(() => _giveLogin = v),
        ),
      ]),
      if (_giveLogin) ...[
        const SizedBox(height: 14),
        if (_rolesError != null) ...[
          MasterBanner(tone: PillTone.red, message: _rolesError!),
          const SizedBox(height: 12),
        ],
        if (roles == null)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (roles.isEmpty)
          MasterBanner(
            tone: PillTone.amber,
            title: 'No staff roles yet',
            message: 'Seed the default roles (Restaurant Admin, Branch Manager, '
                'Cashier, Captain, Kitchen) '
                'or create a custom one in Roles & permissions.',
            trailing: MasterButton(
              key: const Key('staff-seed-roles'),
              label: _seeding ? 'Seeding…' : 'Seed default roles',
              icon: Icons.download_outlined,
              onPressed: _seeding ? null : _seedRoles,
            ),
          )
        else
          StaffFormRow(children: [
            StaffField(
              label: 'Login role',
              required: true,
              child: DropdownButtonFormField<String>(
                key: const Key('staff-login-role'),
                initialValue: _roleId,
                isExpanded: true,
                hint: const Text('Select role',
                    style: TextStyle(
                        fontSize: 13.5, color: ViniiColors.textMutedLight)),
                style: staffDropdownStyle(context, 13.5),
                decoration: staffInput(),
                items: [
                  for (final r in roles)
                    DropdownMenuItem(
                        value: r.id,
                        child: Text(r.name, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _roleId = v),
              ),
            ),
            _text('Password', _password,
                key: const Key('staff-login-password'),
                required: true,
                obscure: true,
                hint: 'At least 8 characters',
                validator: (v) => !_giveLogin || (v ?? '').length >= 8
                    ? null
                    : 'At least 8 characters'),
          ]),
        if (roles != null && roles.isNotEmpty) ...[
          if (_roleId != null) _roleHint(roles),
          Row(children: [
            Checkbox(
              key: const Key('staff-login-force-change'),
              value: _forceChange,
              activeColor: ViniiColors.greenSolid,
              onChanged: (v) => setState(() => _forceChange = v ?? false),
            ),
            const Flexible(
              child: Text('Ask to change password at first login',
                  style: MasterStyle.body),
            ),
          ]),
          Text(
              widget.branches.isEmpty
                  ? 'The login uses the Email above.'
                  : 'The login uses the Email above and works at '
                      '${_branchId.isEmpty ? 'every branch' : staffBranchName(_branchId, null, widget.branches)}.',
              style: MasterStyle.muted),
        ],
      ],
    ]);
  }

  Widget _roleHint(List<StaffRole> roles) {
    final r = roles.where((r) => r.id == _roleId).firstOrNull;
    if (r == null) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
          '${r.name} works on the ${r.panel == 'pos' ? 'POS terminal' : 'vendor panel'} '
          'and opens ${r.screens.length} screen${r.screens.length == 1 ? '' : 's'}.',
          style: MasterStyle.muted),
    );
  }
}

/// "Import staff": paste CSV rows (name,mobile,email,designation,department,
/// monthly_salary) and create one employee per row. Returns how many were
/// created, or null when cancelled.
Future<int?> showStaffImportDialog(
        BuildContext context, StaffRepository repository) =>
    showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StaffImportDialog(repository: repository),
    );

class _StaffImportDialog extends StatefulWidget {
  const _StaffImportDialog({required this.repository});
  final StaffRepository repository;

  @override
  State<_StaffImportDialog> createState() => _StaffImportDialogState();
}

class _StaffImportDialogState extends State<_StaffImportDialog> {
  final _text = TextEditingController(
      text: 'name,mobile,email,designation,department,monthly_salary\n');
  bool _running = false;
  String? _error;
  final _problems = <String>[];
  int _created = 0;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final records = Csv.decode(_text.text);
    setState(() {
      _error = null;
      _problems.clear();
    });
    if (records.isEmpty) {
      setState(() => _error = 'Paste a header row and at least one staff row.');
      return;
    }
    setState(() => _running = true);
    var created = 0;
    final failed = <int>{};
    for (final r in records) {
      final name = r('name', r('full_name'));
      if (name.isEmpty) {
        _problems.add('Line ${r.line}: name is missing');
        failed.add(r.line);
        continue;
      }
      final email = r('email');
      if (email.isNotEmpty && !_emailRe.hasMatch(email)) {
        _problems.add('Line ${r.line}: "$email" is not a valid email');
        failed.add(r.line);
        continue;
      }
      try {
        await widget.repository.createEmployee(StaffMember(
          fullName: name,
          mobile: r('mobile', r('phone')),
          email: email,
          designation: r('designation', r('role')),
          department: r('department', r('dept')),
          monthlySalary: r.number('monthly_salary') ?? r.number('salary') ?? 0,
          joiningDate: isoDate(staffToday()),
          compensationModel: 'salary_only',
        ));
        created++;
      } catch (e) {
        _problems.add('Line ${r.line}: ${staffErrorText(e)}');
        failed.add(r.line);
      }
    }
    if (!mounted) return;
    _created += created;
    setState(() => _running = false);
    if (_problems.isEmpty) {
      Navigator.pop(context, _created);
      return;
    }
    // Leave only the header and the rows that failed, so a second import
    // doesn't duplicate the ones that went in.
    final rows = Csv.decodeRows(_text.text);
    _text.text = Csv.encode(rows.first, [
      for (var i = 1; i < rows.length; i++)
        if (failed.contains(i + 1)) rows[i]
    ]);
    setState(() => _error = 'Imported $created. ${_problems.length} row(s) '
        'were skipped and left below — fix them and import again.');
  }

  @override
  Widget build(BuildContext context) => StaffDialog(
        title: 'Import staff',
        subtitle: 'Paste CSV rows — one employee per line',
        width: 640,
        error: _error,
        onClose: _running
            ? null
            : () => Navigator.pop(context, _created == 0 ? null : _created),
        actions: [
          MasterButton(
              label: _created == 0 ? 'Cancel' : 'Close',
              onPressed: _running
                  ? null
                  : () =>
                      Navigator.pop(context, _created == 0 ? null : _created)),
          MasterButton(
            key: const Key('staff-import-submit'),
            label: _running ? 'Importing…' : 'Import',
            kind: MasterButtonKind.primary,
            icon: Icons.upload_outlined,
            onPressed: _running ? null : _import,
          ),
        ],
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text(
              'Columns: name, mobile, email, designation, department, '
              'monthly_salary. Only name is required. Joining date is set to '
              'today; edit anything else in the Staff tab afterwards.',
              style: MasterStyle.muted),
          const SizedBox(height: 12),
          TextField(
            key: const Key('staff-import-text'),
            controller: _text,
            maxLines: 10,
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            decoration: staffInput(
                hint: 'Asha Patil,+91 9000000000,asha@example.com,Captain,'
                    'Service,15000'),
          ),
          if (_problems.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final p in _problems.take(8))
              Text('• $p',
                  style: const TextStyle(
                      fontSize: 12.5, color: ViniiColors.redSolid)),
            if (_problems.length > 8)
              Text('…and ${_problems.length - 8} more',
                  style: MasterStyle.muted),
          ],
        ]),
      );
}
