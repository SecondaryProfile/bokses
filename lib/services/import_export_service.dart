import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/box.dart';
import '../models/item.dart';
import 'database_service.dart';


import 'web_download.dart' if (dart.library.html) 'web_download_web.dart';

class ImportExportService {
  static Future<Map<String, dynamic>> buildExportPayload() async {
    final boxes = await DatabaseService.instance.getBoxes();
    final allItems = await DatabaseService.instance.getAllItems();
    final itemMaps = await Future.wait(allItems.map((item) async {
      final map = Map<String, dynamic>.from(item.toExportMap());
      if (item.photoPath != null && item.photoPath!.isNotEmpty) {
        if (item.photoPath!.startsWith('data:')) {
          map['photoData'] = item.photoPath!.split(',').last;
        } else {
          final file = File(item.photoPath!);
          if (await file.exists()) {
            map['photoData'] = base64Encode(await file.readAsBytes());
          }
        }
      }
      return map;
    }));
    return {
      'version': '1.1',
      'app': 'Bokses',
      'exportedAt': DateTime.now().toIso8601String(),
      'boxes': boxes.map((b) => b.toExportMap()).toList(),
      'items': itemMaps,
    };
  }

  static String _exportFilename() {
    final now = DateTime.now();
    final ts =
        '${now.year}${_p(now.month)}${_p(now.day)}_${_p(now.hour)}${_p(now.minute)}${_p(now.second)}';
    return 'bokses_export_$ts.json';
  }

  static String _p(int n) => n.toString().padLeft(2, '0');

  static Future<void> exportData({Rect? sharePositionOrigin}) async {
    final data = await buildExportPayload();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    final filename = _exportFilename();

    if (kIsWeb) {
      triggerWebDownload(jsonStr, filename);
      return;
    }

    final bytes = Uint8List.fromList(utf8.encode(jsonStr));
    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Bokses Export',
      fileName: filename,
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (savedPath != null) return;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(jsonStr);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: filename,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  // Step 1 — pick a file and return its contents as a JSON string.
  // Returns null if the user cancels or the file can't be read.
  static Future<String?> pickImportJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final fileBytes = result.files.first.bytes;
    if (fileBytes != null) return utf8.decode(fileBytes);
    if (!kIsWeb && result.files.first.path != null) {
      return await File(result.files.first.path!).readAsString();
    }
    return null;
  }

  // Legacy single-call API kept for compatibility.
  static Future<String> importData() async {
    final jsonStr = await pickImportJson();
    if (jsonStr == null) return 'Import cancelled.';
    return processImportJson(jsonStr);
  }

  // Step 2 — parse and insert.  onProgress(done, total) is called after every
  // inserted record so callers can drive a progress indicator.
  static Future<String> processImportJson(
    String jsonStr, {
    void Function(int done, int total)? onProgress,
  }) async {
    if (!jsonStr.trimLeft().startsWith('{')) {
      return 'Invalid file — expected a Bokses JSON export.';
    }
    final Map<String, dynamic> data = json.decode(jsonStr);
    if (data['app'] != 'Bokses') return 'Invalid Bokses export file.';

    final List boxMaps = data['boxes'] ?? [];
    final List itemMaps = data['items'] ?? [];
    final total = boxMaps.length + itemMaps.length;
    int done = 0;
    int boxCount = 0;
    int itemCount = 0;

    for (final bMap in boxMaps) {
      await DatabaseService.instance
          .insertBox(Box.fromMap(Map<String, dynamic>.from(bMap)));
      boxCount++;
      done++;
      onProgress?.call(done, total);
    }
    for (final iMap in itemMaps) {
      final map = Map<String, dynamic>.from(iMap);
      final photoData = map.remove('photoData') as String?;
      map['photoPath'] =
          photoData != null ? 'data:image/jpeg;base64,$photoData' : null;
      await DatabaseService.instance.insertItem(Item.fromMap(map));
      itemCount++;
      done++;
      onProgress?.call(done, total);
    }
    return 'Imported $boxCount box(es) and $itemCount item(s).';
  }
}
