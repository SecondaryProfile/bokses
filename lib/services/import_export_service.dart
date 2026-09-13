import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import '../models/box.dart';
import '../models/item.dart';
import 'database_service.dart';


import 'web_download.dart' if (dart.library.html) 'web_download_web.dart';

class ImportExportService {
  static Future<Map<String, dynamic>> buildExportPayload() async {
    final boxes = await DatabaseService.instance.getBoxes();
    final allItems = await DatabaseService.instance.getAllItems();
    final itemMaps = allItems.map((item) {
      final map = Map<String, dynamic>.from(item.toExportMap());
      final photo = item.photoPath;
      if (photo != null && photo.isNotEmpty) {
        if (photo.startsWith('data:')) {
          map['photoData'] = photo.split(',').last;
        } else if (photo.startsWith('http')) {
          // Web-search photos are remote URLs — carry the link, not the bytes.
          map['photoUrl'] = photo;
        }
      }
      return map;
    }).toList();
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

  static Future<bool> exportData() async {
    final data = await buildExportPayload();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    triggerWebDownload(jsonStr, _exportFilename());
    return true;
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
    return fileBytes == null ? null : utf8.decode(fileBytes);
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
      final photoUrl = map.remove('photoUrl') as String?;
      map['photoPath'] = photoData != null
          ? 'data:image/jpeg;base64,$photoData'
          : photoUrl;
      // A restored URL is by definition a web-sourced photo, so it keeps its
      // globe badge.
      if (photoUrl != null) map['webPhoto'] = true;
      await DatabaseService.instance.insertItem(Item.fromMap(map));
      itemCount++;
      done++;
      onProgress?.call(done, total);
    }
    return 'Imported $boxCount box(es) and $itemCount item(s).';
  }

}
