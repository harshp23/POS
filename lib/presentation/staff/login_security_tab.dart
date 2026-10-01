import 'package:flutter/material.dart';

import '../../data/staff_repository.dart';
import '../master/master_ui.dart';
import '../vinii_theme.dart';
import 'staff_ui.dart';

/// Why a sign-in failed, in words (the server records a code).
const loginFailureLabels = {
  'wrong_password': 'Wrong password',
  'bad_password': 'Wrong password',
  'invalid_password': 'Wrong password',
  'invalid_credentials': 'Wrong email or password',
  'unknown_email': 'No login with this email',
  'unknown_user': 'No login with this email',
  'no_user': 'No login with this email',
  'locked': 'Account locked',
  'inactive': 'Login inactive',
  'suspended': 'Login suspended',
  'no_organization': 'Not linked to a restaurant',
  'no_restaurant': 'Not linked to a restaurant',
  'no_role': 'No role assigned',
  'rate_limited': 'Too many attempts',
};

/// "Wrong password" from "wrong_password"; unknown codes read as words.
String loginFailureLabel(String? reason) {
  final r = (reason ?? '').trim();
  if (r.isEmpty) return '';
  return loginFailureLabels[r.toLowerCase()] ?? staffHumanize(r);
}

/// "Chrome · Windows" from a browser's user-agent string; the app's own
/// names ("Proviyaa vendor panel") pass through.
String deviceSummary(String? userAgent) {
  final ua = (userAgent ?? '').trim();
  if (ua.isEmpty) return '—';
  final l = ua.toLowerCase();
  String? browser;
  if (l.contains('edg/') || l.contains('edge/')) {
    browser = 'Edge';
  } else if (l.contains('opr/') || l.contains('opera')) {
    browser = 'Opera';
  } else if (l.contains('samsungbrowser')) {
    browser = 'Samsung Internet';
  } else if (l.contains('firefox/') || l.contains('fxios')) {
    browser = 'Firefox';
  } else if (l.contains('chrome/') || l.contains('crios')) {
    browser = 'Chrome';
  } else if (l.contains('safari/') && l.contains('version/')) {
    browser = 'Safari';
  } else if (l.startsWith('dart/') || l.contains('dart:io')) {
    browser = 'Proviyaa app';
  } else if (l.contains('okhttp') || l.contains('curl') || l.contains('postman')) {
    browser = 'API client';
  }
  String? os;
  if (l.contains('windows')) {
    os = 'Windows';
  } else if (l.contains('android')) {
    os = 'Android';
  } else if (l.contains('iphone') || l.contains('ipad') || l.contains('ios')) {
    os = 'iOS';
  } else if (l.contains('mac os') || l.contains('macintosh')) {
    os = 'macOS';
  } else if (l.contains('cros')) {
    os = 'ChromeOS';
  } else if (l.contains('linux')) {
    os = 'Linux';
  }
  if (browser == null && os == null) {
    // Not a browser string: a short name is fine, a long one is trimmed.
    return ua.length <= 40 ? ua : '${ua.substring(0, 37)}…';
  }
  return [browser ?? 'Browser', if (os != null) os].join(' · ');
}

/// Login security tab (v1/staff managment/staff-login-security*.png):
/// sessions & access controls per login, and the sign-in history.
class LoginSecurityTab extends StaffTabWidget {
  const LoginSecurityTab(
      {super.key, required super.repository, super.refreshToken});

  @override
  State<LoginSecurityTab> createState() => _LoginSecurityTabState();
}

