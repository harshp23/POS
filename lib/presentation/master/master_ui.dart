import 'package:flutter/material.dart';

import '../vinii_theme.dart';

/// Shared building blocks for the Master module screens, matching the
/// Figma "finance" section (file YKRdukYpjPUuMz5W1tKlqT, node 423:55270).
/// Every Master screen composes these instead of restyling cards, tables,
/// pills and buttons locally, so the module stays visually consistent.
class MasterStyle {
  const MasterStyle._();

  static const cardBorder = Color(0xFFE5E7EB);
  static const tableHeaderBg = Color(0xFFF9FAFB);
  static const pagePadding = EdgeInsets.fromLTRB(32, 28, 32, 32);
  static const radius = 12.0;

  static const title = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: ViniiColors.textPrimaryLight);
  static const subtitle =
      TextStyle(fontSize: 14, color: ViniiColors.textSecondaryLight);
  static const sectionTitle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: ViniiColors.textPrimaryLight);
  static const label = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: ViniiColors.textSecondaryLight);
  static const value = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: ViniiColors.textPrimaryLight);
  static const body =
      TextStyle(fontSize: 13, color: ViniiColors.textPrimaryLight);
  static const muted =
      TextStyle(fontSize: 12, color: ViniiColors.textMutedLight);
  static const link = TextStyle(
      fontSize: 13, fontWeight: FontWeight.w600, color: ViniiColors.blueSolid);
}

/// Scrollable page body with the standard Master padding.
class MasterPage extends StatelessWidget {
  const MasterPage({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      padding: MasterStyle.pagePadding,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: children));
}

/// Title + subtitle on the left, action buttons on the right.
class MasterPageHeader extends StatelessWidget {
  const MasterPageHeader(
      {super.key,
      required this.title,
      this.subtitle,
      this.actions = const [],
      this.leading,
      this.titleTrailing});
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;
  final Widget? titleTrailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 12,
          spacing: 16,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Flexible(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Flexible(child: Text(title, style: MasterStyle.title)),
                        if (titleTrailing != null) ...[
                          const SizedBox(width: 10),
                          titleTrailing!
                        ],
                      ]),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(subtitle!, style: MasterStyle.subtitle),
                      ],
                    ]),
              ),
            ]),
            if (actions.isNotEmpty)
              Wrap(spacing: 10, runSpacing: 8, children: actions),
          ],
        ),
      );
}

/// "← Back to …" link used at the top of detail screens.
class MasterBackLink extends StatelessWidget {
  const MasterBackLink({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.arrow_back,
                    size: 16, color: ViniiColors.textSecondaryLight),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: ViniiColors.textSecondaryLight)),
              ]),
            ),
          ),
        ),
      );
}

/// White bordered card.
class MasterCard extends StatelessWidget {
  const MasterCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(20),
      this.color = Colors.white,
      this.borderColor = MasterStyle.cardBorder});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(MasterStyle.radius),
          border: Border.all(color: borderColor),
        ),
        child: child,
      );
}

/// Card with a bold heading, optional trailing widget, and body.
class MasterSection extends StatelessWidget {
  const MasterSection(
      {super.key,
      required this.title,
      required this.child,
      this.trailing,
      this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => MasterCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: MasterStyle.sectionTitle),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!, style: MasterStyle.muted),
                    ],
                  ]),
            ),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 16),
          child,
        ]),
      );
}

/// KPI tile: label, big value, caption.
class MasterStatCard extends StatelessWidget {
  const MasterStatCard(
      {super.key,
      required this.label,
      required this.value,
      this.caption,
      this.valueColor = ViniiColors.textPrimaryLight,
      this.captionColor = ViniiColors.textMutedLight});
  final String label;
  final String value;
  final String? caption;
  final Color valueColor;
  final Color captionColor;

  @override
  Widget build(BuildContext context) => MasterCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: MasterStyle.label),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                  letterSpacing: -0.5)),
          if (caption != null) ...[
            const SizedBox(height: 6),
            Text(caption!, style: TextStyle(fontSize: 12, color: captionColor)),
          ],
        ]),
      );
}

