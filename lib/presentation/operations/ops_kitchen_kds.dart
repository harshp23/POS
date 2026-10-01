part of 'ops_kitchen_screen.dart';

// Kitchen Display (KDS) board — v1/operations/OPS-KITCHEN-DISPLAY-KDS-DEFAULT.png

/// Pending items at or above these counts make a station's workload
/// High / Medium (below is Low).
const _highLoadItems = 10;
const _mediumLoadItems = 8;

String _workload(int pendingItems) => pendingItems >= _highLoadItems
    ? 'High'
    : pendingItems >= _mediumLoadItems
        ? 'Medium'
        : 'Low';

String _channelChip(OpsChannel c) => switch (c) {
      OpsChannel.dineIn => 'Dine-in',
      OpsChannel.takeaway => 'Takeaway',
      OpsChannel.delivery => 'Delivery',
    };

/// Readable foreground for a (possibly bright) station colour.
Color _deepen(Color c) {
  final hsl = HSLColor.fromColor(c);
  return hsl.lightness > 0.36 ? hsl.withLightness(0.34).toColor() : c;
}

bool _isOpen(OpsKot k) =>
    k.status == OpsKotStatus.newTicket || k.status == OpsKotStatus.preparing;

class _KdsView extends StatelessWidget {
  const _KdsView({required this.host});
  final _OpsKitchenScreenState host;

  String? get _station => host._station;

  List<OpsOrderLine> _lines(OpsKot k) {
    final st = _station?.toLowerCase();
    return st == null
        ? k.order.lines
        : [
            for (final l in k.order.lines)
              if (l.station.toLowerCase() == st) l
          ];
  }

  static int _openOrder(OpsKot a, OpsKot b) {
    if (a.urgent != b.urgent) return a.urgent ? -1 : 1;
    return a.createdAt.compareTo(b.createdAt);
  }

