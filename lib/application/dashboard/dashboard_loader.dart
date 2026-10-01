import '../../data/drift_inventory_store.dart';
import '../../data/drift_operations_store.dart';
import '../../domain/inventory.dart';
import '../../domain/operations.dart';

/// The raw records the dashboard computes its figures from.
class DashboardInputs {
  const DashboardInputs({
    required this.orders,
    required this.kots,
    this.materials,
  });

  /// Every order on this device, each with its payment row.
  final List<OpsOrder> orders;
  final List<OpsKot> kots;

  /// Active raw materials; null when no inventory store is connected.
  final List<RawMaterial>? materials;
}

/// Reads [DashboardInputs] from the on-device database and re-reads them
/// whenever orders, order lines, payments, kitchen tickets or raw
/// materials change. Read-only: it never writes.
class DashboardLoader {
  DashboardLoader(this.ops, {this.inventory});

  final DriftOperationsStore ops;

  /// Must share [ops]' database for stock changes to refresh the stream.
  final DriftInventoryStore? inventory;

  Future<DashboardInputs> load() async => DashboardInputs(
        orders: await ops.getOrders(),
        kots: await ops.getKots(),
        materials: await inventory?.getMaterials(),
      );

  Stream<DashboardInputs> watch() {
    final db = ops.db;
    return db
        .customSelect('SELECT 1', readsFrom: {
          db.orders,
          db.orderLines,
          db.payments,
          db.kitchenTickets,
          if (inventory != null) inventory!.db.rawMaterialsTable,
        })
        .watch()
        .asyncMap((_) => load());
  }
}
