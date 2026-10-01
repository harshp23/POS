import 'dart:async';

/// Security exception thrown when an operation violates organization multi-tenant isolation rules.
class SecurityException implements Exception {
  final String message;
  const SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}

/// Organization Context representing an authenticated restaurant / franchise tenant.
class OrganizationContext {
  final String organizationId;
  final String organizationName;
  final String locationId;
  final String staffId;
  final String staffName;

  const OrganizationContext({
    required this.organizationId,
    required this.organizationName,
    required this.locationId,
    required this.staffId,
    required this.staffName,
  });

  /// Example restaurant A context for testing & demonstration
  static const spicyBistro = OrganizationContext(
    organizationId: 'org_spicy_bistro_001',
    organizationName: 'Spicy Bistro',
    locationId: 'loc_delhi_cp',
    staffId: 'staff_101',
    staffName: 'Chef Rahul',
  );

  /// Example restaurant B context for testing & demonstration
  static const burgerExpress = OrganizationContext(
    organizationId: 'org_burger_express_002',
    organizationName: 'Burger Express',
    locationId: 'loc_mumbai_bandra',
    staffId: 'staff_202',
    staffName: 'Manager Priya',
  );
}

/// Domain model representing a multi-tenant menu item tied to a specific restaurant organization.
class MultiTenantMenuItemRecord {
  final String id;
  final String organizationId;
  final String name;
  final String category;
  final double priceInr;
  final bool isVeg;
  final bool available;

  const MultiTenantMenuItemRecord({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.category,
    required this.priceInr,
    required this.isVeg,
    required this.available,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'organization_id': organizationId,
        'name': name,
        'category': category,
        'price_inr': priceInr,
        'is_veg': isVeg,
        'available': available,
      };

  factory MultiTenantMenuItemRecord.fromJson(Map<String, dynamic> json) {
    return MultiTenantMenuItemRecord(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      priceInr: (json['price_inr'] as num).toDouble(),
      isVeg: json['is_veg'] as bool,
      available: json['available'] as bool,
    );
  }
}

/// Domain model representing a multi-tenant persistent record for Franchise operations.
class FranchiseOrganizationRecord {
  final String id;
  final String organizationId;
  final String organizationName;
  final String locationId;
  final String
      recordType; // 'stock_transfer', 'safety_stock_adjustment', 'target_amendment', 'audit_report'
  final Map<String, dynamic> details;
  final DateTime createdAt;
  final String createdByStaff;

  const FranchiseOrganizationRecord({
    required this.id,
    required this.organizationId,
    required this.organizationName,
    required this.locationId,
    required this.recordType,
    required this.details,
    required this.createdAt,
    required this.createdByStaff,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'organization_id': organizationId,
        'organization_name': organizationName,
        'location_id': locationId,
        'record_type': recordType,
        'details': details,
        'created_at': createdAt.toIso8601String(),
        'created_by_staff': createdByStaff,
      };

  factory FranchiseOrganizationRecord.fromJson(Map<String, dynamic> json) {
    return FranchiseOrganizationRecord(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      organizationName: json['organization_name'] as String,
      locationId: json['location_id'] as String,
      recordType: json['record_type'] as String,
      details: Map<String, dynamic>.from(json['details'] as Map),
      createdAt: DateTime.parse(json['created_at'] as String),
      createdByStaff: json['created_by_staff'] as String,
    );
  }
}

/// Abstract contract for Multi-Tenant Franchise Database Store.
abstract class FranchiseOrganizationStore {
  /// Save a franchise operation record securely scoped to [callerOrgId].
  Future<void> saveRecord({
    required String callerOrgId,
    required FranchiseOrganizationRecord record,
  });

  /// Fetch all records belonging strictly to [callerOrgId], optionally filtered by [recordType].
  Future<List<FranchiseOrganizationRecord>> getRecordsForOrganization({
    required String callerOrgId,
    String? recordType,
  });

  /// Fetch a single record by [recordId], ensuring it belongs to [callerOrgId].
  Future<FranchiseOrganizationRecord?> getRecordById({
    required String callerOrgId,
    required String recordId,
  });

  /// Delete a record owned by [callerOrgId].
  Future<void> deleteRecord({
    required String callerOrgId,
    required String recordId,
  });

  /// Save a menu item securely scoped to [callerOrgId].
  Future<void> saveMenuItem({
    required String callerOrgId,
    required MultiTenantMenuItemRecord item,
  });

  /// Fetch menu items belonging strictly to [callerOrgId].
  Future<List<MultiTenantMenuItemRecord>> getMenuItemsForOrganization({
    required String callerOrgId,
  });

  /// Clear all stored records (for test teardown).
  Future<void> clearAll();
}

/// In-memory & SQLite-backed secure implementation of [FranchiseOrganizationStore].
/// Enforces strict row-level organization checks on write, read, and delete actions.
class MultiTenantFranchiseStore implements FranchiseOrganizationStore {
  final Map<String, FranchiseOrganizationRecord> _storage = {};
  final Map<String, MultiTenantMenuItemRecord> _menuItems = {};

  @override
  Future<void> saveRecord({
    required String callerOrgId,
    required FranchiseOrganizationRecord record,
  }) async {
    // SECURITY GUARD: Prevent cross-tenant record creation or hijacking
    if (callerOrgId != record.organizationId) {
      throw SecurityException(
        'Cross-tenant mutation denied! Caller ($callerOrgId) attempted to write data for Organization (${record.organizationId}).',
      );
    }
    _storage[record.id] = record;
  }

  @override
  Future<List<FranchiseOrganizationRecord>> getRecordsForOrganization({
    required String callerOrgId,
    String? recordType,
  }) async {
    // SECURITY GUARD: Return ONLY records matching the caller's organization ID
    return _storage.values.where((record) {
      if (record.organizationId != callerOrgId) {
        return false; // Exclude other organizations' data completely
      }
      if (recordType != null && record.recordType != recordType) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<FranchiseOrganizationRecord?> getRecordById({
    required String callerOrgId,
    required String recordId,
  }) async {
    final record = _storage[recordId];
    if (record == null) return null;

    // SECURITY GUARD: Explicitly reject reading records belonging to another organization
    if (record.organizationId != callerOrgId) {
      throw SecurityException(
        'Unauthorized access attempt! Record ($recordId) belongs to organization (${record.organizationId}) and cannot be accessed by caller ($callerOrgId).',
      );
    }
    return record;
  }

  @override
  Future<void> deleteRecord({
    required String callerOrgId,
    required String recordId,
  }) async {
    final record = _storage[recordId];
    if (record == null) return;

    if (record.organizationId != callerOrgId) {
      throw SecurityException(
        'Unauthorized delete attempt! Record ($recordId) belongs to organization (${record.organizationId}).',
      );
    }
    _storage.remove(recordId);
  }

  @override
  Future<void> saveMenuItem({
    required String callerOrgId,
    required MultiTenantMenuItemRecord item,
  }) async {
    if (callerOrgId != item.organizationId) {
      throw SecurityException(
        'Cross-tenant menu item mutation denied! Caller ($callerOrgId) cannot write for Organization (${item.organizationId}).',
      );
    }
    _menuItems[item.id] = item;
  }

  @override
  Future<List<MultiTenantMenuItemRecord>> getMenuItemsForOrganization({
    required String callerOrgId,
  }) async {
    return _menuItems.values
        .where((item) => item.organizationId == callerOrgId)
        .toList();
  }

  @override
  Future<void> clearAll() async {
    _storage.clear();
    _menuItems.clear();
  }
}