/// Lays out children in equal-width columns, wrapping to fewer columns on
/// narrow windows.
class MasterGrid extends StatelessWidget {
  const MasterGrid(
      {super.key,
      required this.children,
      this.columns = 4,
      this.spacing = 16,
      this.minItemWidth = 220});
  final List<Widget> children;
  final int columns;
  final double spacing;
  final double minItemWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        var cols = columns;
        while (cols > 1 &&
            (c.maxWidth - spacing * (cols - 1)) / cols < minItemWidth) {
          cols--;
        }
        final w = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final ch in children) SizedBox(width: w, child: ch)],
        );
      });
}

enum MasterButtonKind { primary, outline, danger, dangerOutline, text }

class MasterButton extends StatelessWidget {
  const MasterButton(
      {super.key,
      required this.label,
      this.onPressed,
      this.kind = MasterButtonKind.outline,
      this.icon});
  final String label;
  final VoidCallback? onPressed;
  final MasterButtonKind kind;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (kind) {
      MasterButtonKind.primary => (
          ViniiColors.brandGreen,
          Colors.black,
          ViniiColors.brandGreen
        ),
      MasterButtonKind.outline => (
          Colors.white,
          ViniiColors.textPrimaryLight,
          MasterStyle.cardBorder
        ),
      MasterButtonKind.danger => (
          ViniiColors.redSolid,
          Colors.white,
          ViniiColors.redSolid
        ),
      MasterButtonKind.dangerOutline => (
          Colors.white,
          ViniiColors.redSolid,
          const Color(0xFFFCA5A5)
        ),
      MasterButtonKind.text => (
          Colors.transparent,
          ViniiColors.textPrimaryLight,
          Colors.transparent
        ),
    };
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed ?? () {},
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Search input used in filter bars.
class MasterSearchField extends StatelessWidget {
  const MasterSearchField(
      {super.key, required this.hint, this.onChanged, this.width = 360});
  final String hint;
  final ValueChanged<String>? onChanged;
  final double? width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: 40,
        child: TextField(
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                fontSize: 13, color: ViniiColors.textMutedLight),
            prefixIcon: const Icon(Icons.search,
                size: 18, color: ViniiColors.textMutedLight),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: MasterStyle.cardBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: MasterStyle.cardBorder)),
          ),
        ),
      );
}

/// "Label: Value ⌄" dropdown chip. Pass [options] to make it selectable.
class MasterFilterButton extends StatelessWidget {
  const MasterFilterButton(
      {super.key, required this.label, this.options, this.onSelected});
  final String label;
  final List<String>? options;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MasterStyle.cardBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: ViniiColors.textPrimaryLight)),
        const SizedBox(width: 6),
        const Icon(Icons.keyboard_arrow_down,
            size: 16, color: ViniiColors.textSecondaryLight),
      ]),
    );
    if (options == null) return chip;
    return PopupMenuButton<String>(
      tooltip: '',
      onSelected: onSelected,
      itemBuilder: (_) =>
          [for (final o in options!) PopupMenuItem(value: o, child: Text(o))],
      child: chip,
    );
  }
}

/// Card holding a search field and filter chips in a wrapping row.
class MasterFilterBar extends StatelessWidget {
  const MasterFilterBar({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => MasterCard(
        padding: const EdgeInsets.all(16),
        child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: children),
      );
}

enum PillTone { green, amber, red, blue, gray, purple }

class MasterStatusPill extends StatelessWidget {
  const MasterStatusPill(this.text, {super.key, this.tone});
  final String text;

  /// When null, the tone is inferred from common status words.
  final PillTone? tone;