class _LoginSecurityTabState extends State<LoginSecurityTab>
    with StaffLoadState<LoginSecurityTab> {
  /// 0 = Sessions & access, 1 = Device & login history.
  int _view = 0;
  List<StaffLogin> _logins = const [];
  List<LoginEvent> _history = const [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  Future<void> fetch() async {
    final r = await Future.wait<Object>([repo.logins(), repo.loginHistory()]);
    _logins = r[0] as List<StaffLogin>;
    _history = r[1] as List<LoginEvent>;
  }

  bool _match(String s) =>
      s.toLowerCase().contains(_query.trim().toLowerCase());

  Future<void> _reset(StaffLogin l) async {
    final v = await showStaffPrompt(
      context,
      title: 'Reset password',
      subtitle: '${l.fullName} · ${l.email}',
      confirmLabel: 'Reset password',
      confirmKey: const Key('reset-confirm'),
      fields: const [
        StaffPromptField('password', 'New password',
            key: Key('reset-password'),
            obscure: true,
            hint: 'At least 8 characters'),
      ],
      checks: const [
        StaffPromptCheck('force', 'Ask to change it at next login',
            initial: true, key: Key('reset-force')),
      ],
      note: const Text(
          'Failed attempts are cleared and any lock is lifted. Share the new '
          'password with the staff member in person.',
          style: MasterStyle.muted),
      validate: (v) => (v['password'] ?? '').length < 8
          ? 'Password must be at least 8 characters.'
          : null,
    );
    if (v == null || !mounted) return;
    await act(
        () => repo.resetPassword(l.userId, v['password']!,
            forceChange: v['force'] == 'true'),
        success: 'Password reset for ${l.fullName}');
  }

  @override
  Widget build(BuildContext context) => StaffTabPage(children: [
        StaffPills(
            keyPrefix: 'security-view',
            options: const ['Sessions & access', 'Device & login history'],
            selected: _view,
            onSelect: (i) => setState(() => _view = i)),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: MasterSearchField(
              key: const Key('security-search'),
              hint: _view == 0 ? 'Search staff logins...' : 'Search history...',
              width: 320,
              onChanged: (v) => setState(() => _query = v)),
        ),
        const SizedBox(height: 16),
        guarded(() => _view == 0 ? _sessions() : _historyView()),
      ]);

  Widget _toggle(Key key, bool value, ValueChanged<bool>? onChanged) =>
      StaffSwitch(key: key, value: value, onChanged: busy ? null : onChanged);

  Widget _sessions() {
    final rows = [
      for (final l in _logins)
        if (_match('${l.fullName} ${l.email} ${l.displayRole}')) l
    ];
    return MasterTable(
      minWidth: 1100,
      columns: const [
        MasterColumn('Staff Login', flex: 22),
        MasterColumn('Last Login', flex: 13),
        MasterColumn('Failed Attempts', flex: 9),
        MasterColumn('Status', flex: 9),
        MasterColumn('Force Password Change', flex: 11),
        MasterColumn('2FA (future-ready)', flex: 10),
        MasterColumn('Actions', flex: 8, alignEnd: true),
      ],
      rows: [
        for (final l in rows)
          [
            MasterCellTitle(l.fullName,
                subtitle: '${l.email} • ${l.displayRole}'),
            MasterCellText(staffDateTime(l.lastLoginAt)),
            MasterCellText('${l.failedAttempts}',
                color: l.failedAttempts > 0 ? kStaffRed : null),
            MasterStatusPill(
                l.lockedUntil != null && l.lockedUntil!.isAfter(DateTime.now())
                    ? 'Locked'
                    : l.status,
                tone: l.isActive ? PillTone.green : PillTone.gray),
            _toggle(
                Key('security-force-${l.userId}'),
                l.forcePasswordChange,
                (v) => act(
                    () => repo
                        .updateLogin(l.userId, {'force_password_change': v}),
                    success: v
                        ? '${l.fullName} must change password at next login'
                        : 'Password change no longer required')),
            _toggle(
                Key('security-2fa-${l.userId}'),
                l.twoFactorEnabled,
                (v) => act(
                    () => repo.updateLogin(l.userId, {'two_factor_enabled': v}),
                    success: v
                        ? '2FA flag on for ${l.fullName} (enforced once 2FA '
                            'sign-in ships)'
                        : '2FA flag off for ${l.fullName}')),
            TextButton.icon(
              key: Key('login-reset-${l.userId}'),
              onPressed: busy ? null : () => _reset(l),
              icon: const Icon(Icons.key, size: 16),
              label: const Text('Reset'),
              style: TextButton.styleFrom(
                  foregroundColor: ViniiColors.textPrimaryLight),
            ),
          ]
      ],
      footer: rows.isEmpty
          ? StaffEmptyState(
              icon: Icons.lock_outline,
              title: _logins.isEmpty ? 'No logins yet' : 'No matches',
              message: _logins.isEmpty
                  ? 'Create logins in Roles & permissions → Staff access.'
                  : null,
            )
          : null,
    );
  }

  Widget _historyView() {
    final rows = [
      for (final e in _history)
        if (_match('${e.fullName ?? ''} ${e.email} ${e.ip ?? ''} '
            '${deviceSummary(e.userAgent)} ${loginFailureLabel(e.reason)}'))
          e
    ];
    return MasterTable(
      minWidth: 1000,
      columns: const [
        MasterColumn('When', flex: 12),
        MasterColumn('Staff', flex: 18),
        MasterColumn('Result', flex: 14),
        MasterColumn('Device', flex: 22),
        MasterColumn('IP', flex: 10),
      ],
      rows: [
        for (final e in rows)
          [
            MasterCellText(staffDateTime(e.at)),
            MasterCellTitle(e.fullName ?? e.email,
                subtitle: e.fullName == null ? null : e.email),
            Row(mainAxisSize: MainAxisSize.min, children: [
              StaffChip(e.success ? 'Success' : 'Failed',
                  color: e.success ? kStaffGreen : kStaffRed),
              if (!e.success && (e.reason ?? '').isNotEmpty) ...[
                const SizedBox(width: 6),
                Flexible(
                    child: Text(loginFailureLabel(e.reason),
                        overflow: TextOverflow.ellipsis,
                        style: MasterStyle.muted)),
              ],
            ]),
            MasterCellText(deviceSummary(e.userAgent)),
            MasterCellText(e.ip ?? '—'),
          ]
      ],
      footer: rows.isEmpty
          ? const StaffEmptyState(
              icon: Icons.history,
              title: 'No sign-ins recorded',
            )
          : null,
    );
  }
}
