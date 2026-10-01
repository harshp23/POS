import 'access.dart';

/// Who is signed in, as the Proviyaa backend resolved it from master-admin's
/// tables (users / security_roles / organizations / org_locations).
class BranchLocation {
  const BranchLocation({
    required this.id,
    required this.name,
    this.code,
    this.status,
  });
  final String id;
  final String name;
  final String? code;
  final String? status;

  factory BranchLocation.fromJson(Map<String, dynamic> j) {
    final name = '${j['name'] ?? ''}'.trim();
    final code = j['code'] == null ? null : '${j['code']}';
    return BranchLocation(
      id: '${j['id']}',
      name: name.isNotEmpty
          ? name
          : (code != null && code.isNotEmpty ? 'Branch $code' : 'Branch'),
      code: code,
      status: j['status'] == null ? null : '${j['status']}',
    );
  }
}

/// A restaurant (master-admin organization) a platform admin may open.
class OrganizationRef {
  const OrganizationRef({required this.id, required this.name, this.status});
  final String id;
  final String name;
  final String? status;

  factory OrganizationRef.fromJson(Map<String, dynamic> j) => OrganizationRef(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        status: j['status'] as String?,
      );
}

class VendorAccount {
  const VendorAccount({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.organizationId,
    required this.organizationName,
    required this.role,
    required this.roleName,
    required this.panel,
    required this.capabilities,
    required this.locations,
    this.location,
    this.platformAdmin = false,
    this.organizations = const [],
    this.screens = const {},
    this.mustChangePassword = false,
  });

  final String userId;
  final String email;
  final String fullName;
  final String organizationId;
  final String organizationName;

  /// OS role slug (org_admin, manager, biller, captain, kitchen, …).
  final String role;
  final String roleName;

  /// 'vendor' (restaurant admin panel) or 'pos' (billing terminal).
  final String panel;

  /// module → allowed actions, e.g. {'master': ['read', 'write']}.
  final Map<String, List<String>> capabilities;
  final List<BranchLocation> locations;

  /// The branch this device works for.
  final BranchLocation? location;

  /// A Proviyaa platform admin (master-admin super_admin) working inside
  /// [organizationId]; [organizations] lists every restaurant they can open.
  final bool platformAdmin;
  final List<OrganizationRef> organizations;

  /// Screens this account may open (lib/domain/access.dart). The server
  /// decides them from the account's role; the app shows nothing else.
  final Set<String> screens;

  /// An admin reset the password: the app asks for a new one first.
  final bool mustChangePassword;

  bool canOpen(String screen) => screens.contains(screen);

  bool get isVendorPanel => panel == 'vendor';
  bool can(String module, String action) =>
      capabilities[module]?.contains(action) ?? false;

  /// True when `me` names an organization. A platform admin who has not
  /// picked a restaurant yet gets `organization: null`.
  static bool hasOrganization(Map<String, dynamic> me) =>
      me['organization'] is Map;

  static bool isPlatformAdmin(Map<String, dynamic> me) =>
      me['platform_admin'] == true;

  static List<OrganizationRef> organizationsOf(Map<String, dynamic> me) => [
        for (final o in (me['organizations'] as List? ?? const []))
          OrganizationRef.fromJson((o as Map).cast<String, dynamic>()),
      ];

  /// This account acting for [branch] — one of its [locations].
  VendorAccount actingFor(BranchLocation branch) => VendorAccount(
        userId: userId,
        email: email,
        fullName: fullName,
        organizationId: organizationId,
        organizationName: organizationName,
        role: role,
        roleName: roleName,
        panel: panel,
        capabilities: capabilities,
        locations: locations,
        location: branch,
        platformAdmin: platformAdmin,
        organizations: organizations,
        screens: screens,
        mustChangePassword: mustChangePassword,
      );

  factory VendorAccount.fromMe(Map<String, dynamic> me) {
    if (!hasOrganization(me)) {
      throw StateError('This account is not linked to a restaurant.');
    }
    final user = (me['user'] as Map).cast<String, dynamic>();
    final org = (me['organization'] as Map).cast<String, dynamic>();
    final member = (me['member'] as Map).cast<String, dynamic>();
    final caps = (me['capabilities'] as Map? ?? const {}).map(
        (k, v) => MapEntry(k as String, (v as List).cast<String>().toList()));
    final loc = me['location'];
    final role = '${member['role'] ?? ''}';
    final serverRoleName = '${member['role_name'] ?? ''}'.trim();
    final screens = me['screens'];
    return VendorAccount(
      userId: user['id'] as String,
      email: '${user['email'] ?? ''}',
      fullName: '${member['full_name'] ?? ''}',
      organizationId: org['id'] as String,
      organizationName: '${org['name'] ?? ''}',
      role: role,
      // A human name only — never the role key (org_admin).
      roleName: serverRoleName.isNotEmpty && serverRoleName != role
          ? serverRoleName
          : (PosRoles.names[role] ?? 'No role'),
      panel: (me['panel'] ?? 'vendor') as String,
      capabilities: caps,
      locations: [
        for (final l in (me['locations'] as List? ?? const []))
          BranchLocation.fromJson((l as Map).cast<String, dynamic>()),
      ],
      location: loc is Map
          ? BranchLocation.fromJson(loc.cast<String, dynamic>())
          : null,
      platformAdmin: isPlatformAdmin(me),
      organizations: organizationsOf(me),
      // Older servers send no list: fall back to the role's defaults.
      screens: screens is List
          ? {for (final s in screens) '$s'}
          : PosRoles.defaultScreens(role),
      mustChangePassword: me['must_change_password'] == true,
    );
  }
}
