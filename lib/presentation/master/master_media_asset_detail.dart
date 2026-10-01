import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/drift_master_store.dart';
import '../../data/master_catalog.dart';
import '../../domain/inventory.dart';
import '../../domain/master.dart';
import '../vinii_theme.dart';
import 'master_file_io.dart';
import 'master_ui.dart';

/// One row of the "Active Usage Map (Reference Check)" card.
class _UsageRef {
  const _UsageRef(this.kind, this.name, this.source);
  final String kind;
  final String name;
  final String source;
}

String _mimeFor(MediaAssetRecord a) {
  final ext = a.fileName.split('.').last.toLowerCase();
  return switch (ext) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'mp4' => 'video/mp4',
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    _ => 'application/octet-stream',
  };
}

String _stamp(DateTime d) =>
    '${formatShortDate(d)}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Detail view for a single media asset (Figma node 385:55133). Re-reads the
/// asset live from [store] so edits show immediately.
class MasterMediaAssetDetail extends StatefulWidget {
  const MasterMediaAssetDetail(
      {super.key,
      required this.store,
      required this.assetId,
      required this.onBack});
  final DriftMasterStore store;
  final String assetId;
  final VoidCallback onBack;

  @override
  State<MasterMediaAssetDetail> createState() => _MasterMediaAssetDetailState();
}

