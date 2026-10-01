// Persistent top application bar — rebuilt from v1/POS-DINE-IN-V3.png.
// Deliberately not a Material AppBar: the reference bar has no elevation
// and a plain bottom border, so it's a plain Container instead of
// fighting Material defaults into looking like this.
//
// Only controls that do something are shown: the reference's search box,
// three unlabeled utility icons, a notification bell with a fixed "3"
// badge and a help icon had no behaviour behind them and were removed
// rather than left as dead buttons. What remains is today's date and the
// Kitchen Display shortcut (when the role may open it). Searching lives on
// each module's own screen (order screen menu search, Takeaway / Delivery
// / All Orders search boxes).

import 'package:flutter/material.dart';

import 'vinii_theme.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

class PosTopBar extends StatelessWidget {
  const PosTopBar({super.key, this.onOpenKitchen, this.today});

  /// Null hides the Kitchen Display button (the role has no kitchen
  /// access).
  final VoidCallback? onOpenKitchen;

  /// The date shown; defaults to now (tests pass a fixed one).
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final d = today ?? DateTime.now();
    return Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: const BoxDecoration(
            color: ViniiColors.lightBg,
            border: Border(bottom: BorderSide(color: ViniiColors.lightBorder))),
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined,
              size: 15, color: ViniiColors.textMutedLight),
          const SizedBox(width: 8),
          Text(
              '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}',
              style: const TextStyle(
                  color: ViniiColors.textSecondaryLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          if (onOpenKitchen != null)
            _UtilityButton(
                icon: Icons.soup_kitchen_outlined,
                label: 'Kitchen Display',
                onTap: onOpenKitchen!),
        ]));
  }
}

class _UtilityButton extends StatelessWidget {
  const _UtilityButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: label,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  color: ViniiColors.lightBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ViniiColors.lightBorder)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 17, color: ViniiColors.textSecondaryLight),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ViniiColors.textSecondaryLight)),
              ]),
            ),
          ),
        ),
      );
}
