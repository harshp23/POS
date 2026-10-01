import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/drift_master_store.dart';
import '../../domain/master.dart';
import '../vinii_theme.dart';
import 'master_file_io.dart';
import 'master_media_asset_detail.dart';
import 'master_ui.dart';

const _allFormats = 'All formats';
const _images = 'Images';
const _videos = 'Videos';
const _allFolders = 'All folders';

/// Media library backed by the media_assets table: folder cards, search and
/// filters, uploads, bulk archive, and an asset detail view.
class MasterMediaScreen extends StatefulWidget {
  const MasterMediaScreen({super.key, required this.store});
  final DriftMasterStore store;

  @override
  State<MasterMediaScreen> createState() => _MasterMediaScreenState();
}

class _MasterMediaScreenState extends State<MasterMediaScreen> {
  final _subs = <StreamSubscription<Object?>>[];
  List<MediaAssetRecord>? _media;
  Map<String, int> _folderCounts = const {};

  /// Folders created in this session that have no files yet (a folder only
  /// exists in the database once it holds a file).
  final Set<String> _pendingFolders = {};

  final Set<String> _selectedMediaIds = {};
  final TextEditingController _aiPromptController = TextEditingController();
  String _searchQuery = '';
  String _format = _allFormats;
  String? _folder; // null = all folders
  bool _uploading = false;
  String? _openAssetId;

  @override
  void initState() {
    super.initState();
    _subs
      ..add(widget.store.watchMedia().listen((m) {
        if (!mounted) return;
        setState(() {
          _media = m;
          final ids = {for (final a in m) a.id};
          _selectedMediaIds.removeWhere((id) => !ids.contains(id));
        });
      }))
      ..add(widget.store.watchFolders().listen((f) {
        if (!mounted) return;
        setState(() {
          _folderCounts = f;
          _pendingFolders.removeWhere(f.containsKey);
        });
      }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _aiPromptController.dispose();
    super.dispose();
  }

  List<String> get _folderNames =>
      {..._folderCounts.keys, ..._pendingFolders}.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  List<MediaAssetRecord> get _filtered {
    final q = _searchQuery.trim().toLowerCase();
    return (_media ?? const <MediaAssetRecord>[]).where((m) {
      if (q.isNotEmpty &&
          !m.fileName.toLowerCase().contains(q) &&
          !m.usageLabel.toLowerCase().contains(q) &&
          !m.folder.toLowerCase().contains(q)) {
        return false;
      }
      if (_folder != null && m.folder != _folder) return false;
      switch (_format) {
        case _allFormats:
          break;
        case _images:
          if (m.isVideo) return false;
        case _videos:
          if (!m.isVideo) return false;
        default:
          if (m.fileType != _format) return false;
      }
      return true;
    }).toList();
  }

  Future<String?> _askFolderName() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final existing = _folderNames.map((f) => f.toLowerCase()).toSet();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        void submit() {
          if (formKey.currentState!.validate()) {
            Navigator.pop(ctx, controller.text.trim());
          }
        }

        return AlertDialog(
          title: const Text('Create Folder'),
          content: SizedBox(
            width: 380,
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Folder name',
                  hintText: 'e.g. Desserts',
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Enter a folder name';
                  if (existing.contains(t.toLowerCase())) {
                    return 'A folder with this name already exists';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => submit(),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(onPressed: submit, child: const Text('Create')),
          ],
        );
      },
    );
    controller.dispose();
    return name;
  }

  Future<void> _createFolder() async {
    final name = await _askFolderName();
    if (name == null || !mounted) return;
    setState(() {
      _pendingFolders.add(name);
      _folder = name;
    });
    final upload = await confirmMasterAction(context,
        title: 'Folder "$name" created',
        message:
            'A folder is saved once it contains a file. Upload files into "$name" now?',
        confirmLabel: 'Upload Files',
        destructive: false);
    if (upload && mounted) await _upload(targetFolder: name);
  }

