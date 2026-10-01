// Reusable application chrome — mounts PosSidebar + PosTopBar once and
// swaps only the content area beneath them. Every module (Tables, Dine
// In, and any future one) is a plain widget passed in as `content`; none
// of them own or rebuild the sidebar/top bar themselves.

import 'package:flutter/material.dart';

import '../data/drift_operations_store.dart';
import '../domain/operations.dart';
import 'operations/ops_pickers.dart';
import 'pos_sidebar.dart';
import 'pos_top_bar.dart';
import 'vinii_theme.dart';

class PosShell extends StatelessWidget {
  const PosShell(
      {super.key,
      required this.selected,
      required this.onSelect,
      required this.onNewOrder,
      required this.onOpenKitchen,
      required this.staffName,
      required this.branchName,
      required this.content,
      this.onSignOut,
      this.modules = PosModule.values});

  final PosModule selected;
  final ValueChanged<PosModule> onSelect;

  /// Null when the role cannot take orders / open the kitchen display.
  final VoidCallback? onNewOrder;
  final VoidCallback? onOpenKitchen;

  /// Sidebar modules the signed-in role opens.
  final List<PosModule> modules;
  final String staffName;
  final String branchName;
  final Widget content;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: ViniiColors.lightPageBg,
      body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PosSidebar(
            selected: selected,
            onSelect: onSelect,
            onNewOrder: onNewOrder,
            staffName: staffName,
            branchName: branchName,
            onSignOut: onSignOut,
            modules: modules),
        Expanded(
          child: Column(children: [
            PosTopBar(onOpenKitchen: onOpenKitchen),
            Expanded(child: content),
          ]),
        ),
      ]));
}

/// The POS home panel (shown when the POS module itself is selected):
/// start a new order, and the held orders ("Save & Hold") waiting to be
/// resumed — read live from the order store.
class PosModulePlaceholder extends StatefulWidget {
  const PosModulePlaceholder(
      {super.key,
      required this.title,
      this.ops,
      this.onNewOrder,
      this.onResumeOrder});
  final String title;

  /// Source of the held orders; without it the list is not shown.
  final DriftOperationsStore? ops;

  /// Opens the order screen for a new order. When null the panel points
  /// to the sidebar's "+ New Order".
  final VoidCallback? onNewOrder;

  /// Opens a held order in the order screen.
  final ValueChanged<String>? onResumeOrder;

  @override
  State<PosModulePlaceholder> createState() => _PosModulePlaceholderState();
}

class _PosModulePlaceholderState extends State<PosModulePlaceholder> {
  late final Stream<List<OpsOrder>>? _held = widget.ops?.watchHeldOrders();

  @override
  Widget build(BuildContext context) => Container(
      color: ViniiColors.lightPageBg,
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: ViniiColors.lightBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ViniiColors.lightBorder)),
          child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.point_of_sale,
                    size: 32, color: ViniiColors.greenSolid),
                const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Start a new order',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text(
                          'Dine-in, takeaway or delivery — pick the type in '
                          'the order screen.',
                          style: TextStyle(
                              color: ViniiColors.textMutedLight, fontSize: 13)),
                    ]),
                if (widget.onNewOrder != null)
                  FilledButton.icon(
                      onPressed: widget.onNewOrder,
                      style: FilledButton.styleFrom(
                          backgroundColor: ViniiColors.brandGreen,
                          foregroundColor: Colors.black),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New Order',
                          style: TextStyle(fontWeight: FontWeight.w700)))
                else
                  const Text('Use "+ New Order" in the sidebar.',
                      style: TextStyle(
                          color: ViniiColors.textSecondaryLight,
                          fontWeight: FontWeight.w600)),
              ]),
        ),
        const SizedBox(height: 24),
        const Text('Held orders',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Saved with "Save & Hold" — not sent to the kitchen yet.',
            style: TextStyle(color: ViniiColors.textMutedLight, fontSize: 13)),
        const SizedBox(height: 12),
        Expanded(
          child: _held == null
              ? const Text('Held orders are not available on this screen.',
                  style: TextStyle(color: ViniiColors.textMutedLight))
              : StreamBuilder<List<OpsOrder>>(
                  stream: _held,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Text('Could not load held orders: '
                          '${friendlyError(snap.error!)}');
                    }
                    final held = snap.data;
                    if (held == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (held.isEmpty) {
                      return const Text('No held orders.',
                          style: TextStyle(color: ViniiColors.textMutedLight));
                    }
                    return ListView.separated(
                      itemCount: held.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final o = held[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                              color: ViniiColors.lightBg,
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: ViniiColors.lightBorder)),
                          child: Row(children: [
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${o.number} · ${o.displayName}',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    Text(
                                        '${o.channel.label} · ${o.itemCount} item${o.itemCount == 1 ? '' : 's'} · '
                                        'held since ${formatClock(o.createdAt)}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: ViniiColors.textMutedLight)),
                                  ]),
                            ),
                            Text(
                                '₹${(o.grandTotalMinor / 100).toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(width: 12),
                            OutlinedButton(
                                onPressed: widget.onResumeOrder == null
                                    ? null
                                    : () => widget.onResumeOrder!(o.id),
                                child: const Text('Resume')),
                          ]),
                        );
                      },
                    );
                  }),
        ),
      ]));
}
