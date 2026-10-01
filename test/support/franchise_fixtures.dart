import 'package:proviyaa_pos/data/api/api_client.dart';
import 'package:proviyaa_pos/data/franchise_repository.dart';
import 'package:proviyaa_pos/domain/franchise_models.dart';

/// An in-memory [FranchiseRepository] that records every call. With [fail]
/// set, every write throws like an unreachable server.
class FakeFranchiseRepository implements FranchiseRepository {
  FakeFranchiseRepository({this.fail = false});

  bool fail;
  final List<String> calls = [];

  /// Saved records, newest first.
  final List<FranchiseRecord> saved = [];

  static const failure = ApiException(503, 'unavailable', 'Server unavailable');

  Future<void> _write(String call) async {
    calls.add(call);
    if (fail) throw failure;
  }

  @override
  Future<FranchiseSnapshot> load() async => sampleSnapshot();

  @override
  Future<void> initiateTransfer(HighImpactRecommendation rec) =>
      _write('transfer:${rec.id}');

  @override
  Future<void> resolveException(String id) => _write('resolve:$id');

  @override
  Future<void> resolveAllExceptions() => _write('resolveAll');

  @override
  Future<void> decidePurchase(PurchaseRequirement req,
          {required bool approve}) =>
      _write('purchase:${req.rowId}:${approve ? 'approve' : 'reject'}');

  @override
  Future<void> logRecord(
      String type, String title, Map<String, Object?> details,
      {String? status, String? locationId}) async {
    await _write('log:$type');
    saved.insert(
      0,
      FranchiseRecord(
        id: 'rec-${saved.length + 1}',
        type: type,
        title: title,
        status: status ?? 'open',
        details: Map<String, dynamic>.of(details),
        locationId: locationId,
        createdAt: DateTime.now(),
        createdByName: 'Test Owner',
      ),
    );
  }

  @override
  Future<List<FranchiseRecord>> records(String type, {int limit = 50}) async =>
      saved.where((r) => r.type == type).take(limit).toList();

  @override
  Future<void> updateRecordStatus(String id, String status) async {
    await _write('status:$id:$status');
    final i = saved.indexWhere((r) => r.id == id);
    final r = saved[i];
    saved[i] = FranchiseRecord(
      id: r.id,
      type: r.type,
      title: r.title,
      status: status,
      details: r.details,
      locationId: r.locationId,
      createdAt: r.createdAt,
      createdByName: r.createdByName,
    );
  }
}

/// A two-branch chain as the backend would report it: Latur Main has sales
/// and food cost (no sales target); Latur Station Road has no sales and is
/// short of paneer, with a transfer suggested from Latur Main.
FranchiseSnapshot sampleSnapshot() => FranchiseSnapshot(
      live: true,
      overview: const ChainSystemOverview(
        totalSalesLakhs: 0.02,
        totalOrders: 7,
        averageOrderValue: 350,
        foodCostPercent: 31.2,
        inventoryValueLakhs: 0.5,
        criticalItemsCount: 1,
      ),
      totalSalesMinor: 245000,
      averageOrderValueMinor: 35000,
      inventoryValueMinor: 5000000,
      recommendations: const [
        HighImpactRecommendation(
          id: 'TRF-1',
          title: 'Paneer low at Latur Station Road — Paneer at 2 kg '
              '(reorder level 5)',
          rootCause: 'Paneer at 2 kg (reorder level 5)',
          whereLocation: 'Latur Station Road',
          financialImpact: '₹1200 of stock to move',
          recommendedAction: 'Transfer 4 kg from Latur Main',
          sourceBranch: 'Latur Main',
          targetBranch: 'Latur Station Road',
          item: 'Paneer',
          quantityKg: 4,
          owner: 'Chain operations',
          materialId: 'mat-paneer',
          fromLocationId: 'loc-main',
          toLocationId: 'loc-station',
        ),
      ],
      leaderboard: const [
        BranchRankItem(
            rank: 1,
            branchName: 'Latur Main',
            revenueLakhs: 0.02,
            targetAchievedPercent: 0),
        BranchRankItem(
            rank: 2,
            branchName: 'Latur Station Road',
            revenueLakhs: 0,
            targetAchievedPercent: 0),
      ],
      branches: const [
        BranchPerformanceRow(
          id: 'loc-main',
          branchName: 'Latur Main',
          city: 'LTR-01',
          todayRevenue: 2450,
          targetMetPercent: 0,
          aovInr: 350,
          foodCostPercent: 31.2,
          healthIndex: 6.3,
          status: 'Warning',
        ),
        BranchPerformanceRow(
          id: 'loc-station',
          branchName: 'Latur Station Road',
          city: 'LTR-02',
          todayRevenue: 0,
          targetMetPercent: 0,
          aovInr: 0,
          foodCostPercent: 0,
          healthIndex: 6.0,
          status: 'Warning',
        ),
      ],
      branchKpis: const {
        'loc-main': BranchKpis(
          locationId: 'loc-main',
          code: 'LTR-01',
          revenueMinor: 245000,
          orders: 7,
          aovMinor: 35000,
          foodCostPercent: 31.2,
          healthIndex: 6.3,
        ),
        'loc-station': BranchKpis(
          locationId: 'loc-station',
          code: 'LTR-02',
          criticalItems: 1,
          healthIndex: 6.0,
        ),
      },
      exceptions: const [
        OperationalException(
          id: 'exc-1',
          severityStatus: 'Warning',
          rootCause: 'Low stock — Paneer (2 kg, reorder at 5)',
          location: 'Latur Station Road',
          bottomLineImpact: '₹1,200 of stock to restore par',
          recommendedAction: 'Transfer 4 kg from Latur Main',
          actionType: 'Transfer',
        ),
      ],
      purchaseRequirements: const [
        PurchaseRequirement(
          branch: 'Latur Main',
          supplier: 'Fresh Dairy Co',
          quantityKg: 10,
          lastPricePerKg: 0,
          currentPricePerKg: 0,
          variancePercent: 0,
          rowId: 'po-1',
        ),
      ],
      purchasesWithoutQuote: const {'po-1'},
      inventory: const [
        ChainStockRow(
          materialId: 'mat-paneer',
          category: 'Dairy',
          name: 'Paneer',
          unit: 'kg',
          chainStock: 14,
          chainTarget: 20,
          branches: [
            BranchStock(
                locationId: 'loc-main',
                branchName: 'Latur Main',
                stockQty: 12,
                reorderLevel: 5,
                status: 'Normal'),
            BranchStock(
                locationId: 'loc-station',
                branchName: 'Latur Station Road',
                stockQty: 2,
                reorderLevel: 5,
                status: 'Critical'),
          ],
          suggestion: 'Transfer',
        ),
      ],
    );