  /// Asks which folder to upload into when no folder filter is active.
  Future<String?> _chooseUploadFolder() async {
    final folders = _folderNames;
    if (folders.isEmpty) return 'General';
    var choice = folders.first;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Upload into folder'),
          content: SizedBox(
            width: 380,
            child: DropdownButtonFormField<String>(
              initialValue: choice,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Folder',
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: [
                for (final f in folders)
                  DropdownMenuItem(value: f, child: Text(f)),
              ],
              onChanged: (v) => setLocal(() => choice = v ?? choice),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, choice),
                child: const Text('Choose Files')),
          ],
        ),
      ),
    );
  }

  Future<void> _upload({String? targetFolder}) async {
    if (_uploading) return;
    final folder = targetFolder ?? _folder ?? await _chooseUploadFolder();
    if (folder == null || !mounted) return;
    final files = await pickMediaFiles(context);
    if (files.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    var added = 0;
    final errors = <String>[];
    for (final (name, bytes) in files) {
      try {
        await widget.store
            .addMedia(fileName: name, bytes: bytes, folder: folder);
        added++;
      } on StateError catch (e) {
        errors.add(e.message);
      } catch (e) {
        errors.add(masterErrorMessage(e,
            fallback: '$name could not be uploaded. Please try again.'));
      }
    }
    if (!mounted) return;
    setState(() => _uploading = false);
    if (errors.isEmpty) {
      showMasterNotice(
          context, 'Uploaded $added file${added == 1 ? '' : 's'} to "$folder"');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Uploaded $added of ${files.length} files'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in errors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $e', style: MasterStyle.body),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final n = _selectedMediaIds.length;
    final ok = await confirmMasterAction(context,
        title: 'Archive $n asset${n == 1 ? '' : 's'}?',
        message:
            'The selected files will be removed from the Media Library. Menu items or offers using them may show a placeholder.',
        confirmLabel: 'Delete Selected');
    if (!ok || !mounted) return;
    final ids = _selectedMediaIds.toList();
    final done = await runMasterAction(
        context, () => widget.store.archiveMedia(ids),
        success: 'Archived $n asset${n == 1 ? '' : 's'}');
    if (done && mounted) setState(_selectedMediaIds.clear);
  }

  IconData _folderIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('video') || n.contains('tutorial') || n.contains('prep')) {
      return Icons.video_library_outlined;
    }
    if (n.contains('drink') || n.contains('beverage') || n.contains('bar')) {
      return Icons.local_bar_outlined;
    }
    return Icons.folder_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final openId = _openAssetId;
    if (openId != null) {
      return MasterMediaAssetDetail(
        key: ValueKey(openId),
        store: widget.store,
        assetId: openId,
        onBack: () => setState(() => _openAssetId = null),
      );
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    final loading = _media == null;
    final filteredMedia = _filtered;
    final folders = _folderNames;
    final types = {
      for (final m in _media ?? const <MediaAssetRecord>[]) m.fileType
    }.toList()
      ..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Restaurant Media Hub',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Upload kitchen videos, high-resolution photography, or generate AI cover assets',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              Wrap(spacing: 10, runSpacing: 8, children: [
                OutlinedButton.icon(
                  onPressed: _createFolder,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 16),
                  label: const Text('Create Folder'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _uploading ? null : () => _upload(),
                  icon: _uploading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cloud_upload_outlined,
                          size: 16, color: Colors.black),
                  label: Text(
                      _uploading
                          ? 'Uploading...'
                          : _folder == null
                              ? 'Upload Files'
                              : 'Upload to $_folder',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ViniiColors.brandGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 20),

          // Folder cards (click = filter to that folder, click again = all)
          if (folders.isNotEmpty)
            MasterGrid(
              columns: 3,
              minItemWidth: 200,
              children: [
                for (final f in folders)
                  _buildFolderCard(
                    icon: _folderIcon(f),
                    title: f,
                    fileCount: _pendingFolders.contains(f)
                        ? 'Empty — upload to save'
                        : '${_folderCounts[f] ?? 0} file${(_folderCounts[f] ?? 0) == 1 ? '' : 's'}',
                    selected: _folder == f,
                    onTap: () => setState(() {
                      _folder = _folder == f ? null : f;
                    }),
                    cardBg: cardBg,
                    borderColor: borderColor,
                  ),
              ],
            ),
          if (folders.isNotEmpty) const SizedBox(height: 20),

          // Main 2-Column Section: Asset Grid (Left) + Generative AI (Right)
          LayoutBuilder(builder: (context, c) {
            final library = _buildLibrary(
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              loading: loading,
              filteredMedia: filteredMedia,
              folders: folders,
              types: types,
            );
            final ai = _buildAiPanel(isDark, cardBg, borderColor);
            if (c.maxWidth < 760) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [library, const SizedBox(height: 20), ai]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: library),
                const SizedBox(width: 20),
                Expanded(flex: 5, child: ai),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLibrary({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required bool loading,
    required List<MediaAssetRecord> filteredMedia,
    required List<String> folders,
    required List<String> types,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search & Actions Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF4F6F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              _buildFilterDrop(
                label: 'Format: $_format',
                options: [_allFormats, _images, _videos, ...types],
                onSelected: (v) => setState(() => _format = v),
                isDark: isDark,
              ),
              _buildFilterDrop(
                label: _folder ?? _allFolders,
                options: [_allFolders, ...folders],
                onSelected: (v) =>
                    setState(() => _folder = v == _allFolders ? null : v),
                isDark: isDark,
              ),
              if (filteredMedia.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() {
                    final ids = filteredMedia.map((m) => m.id);
                    if (ids.every(_selectedMediaIds.contains)) {
                      _selectedMediaIds.removeAll(ids);
                    } else {
                      _selectedMediaIds.addAll(ids);
                    }
                  }),
                  child: Text(
                      filteredMedia
                              .every((m) => _selectedMediaIds.contains(m.id))
                          ? 'Clear selection'
                          : 'Select all',
                      style: const TextStyle(fontSize: 11)),
                ),
              if (_selectedMediaIds.isNotEmpty) ...[
                Text(
                  'Selected: ${_selectedMediaIds.length} items',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                ElevatedButton(
                  onPressed: _deleteSelected,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD92D20),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Delete Selected',
                      style: TextStyle(fontSize: 11)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (loading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (filteredMedia.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(children: [
              Icon(Icons.perm_media_outlined,
                  size: 36, color: Colors.grey[400]),
              const SizedBox(height: 10),
              Text(
                (_media ?? const []).isEmpty
                    ? 'No media yet — click Upload Files to add photos or videos (max 5 MB each).'
                    : _folder != null && _pendingFolders.contains(_folder)
                        ? '"$_folder" is empty — upload files to save this folder.'
                        : 'No assets match these filters.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ]),
          )
        else
          // Asset Grid
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 720
                ? 3
                : c.maxWidth >= 420
                    ? 2
                    : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredMedia.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisExtent: 260,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemBuilder: (context, index) =>
                  _buildAssetCard(filteredMedia[index], cardBg, borderColor),
            );
          }),
      ],
    );
  }

  Widget _thumbnail(MediaAssetRecord media) {
    final placeholder = Container(
      color: const Color(0xFFF3F4F6),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 36, color: Colors.grey),
      ),
    );
    if (media.isVideo && (media.imageUrl ?? '').isEmpty) {
      return Container(
        color: const Color(0xFF1F2937),
        child: const Center(
          child: Icon(Icons.videocam_outlined, size: 36, color: Colors.white70),
        ),
      );
    }
    if (!media.isVideo && media.bytes != null && media.bytes!.isNotEmpty) {
      return Image.memory(media.bytes!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => placeholder);
    }
    if ((media.imageUrl ?? '').isNotEmpty) {
      return Image.network(media.imageUrl!,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder);
    }
    return placeholder;
  }

  Widget _buildAssetCard(
      MediaAssetRecord media, Color cardBg, Color borderColor) {
    final isSelected = _selectedMediaIds.contains(media.id);
    return GestureDetector(
      onTap: () => setState(() => _openAssetId = media.id),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? ViniiColors.brandGreen : borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _thumbnail(media),
                    if (media.isVideo)
                      Container(
                        color: Colors.black.withValues(alpha: 0.3),
                        child: const Center(
                          child: Icon(Icons.play_circle_fill,
                              size: 40, color: Colors.white),
                        ),
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Checkbox(
                        value: isSelected,
                        activeColor: ViniiColors.emeraldText,
                        fillColor: isSelected
                            ? null
                            : const WidgetStatePropertyAll(Colors.white),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedMediaIds.add(media.id);
                            } else {
                              _selectedMediaIds.remove(media.id);
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${media.fileType} · '
                    '${media.bytes == null && media.sizeBytes == 0 ? 'remote' : media.sizeLabel}'
                    ' · ${media.folder}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'Usage: ',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                      Expanded(
                        child: Text(
                          media.usageLabel.isEmpty
                              ? 'Not assigned'
                              : media.usageLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: media.usageLabel.isEmpty
                                ? Colors.grey[500]
                                : ViniiColors.emeraldText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiPanel(bool isDark, Color cardBg, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome,
                  color: ViniiColors.emeraldText, size: 20),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Generative AI Menu Assistant',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Create appetizing placeholder images for upcoming test kitchen experiments.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Dish Description Input Prompt',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _aiPromptController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText:
                  'e.g., Creamy Paneer Butter Masala served in copper bowl...',
              contentPadding: const EdgeInsets.all(12),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 14),

          // Availability notice
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3A2400) : const Color(0xFFFFFAEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF7A5200) : const Color(0xFFFEDF89),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Server connection required',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB54708),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'AI image generation runs on a cloud image model. This POS works offline against its local database, so generation is not available here — upload your own photos with Upload Files instead.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFFFEF0C7)
                        : const Color(0xFFB54708),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => showMasterNotice(context,
                  'AI generation needs a server connection — not available offline'),
              icon:
                  const Icon(Icons.auto_awesome, size: 16, color: Colors.black),
              label: const Text(
                'Generate Asset',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ViniiColors.brandGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderCard({
    required IconData icon,
    required String title,
    required String fileCount,
    required bool selected,
    required VoidCallback onTap,
    required Color cardBg,
    required Color borderColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? ViniiColors.lightGreenTint : cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? ViniiColors.brandGreen : borderColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ViniiColors.successPillBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: ViniiColors.emeraldText, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fileCount,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDrop({
    required String label,
    required List<String> options,
    required ValueChanged<String> onSelected,
    required bool isDark,
  }) {
    return PopupMenuButton<String>(
      tooltip: '',
      onSelected: onSelected,
      itemBuilder: (_) =>
          [for (final o in options) PopupMenuItem(value: o, child: Text(o))],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8F9FA),
          border:
              Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
    );
  }
}
