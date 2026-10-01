import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/api/api_client.dart';
import '../../data/csv.dart';
import '../vinii_theme.dart';
import 'master_ui.dart';

/// File import/export for Master screens. Uses file_picker, which saves
/// through a download on web and a native Save dialog on Windows.

/// A sentence people can act on for an error thrown while loading or
/// saving — never a raw exception dump. Backend errors ([ApiException])
/// and the stores' own rule messages ([StateError] / [ArgumentError]) are
/// already written for people and are shown as they are; anything else
/// (database, file system, platform) becomes [fallback].
String masterErrorMessage(Object error,
    {String fallback = 'Something went wrong. Please try again.'}) {
  if (error is ApiException) {
    return error.message.trim().isEmpty ? fallback : error.message;
  }
  if (error is StateError) {
    final m = error.message.trim();
    // Collection errors ("No element") are internal, not rule messages.
    const internal = {'No element', 'Too many elements', 'Too few elements'};
    return m.isEmpty || internal.contains(m) ? fallback : m;
  }
  if (error is ArgumentError) {
    final m = error.message;
    return m is String && m.trim().isNotEmpty ? m : fallback;
  }
  return fallback;
}

/// Saves [headers]/[rows] as a CSV file. Shows the outcome as a snackbar.
Future<void> exportCsv(
  BuildContext context, {
  required String fileName,
  required List<String> headers,
  required Iterable<List<Object?>> rows,
}) async {
  final list = rows.toList();
  // BOM so Excel opens ₹ and other non-ASCII text correctly.
  final bytes =
      Uint8List.fromList(utf8.encode('﻿${Csv.encode(headers, list)}'));
  try {
    final saved = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: 'text/csv',
      dialogTitle: 'Export $fileName',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (!context.mounted) return;
    if (saved == null) {
      showMasterNotice(context, 'Export cancelled');
    } else {
      showMasterNotice(context, 'Exported ${list.length} rows to $fileName');
    }
  } catch (e) {
    if (context.mounted) {
      showMasterError(
          context,
          masterErrorMessage(e,
              fallback:
                  'Export failed — $fileName could not be saved. Please try again.'));
    }
  }
}

/// Lets the user pick a CSV and returns its records, or null if cancelled
/// or unreadable (the error is shown).
Future<List<CsvRecord>?> pickCsv(BuildContext context) async {
  try {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Import CSV',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (file == null) return null;
    final text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
    final records = Csv.decode(text);
    if (records.isEmpty && context.mounted) {
      showMasterError(context, '${file.name} has no data rows.');
      return null;
    }
    return records;
  } catch (e) {
    if (context.mounted) {
      showMasterError(
          context,
          masterErrorMessage(e,
              fallback:
                  'Could not read that file. Check it is a CSV file and try again.'));
    }
    return null;
  }
}

/// Picks one image/video; returns (name, bytes) or null.
Future<(String, Uint8List)?> pickMediaFile(BuildContext context) async {
  try {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Upload media',
      type: FileType.custom,
      allowedExtensions: const [
        'png',
        'jpg',
        'jpeg',
        'webp',
        'gif',
        'mp4',
        'mov',
        'webm'
      ],
    );
    if (file == null) return null;
    return (file.name, await file.readAsBytes());
  } catch (e) {
    if (context.mounted) {
      showMasterError(
          context,
          masterErrorMessage(e,
              fallback:
                  'Could not read that file. Pick an image or video and try again.'));
    }
    return null;
  }
}

/// Picks several images/videos.
Future<List<(String, Uint8List)>> pickMediaFiles(BuildContext context) async {
  try {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Upload media',
      type: FileType.custom,
      allowedExtensions: const [
        'png',
        'jpg',
        'jpeg',
        'webp',
        'gif',
        'mp4',
        'mov',
        'webm'
      ],
    );
    return [for (final f in files) (f.name, await f.readAsBytes())];
  } catch (e) {
    if (context.mounted) {
      showMasterError(
          context,
          masterErrorMessage(e,
              fallback:
                  'Could not read those files. Pick images or videos and try again.'));
    }
    return const [];
  }
}

/// Saves raw bytes (e.g. downloading a media asset).
Future<void> saveBytes(BuildContext context, String fileName, Uint8List bytes,
    {String mimeType = 'application/octet-stream'}) async {
  try {
    final saved = await FilePicker.saveFile(
        fileName: fileName, bytes: bytes, mimeType: mimeType);
    if (context.mounted && saved != null) {
      showMasterNotice(context, 'Saved $fileName');
    }
  } catch (e) {
    if (context.mounted) {
      showMasterError(
          context,
          masterErrorMessage(e,
              fallback:
                  'Download failed — $fileName could not be saved. Please try again.'));
    }
  }
}

/// Shows an import result, listing the first few row errors.
void showImportSummary(BuildContext context, ImportSummary s) {
  if (s.errors.isEmpty) {
    showMasterNotice(context, s.message);
    return;
  }
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.message),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in s.errors.take(20))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(e, style: MasterStyle.body),
                ),
              if (s.errors.length > 20)
                Text('…and ${s.errors.length - 20} more',
                    style: MasterStyle.muted),
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

/// Red error snackbar.
void showMasterError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    behavior: SnackBarBehavior.floating,
    width: 480,
    backgroundColor: ViniiColors.redSolid,
    duration: const Duration(seconds: 4),
  ));
}

/// Yes/No confirmation for destructive actions. Returns true on confirm.
Future<bool> confirmMasterAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  bool destructive = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor:
                  destructive ? ViniiColors.redSolid : ViniiColors.greenSolid),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Runs a store call, turning thrown errors into a red snackbar and a
/// success message into a normal one. Returns true when it succeeded.
Future<bool> runMasterAction(BuildContext context, Future<void> Function() op,
    {String? success}) async {
  try {
    await op();
    if (context.mounted && success != null) showMasterNotice(context, success);
    return true;
  } catch (e) {
    if (context.mounted) {
      showMasterError(
          context,
          masterErrorMessage(e,
              fallback:
                  'Could not save your changes. Please check them and try again.'));
    }
  }
  return false;
}