  @override
  Widget build(BuildContext context) {
    final all = host._kots ?? const <OpsKot>[];
    final visible = [
      for (final k in all)
        if (_lines(k).isNotEmpty) k
    ];
    List<OpsKot> of(OpsKotStatus s) =>
        visible.where((k) => k.status == s).toList();
    final newT = of(OpsKotStatus.newTicket)..sort(_openOrder);
    final prog = of(OpsKotStatus.preparing)..sort(_openOrder);
    final ready = of(OpsKotStatus.ready)..sort(_openOrder);
    final served = of(OpsKotStatus.completed)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final active = [...newT, ...prog, ...ready];
    final delayed = active.where((k) => host._isDelayed(k, _station)).length;

    final kpis = [
      (
        'QUEUE / CRITICAL',
        active
            .where(
                (k) => _isOpen(k) && (k.urgent || host._isDelayed(k, _station)))
            .length,
        _Tone.red
      ),
      ('PENDING', newT.length, _Tone.amber),
      (
        'DINE-IN ORDERS',
        active.where((k) => k.order.channel == OpsChannel.dineIn).length,
        _Tone.blue
      ),
      (
        'ONLINE DELIVERY',
        active
            .where((k) =>
                k.order.channel == OpsChannel.delivery ||
                k.order.source.toLowerCase() == 'online')
            .length,
        _Tone.purple
      ),
      ('DELAYED', delayed, _Tone.orange),
      ('COMPLETED TODAY', served.length, _Tone.green),
    ];

    final stationBand = Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _Kc.border))),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 10,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _PillTab(
                  label: 'All Stations',
                  selected: _station == null,
                  onTap: () => host._selectStation(null)),
              for (final st in host._activeStations)
                _PillTab(
                    label: st,
                    selected: _station == st,
                    onTap: () => host._selectStation(st)),
              Tooltip(
                message: 'Kitchen stations',
                child: Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: const BorderSide(color: _Kc.border)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: host._openStationSettings,
                    child: const SizedBox(
                        width: 34,
                        height: 34,
                        child: Icon(Icons.settings_outlined,
                            size: 17, color: _Kc.label)),
                  ),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              host._viewSwitch(),
              _AlertsButton(
                  enabled: host._alerts.soundsEnabled,
                  onTap: host._openAlertSettings),
            ],
          ),
        ],
      ),
    );

    final kpiBand = Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _Kc.border))),
      child: LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 860
            ? 6
            : c.maxWidth >= 520
                ? 3
                : 2;
        final w = (c.maxWidth - (cols - 1) * 12) / cols;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final (label, value, tone) in kpis)
            SizedBox(width: w, child: _KpiTile(label, value, tone)),
        ]);
      }),
    );

    Widget columns() {
      return LayoutBuilder(builder: (context, c) {
        const gap = 12.0;
        final colW = ((c.maxWidth - 3 * gap) / 4).clamp(200.0, 1000.0);
        final row = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, (title, tone, list)) in [
              ('NEW', _Tone.blue, newT),
              ('IN PROGRESS', _Tone.amber, prog),
              ('READY', _Tone.green, ready),
              ('SERVED', _Tone.gray, served),
            ].indexed) ...[
              if (i > 0) const SizedBox(width: gap),
              SizedBox(
                  width: colW,
                  child: _column(title, tone, list,
                      empty: title == 'SERVED'
                          ? 'Nothing served yet today'
                          : 'No tickets')),
            ],
          ],
        );
        return colW * 4 + 3 * gap > c.maxWidth + 0.5
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal, child: row)
            : row;
      });
    }

    // Tickets whose order was cancelled leave the columns; the kitchen
    // sees them above the board as "Order cancelled".
    Widget board() {
      if (host._kots == null) return host._statusBody();
      final cancelled = host._recentlyCancelled;
      if (cancelled.isEmpty) return columns();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _CancelledBanner(kots: cancelled),
        const SizedBox(height: 12),
        columns(),
      ]);
    }

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 1000 && c.maxHeight.isFinite;
      if (wide) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            stationBand,
            kpiBand,
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: board(),
                    ),
                  ),
                  _summaryPanel(all, wide: true),
                ],
              ),
            ),
          ],
        );
      }
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            stationBand,
            kpiBand,
            Padding(padding: const EdgeInsets.all(16), child: board()),
            _summaryPanel(all, wide: false),
          ],
        ),
      );
    });
  }

  // ---- Kanban ------------------------------------------------------------

  Widget _column(String title, _Tone tone, List<OpsKot> list,
          {required String empty}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 36,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                color: tone.bg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tone.border)),
            child: Text('$title (${list.length})',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: tone.fg)),
          ),
          const SizedBox(height: 10),
          if (list.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 22),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _Kc.border)),
              child: Text(empty,
                  style: const TextStyle(fontSize: 12, color: _Kc.textMuted)),
            ),
          for (final k in list)
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _card(k, _lines(k))),
        ],
      );

  String _mainStation(List<OpsOrderLine> lines) {
    final count = <String, int>{};
    for (final l in lines) {
      count[l.station] = (count[l.station] ?? 0) + l.quantity;
    }
    var best = lines.first.station;
    for (final e in count.entries) {
      if (e.value > (count[best] ?? 0)) best = e.key;
    }
    return best;
  }

  Widget _card(OpsKot k, List<OpsOrderLine> lines) {
    final servedCard = k.status == OpsKotStatus.completed;
    final delayed = host._isDelayed(k, _station);
    final urgent = k.urgent && !servedCard;
    final hot = urgent || delayed;
    final done = lines.where((l) => l.done).length;
    final flash = host._flashing(k.ticketId);
    final age = k.ageMinutes(host._now);
    final timeColor = hot ? _Kc.red : _Kc.label;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: Text('$done/${lines.length} items done',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF4B5563))),
          ),
          SizedBox(
            width: 44,
            height: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: lines.isEmpty ? 0 : done / lines.length,
                backgroundColor: const Color(0xFFF1F2F4),
                color: hot ? _Kc.red : _Kc.progressGreen,
                minHeight: 4,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Row(children: [
              Flexible(
                child: Text(k.order.number,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _Kc.ink)),
              ),
              const SizedBox(width: 5),
              _SmallChip(_channelChip(k.order.channel),
                  bg: _Kc.qtyBg, fg: const Color(0xFF4B5563)),
            ]),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: delayed
                ? 'Delayed — past the ${host._thresholdOf(k, _station)} min target'
                : 'Waiting since ${formatClock(k.createdAt)}',
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.schedule, size: 13, color: timeColor),
              const SizedBox(width: 3),
              Text(_ageText(age),
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: timeColor)),
            ]),
          ),
        ]),
        const SizedBox(height: 6),
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              _KitchenSwitch(
                  value: l.done,
                  onChanged:
                      servedCard ? null : (v) => host._setLineDone(k, l, v)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(l.name,
                    style: TextStyle(
                        fontSize: 13,
                        color: l.done ? _Kc.sub : _Kc.ink,
                        decoration: l.done
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: _Kc.sub)),
              ),
              Text('x${l.quantity}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: l.done ? _Kc.sub : _Kc.ink)),
            ]),
          ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Align(
                alignment: Alignment.centerLeft,
                child: _stationChip(_mainStation(lines))),
          ),
          const SizedBox(width: 6),
          if (_isOpen(k)) ...[
            _urgentControl(k),
            const SizedBox(width: 6),
          ],
          _action(k),
        ]),
      ],
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: flash
                ? _Kc.lime
                : urgent
                    ? _Kc.red
                    : _Kc.border,
            width: flash
                ? 2.5
                : urgent
                    ? 2
                    : 1),
        boxShadow: flash
            ? [
                BoxShadow(
                    color: _Kc.lime.withValues(alpha: 0.45), blurRadius: 14)
              ]
            : const [],
      ),
      child: servedCard ? Opacity(opacity: 0.6, child: body) : body,
    );
  }

  Widget _stationChip(String station) {
    final cfg = host._stationConfig(station);
    final color = cfg == null ? _Kc.sub : Color(cfg.colorValue);
    return _SmallChip(station,
        bg: color.withValues(alpha: 0.12), fg: _deepen(color));
  }

  Widget _urgentControl(OpsKot k) => k.urgent
      ? Tooltip(
          message: 'Urgent — tap to clear',
          child: _SolidButton(
              label: 'Urgent',
              bg: _Kc.red,
              fg: Colors.white,
              height: 24,
              fontSize: 11.5,
              radius: 4,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              onPressed: () => host._toggleUrgent(k)),
        )
      : Tooltip(
          message: 'Mark urgent',
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: const BorderSide(color: _Kc.border)),
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => host._toggleUrgent(k),
              child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: Icon(Icons.flag_outlined, size: 14, color: _Kc.sub)),
            ),
          ),
        );

  Widget _action(OpsKot k) {
    final busy = host._busy.contains(k.ticketId);
    Widget lime(String label, VoidCallback onTap, String tip) => Tooltip(
          message: tip,
          child: _SolidButton(
              label: label,
              bg: _Kc.lime,
              fg: _Kc.ink,
              height: 24,
              fontSize: 11.5,
              radius: 4,
              busy: busy,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              onPressed: onTap),
        );
    return switch (k.status) {
      OpsKotStatus.newTicket =>
        lime('Start', () => host._advance(k), 'Start cooking'),
      OpsKotStatus.preparing =>
        lime('Ready', () => host._markReady(k), 'Mark ticket ready'),
      OpsKotStatus.ready => Tooltip(
          message: 'Mark served — moves to Served',
          child: _SolidButton(
              label: 'Mark Served',
              bg: const Color(0xFFD1F1E6),
              fg: _Kc.green,
              height: 28,
              fontSize: 12,
              radius: 20,
              busy: busy,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              onPressed: () => host._advance(k)),
        ),
      OpsKotStatus.completed =>
        const _SmallChip('Served', bg: _Kc.qtyBg, fg: _Kc.sub),
    };
  }

  // ---- Summary panel -----------------------------------------------------

  Widget _summaryPanel(List<OpsKot> all, {required bool wide}) {
    final collapsed = host._summaryCollapsed;
    if (wide && collapsed) {
      return Container(
        width: 44,
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(left: BorderSide(color: _Kc.border))),
        child: Column(children: [
          const SizedBox(height: 10),
          IconButton(
            tooltip: 'Show summary',
            onPressed: host._toggleSummary,
            icon: const Icon(Icons.chevron_left, color: _Kc.label),
          ),
          const SizedBox(height: 8),
          const RotatedBox(
            quarterTurns: 3,
            child: Text('Summary View',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: _Kc.ink)),
          ),
        ]),
      );
    }

    final header = Row(children: [
      const Expanded(
        child: Text('Summary View',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: _Kc.ink)),
      ),
      InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: host._toggleSummary,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(collapsed ? 'Expand' : 'Collapse',
                style: const TextStyle(fontSize: 12, color: _Kc.label)),
            const SizedBox(width: 4),
            Icon(
                collapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                size: 16,
                color: _Kc.label),
          ]),
        ),
      ),
    ]);

    final content = collapsed
        ? const <Widget>[]
        : <Widget>[
            const SizedBox(height: 12),
            Row(children: [
              for (final (i, (t, label)) in [
                (_SummaryTab.category, 'Category'),
                (_SummaryTab.item, 'Item'),
                (_SummaryTab.overall, 'Overall'),
              ].indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: _segment(label, t)),
              ],
            ]),
            const SizedBox(height: 14),
            ...switch (host._summaryTab) {
              _SummaryTab.category => _categorySummary(all),
              _SummaryTab.item => _itemSummary(all),
              _SummaryTab.overall => _overallSummary(all),
            },
          ];

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [header, ...content],
    );

    if (!wide) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: _Kc.border))),
        child: column,
      );
    }
    return Container(
      width: 272,
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: _Kc.border))),
      child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16), child: column),
    );
  }

  Widget _segment(String label, _SummaryTab t) {
    final sel = host._summaryTab == t;
    return Material(
      color: sel ? const Color(0xFFEAF9DA) : const Color(0xFFF4F4F2),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => host._selectSummaryTab(t),
        child: Container(
          height: 30,
          alignment: Alignment.center,
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                  color: sel ? _Kc.ink : _Kc.sub)),
        ),
      ),
    );
  }

  static const _sectionLabel = TextStyle(
      fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF4B5563));

  List<Widget> _categorySummary(List<OpsKot> all) {
    final stations = host._activeStations;
    final lower = {for (final s in stations) s.toLowerCase(): s};
    String bucket(String station) => lower[station.toLowerCase()] ?? 'Other';

    final items = <String, int>{for (final s in stations) s: 0, 'Other': 0};
    final delayedIds = <String, Set<String>>{
      for (final s in stations) s: {},
      'Other': {}
    };
    for (final k in all) {
      if (!_isOpen(k)) continue;
      for (final l in k.order.lines) {
        if (l.done) continue;
        final b = bucket(l.station);
        items[b] = items[b]! + l.quantity;
        if (host._isDelayed(k, b == 'Other' ? null : b)) {
          delayedIds[b]!.add(k.ticketId);
        }
      }
    }
    return [
      const Text('Category', style: _sectionLabel),
      const SizedBox(height: 8),
      for (final s in [...stations, 'Other'])
        _SummaryCard(
          title: s,
          trailing: '${items[s]} items',
          rows: [
            ('Delayed', '${delayedIds[s]!.length}', _Kc.red, FontWeight.w500),
            ('Workload', _workload(items[s]!), _Kc.ink, FontWeight.w600),
          ],
        ),
    ];
  }

  List<Widget> _itemSummary(List<OpsKot> all) {
    final qty = <String, int>{};
    final station = <String, String>{};
    for (final k in all) {
      if (!_isOpen(k)) continue;
      for (final l in k.order.lines) {
        if (l.done) continue;
        qty[l.name] = (qty[l.name] ?? 0) + l.quantity;
        station[l.name] = l.station;
      }
    }
    final rows = qty.entries.toList()
      ..sort((a, b) => b.value != a.value
          ? b.value.compareTo(a.value)
          : a.key.compareTo(b.key));
    return [
      const Text('Pending items', style: _sectionLabel),
      const SizedBox(height: 8),
      if (rows.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('Nothing pending — the kitchen is clear.',
              style: TextStyle(fontSize: 12.5, color: _Kc.sub)),
        ),
      for (final e in rows)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _Kc.border)),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.key,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: _Kc.ink)),
                  const SizedBox(height: 2),
                  Text(station[e.key]!,
                      style: const TextStyle(fontSize: 11.5, color: _Kc.sub)),
                ],
              ),
            ),
            Text('x${e.value}',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: _Kc.ink)),
          ]),
        ),
    ];
  }

  List<Widget> _overallSummary(List<OpsKot> all) {
    final open = all.where((k) => k.status != OpsKotStatus.completed).toList();
    final cooking = all.where(_isOpen).toList();
    var pending = 0, done = 0;
    for (final k in cooking) {
      for (final l in k.order.lines) {
        if (l.done) {
          done += l.quantity;
        } else {
          pending += l.quantity;
        }
      }
    }
    final delayed = cooking.where((k) => host._isDelayed(k)).length;
    final avgWait = cooking.isEmpty
        ? 0
        : (cooking.fold<int>(0, (s, k) => s + k.ageMinutes(host._now)) /
                cooking.length)
            .round();
    int count(OpsKotStatus s) => all.where((k) => k.status == s).length;
    return [
      const Text('Overall', style: _sectionLabel),
      const SizedBox(height: 8),
      _SummaryCard(title: 'Tickets', trailing: '${open.length} open', rows: [
        ('New', '${count(OpsKotStatus.newTicket)}', _Kc.blue, FontWeight.w600),
        (
          'In progress',
          '${count(OpsKotStatus.preparing)}',
          _Kc.amber,
          FontWeight.w600
        ),
        (
          'Ready to serve',
          '${count(OpsKotStatus.ready)}',
          _Kc.green,
          FontWeight.w600
        ),
        (
          'Served today',
          '${count(OpsKotStatus.completed)}',
          _Kc.ink,
          FontWeight.w600
        ),
      ]),
      _SummaryCard(
          title: 'Items',
          trailing: '${pending + done} in kitchen',
          rows: [
            ('Pending', '$pending', _Kc.ink, FontWeight.w600),
            ('Done', '$done', _Kc.green, FontWeight.w600),
            ('Workload', _workload(pending), _Kc.ink, FontWeight.w600),
          ]),
      _SummaryCard(title: 'Timing', trailing: 'Avg ${avgWait}m', rows: [
        ('Delayed', '$delayed', _Kc.red, FontWeight.w600),
        (
          'Urgent',
          '${open.where((k) => k.urgent).length}',
          _Kc.red,
          FontWeight.w600
        ),
      ]),
    ];
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(
      {required this.title, required this.trailing, required this.rows});
  final String title;
  final String trailing;
  final List<(String, String, Color, FontWeight)> rows;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _Kc.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: Text(title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _Kc.ink)),
              ),
              Text(trailing,
                  style: const TextStyle(fontSize: 12, color: _Kc.label)),
            ]),
            const SizedBox(height: 4),
            for (final (label, value, color, weight) in rows)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(children: [
                  Expanded(
                    child: Text(label,
                        style: const TextStyle(fontSize: 12, color: _Kc.sub)),
                  ),
                  Text(value,
                      style: TextStyle(
                          fontSize: 12, fontWeight: weight, color: color)),
                ]),
              ),
          ],
        ),
      );
}

class _KpiTile extends StatelessWidget {
  const _KpiTile(this.label, this.value, this.tone);
  final String label;
  final int value;
  final _Tone tone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        decoration: BoxDecoration(
            color: tone.bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: tone.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                    color: Color(0xFF8B8F98))),
            const SizedBox(height: 2),
            Text('$value',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: tone.fg)),
          ],
        ),
      );
}

class _SmallChip extends StatelessWidget {
  const _SmallChip(this.label, {required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w500, color: fg)),
      );
}