  static PillTone toneFor(String s) {
    final t = s.toLowerCase();
    if (t.contains('low') ||
        t.contains('pending') ||
        t.contains('draft') ||
        t.contains('progress') ||
        t.contains('review') ||
        t.contains('partial') ||
        t.contains('scheduled') ||
        t.contains('warning') ||
        t.contains('stale') ||
        t.contains('medium')) {
      return PillTone.amber;
    }
    if (t.contains('out') ||
        t.contains('reject') ||
        t.contains('cancel') ||
        t.contains('fail') ||
        t.contains('critical') ||
        t.contains('overdue') ||
        t.contains('high') ||
        t.contains('expired')) {
      return PillTone.red;
    }
    if (t.contains('inactive') ||
        t.contains('closed') ||
        t.contains('paused')) {
      return PillTone.gray;
    }
    if (t.contains('sent') ||
        t.contains('transit') ||
        t.contains('approved') ||
        t.contains('ordered') ||
        t.contains('new') ||
        t.contains('info')) {
      return PillTone.blue;
    }
    return PillTone.green;
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone ?? toneFor(text)) {
      PillTone.green => (
          ViniiColors.successPillBg,
          ViniiColors.successPillText
        ),
      PillTone.amber => (const Color(0xFFFEF3C7), const Color(0xFFB45309)),
      PillTone.red => (const Color(0xFFFEE2E2), ViniiColors.redSolid),
      PillTone.blue => (const Color(0xFFDBEAFE), ViniiColors.blueSolid),
      PillTone.gray => (ViniiColors.grayTint, ViniiColors.graySolid),
      PillTone.purple => (ViniiColors.purpleTint, ViniiColors.purpleSolid),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          style:
              TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

/// Column definition for [MasterTable]. [flex] sets relative width.
class MasterColumn {
  const MasterColumn(this.label, {this.flex = 1, this.alignEnd = false});
  final String label;
  final int flex;
  final bool alignEnd;
}

/// Figma-style table: grey header row, divided rows, optional row tap.
/// Scrolls horizontally when the window is narrower than [minWidth].
class MasterTable extends StatelessWidget {
  const MasterTable(
      {super.key,
      required this.columns,
      required this.rows,
      this.onRowTap,
      this.minWidth = 960,
      this.footer,
      this.selectedRows = const {}});
  final List<MasterColumn> columns;
  final List<List<Widget>> rows;
  final ValueChanged<int>? onRowTap;
  final double minWidth;
  final Widget? footer;
  final Set<int> selectedRows;

  Widget _cells(List<Widget> cells) => Row(children: [
        for (var i = 0; i < columns.length; i++)
          Expanded(
            flex: columns[i].flex,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                  alignment: columns[i].alignEnd
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: i < cells.length ? cells[i] : const SizedBox()),
            ),
          ),
      ]);

  @override
  Widget build(BuildContext context) {
    final table =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        color: MasterStyle.tableHeaderBg,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: _cells([
          for (final c in columns)
            Text(c.label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ViniiColors.textSecondaryLight)),
        ]),
      ),
      for (var r = 0; r < rows.length; r++)
        Material(
          color: selectedRows.contains(r)
              ? ViniiColors.lightGreenTint
              : Colors.white,
          child: InkWell(
            onTap: onRowTap == null ? null : () => onRowTap!(r),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              decoration: const BoxDecoration(
                  border:
                      Border(top: BorderSide(color: MasterStyle.cardBorder))),
              child: _cells(rows[r]),
            ),
          ),
        ),
      if (footer != null)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: MasterStyle.cardBorder))),
          child: footer,
        ),
    ]);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MasterStyle.radius),
        border: Border.all(color: MasterStyle.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, c) => c.maxWidth >= minWidth
            ? table
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: minWidth, child: table)),
      ),
    );
  }
}

/// Two-line table cell: bold primary + muted secondary.
class MasterCellTitle extends StatelessWidget {
  const MasterCellTitle(this.title,
      {super.key, this.subtitle, this.isLink = false, this.emoji});
  final String title;
  final String? subtitle;
  final bool isLink;
  final String? emoji;

  @override
  Widget build(BuildContext context) => Row(children: [
        if (emoji != null) ...[
          Text(emoji!, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isLink
                            ? ViniiColors.blueSolid
                            : ViniiColors.textPrimaryLight)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      overflow: TextOverflow.ellipsis,
                      style: MasterStyle.muted),
                ],
              ]),
        ),
      ]);
}

/// Plain table cell text.
class MasterCellText extends StatelessWidget {
  const MasterCellText(this.text,
      {super.key, this.bold = false, this.color, this.size = 13});
  final String text;
  final bool bold;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => Text(text,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
          fontSize: size,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          color: color ?? ViniiColors.textPrimaryLight));
}

/// Inline "Edit · Pause" style row actions.
class MasterRowActions extends StatelessWidget {
  const MasterRowActions(this.actions, {super.key, this.onTap});
  final List<String> actions;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) => Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text('·', style: MasterStyle.muted),
              ),
            InkWell(
              onTap: () => onTap?.call(actions[i]),
              child: Text(actions[i],
                  style: MasterStyle.link.copyWith(
                      color: const {'delete', 'cancel', 'reject'}
                              .contains(actions[i].toLowerCase())
                          ? ViniiColors.redSolid
                          : ViniiColors.blueSolid)),
            ),
          ],
        ],
      );
}

