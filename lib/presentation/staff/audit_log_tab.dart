import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/staff_repository.dart';
import '../master/master_ui.dart';
import '../vinii_theme.dart';
import 'approvals_tab.dart' show approvalTypeLabels;
import 'staff_ui.dart';

/// What a changed field is called on screen (audit `fields` / `changes`).
const _fieldLabels = <String, String>{
  'full_name': 'name',
  'mobile': 'mobile',
  'email': 'email',
  'emergency_contact': 'emergency contact',
  'designation': 'designation',
  'department': 'department',
  'bank_name': 'bank name',
  'account_number': 'account number',
  'ifsc': 'IFSC',
  'upi_id': 'UPI ID',
  'photo_url': 'photo',
  'id_proof_url': 'ID proof',
  'address': 'address',
  'joining_date': 'joining date',
  'salary_type': 'salary type',
  'monthly_salary': 'monthly salary',
  'daily_wage': 'daily wage',
  'hourly_rate': 'hourly rate',
  'working_hours': 'working hours',
  'compensation_model': 'compensation',
  'incentive_type': 'incentive type',
  'incentive_value': 'incentive',
  'status': 'status',
  'location_id': 'branch',
  'delivery_enabled': 'delivery',
  'role_id': 'role',
  'staff_id': 'linked staff',
  'force_password_change': 'password change at next login',
  'two_factor_enabled': '2FA',
};

/// The action with whose record it was: "Updated staff member — Asha
/// Patil".
String auditTitle(AuditEntry a) {
  final who = a.subject;
  return who == null ? a.action : '${a.action} — $who';
}

/// The rest of what the server noted, in words: dates, months, amounts,
/// request types and which fields changed — never raw keys or codes.
String? auditDetails(AuditEntry a) {
  final d = a.details;
  final parts = <String>[];
  num? n(Object? v) => v is num ? v : num.tryParse('${v ?? ''}');
  final type = d['type'];
  if (type is String && type.isNotEmpty) {
    parts.add(approvalTypeLabels[type] ?? staffCodeLabel(type));
  }
  final shift = d['shift'];
  if (shift is String && shift.isNotEmpty) parts.add('Shift: $shift');
  final date = d['date'];
  if (date is String && date.isNotEmpty) parts.add(staffDate(date));
  final month = n(d['month']);
  final year = n(d['year']);
  if (month != null && year != null) {
    parts.add(staffMonthYear(month.toInt(), year.toInt(), long: true));
  }
  final amount = n(d['amount']);
  if (amount != null) parts.add(staffMoney(amount));
  final bonus = n(d['bonus']);
  if (bonus != null) parts.add('Bonus ${staffMoney(bonus)}');
  final penalty = n(d['penalty']);
  if (penalty != null) parts.add('Penalty ${staffMoney(penalty)}');
  final status = d['status'];
  if (status is String && status.isNotEmpty) {
    parts.add(staffCodeLabel(status));
  }
  final score = n(d['score']);
  if (score != null) parts.add('Score ${score.round()}%');
  final entries = n(d['entries']);
  if (entries != null) {
    parts.add('${entries.toInt()} staff');
  }
  if (d['staff'] is num) parts.add('${(d['staff'] as num).toInt()} staff');
  final roles = d['roles'];
  if (roles is List && roles.isNotEmpty) {
    parts.add('Added ${roles.join(', ')}');
  } else if (roles is num && roles > 0) {
    parts.add('${roles.toInt()} roles added');
  }
  final base = d['base_role'];
  if (base is String && base.isNotEmpty) {
    parts.add('Based on ${posRoleLabel(base)}');
  }
  final login = d['login'];
  if (login is String && login.isNotEmpty && login != a.subject) {
    parts.add('Login $login');
  }
  final changed = d['fields'] ?? d['changes'];
  if (changed is List && changed.isNotEmpty) {
    final names = <String>[];
    for (final f in changed) {
      final label = _fieldLabels['$f'] ?? staffHumanize('$f').toLowerCase();
      if (label != '—' && !names.contains(label)) names.add(label);
    }
    if (names.isNotEmpty) parts.add('Changed ${names.join(', ')}');
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Audit log tab (v1/staff managment/staff-audit-log-v3.png): who changed
/// what in Staff Management, newest first.
class AuditLogTab extends StaffTabWidget {
  const AuditLogTab({super.key, required super.repository, super.refreshToken});

  @override
  State<AuditLogTab> createState() => _AuditLogTabState();
}

class _AuditLogTabState extends State<AuditLogTab>
    with StaffLoadState<AuditLogTab> {
  List<AuditEntry> _rows = const [];
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Future<void> fetch() async => _rows = await repo.auditLog(query: _query);

  void _search(String v) {
    _query = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), reload);
  }

  @override
  Widget build(BuildContext context) => StaffTabPage(children: [
        Align(
          alignment: Alignment.centerLeft,
          child: MasterSearchField(
              key: const Key('audit-search'),
              hint: 'Search actions, users, entities...',
              width: 320,
              onChanged: _search),
        ),
        const SizedBox(height: 16),
        guarded(() => MasterTable(
              minWidth: 800,
              columns: const [
                MasterColumn('WHEN', flex: 12),
                MasterColumn('ACTION', flex: 26),
                MasterColumn('ENTITY', flex: 10),
                MasterColumn('ACTOR', flex: 10),
              ],
              rows: [
                for (final a in _rows)
                  [
                    MasterCellText(staffDateTime(a.at),
                        color: ViniiColors.textSecondaryLight),
                    MasterCellTitle(auditTitle(a), subtitle: auditDetails(a)),
                    StaffChip(a.entity,
                        color: ViniiColors.textPrimaryLight,
                        tint: const Color(0xFFF3F4F6)),
                    MasterCellText(a.actorName),
                  ]
              ],
              footer: _rows.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Text(
                            _query.trim().isEmpty
                                ? 'No activity recorded yet.'
                                : 'Nothing matches "${_query.trim()}".',
                            style: MasterStyle.muted.copyWith(fontSize: 13)),
                      ),
                    )
                  : null,
            )),
      ]);
}
