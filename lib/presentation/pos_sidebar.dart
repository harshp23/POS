// Persistent left navigation — rebuilt 1:1 from the sidebar visible in
// v1/POS-DINE-IN-V3.png (the same rail also appears, cropped, in every
// other v1/ reference). This is application chrome: PosShell mounts one
// instance and swaps only the content area, so it never gets rebuilt
// per-page and never duplicated inside a page.

import 'package:flutter/material.dart';

import 'vinii_theme.dart';

enum PosModule {
  pos,
  tables,
  allOrders,
  dineIn,
  takeaway,
  delivery,
  online,
  menu,
}

const _posModuleIcons = <PosModule, IconData>{
  PosModule.pos: Icons.dashboard_outlined,
  PosModule.tables: Icons.table_bar_outlined,
  PosModule.allOrders: Icons.receipt_long_outlined,
  PosModule.dineIn: Icons.restaurant_outlined,
  PosModule.takeaway: Icons.shopping_bag_outlined,
  PosModule.delivery: Icons.moped_outlined,
  PosModule.online: Icons.language_outlined,
  PosModule.menu: Icons.menu_book_outlined,
};

const _posModuleLabels = <PosModule, String>{
  PosModule.pos: 'POS',
  PosModule.tables: 'Tables',
  PosModule.allOrders: 'All Orders',
  PosModule.dineIn: 'Dine In',
  PosModule.takeaway: 'Takeaway',
  PosModule.delivery: 'Delivery',
  PosModule.online: 'Online',
  PosModule.menu: 'Menu',
};

class PosSidebar extends StatelessWidget {
  const PosSidebar(
      {super.key,
      required this.selected,
      required this.onSelect,
      required this.onNewOrder,
      required this.staffName,
      required this.branchName,
      this.onSignOut,
      this.modules = PosModule.values});

  final PosModule selected;
  final ValueChanged<PosModule> onSelect;

  /// Null hides "New Order" (the role cannot take orders).
  final VoidCallback? onNewOrder;

  /// The modules this staff member's role opens, in sidebar order.
  final List<PosModule> modules;
  final String staffName;
  final String branchName;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) => Container(
      width: 220,
      color: ViniiColors.sidebarDark,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 12, 20),
          child: Row(children: [
            Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: ViniiColors.brandGreen,
                    borderRadius: BorderRadius.circular(7)),
                child: const Text('V',
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 15))),
            const SizedBox(width: 10),
            const Expanded(
                child: Text('VINII POS',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15))),
            const Icon(Icons.menu, color: Colors.white38, size: 18),
          ]),
        ),
        if (onNewOrder != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                    onPressed: onNewOrder,
                    style: FilledButton.styleFrom(
                        backgroundColor: ViniiColors.brandGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Order',
                        style: TextStyle(fontWeight: FontWeight.w700)))),
          ),
        const SizedBox(height: 22),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Align(
              alignment: Alignment.centerLeft,
              child: Text('NAVIGATION',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6))),
        ),
        const SizedBox(height: 8),
        // Scrollable rather than a fixed Column + Spacer: on a short
        // window (or the default flutter test surface) 8 fixed-height
        // rows plus the header/button/footer overflow a plain Column —
        // caught by actually running the widget test, not by inspection.
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              for (final module in modules)
                SidebarNavItem(
                    icon: _posModuleIcons[module]!,
                    label: _posModuleLabels[module]!,
                    isSelected: module == selected,
                    onTap: () => onSelect(module)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF1F2029)))),
          child: Row(children: [
            CircleAvatar(
                radius: 16,
                backgroundColor: ViniiColors.brandGreen.withValues(alpha: 0.2),
                child: Text(
                    staffName
                        .trim()
                        .split(' ')
                        .map((s) => s.isEmpty ? '' : s[0])
                        .take(2)
                        .join(),
                    style: const TextStyle(
                        color: ViniiColors.brandGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 12))),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(staffName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  Text(branchName,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11)),
                ])),
            if (onSignOut != null)
              IconButton(
                icon: const Icon(Icons.logout, size: 16, color: Colors.white54),
                tooltip: 'Sign Out',
                onPressed: onSignOut,
              ),
          ]),
        ),
      ]));
}

class SidebarNavItem extends StatefulWidget {
  const SidebarNavItem(
      {super.key,
      required this.icon,
      required this.label,
      required this.isSelected,
      required this.onTap});

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<SidebarNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.isSelected;
    final color = selected
        ? ViniiColors.brandGreen
        : (_hovered ? Colors.white70 : Colors.white54);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  color: selected
                      ? ViniiColors.sidebarSelectedTint
                      : (_hovered
                          ? Colors.white.withValues(alpha: 0.04)
                          : null),
                  borderRadius: BorderRadius.circular(8),
                  border: selected
                      ? const Border(
                          right: BorderSide(
                              color: ViniiColors.brandGreen, width: 3))
                      : null),
              child: Row(children: [
                Icon(widget.icon, size: 18, color: color),
                const SizedBox(width: 12),
                Text(widget.label,
                    style: TextStyle(
                        color: color,
                        fontSize: 13.5,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