/// Underlined tab strip (e.g. Overview | Stock | Suppliers …).
class MasterTabStrip extends StatelessWidget {
  const MasterTabStrip(
      {super.key,
      required this.tabs,
      required this.selected,
      required this.onSelect});
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: MasterStyle.cardBorder))),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (var i = 0; i < tabs.length; i++)
              InkWell(
                onTap: () => onSelect(i),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            width: 2,
                            color: i == selected
                                ? ViniiColors.greenSolid
                                : Colors.transparent)),
                  ),
                  child: Text(tabs[i],
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              i == selected ? FontWeight.w600 : FontWeight.w500,
                          color: i == selected
                              ? ViniiColors.textPrimaryLight
                              : ViniiColors.textSecondaryLight)),
                ),
              ),
          ]),
        ),
      );
}

/// Label above value, used in info grids.
class MasterKeyValue extends StatelessWidget {
  const MasterKeyValue(this.label, this.value,
      {super.key, this.valueColor, this.trailing});
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: MasterStyle.label),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                child: Text(value,
                    style: MasterStyle.value.copyWith(color: valueColor)),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ]),
          ]);
}

/// Tinted callout banner (info / warning / danger / success).
class MasterBanner extends StatelessWidget {
  const MasterBanner(
      {super.key,
      required this.message,
      this.title,
      this.tone = PillTone.amber,
      this.trailing,
      this.icon});
  final String? title;
  final String message;
  final PillTone tone;
  final Widget? trailing;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg) = switch (tone) {
      PillTone.amber => (
          ViniiColors.amberTint,
          const Color(0xFFFCD34D),
          const Color(0xFF92400E)
        ),
      PillTone.red => (
          ViniiColors.redTint,
          const Color(0xFFFCA5A5),
          const Color(0xFF991B1B)
        ),
      PillTone.blue => (
          ViniiColors.blueTint,
          const Color(0xFF93C5FD),
          const Color(0xFF1E40AF)
        ),
      PillTone.green || PillTone.purple || PillTone.gray => (
          ViniiColors.greenTint,
          const Color(0xFF86EFAC),
          ViniiColors.emeraldText
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (icon != null) ...[
          Text(icon!, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 10),
        ],
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title != null)
              Text(title!,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
            if (title != null) const SizedBox(height: 2),
            Text(message, style: TextStyle(fontSize: 13, color: fg)),
          ]),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ]),
    );
  }
}

/// Labelled text input as used in Figma forms.
class MasterTextField extends StatelessWidget {
  const MasterTextField(
      {super.key,
      required this.label,
      this.initialValue,
      this.hint,
      this.maxLines = 1,
      this.suffix});
  final String label;
  final String? initialValue;
  final String? hint;
  final int maxLines;
  final String? suffix;

  @override
  Widget build(BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ViniiColors.textPrimaryLight)),
            const SizedBox(height: 6),
            TextFormField(
              initialValue: initialValue,
              maxLines: maxLines,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: hint,
                suffixText: suffix,
                hintStyle: const TextStyle(
                    fontSize: 13, color: ViniiColors.textMutedLight),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: MasterStyle.cardBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: MasterStyle.cardBorder)),
              ),
            ),
          ]);
}

/// Simple horizontal progress bar with a label and percentage.
class MasterProgress extends StatelessWidget {
  const MasterProgress(
      {super.key,
      required this.value,
      this.label,
      this.color = ViniiColors.greenSolid});
  final double value; // 0..1
  final String? label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Expanded(child: Text(label!, style: MasterStyle.body)),
                  Text('${(value * 100).round()}%',
                      style: MasterStyle.body
                          .copyWith(fontWeight: FontWeight.w600)),
                ]),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                  value: value.clamp(0, 1),
                  minHeight: 6,
                  color: color,
                  backgroundColor: ViniiColors.grayTint),
            ),
          ]);
}

/// Shows a transient confirmation for buttons whose backend doesn't exist
/// yet, rather than silently doing nothing.
void showMasterNotice(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    behavior: SnackBarBehavior.floating,
    width: 420,
    duration: const Duration(seconds: 2),
  ));
}

// ---------------------------------------------------------------------------
// Shared vocabularies — one list per concept, used by every Master screen.
// ---------------------------------------------------------------------------

