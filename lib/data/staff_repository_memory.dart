import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import '../domain/access.dart';
import 'staff_repository.dart';

/// On-device [StaffRepository] for the local demo mode and widget tests.
///
/// Rows are kept in the same JSON shape the backend returns and turned into
/// models with the models' own `fromJson`, so both repositories feed the UI
/// identically. The rules (role screen limits, salary maths, roster flags,
/// approval side effects, audit trail) mirror the backend's `/v1/staff/*`.
class InMemoryStaffRepository implements StaffRepository {
  InMemoryStaffRepository({bool seedDemo = true, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    if (seedDemo) _seedDemo();
  }

  final DateTime Function() _clock;

  @override
  bool get live => false;

  int _seq = 0;
  int _codeSeq = 0;
  String _id(String prefix) => '$prefix-${++_seq}';

  final _employees = <Map<String, dynamic>>[];
  final _logins = <Map<String, dynamic>>[];
  final _passwords = <String, String>{};
  final _roles = <Map<String, dynamic>>[];

  /// Keyed by `staffId|YYYY-MM-DD`.
  final _attendance = <String, Map<String, dynamic>>{};
  final _shifts = <Map<String, dynamic>>[];
  final _roster = <Map<String, dynamic>>[];
  final _advances = <Map<String, dynamic>>[];
  final _salaries = <Map<String, dynamic>>[];
  final _approvals = <Map<String, dynamic>>[];
  final _audit = <AuditEntry>[];
  final _loginEvents = <LoginEvent>[];
  final _modules = <Map<String, dynamic>>[];
  final _attempts = <Map<String, dynamic>>[];

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const _attendanceStatuses = {
    'present',
    'absent',
    'half_day',
    'leave',
    'week_off',
  };
  static const _approvalTypes = {
    'leave',
    'salary_advance',
    'shift_change',
    'attendance_correction',
    'other',
  };
  static const _approvalLabels = {
    'leave': 'leave',
    'salary_advance': 'salary advance',
    'shift_change': 'shift change',
    'attendance_correction': 'attendance correction',
    'other': 'other',
  };
  static const _defaultRoles = <(String, String, Set<String>?)>[
    ('Restaurant Admin', 'org_admin', null),
    ('Branch Manager', 'location_manager', null),
    ('Cashier', 'biller', null),
    ('Captain', 'captain', null),
    ('Kitchen (KOT)', 'kitchen', null),
  ];

  // ── seed ───────────────────────────────────────────────────────────────

  void _seedDemo() {
    const people = [
      (
        'Pravin M',
        'Captain',
        'Operations',
        '2023-10-12',
        24000.0,
        '+91 9988776655'
      ),
      (
        'Suresh Kumar',
        'Cashier',
        'Billing',
        '2023-11-01',
        18000.0,
        '+91 8877665544'
      ),
      (
        'Ramesh Singh',
        'Chef',
        'Kitchen',
        '2022-06-15',
        35000.0,
        '+91 7766554433'
      ),
    ];
    for (final p in people) {
      _employees.add({
        ...StaffMember(
          fullName: p.$1,
          designation: p.$2,
          department: p.$3,
          joiningDate: p.$4,
          monthlySalary: p.$5,
          mobile: p.$6,
        ).toJson(),
        'id': _id('emp'),
        'staff_code': _nextStaffCode(),
      });
    }
    for (final s in const [
      Shift(name: 'Morning', startTime: '09:00', endTime: '17:00'),
      Shift(name: 'Evening', startTime: '16:00', endTime: '00:00'),
    ]) {
      _shifts.add({...s.toJson(), 'id': _id('shift')});
    }
    final now = _clock();
    final owner = <String, dynamic>{
      'user_id': _id('user'),
      'full_name': 'Owner',
      'email': 'owner@demo.proviyaa.in',
      'phone_number': '+91 9000000001',
      'pos_role': 'org_owner',
      'role_id': null,
      'status': 'Active',
      'staff_id': null,
      'delivery_enabled': false,
      'last_login_at': now.toIso8601String(),
      'last_seen_at': now.toIso8601String(),
      'failed_attempts': 0,
      'force_password_change': false,
      'two_factor_enabled': false,
      'location_id': null,
    };
    _logins.add(owner);
    _loginEvents.add(LoginEvent(
      id: _id('login-event'),
      email: owner['email'] as String,
      fullName: owner['full_name'] as String,
      success: true,
      ip: '127.0.0.1',
      userAgent: 'Proviyaa vendor panel (demo)',
      at: now,
    ));
  }

  String _nextStaffCode() => 'VIN-${(++_codeSeq).toString().padLeft(3, '0')}';

  // ── helpers ────────────────────────────────────────────────────────────

  static double _money(num v) => (v * 100).roundToDouble() / 100;
  static double _d(Object? v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Minutes after midnight for an `HH:MM` time, or null when malformed.
  static int? _minutesOf(String? hhmm) {
    if (hhmm == null) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hhmm.trim());
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return null;
    return h * 60 + min;
  }

  static void _checkTime(String? v, String field) {
    if (v == null || v.isEmpty) return;
    if (_minutesOf(v) == null) {
      throw ArgumentError('$field must be a time like 09:30.');
    }
  }

  static DateTime? _day(Object? v) {
    final d = v == null ? null : DateTime.tryParse('$v');
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  static String _hash(String password) =>
      sha256.convert(utf8.encode(password)).toString();

  /// Records an action like the backend's audit(): [details] names whose
  /// record it was (name / staff / email / title / role).
  void _log(String action, String entity,
          [String? entityId, Map<String, dynamic> details = const {}]) =>
      _audit.insert(
          0,
          AuditEntry(
            id: _id('audit'),
            at: _clock(),
            action: action,
            entity: entity,
            entityId: entityId,
            actorName: 'You',
            details: details,
          ));

  Map<String, dynamic>? _employeeRow(String? id) =>
      id == null ? null : _employees.where((e) => e['id'] == id).firstOrNull;

  Map<String, dynamic> _requireEmployee(String id) =>
      _employeeRow(id) ?? (throw StateError('Staff member not found.'));

  bool _isActive(Map<String, dynamic> e) => e['status'] == 'active';

  Iterable<Map<String, dynamic>> get _activeEmployees =>
      _employees.where(_isActive);

  Map<String, dynamic>? _loginRow(String userId) =>
      _logins.where((l) => l['user_id'] == userId).firstOrNull;

  Map<String, dynamic>? _loginForStaff(String? staffId) => staffId == null
      ? null
      : _logins.where((l) => l['staff_id'] == staffId).firstOrNull;

  Map<String, dynamic>? _roleRow(String? id) =>
      id == null ? null : _roles.where((r) => r['id'] == id).firstOrNull;

  StaffMember _member(Map<String, dynamic> e) {
    final login = _loginForStaff(e['id'] as String);
    final role = _roleRow(login?['role_id'] as String?);
    return StaffMember.fromJson({
      ...e,
      'user_id': login?['user_id'],
      'role_id': login?['role_id'],
      'role_name': role?['name'],
      'login': login == null
          ? null
          : {'email': login['email'], 'status': login['status']},
    });
  }

  StaffLogin _loginOut(Map<String, dynamic> l) {
    final role = _roleRow(l['role_id'] as String?);
    final staff = _employeeRow(l['staff_id'] as String?);
    return StaffLogin.fromJson({
      ...l,
      'pos_role_name': posRoleLabel(l['pos_role'] as String?),
      'role_name': role?['name'],
      'staff_name': staff?['full_name'],
      'staff_code': staff?['staff_code'],
    });
  }

  static final Set<String> _vendorScreens = {
    for (final s in Screens.all)
      if (!s.isPos) s.id
  };
  static final Set<String> _posScreens = {
    for (final s in Screens.all)
      if (s.isPos) s.id
  };

  static Set<String> _grantable(String baseRole) =>
      PosRoles.panelFor(baseRole) == 'pos' ? _posScreens : _vendorScreens;

  static void _checkScreens(String baseRole, Set<String> screens) {
    final bad = screens.difference(_grantable(baseRole));
    if (bad.isNotEmpty) {
      throw ArgumentError('${posRoleLabel(baseRole)} roles '
          "can't open: ${bad.map((s) => Screens.byId[s]?.label ?? 'that screen').join(', ')}.");
    }
  }

  StaffRole _roleOut(Map<String, dynamic> r) {
    final base = r['base_role'] as String;
    return StaffRole.fromJson({
      ...r,
      'base_role_name': posRoleLabel(base),
      'panel': PosRoles.panelFor(base),
      'staff_count': _logins.where((l) => l['role_id'] == r['id']).length,
    });
  }

  // ── dashboard ──────────────────────────────────────────────────────────

  @override
  Future<StaffDashboard> dashboard() async {
    final now = _clock();
    final today = isoDate(now);
    final active = _activeEmployees.length;
    final onShift = _roster
        .where((r) =>
            r['date'] == today &&
            r['clock_in'] != null &&
            r['clock_out'] == null &&
            _isActive(_employeeRow(r['staff_id'] as String) ?? const {}))
        .length;
    final todayAttendance =
        _attendance.values.where((a) => a['date'] == today).toList();
    final monthRows = _salaries
        .where((s) => s['year'] == now.year && s['month'] == now.month)
        .toList();
    double sum(String k) => monthRows.fold(0.0, (t, s) => t + _d(s[k]));
    final payable = sum('net');
    final paid = sum('paid');
    final pending = monthRows.fold(
        0.0, (t, s) => t + math.max(0.0, _d(s['net']) - _d(s['paid'])));
    return StaffDashboard(
      total: _employees.length,
      active: active,
      inactive: _employees.length - active,
      onlineNow: _logins.where((l) {
        final seen = DateTime.tryParse('${l['last_seen_at'] ?? ''}');
        return seen != null &&
            now.difference(seen).abs() <= const Duration(minutes: 5);
      }).length,
      onShift: onShift,
      offShift: math.max(0, active - onShift),
      pendingApprovals:
          _approvals.where((a) => a['status'] == 'pending').length,
      presentToday: todayAttendance
          .where((a) => a['status'] == 'present' || a['status'] == 'half_day')
          .length,
      absentToday: todayAttendance.where((a) => a['status'] == 'absent').length,
      payableMonth: _money(payable),
      paidMonth: _money(paid),
      pendingMonth: _money(pending),
      month: '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}',
    );
  }

  // ── employees ──────────────────────────────────────────────────────────

  @override
  Future<List<StaffMember>> employees() async =>
      [for (final e in _employees) _member(e)];

  Map<String, dynamic> _validateLoginDraft(StaffLoginDraft d) {
    final email = d.email.trim().toLowerCase();
    if (!_emailRe.hasMatch(email)) {
      throw ArgumentError('Enter a valid email address for the login.');
    }
    if (_logins.any((l) => '${l['email']}'.toLowerCase() == email)) {
      throw StateError('An account with this email already exists.');
    }
    if (d.password.length < 8) {
      throw ArgumentError('Password must be at least 8 characters.');
    }
    return _roleRow(d.roleId) ??
        (throw ArgumentError('Pick a valid staff role for the login.'));
  }

  Map<String, dynamic> _insertLogin(
      StaffLoginDraft d, Map<String, dynamic> role,
      {Map<String, dynamic>? staff}) {
    final names = [d.firstName?.trim(), d.lastName?.trim()]
        .whereType<String>()
        .where((s) => s.isNotEmpty);
    var fullName = names.join(' ');
    final email = d.email.trim().toLowerCase();
    if (fullName.isEmpty) {
      fullName = (staff?['full_name'] as String?) ?? email.split('@').first;
    }
    final phone = d.phoneNumber?.trim();
    final row = <String, dynamic>{
      'user_id': _id('user'),
      'full_name': fullName,
      'email': email,
      'phone_number': (phone == null || phone.isEmpty)
          ? (staff?['mobile'] as String? ?? '')
          : phone,
      'pos_role': role['base_role'],
      'role_id': role['id'],
      'status': 'Active',
      'staff_id': staff?['id'],
      'delivery_enabled': staff?['delivery_enabled'] == true,
      'last_login_at': null,
      'last_seen_at': null,
      'failed_attempts': 0,
      'force_password_change': d.forcePasswordChange,
      'two_factor_enabled': false,
      // Like the server: the login works at the employee's branch unless
      // another one is picked.
      'location_id': d.locationId ?? staff?['location_id'],
    };
    _passwords[row['user_id'] as String] = _hash(d.password);
    _logins.add(row);
    _log('Created app login', 'Login', row['user_id'] as String,
        {'email': email, 'role': role['name']});
    return row;
  }

  @override
  Future<StaffMember> createEmployee(StaffMember draft,
      {StaffLoginDraft? login}) async {
    final name = draft.fullName.trim();
    if (name.isEmpty) throw ArgumentError('Name is required.');
    final role = login == null ? null : _validateLoginDraft(login);
    final row = <String, dynamic>{
      ...draft.toJson(),
      'full_name': name,
      'id': _id('emp'),
      'staff_code': _nextStaffCode(),
    };
    _employees.add(row);
    _log('Created staff member', 'Staff', row['id'] as String, {'name': name});
    if (login != null) _insertLogin(login, role!, staff: row);
    return _member(row);
  }

  @override
  Future<StaffMember> updateEmployee(
      String id, Map<String, Object?> patch) async {
    final row = _requireEmployee(id);
    const locked = {'id', 'staff_code', 'user_id', 'role_id', 'role_name'};
    final next = <String, dynamic>{...row};
    for (final e in patch.entries) {
      if (locked.contains(e.key)) continue;
      next[e.key] = e.value;
    }
    final name = '${next['full_name'] ?? ''}'.trim();
    if (name.isEmpty) throw ArgumentError('Name is required.');
    next['full_name'] = name;
    // Validate the shape by parsing it before committing.
    StaffMember.fromJson(next);
    row
      ..clear()
      ..addAll(next);
    final login = _loginForStaff(id);
    if (login != null && patch.containsKey('delivery_enabled')) {
      login['delivery_enabled'] = next['delivery_enabled'] == true;
    }
    _log('Updated staff member', 'Staff', id,
        {'name': name, 'fields': patch.keys.toList()});
    return _member(row);
  }

  @override
  Future<void> deleteEmployee(String id) async {
    final row = _requireEmployee(id);
    _employees.remove(row);
    final login = _loginForStaff(id);
    if (login != null) {
      login['status'] = 'Inactive';
      login['staff_id'] = null;
    }
    _roster.removeWhere((r) => r['staff_id'] == id && r['clock_in'] == null);
    _log('Removed staff member', 'Staff', id, {'name': row['full_name']});
  }

  // ── logins ─────────────────────────────────────────────────────────────

  @override
  Future<List<StaffLogin>> logins() async =>
      [for (final l in _logins) _loginOut(l)];

  @override
  Future<StaffLogin> createLogin(StaffLoginDraft draft) async {
    final role = _validateLoginDraft(draft);
    Map<String, dynamic>? staff;
    final staffId = draft.staffId;
    if (staffId != null && staffId.isNotEmpty) {
      staff = _requireEmployee(staffId);
      if (_loginForStaff(staffId) != null) {
        throw StateError('${staff['full_name']} already has a login.');
      }
    }
    return _loginOut(_insertLogin(draft, role, staff: staff));
  }

  @override
  Future<StaffLogin> updateLogin(
      String userId, Map<String, Object?> patch) async {
    final row = _loginRow(userId) ?? (throw StateError('Login not found.'));
    final owner = row['pos_role'] == 'org_owner';
    if (owner &&
        (patch.containsKey('role_id') || patch.containsKey('status'))) {
      throw StateError("The owner's role and status can't be changed.");
    }
    final next = <String, dynamic>{...row};
    for (final e in patch.entries) {
      switch (e.key) {
        case 'role_id':
          final role = _roleRow('${e.value}') ??
              (throw ArgumentError('Pick a valid staff role.'));
          next['role_id'] = role['id'];
          next['pos_role'] = role['base_role'];
        case 'status':
          next['status'] = switch ('${e.value}'.toLowerCase()) {
            'active' => 'Active',
            'inactive' => 'Inactive',
            'suspended' => 'Suspended',
            _ => throw ArgumentError('Unknown status: ${e.value}'),
          };
        case 'staff_id':
          final id = e.value == null ? '' : '${e.value}';
          if (id.isEmpty) {
            next['staff_id'] = null;
          } else {
            final staff = _requireEmployee(id);
            final other = _loginForStaff(id);
            if (other != null && other['user_id'] != userId) {
              throw StateError(
                  '${staff['full_name']} is already linked to another login.');
            }
            next['staff_id'] = id;
          }
        case 'delivery_enabled':
          next['delivery_enabled'] = e.value == true;
        case 'force_password_change':
          next['force_password_change'] = e.value == true;
        case 'two_factor_enabled':
          next['two_factor_enabled'] = e.value == true;
        case 'location_id':
          next['location_id'] = e.value;
        default:
          throw ArgumentError('Unknown login field: ${e.key}');
      }
    }
    row
      ..clear()
      ..addAll(next);
    if (patch.containsKey('delivery_enabled')) {
      final staff = _employeeRow(row['staff_id'] as String?);
      if (staff != null) staff['delivery_enabled'] = row['delivery_enabled'];
    }
    _log('Updated app login', 'Login', userId,
        {'email': row['email'], 'changes': patch.keys.toList()});
    return _loginOut(row);
  }

  @override
  Future<void> resetPassword(String userId, String password,
      {bool forceChange = true}) async {
    final row = _loginRow(userId) ?? (throw StateError('Login not found.'));
    if (password.length < 8) {
      throw ArgumentError('Password must be at least 8 characters.');
    }
    _passwords[userId] = _hash(password);
    row['failed_attempts'] = 0;
    row['locked_until'] = null;
    row['force_password_change'] = forceChange;
    _log('Reset password', 'Login', userId, {'email': row['email']});
  }

  @override
  Future<List<LoginEvent>> loginHistory() async {
    final list = [..._loginEvents]..sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  // ── roles ──────────────────────────────────────────────────────────────

  @override
  Future<RolesOverview> roles() async => RolesOverview(
        roles: [for (final r in _roles) _roleOut(r)],
        baseRoles: [
          for (final k in PosRoles.names.keys)
            BaseRoleInfo(
              key: k,
              name: PosRoles.names[k]!,
              panel: PosRoles.panelFor(k),
              grantable: _grantable(k),
              defaultScreens: PosRoles.defaultScreens(k),
            ),
        ],
      );

  void _checkRoleName(String name, {String? exceptId}) {
    if (name.isEmpty) throw ArgumentError('Role name is required.');
    if (_roles.any((r) =>
        r['id'] != exceptId &&
        '${r['name']}'.toLowerCase() == name.toLowerCase())) {
      throw StateError('A role named "$name" already exists.');
    }
  }

  static void _checkBase(String baseRole) {
    if (!PosRoles.names.containsKey(baseRole)) {
      throw ArgumentError('Unknown base role: $baseRole');
    }
  }

  @override
  Future<StaffRole> createRole({
    required String name,
    required String baseRole,
    Set<String>? screens,
    String description = '',
  }) async {
    final n = name.trim();
    _checkBase(baseRole);
    _checkRoleName(n);
    final s = screens ?? PosRoles.defaultScreens(baseRole);
    _checkScreens(baseRole, s);
    final row = <String, dynamic>{
      'id': _id('role'),
      'name': n,
      'base_role': baseRole,
      'screens': s.toList(),
      'description': description,
      'is_default': false,
    };
    _roles.add(row);
    _log('Created role', 'Role', row['id'] as String,
        {'name': n, 'base_role': baseRole});
    return _roleOut(row);
  }

  @override
  Future<StaffRole> updateRole(String id,
      {String? name,
      String? baseRole,
      Set<String>? screens,
      String? description}) async {
    final row = _roleRow(id) ?? (throw StateError('Role not found.'));
    final n = name?.trim();
    if (n != null) _checkRoleName(n, exceptId: id);
    final base = baseRole ?? row['base_role'] as String;
    _checkBase(base);
    Set<String> nextScreens;
    if (screens != null) {
      nextScreens = screens;
    } else if (base != row['base_role']) {
      nextScreens = {
        for (final s in (row['screens'] as List))
          if (_grantable(base).contains(s)) '$s'
      };
      if (nextScreens.isEmpty) nextScreens = PosRoles.defaultScreens(base);
    } else {
      nextScreens = {for (final s in (row['screens'] as List)) '$s'};
    }
    _checkScreens(base, nextScreens);
    if (n != null) row['name'] = n;
    if (description != null) row['description'] = description;
    row['base_role'] = base;
    row['screens'] = nextScreens.toList();
    for (final l in _logins.where((l) => l['role_id'] == id)) {
      l['pos_role'] = base;
    }
    _log('Updated role', 'Role', id, {'name': row['name']});
    return _roleOut(row);
  }

  @override
  Future<void> deleteRole(String id) async {
    final row = _roleRow(id) ?? (throw StateError('Role not found.'));
    final used = _logins.where((l) => l['role_id'] == id).length;
    if (used > 0) {
      throw StateError('${row['name']} is assigned to $used login(s). '
          'Move them to another role first.');
    }
    _roles.remove(row);
    _log('Deleted role', 'Role', id, {'name': row['name']});
  }

  @override
  Future<List<StaffRole>> seedDefaultRoles() async {
    var added = 0;
    for (final (name, base, screens) in _defaultRoles) {
      if (_roles
          .any((r) => '${r['name']}'.toLowerCase() == name.toLowerCase())) {
        continue;
      }
      _roles.add({
        'id': _id('role'),
        'name': name,
        'base_role': base,
        'screens': (screens ?? PosRoles.defaultScreens(base)).toList(),
        'description': '',
        'is_default': true,
      });
      added++;
    }
    if (added > 0) _log('Seeded $added default roles', 'Role');
    return [for (final r in _roles) _roleOut(r)];
  }

  // ── attendance ─────────────────────────────────────────────────────────

  AttendanceEntry _attendanceOut(Map<String, dynamic> e, String date) {
    final a = _attendance['${e['id']}|$date'];
    return AttendanceEntry.fromJson({
      ...?a,
      'staff_id': e['id'],
      'staff_name': e['full_name'],
      'staff_code': e['staff_code'],
      'date': date,
    });
  }

  void _putAttendance(
      Map<String, dynamic> staff, String date, Map<String, dynamic> fields) {
    final key = '${staff['id']}|$date';
    _attendance[key] = {
      'ot_hours': 0.0,
      'notes': '',
      ...?_attendance[key],
      ...fields,
      'staff_id': staff['id'],
      'staff_name': staff['full_name'],
      'staff_code': staff['staff_code'],
      'date': date,
    };
  }

  @override
  Future<List<AttendanceEntry>> attendance(DateTime day) async {
    final date = isoDate(day);
    return [for (final e in _activeEmployees) _attendanceOut(e, date)];
  }

  @override
  Future<List<AttendanceEntry>> saveAttendance(
      DateTime day, List<AttendanceEntry> entries) async {
    final date = isoDate(day);
    final marked = entries.where((e) => e.status != null).toList();
    for (final e in marked) {
      if (!_attendanceStatuses.contains(e.status)) {
        throw ArgumentError('Unknown attendance status: ${e.status}');
      }
      _checkTime(e.checkIn, 'Check-in');
      _checkTime(e.checkOut, 'Check-out');
      if (e.otHours < 0) throw ArgumentError('OT hours cannot be negative.');
      _requireEmployee(e.staffId);
    }
    for (final e in marked) {
      _putAttendance(_requireEmployee(e.staffId), date, {
        'status': e.status,
        'check_in': (e.checkIn?.isEmpty ?? true) ? null : e.checkIn,
        'check_out': (e.checkOut?.isEmpty ?? true) ? null : e.checkOut,
        'ot_hours': e.otHours,
        'notes': e.notes,
      });
    }
    if (marked.isNotEmpty) {
      _log('Saved attendance', 'Attendance', null,
          {'date': date, 'entries': marked.length});
    }
    return attendance(day);
  }

  @override
  Future<List<AttendanceEntry>> markAllPresent(DateTime day) async {
    final date = isoDate(day);
    for (final e in _activeEmployees) {
      final existing = _attendance['${e['id']}|$date'];
      _putAttendance(e, date, {
        'status': 'present',
        'check_in': existing?['check_in'] ?? '09:00',
      });
    }
    _log('Marked everyone present', 'Attendance', null, {'date': date});
    return attendance(day);
  }

  // ── shifts & roster ────────────────────────────────────────────────────

  Map<String, dynamic>? _shiftRow(String? id) =>
      id == null ? null : _shifts.where((s) => s['id'] == id).firstOrNull;

  @override
  Future<List<Shift>> shifts() async =>
      [for (final s in _shifts) Shift.fromJson(s)];

  @override
  Future<Shift> saveShift(Shift shift) async {
    final name = shift.name.trim();
    if (name.isEmpty) throw ArgumentError('Shift name is required.');
    if (_minutesOf(shift.startTime) == null ||
        _minutesOf(shift.endTime) == null) {
      throw ArgumentError('Start and end must be times like 09:00.');
    }
    if (shift.breakMinutes < 0 || shift.graceMinutes < 0) {
      throw ArgumentError('Break and grace minutes cannot be negative.');
    }
    final fields = {...shift.toJson(), 'name': name};
    if (shift.id.isEmpty) {
      final row = <String, dynamic>{...fields, 'id': _id('shift')};
      _shifts.add(row);
      _log('Created shift', 'Shift', row['id'] as String, {'name': name});
      return Shift.fromJson(row);
    }
    final row = _shiftRow(shift.id) ?? (throw StateError('Shift not found.'));
    row.addAll(fields);
    _log('Updated shift', 'Shift', shift.id, {'name': name});
    return Shift.fromJson(row);
  }

  @override
  Future<void> deleteShift(String id) async {
    final row = _shiftRow(id) ?? (throw StateError('Shift not found.'));
    _shifts.remove(row);
    // Assignments nobody has worked yet go; worked ones keep their
    // snapshot of the shift's times.
    _roster.removeWhere((r) => r['shift_id'] == id && r['clock_in'] == null);
    _log('Deleted shift', 'Shift', id, {'name': row['name']});
  }

  /// Shift details for a roster row: the live shift, else its snapshot.
  ({String name, String start, String end, int breakMin, int grace})
      _rosterShift(Map<String, dynamic> r) {
    final s = _shiftRow(r['shift_id'] as String?) ?? r;
    return (
      name: '${s['shift_name'] ?? s['name'] ?? ''}',
      start: '${s['start_time']}',
      end: '${s['end_time']}',
      breakMin: (s['break_minutes'] as num?)?.toInt() ?? 0,
      grace: (s['grace_minutes'] as num?)?.toInt() ?? 0,
    );
  }

  ({int breakMin, int worked, int overtime, List<String> flags}) _metrics(
      Map<String, dynamic> r, DateTime now) {
    final shift = _rosterShift(r);
    final day = _day(r['date'])!;
    final start = _minutesOf(shift.start) ?? 0;
    final end = _minutesOf(shift.end) ?? 0;
    var span = end - start;
    if (span <= 0) span += 24 * 60;
    final shiftStart = day.add(Duration(minutes: start));
    final clockIn = DateTime.tryParse('${r['clock_in'] ?? ''}');
    final clockOut = DateTime.tryParse('${r['clock_out'] ?? ''}');
    final flags = <String>[];
    var breakMin = 0, worked = 0, overtime = 0;
    if (clockIn == null) {
      if (now.isAfter(shiftStart)) flags.add('Absent');
    } else {
      if (clockIn.isAfter(shiftStart.add(Duration(minutes: shift.grace)))) {
        flags.add('Late');
      }
      final elapsed =
          math.max(0, (clockOut ?? now).difference(clockIn).inMinutes);
      breakMin = shift.breakMin;
      worked = math.max(0, elapsed - breakMin);
      overtime = math.max(0, worked - math.max(0, span - shift.breakMin));
      if (clockOut == null) flags.add('On shift');
      if (overtime > 0) flags.add('Overtime');
    }
    return (
      breakMin: breakMin,
      worked: worked,
      overtime: overtime,
      flags: flags
    );
  }

  @override
  Future<RosterDay> roster(DateTime day) async {
    final date = isoDate(day);
    final now = _clock();
    final rows = <Map<String, dynamic>>[];
    for (final e in _activeEmployees) {
      final base = <String, dynamic>{
        'staff_id': e['id'],
        'staff_name': e['full_name'],
        'staff_code': e['staff_code'],
      };
      final r = _roster
          .where((x) => x['date'] == date && x['staff_id'] == e['id'])
          .firstOrNull;
      if (r == null) {
        rows.add({
          ...base,
          'flags': ['Not scheduled']
        });
        continue;
      }
      final shift = _rosterShift(r);
      final m = _metrics(r, now);
      rows.add({
        ...base,
        'roster_id': r['id'],
        'shift_id': r['shift_id'],
        'shift_name': shift.name,
        'start_time': shift.start,
        'end_time': shift.end,
        'clock_in': r['clock_in'],
        'clock_out': r['clock_out'],
        'break_minutes': m.breakMin,
        'worked_minutes': m.worked,
        'overtime_minutes': m.overtime,
        'flags': m.flags,
      });
    }
    int count(String flag) =>
        rows.where((r) => (r['flags'] as List).contains(flag)).length;
    return RosterDay.fromJson({
      'date': date,
      'stats': {
        'scheduled': rows.where((r) => r['roster_id'] != null).length,
        'on_shift': count('On shift'),
        'late': count('Late'),
        'overtime': count('Overtime'),
      },
      'rows': rows,
    });
  }

  @override
  Future<void> assignShift(DateTime day, String staffId, String shiftId) async {
    final staff = _requireEmployee(staffId);
    if (!_isActive(staff)) {
      throw StateError('${staff['full_name']} is inactive.');
    }
    final shift = _shiftRow(shiftId) ?? (throw StateError('Shift not found.'));
    final date = isoDate(day);
    final snapshot = {
      'shift_id': shiftId,
      'shift_name': shift['name'],
      'start_time': shift['start_time'],
      'end_time': shift['end_time'],
      'break_minutes': shift['break_minutes'],
      'grace_minutes': shift['grace_minutes'],
    };
    final existing = _roster
        .where((r) => r['date'] == date && r['staff_id'] == staffId)
        .firstOrNull;
    if (existing != null) {
      if (existing['clock_in'] != null) {
        throw StateError('${staff['full_name']} has already clocked in; '
            "the shift can't be changed.");
      }
      existing.addAll(snapshot);
      _log('Assigned shift', 'Roster', staffId,
          {'staff': staff['full_name'], 'shift': shift['name'], 'date': date});
      return;
    }
    final row = <String, dynamic>{
      'id': _id('roster'),
      'date': date,
      'staff_id': staffId,
      ...snapshot,
      'clock_in': null,
      'clock_out': null,
    };
    _roster.add(row);
    _log('Assigned shift', 'Roster', staffId,
        {'staff': staff['full_name'], 'shift': shift['name'], 'date': date});
  }

  Map<String, dynamic> _rosterRow(String id) =>
      _roster.where((r) => r['id'] == id).firstOrNull ??
      (throw StateError('Roster entry not found.'));

  @override
  Future<void> clockIn(String rosterId) async {
    final r = _rosterRow(rosterId);
    if (r['clock_in'] != null) throw StateError('Already clocked in.');
    final now = _clock();
    r['clock_in'] = now.toIso8601String();
    final staff = _employeeRow(r['staff_id'] as String);
    if (staff != null) {
      _putAttendance(staff, r['date'] as String,
          {'status': 'present', 'check_in': _hm(now)});
    }
    _log('Clocked in', 'Roster', r['staff_id'] as String?,
        {'staff': staff?['full_name'], 'date': r['date']});
  }

  @override
  Future<void> clockOut(String rosterId) async {
    final r = _rosterRow(rosterId);
    if (r['clock_in'] == null) throw StateError('Not clocked in yet.');
    if (r['clock_out'] != null) throw StateError('Already clocked out.');
    final now = _clock();
    r['clock_out'] = now.toIso8601String();
    final staff = _employeeRow(r['staff_id'] as String);
    if (staff != null) {
      final m = _metrics(r, now);
      _putAttendance(staff, r['date'] as String, {
        'status': 'present',
        'check_out': _hm(now),
        if (m.overtime > 0) 'ot_hours': _money(m.overtime / 60),
      });
    }
    _log('Clocked out', 'Roster', r['staff_id'] as String?,
        {'staff': staff?['full_name'], 'date': r['date']});
  }

  // ── advances ───────────────────────────────────────────────────────────

  @override
  Future<List<StaffAdvance>> advances() async {
    final list = [..._advances]..sort((a, b) {
        final byDate = '${b['advance_date']}'.compareTo('${a['advance_date']}');
        return byDate != 0
            ? byDate
            : (b['seq'] as int).compareTo(a['seq'] as int);
      });
    return [for (final a in list) StaffAdvance.fromJson(a)];
  }

  Map<String, dynamic> _insertAdvance({
    required Map<String, dynamic> staff,
    required double amount,
    required DateTime date,
    required int deductMonth,
    required int deductYear,
    required String reason,
    required String mode,
  }) {
    if (amount <= 0) throw ArgumentError('Amount must be more than zero.');
    if (deductMonth < 1 || deductMonth > 12) {
      throw ArgumentError('Deduct month must be 1–12.');
    }
    if (deductYear < 2000 || deductYear > 2100) {
      throw ArgumentError('Deduct year looks wrong.');
    }
    final m = mode.toLowerCase();
    if (!const {'cash', 'upi', 'bank'}.contains(m)) {
      throw ArgumentError('Mode must be cash, upi or bank.');
    }
    final row = <String, dynamic>{
      'id': _id('adv'),
      'seq': _seq,
      'staff_id': staff['id'],
      'staff_name': staff['full_name'],
      'advance_date': isoDate(date),
      'amount': _money(amount),
      'deduct_month': deductMonth,
      'deduct_year': deductYear,
      'reason': reason.trim(),
      'mode': m,
      'status': 'open',
    };
    _advances.add(row);
    _log('Recorded salary advance', 'Advance', row['id'] as String,
        {'staff': staff['full_name'], 'amount': row['amount']});
    return row;
  }

  @override
  Future<StaffAdvance> createAdvance({
    required String staffId,
    required double amount,
    required DateTime date,
    required int deductMonth,
    required int deductYear,
    String reason = '',
    String mode = 'cash',
  }) async =>
      StaffAdvance.fromJson(_insertAdvance(
        staff: _requireEmployee(staffId),
        amount: amount,
        date: date,
        deductMonth: deductMonth,
        deductYear: deductYear,
        reason: reason,
        mode: mode,
      ));

  // ── salaries ───────────────────────────────────────────────────────────

  Map<String, dynamic> _salaryRow(String id) =>
      _salaries.where((s) => s['id'] == id).firstOrNull ??
      (throw StateError('Salary row not found.'));

  static String _salaryStatus(double net, double paid) {
    if (paid <= 0) return 'pending';
    return paid + 0.005 >= net ? 'paid' : 'partial';
  }

  @override
  Future<List<SalaryRow>> salaries(int year, int month) async => [
        for (final s in _salaries)
          if (s['year'] == year && s['month'] == month) SalaryRow.fromJson(s)
      ];

  @override
  Future<List<SalaryRow>> generateSalaries(int year, int month) async {
    if (month < 1 || month > 12) throw ArgumentError('Month must be 1–12.');
    final days = DateTime(year, month + 1, 0).day;
    final prefix = '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-';
    for (final e in _activeEmployees) {
      final m = StaffMember.fromJson(e);
      final existing = _salaries
          .where((s) =>
              s['staff_id'] == m.id && s['year'] == year && s['month'] == month)
          .firstOrNull;
      if (existing != null && existing['status'] == 'paid') continue;

      final att = _attendance.values
          .where(
              (a) => a['staff_id'] == m.id && '${a['date']}'.startsWith(prefix))
          .toList();
      int count(String status) =>
          att.where((a) => a['status'] == status).length;
      final absent = count('absent');
      final half = count('half_day');
      final present = count('present') + half * 0.5;
      final hours = m.workingHours > 0 ? m.workingHours : 8;

      double basic;
      double hourly;
      switch (m.salaryType) {
        case 'daily':
          basic = m.dailyWage * present;
          hourly = m.dailyWage / hours;
        case 'hourly':
          basic = m.hourlyRate * hours * present;
          hourly = m.hourlyRate;
        default:
          final perDay = m.monthlySalary / days;
          basic = m.monthlySalary - absent * perDay - half * 0.5 * perDay;
          hourly = m.monthlySalary / (days * hours);
      }
      basic = math.max(0, basic);
      final otHours = att.fold(0.0, (t, a) => t + _d(a['ot_hours']));
      final ot = otHours * hourly;
      var bonus = 0.0;
      if (m.compensationModel == 'salary_incentive') {
        bonus = switch (m.incentiveType) {
          'fixed_amount' => m.incentiveValue,
          'percentage' => basic * m.incentiveValue / 100,
          _ => 0.0,
        };
      }
      final advance = _advances
          .where((a) =>
              a['staff_id'] == m.id &&
              a['status'] == 'open' &&
              a['deduct_month'] == month &&
              a['deduct_year'] == year)
          .fold(0.0, (t, a) => t + _d(a['amount']));
      final penalty = existing == null ? 0.0 : _d(existing['penalty']);
      final net = math.max(
          0.0,
          _money(basic) +
              _money(ot) +
              _money(bonus) -
              _money(advance) -
              _money(penalty));
      final paid = existing == null ? 0.0 : _d(existing['paid']);
      final row = <String, dynamic>{
        'id': existing?['id'] ?? _id('sal'),
        'staff_id': m.id,
        'staff_name': m.fullName,
        'year': year,
        'month': month,
        'basic': _money(basic),
        'ot_amount': _money(ot),
        'bonus': _money(bonus),
        'advance': _money(advance),
        'penalty': _money(penalty),
        'net': _money(net),
        'paid': _money(paid),
        'status': _salaryStatus(net, paid),
      };
      if (existing != null) {
        existing
          ..clear()
          ..addAll(row);
      } else {
        _salaries.add(row);
      }
    }
    _log('Generated salaries', 'Salary', null, {'year': year, 'month': month});
    return salaries(year, month);
  }

  @override
  Future<SalaryRow> updateSalary(String id,
      {double? bonus, double? penalty}) async {
    final row = _salaryRow(id);
    if (row['status'] == 'paid') {
      throw StateError('This salary is already paid.');
    }
    if ((bonus ?? 0) < 0 || (penalty ?? 0) < 0) {
      throw ArgumentError('Bonus and penalty cannot be negative.');
    }
    if (bonus != null) row['bonus'] = _money(bonus);
    if (penalty != null) row['penalty'] = _money(penalty);
    final net = math.max(
        0.0,
        _d(row['basic']) +
            _d(row['ot_amount']) +
            _d(row['bonus']) -
            _d(row['advance']) -
            _d(row['penalty']));
    row['net'] = _money(net);
    row['status'] = _salaryStatus(net, _d(row['paid']));
    _log('Adjusted salary', 'Salary', id, {'staff': row['staff_name']});
    return SalaryRow.fromJson(row);
  }

  @override
  Future<SalaryRow> paySalary(String id, {double? amount}) async {
    final row = _salaryRow(id);
    if (row['status'] == 'paid') {
      throw StateError('This salary is already paid.');
    }
    final net = _d(row['net']);
    final paid = _d(row['paid']);
    final pending = _money(math.max(0.0, net - paid));
    final pay = amount ?? pending;
    if (amount != null && amount <= 0) {
      throw ArgumentError('Amount must be more than zero.');
    }
    if (pay > pending + 0.005) {
      throw ArgumentError('Amount is more than the pending balance.');
    }
    final newPaid = _money(paid + pay);
    row['paid'] = newPaid;
    final full = newPaid + 0.005 >= net;
    row['status'] = full ? 'paid' : 'partial';
    if (full) {
      for (final a in _advances.where((a) =>
          a['staff_id'] == row['staff_id'] &&
          a['status'] == 'open' &&
          a['deduct_month'] == row['month'] &&
          a['deduct_year'] == row['year'])) {
        a['status'] = 'deducted';
      }
    }
    _log(full ? 'Paid salary' : 'Paid salary (partial)', 'Salary', id,
        {'staff': row['staff_name'], 'amount': pay});
    return SalaryRow.fromJson(row);
  }

  // ── approvals ──────────────────────────────────────────────────────────

  @override
  Future<ApprovalsOverview> approvals({bool history = false}) async {
    int count(bool Function(Map<String, dynamic>) test) =>
        _approvals.where(test).length;
    final rows = _approvals
        .where((a) =>
            history ? a['status'] != 'pending' : a['status'] == 'pending')
        .toList()
      ..sort((a, b) {
        final ka = '${history ? a['decided_at'] : a['requested_at']}';
        final kb = '${history ? b['decided_at'] : b['requested_at']}';
        final c = kb.compareTo(ka);
        return c != 0 ? c : (b['seq'] as int).compareTo(a['seq'] as int);
      });
    return ApprovalsOverview.fromJson({
      'stats': {
        'total': _approvals.length,
        'pending': count((a) => a['status'] == 'pending'),
        'approved': count((a) => a['status'] == 'approved'),
        'declined': count((a) => a['status'] == 'declined'),
        'leave_requests': count((a) => a['type'] == 'leave'),
        'salary_advances': count((a) => a['type'] == 'salary_advance'),
      },
      'rows': rows,
    });
  }

  @override
  Future<StaffApproval> createApproval(
      {required String staffId,
      required String type,
      Map<String, Object?> details = const {}}) async {
    final staff = _requireEmployee(staffId);
    if (!_approvalTypes.contains(type)) {
      throw ArgumentError('Unknown request type: $type');
    }
    if (type == 'leave') {
      final from = _day(details['from']);
      final to = _day(details['to']);
      if (from == null || to == null) {
        throw ArgumentError('Leave needs a from and to date.');
      }
      if (to.isBefore(from)) {
        throw ArgumentError('Leave cannot end before it starts.');
      }
      if (to.difference(from).inDays > 366) {
        throw ArgumentError('Leave cannot be longer than a year.');
      }
    }
    if (type == 'salary_advance' && _d(details['amount']) <= 0) {
      throw ArgumentError('Advance amount must be more than zero.');
    }
    final row = <String, dynamic>{
      'id': _id('apr'),
      'seq': _seq,
      'staff_id': staffId,
      'staff_name': staff['full_name'],
      'type': type,
      'details': <String, dynamic>{...details},
      'status': 'pending',
      'requested_at': _clock().toIso8601String(),
      'decided_at': null,
      'decided_by_name': null,
      'decision_note': null,
    };
    _approvals.add(row);
    _log('Raised ${_approvalLabels[type]} request', 'Approval',
        row['id'] as String, {'staff': staff['full_name'], 'type': type});
    return StaffApproval.fromJson(row);
  }

  @override
  Future<StaffApproval> decideApproval(String id,
      {required bool approve, String? note}) async {
    final row = _approvals.where((a) => a['id'] == id).firstOrNull ??
        (throw StateError('Request not found.'));
    if (row['status'] != 'pending') {
      throw StateError('This request has already been decided.');
    }
    final details = (row['details'] as Map).cast<String, dynamic>();
    final staff = _employeeRow(row['staff_id'] as String);
    if (approve) {
      switch (row['type']) {
        case 'leave':
          final from = _day(details['from'])!;
          final to = _day(details['to'])!;
          if (staff != null) {
            for (var d = from;
                !d.isAfter(to);
                d = DateTime(d.year, d.month, d.day + 1)) {
              final reason = '${details['reason'] ?? ''}'.trim();
              _putAttendance(staff, isoDate(d), {
                'status': 'leave',
                if (reason.isNotEmpty) 'notes': reason,
              });
            }
          }
        case 'salary_advance':
          if (staff == null) {
            throw StateError('The staff member no longer exists.');
          }
          final now = _clock();
          final next = DateTime(now.year, now.month + 1);
          final reason = '${details['reason'] ?? ''}'.trim();
          _insertAdvance(
            staff: staff,
            amount: _d(details['amount']),
            date: now,
            deductMonth:
                int.tryParse('${details['deduct_month']}') ?? next.month,
            deductYear: int.tryParse('${details['deduct_year']}') ?? next.year,
            reason: reason.isEmpty ? 'Salary advance request' : reason,
            mode: 'cash',
          );
      }
    }
    final trimmed = note?.trim();
    row
      ..['status'] = approve ? 'approved' : 'declined'
      ..['decided_at'] = _clock().toIso8601String()
      ..['decided_by_name'] = 'You'
      ..['decision_note'] =
          (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    _log(
        '${approve ? 'Approved' : 'Declined'} '
            '${_approvalLabels[row['type']]} request',
        'Approval',
        id,
        {'staff': row['staff_name'], 'type': row['type']});
    return StaffApproval.fromJson(row);
  }

  // ── audit ──────────────────────────────────────────────────────────────

  @override
  Future<List<AuditEntry>> auditLog({String? query}) async {
    final q = query?.trim().toLowerCase() ?? '';
    if (q.isEmpty) return [..._audit];
    return [
      for (final a in _audit)
        if (a.action.toLowerCase().contains(q) ||
            a.entity.toLowerCase().contains(q) ||
            a.actorName.toLowerCase().contains(q))
          a
    ];
  }

  // ── reports ────────────────────────────────────────────────────────────

  @override
  Future<Map<String, int>> reportCounts() async => {
        'staff_list': _employees.length,
        'attendance': _attendance.length,
        'salaries': _salaries.length,
        'salary_paid': _salaries.where((s) => s['status'] == 'paid').length,
        'salary_pending': _salaries.where((s) => s['status'] != 'paid').length,
        'advances': _advances.length,
      };

  static String _num(Object? v) {
    final d = _d(v);
    return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toStringAsFixed(2);
  }

  @override
  Future<ReportTable> report(String kind) async {
    List<String> salaryRow(Map<String, dynamic> s) => [
          '${s['year']}-${'${s['month']}'.padLeft(2, '0')}',
          '${s['staff_name']}',
          _num(s['basic']),
          _num(s['ot_amount']),
          _num(s['bonus']),
          _num(s['advance']),
          _num(s['penalty']),
          _num(s['net']),
          _num(s['paid']),
          _num(math.max(0.0, _d(s['net']) - _d(s['paid']))),
          '${s['status']}',
        ];
    const salaryColumns = [
      'Month',
      'Staff',
      'Basic',
      'OT',
      'Bonus',
      'Advance',
      'Penalty',
      'Net',
      'Paid',
      'Pending',
      'Status',
    ];
    switch (kind) {
      case 'staff_list':
        return ReportTable(
          kind: kind,
          title: 'Staff List',
          columns: const [
            'Staff code',
            'Name',
            'Mobile',
            'Email',
            'Designation',
            'Department',
            'Joined',
            'Salary type',
            'Pay rate',
            'Status',
            'Login role',
          ],
          rows: [
            for (final m in _employees.map(_member))
              [
                m.staffCode,
                m.fullName,
                m.mobile,
                m.email,
                m.designation,
                m.department,
                m.joiningDate ?? '',
                m.salaryType,
                _num(m.payRate),
                m.status,
                m.roleName ?? '',
              ],
          ],
        );
      case 'attendance':
        final rows = _attendance.values.toList()
          ..sort((a, b) {
            final c = '${b['date']}'.compareTo('${a['date']}');
            return c != 0
                ? c
                : '${a['staff_name']}'.compareTo('${b['staff_name']}');
          });
        return ReportTable(
          kind: kind,
          title: 'Attendance',
          columns: const [
            'Date',
            'Staff',
            'Staff code',
            'Status',
            'Check-in',
            'Check-out',
            'OT (hr)',
            'Notes',
          ],
          rows: [
            for (final a in rows)
              [
                '${a['date']}',
                '${a['staff_name']}',
                '${a['staff_code'] ?? ''}',
                '${a['status']}',
                '${a['check_in'] ?? ''}',
                '${a['check_out'] ?? ''}',
                _num(a['ot_hours']),
                '${a['notes'] ?? ''}',
              ]
          ],
        );
      case 'salaries':
      case 'salary_paid':
      case 'salary_pending':
        final rows = _salaries.where((s) => switch (kind) {
              'salary_paid' => s['status'] == 'paid',
              'salary_pending' => s['status'] != 'paid',
              _ => true,
            });
        return ReportTable(
          kind: kind,
          title: switch (kind) {
            'salary_paid' => 'Salary Paid',
            'salary_pending' => 'Salary Pending',
            _ => 'Salaries',
          },
          columns: salaryColumns,
          rows: [for (final s in rows) salaryRow(s)],
        );
      case 'advances':
        final list = await advances();
        return ReportTable(
          kind: kind,
          title: 'Advances',
          columns: const [
            'Date',
            'Staff',
            'Amount',
            'Deduct in',
            'Reason',
            'Mode',
            'Status',
          ],
          rows: [
            for (final a in list)
              [
                a.date,
                a.staffName,
                _num(a.amount),
                '${a.deductMonth}/${a.deductYear}',
                a.reason,
                a.mode,
                a.status,
              ]
          ],
        );
    }
    throw ArgumentError('Unknown report: $kind');
  }

  // ── training ───────────────────────────────────────────────────────────

  Map<String, dynamic>? _moduleRow(String id) =>
      _modules.where((m) => m['id'] == id).firstOrNull;

  List<Map<String, dynamic>> _assignedTo(List<String> roles) {
    final wanted = {for (final r in roles) r.trim().toLowerCase()};
    if (wanted.contains('all staff')) return _activeEmployees.toList();
    return [
      for (final e in _activeEmployees)
        if (wanted.contains('${e['designation'] ?? ''}'.trim().toLowerCase()) ||
            wanted.contains((_member(e).roleName ?? '').trim().toLowerCase()))
          e
    ];
  }

  Map<String, dynamic> _progress(String moduleId, Map<String, dynamic> e) {
    final attempts = _attempts
        .where((a) => a['module_id'] == moduleId && a['staff_id'] == e['id'])
        .toList();
    if (attempts.isEmpty) {
      return {
        'staff_id': e['id'],
        'staff_name': e['full_name'],
        'status': 'not_started',
        'best_score': null,
      };
    }
    return {
      'staff_id': e['id'],
      'staff_name': e['full_name'],
      'status': attempts.any((a) => a['passed'] == true) ? 'passed' : 'failed',
      'best_score': attempts
          .map((a) => a['score'] as int)
          .reduce((a, b) => math.max(a, b)),
    };
  }

  TrainingModule _moduleOut(Map<String, dynamic> m) {
    final roles = [for (final r in (m['roles'] as List)) '$r'];
    final progress = [
      for (final e in _assignedTo(roles)) _progress(m['id'] as String, e)
    ];
    return TrainingModule.fromJson({
      ...m,
      'assigned_count': progress.length,
      'passed_count': progress.where((p) => p['status'] == 'passed').length,
      'progress': progress,
    });
  }

  @override
  Future<TrainingOverview> training() async {
    final modules = [for (final m in _modules) _moduleOut(m)];
    return TrainingOverview(
      modules: modules,
      totalModules: modules.length,
      completionsPassed: modules.fold(0, (t, m) => t + m.passedCount),
      inProgress: 0,
      failedAttempts: _attempts.where((a) => a['passed'] != true).length,
    );
  }

  @override
  Future<TrainingModule> saveTrainingModule(TrainingModule module) async {
    final title = module.title.trim();
    if (title.isEmpty) throw ArgumentError('Module name is required.');
    if (module.passScore < 1 || module.passScore > 100) {
      throw ArgumentError('Pass score must be between 1 and 100.');
    }
    if (module.timeLimitMinutes < 0) {
      throw ArgumentError('Time limit cannot be negative.');
    }
    if (!const {'draft', 'published'}.contains(module.status)) {
      throw ArgumentError('Unknown module status: ${module.status}');
    }
    for (var i = 0; i < module.questions.length; i++) {
      final q = module.questions[i];
      if (q.question.trim().isEmpty) {
        throw ArgumentError('Question ${i + 1} has no text.');
      }
      if (q.options.length < 2 || q.options.any((o) => o.trim().isEmpty)) {
        throw ArgumentError('Question ${i + 1} needs at least two options.');
      }
      if (q.answerIndex < 0 || q.answerIndex >= q.options.length) {
        throw ArgumentError('Question ${i + 1} has no correct answer marked.');
      }
    }
    if (module.status == 'published' && module.questions.isEmpty) {
      throw ArgumentError('Add at least one question before publishing.');
    }
    final fields = <String, dynamic>{
      ...module.toJson(),
      'title': title,
      'roles': module.roles.isEmpty ? const ['All Staff'] : module.roles,
      'updated_at': _clock().toIso8601String(),
    };
    if (module.id.isEmpty) {
      final row = <String, dynamic>{...fields, 'id': _id('module')};
      _modules.add(row);
      _log('Created training module', 'Training', row['id'] as String,
          {'title': title});
      return _moduleOut(row);
    }
    final row =
        _moduleRow(module.id) ?? (throw StateError('Module not found.'));
    final publishing =
        row['status'] != 'published' && module.status == 'published';
    row.addAll(fields);
    _log(publishing ? 'Published training module' : 'Updated training module',
        'Training', module.id, {'title': title});
    return _moduleOut(row);
  }

  @override
  Future<void> deleteTrainingModule(String id) async {
    final row = _moduleRow(id) ?? (throw StateError('Module not found.'));
    _modules.remove(row);
    _attempts.removeWhere((a) => a['module_id'] == id);
    _log('Deleted training module', 'Training', id, {'title': row['title']});
  }

  @override
  Future<TrainingResult> submitTrainingAttempt(
      String moduleId, String staffId, List<int> answers) async {
    final module = _moduleOut(
        _moduleRow(moduleId) ?? (throw StateError('Module not found.')));
    final staff = _requireEmployee(staffId);
    if (module.questions.isEmpty) {
      throw StateError('This module has no questions yet.');
    }
    var correct = 0;
    for (var i = 0; i < module.questions.length; i++) {
      if (i < answers.length && answers[i] == module.questions[i].answerIndex) {
        correct++;
      }
    }
    final total = module.questions.length;
    final score = (correct * 100 / total).round();
    final passed = score >= module.passScore;
    _attempts.add({
      'module_id': moduleId,
      'staff_id': staff['id'],
      'score': score,
      'passed': passed,
      'at': _clock().toIso8601String(),
    });
    _log('Submitted training test (${passed ? 'passed' : 'failed'})',
        'Training', moduleId, {'title': module.title, 'staff': staff['full_name']});
    return TrainingResult(
        score: score, passed: passed, correct: correct, total: total);
  }
}