class _MasterMediaAssetDetailState extends State<MasterMediaAssetDetail> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _folder = TextEditingController();
  final _usage = TextEditingController();

  final _subs = <StreamSubscription<Object?>>[];
  List<MediaAssetRecord>? _media;
  List<MasterDishItem> _dishes = const [];
  List<MasterOffer> _offers = const [];
  bool _filled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _subs
      ..add(widget.store.watchMedia().listen((m) {
        if (!mounted) return;
        setState(() {
          _media = m;
          final a = _asset;
          if (a != null && !_filled) {
            _filled = true;
            _name.text = a.fileName;
            _folder.text = a.folder;
            _usage.text = a.usageLabel;
          }
        });
      }))
      ..add(widget.store.watchDishes().listen((d) {
        if (mounted) setState(() => _dishes = d);
      }))
      ..add(widget.store.watchOffers().listen((o) {
        if (mounted) setState(() => _offers = o);
      }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _name.dispose();
    _folder.dispose();
    _usage.dispose();
    super.dispose();
  }

  MediaAssetRecord? get _asset =>
      _media?.where((m) => m.id == widget.assetId).firstOrNull;

  List<_UsageRef> _references(MediaAssetRecord a) {
    final refs = <_UsageRef>[];
    final linkedDishes = <String>{};
    for (final d in _dishes) {
      final byUrl = a.imageUrl != null &&
          a.imageUrl!.isNotEmpty &&
          d.imageUrl == a.imageUrl;
      final byId = d.details['mediaId'] == a.id;
      if (byUrl || byId) {
        linkedDishes.add(d.name.toLowerCase());
        refs.add(_UsageRef('🍲 Product', d.name, 'Master Portal / Menu'));
      }
    }
    // "Used For" names a menu item or an offer exactly (it is picked from
    // a list), so an offer counts when it is that offer, or it covers that
    // menu item or a dish showing this asset.
    final label = a.usageLabel.trim().toLowerCase();
    for (final o in _offers) {
      final items = o.linkedItems.split(',').map((e) => e.trim().toLowerCase());
      final hit = (label.isNotEmpty && o.title.trim().toLowerCase() == label) ||
          items.any((i) =>
              i.isNotEmpty &&
              (linkedDishes.contains(i) || (label.isNotEmpty && i == label)));
      if (hit) {
        refs.add(_UsageRef(
            '🏷️ Offer Campaign', o.title, 'Offers Hub · ${o.status}'));
      }
    }
    return refs;
  }

  Future<void> _saveChanges(MediaAssetRecord a) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    await runMasterAction(
        context,
        () => widget.store.updateMedia(a.id,
            fileName: _name.text.trim(),
            folder: _folder.text.trim(),
            usageLabel: _usage.text.trim()),
        success: 'Saved changes to ${_name.text.trim()}');
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _replace(MediaAssetRecord a) async {
    final picked = await pickMediaFile(context);
    if (picked == null || !mounted) return;
    final (name, bytes) = picked;
    setState(() => _busy = true);
    final ok = await runMasterAction(
        context, () => widget.store.replaceMediaFile(a.id, name, bytes),
        success: 'Replaced file with $name');
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _name.text = name;
    });
  }

  Future<void> _download(MediaAssetRecord a) async {
    final bytes = a.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      await saveBytes(context, a.fileName, bytes, mimeType: _mimeFor(a));
      return;
    }
    final url = a.imageUrl;
    if (url == null || url.isEmpty) {
      showMasterError(context, '${a.fileName} has no stored file to download.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    showMasterNotice(context,
        '${a.fileName} is a remote image, not stored locally — its URL was copied to the clipboard. Open it in a browser to save it, or use Replace File to store a local copy.');
  }

  Future<void> _archive(MediaAssetRecord a, int refs) async {
    final ok = await confirmMasterAction(context,
        title: 'Archive asset?',
        message: refs == 0
            ? '${a.fileName} will be removed from the Media Library.'
            : '${a.fileName} is referenced by $refs item${refs == 1 ? '' : 's'}. '
                'Archiving removes it from the Media Library and those references may show a placeholder.',
        confirmLabel: 'Archive');
    if (!ok || !mounted) return;
    final done = await runMasterAction(
        context, () => widget.store.archiveMedia([a.id]),
        success: '${a.fileName} archived');
    if (done && mounted) widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    if (_media == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final asset = _asset;
    if (asset == null) {
      return MasterPage(children: [
        MasterBackLink(label: 'Back to Media Library', onTap: widget.onBack),
        const MasterBanner(
            tone: PillTone.red,
            icon: '⚠️',
            message: 'This asset is no longer in the library — it may have '
                'been archived.'),
      ]);
    }
    final refs = _references(asset);

    final left =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _preview(asset),
      const SizedBox(height: 20),
      _details(asset),
      const SizedBox(height: 20),
      _usageMap(asset, refs),
    ]);
    final right =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _history(asset),
      const SizedBox(height: 24),
      _safetyCheck(asset, refs.length),
    ]);

    return MasterPage(children: [
      MasterBackLink(label: 'Back to Media Library', onTap: widget.onBack),
      MasterPageHeader(
        title: asset.fileName,
        titleTrailing: const MasterStatusPill('Active Asset'),
        actions: [
          MasterButton(
              label: 'Download',
              icon: Icons.download_outlined,
              onPressed: _busy ? null : () => _download(asset)),
          MasterButton(
              label: 'Replace File',
              icon: Icons.swap_horiz,
              onPressed: _busy ? null : () => _replace(asset)),
          MasterButton(
              label: 'Save Changes',
              kind: MasterButtonKind.primary,
              onPressed: _busy ? null : () => _saveChanges(asset)),
        ],
      ),
      LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 900) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [left, const SizedBox(height: 24), right]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 712, child: left),
          const SizedBox(width: 24),
          Expanded(flex: 400, child: right),
        ]);
      }),
    ]);
  }

  Widget _thumb(MediaAssetRecord a) {
    const placeholder = Center(
      child: Icon(Icons.image_outlined,
          size: 48, color: ViniiColors.textMutedLight),
    );
    if (a.isVideo && (a.imageUrl == null || a.imageUrl!.isEmpty)) {
      return Container(
        color: const Color(0xFF1F2937),
        child: const Center(
          child: Icon(Icons.videocam_outlined, size: 48, color: Colors.white70),
        ),
      );
    }
    if (!a.isVideo && a.bytes != null && a.bytes!.isNotEmpty) {
      return Image.memory(a.bytes!,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder);
    }
    if (a.imageUrl != null && a.imageUrl!.isNotEmpty) {
      return Image.network(a.imageUrl!,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder);
    }
    return placeholder;
  }

  Widget _preview(MediaAssetRecord a) => MasterCard(
        padding: const EdgeInsets.all(12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 320,
              color: ViniiColors.grayTint,
              child: Stack(fit: StackFit.expand, children: [
                _thumb(a),
                if (a.isVideo)
                  Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: const Center(
                      child: Icon(Icons.play_circle_fill,
                          size: 56, color: Colors.white),
                    ),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Text(
                  'Uploaded: ${formatShortDate(a.createdAt)} · Format: ${a.fileType} · '
                  'Size: ${a.bytes == null && a.sizeBytes == 0 ? 'remote' : a.sizeLabel} · Folder: ${a.folder}',
                  style: MasterStyle.body
                      .copyWith(color: ViniiColors.textSecondaryLight)),
            ),
            const SizedBox(width: 12),
            MasterButton(
                label: 'Crop & Edit',
                icon: Icons.crop,
                onPressed: () => showMasterNotice(context,
                    'There is no built-in image editor offline — edit the file in an image app, then use Replace File.')),
          ]),
        ]),
      );

  /// "Used For" picker: a menu item or an offer (a label from older data
  /// that names neither stays selectable).
  Widget _usagePicker() {
    final usage = _usage.text.trim();
    final dishNames = <String>{
      for (final d in _dishes)
        if (d.name.trim().isNotEmpty) d.name.trim()
    };
    final offerTitles = <String>{
      for (final o in _offers)
        if (o.title.trim().isNotEmpty && !dishNames.contains(o.title.trim()))
          o.title.trim()
    };
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: MasterStyle.cardBorder));
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Used For',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ViniiColors.textPrimaryLight)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            key: ValueKey('usage-$usage'),
            initialValue: usage,
            isExpanded: true,
            style: const TextStyle(
                fontSize: 13, color: ViniiColors.textPrimaryLight),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              border: border,
              enabledBorder: border,
            ),
            items: [
              const DropdownMenuItem(
                  value: '', child: Text('Not linked to anything')),
              for (final n in dishNames)
                DropdownMenuItem(
                    value: n,
                    child: Text('Menu item · $n',
                        overflow: TextOverflow.ellipsis)),
              for (final t in offerTitles)
                DropdownMenuItem(
                    value: t,
                    child:
                        Text('Offer · $t', overflow: TextOverflow.ellipsis)),
              if (usage.isNotEmpty &&
                  !dishNames.contains(usage) &&
                  !offerTitles.contains(usage))
                DropdownMenuItem(
                    value: usage,
                    child: Text(usage, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _usage.text = v ?? ''),
          ),
        ]);
  }

  Widget _details(MediaAssetRecord a) {
    final folders = {
      for (final m in _media ?? const <MediaAssetRecord>[]) m.folder
    }.toList()
      ..sort();
    return Form(
      key: _formKey,
      child: MasterSection(
        title: 'Asset Details',
        child: MasterGrid(columns: 3, minItemWidth: 180, children: [
          _AssetField(
              label: 'File Name',
              controller: _name,
              hint: 'e.g. paneer_tikka.jpg',
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'File name is required'
                  : null),
          _AssetField(
            label: 'Folder',
            controller: _folder,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Folder is required' : null,
            suffix: PopupMenuButton<String>(
              tooltip: 'Pick existing folder',
              icon: const Icon(Icons.arrow_drop_down, size: 20),
              onSelected: (f) => setState(() => _folder.text = f),
              itemBuilder: (_) => [
                for (final f in folders)
                  PopupMenuItem(value: f, child: Text(f)),
              ],
            ),
          ),
          _usagePicker(),
        ]),
      ),
    );
  }

  Widget _usageMap(MediaAssetRecord a, List<_UsageRef> refs) => MasterCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Active Usage Map (Reference Check)',
              style: MasterStyle.sectionTitle),
          const SizedBox(height: 12),
          if (refs.isEmpty)
            Text(
                a.usageLabel.isEmpty
                    ? 'No menu items or offers reference this asset.'
                    : 'Used for "${a.usageLabel}", but no menu item or offer references this asset.',
                style: MasterStyle.muted),
          for (final u in refs)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: MasterStyle.tableHeaderBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MasterStyle.cardBorder),
              ),
              child: Row(children: [
                Expanded(
                    flex: 120,
                    child: Text(u.kind,
                        overflow: TextOverflow.ellipsis,
                        style: MasterStyle.body
                            .copyWith(color: ViniiColors.textSecondaryLight))),
                const SizedBox(width: 12),
                Expanded(
                    flex: 180,
                    child: Text(u.name,
                        overflow: TextOverflow.ellipsis,
                        style: MasterStyle.body
                            .copyWith(fontWeight: FontWeight.w600))),
                const SizedBox(width: 12),
                Expanded(
                    flex: 120,
                    child: Text(u.source,
                        overflow: TextOverflow.ellipsis,
                        style: MasterStyle.link)),
              ]),
            ),
        ]),
      );

  Widget _history(MediaAssetRecord a) => MasterCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Version & Audit History',
              style: MasterStyle.sectionTitle),
          const SizedBox(height: 14),
          Text('Current file — ${a.fileName}',
              style: MasterStyle.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
              '${a.fileType} · ${a.bytes == null && a.sizeBytes == 0 ? 'remote image' : a.sizeLabel}'
              '${a.bytes == null && (a.imageUrl ?? '').isNotEmpty ? ' · linked from URL' : ' · stored locally'}',
              style: MasterStyle.muted),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: MasterStyle.cardBorder),
          ),
          Text('Added to library',
              style: MasterStyle.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('${_stamp(a.createdAt)} · Folder: ${a.folder}',
              style: MasterStyle.muted),
          const SizedBox(height: 10),
          const Text(
              'Earlier versions are not kept — Replace File overwrites the stored file.',
              style: MasterStyle.muted),
        ]),
      );

  Widget _safetyCheck(MediaAssetRecord a, int n) => MasterCard(
        color: ViniiColors.redTint,
        borderColor: const Color(0xFFFCA5A5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('⚠️ Destructive Action Safety Check',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF991B1B))),
          const SizedBox(height: 8),
          Text(
              n == 0
                  ? '${a.fileName} is not referenced by any menu item or offer. Archiving removes it from the Media Library.'
                  : '${a.fileName} is used in $n active reference${n == 1 ? '' : 's'}. Deleting or archiving this asset will break those references instantly.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF991B1B))),
          const SizedBox(height: 14),
          MasterButton(
              label: 'Archive Asset',
              kind: MasterButtonKind.dangerOutline,
              icon: Icons.archive_outlined,
              onPressed: _busy ? null : () => _archive(a, n)),
        ]),
      );
}

class _AssetField extends StatelessWidget {
  const _AssetField(
      {required this.label,
      required this.controller,
      this.hint,
      this.validator,
      this.suffix});
  final String label;
  final TextEditingController controller;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final Widget? suffix;

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
              controller: controller,
              validator: validator,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: hint,
                suffixIcon: suffix,
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