/// GST slabs offered wherever a tax rate is picked (menu items, POs).
const masterGstSlabs = <double>[0, 5, 12, 18, 28];

/// "GST 5%", "0% (Exempt)", or "7.5%" for a custom rate kept from old data.
String gstSlabLabel(double pct) {
  final n =
      pct == pct.roundToDouble() ? pct.toStringAsFixed(0) : pct.toString();
  if (pct == 0) return '0% (Exempt)';
  return masterGstSlabs.contains(pct) ? 'GST $n%' : '$n%';
}

/// Units a raw material — and a recipe line costed from it — is measured in.
const masterUnits = ['kg', 'g', 'L', 'ml', 'pcs'];

/// The one list of sales channels used by menu items, offers and recipe
/// menu activation.
const masterSalesChannels = [
  'POS',
  'Dine-In',
  'Takeaway',
  'Captain App',
  'Kiosk',
  'App',
  'Web',
  'Swiggy',
  'Zomato',
];

/// Maps older channel spellings ("POS Dine-In", "Swiggy Delivery", "Web
/// Portal", "Take Away" …) onto [masterSalesChannels]. Anything else is
/// returned as it was stored (trimmed), so no saved value is lost.
String canonicalSalesChannel(String raw) {
  final t = raw.trim();
  String norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), ' ').trim();
  final k = norm(t);
  for (final c in masterSalesChannels) {
    if (norm(c) == k) return c;
  }
  return switch (k) {
    'pos dine in' || 'dine in only' || 'dinein' => 'Dine-In',
    'take away' || 'take out' || 'parcel' => 'Takeaway',
    'swiggy delivery' => 'Swiggy',
    'zomato delivery' => 'Zomato',
    'web portal' || 'website' => 'Web',
    'mobile app' || 'customer app' => 'App',
    _ => t,
  };
}

/// Human label for a lower-case stored code: "non-veg" → "Non-Veg",
/// "all day" → "All Day", "hot_kitchen" → "Hot Kitchen". The stored value
/// itself is never changed.
String masterHumanLabel(String raw) {
  final t = raw.trim().replaceAll('_', ' ');
  if (t.isEmpty) return t;
  final out = StringBuffer();
  var upper = true;
  for (final ch in t.split('')) {
    out.write(upper ? ch.toUpperCase() : ch);
    upper = ch == ' ' || ch == '-' || ch == '/';
  }
  return out.toString();
}

/// Opens [MasterMultiSelectDialog]; returns the chosen set, or null when
/// cancelled.
Future<Set<String>?> showMasterMultiSelect(
  BuildContext context, {
  required String title,
  required List<String> options,
  required Set<String> selected,
  required String emptyText,
}) =>
    showDialog<Set<String>>(
      context: context,
      builder: (_) => MasterMultiSelectDialog(
          title: title,
          options: options,
          selected: selected,
          emptyText: emptyText),
    );

/// Searchable checkbox list; pops the chosen set (or null on cancel).
class MasterMultiSelectDialog extends StatefulWidget {
  const MasterMultiSelectDialog({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.emptyText,
  });
  final String title;
  final List<String> options;
  final Set<String> selected;
  final String emptyText;

  @override
  State<MasterMultiSelectDialog> createState() =>
      _MasterMultiSelectDialogState();
}

class _MasterMultiSelectDialogState extends State<MasterMultiSelectDialog> {
  late final Set<String> _picked = {...widget.selected};
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final shown = widget.options
        .where((o) => o.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(children: [
          MasterSearchField(
              hint: 'Search…',
              width: double.infinity,
              onChanged: (v) => setState(() => _q = v)),
          const SizedBox(height: 8),
          Expanded(
            child: widget.options.isEmpty
                ? Center(
                    child: Text(widget.emptyText,
                        textAlign: TextAlign.center, style: MasterStyle.muted))
                : ListView(children: [
                    for (final o in shown)
                      CheckboxListTile(
                        dense: true,
                        value: _picked.contains(o),
                        title: Text(o, style: MasterStyle.body),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (v) => setState(() =>
                            v == true ? _picked.add(o) : _picked.remove(o)),
                      ),
                  ]),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('${_picked.length} selected', style: MasterStyle.muted),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _picked),
            child: const Text('Apply')),
      ],
    );
  }
}
