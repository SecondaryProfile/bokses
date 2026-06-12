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
  static Future<void> exportData({Rect? sharePositionOrigin}) async {
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
            final bytes = await file.readAsBytes();
            map['photoData'] = base64Encode(bytes);
          }
        }
      }
      return map;
    }));

    final data = {
      'version': '1.1',
      'app': 'Bokses',
      'exportedAt': DateTime.now().toIso8601String(),
      'boxes': boxes.map((b) => b.toExportMap()).toList(),
      'items': itemMaps,
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    final timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
    final filename = 'bokses_export_$timestamp.json';

    if (kIsWeb) {
      triggerWebDownload(jsonStr, filename);
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsString(jsonStr);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Bokses Export',
        text: 'My Bokses data export',
        sharePositionOrigin: sharePositionOrigin,
      );
    }
  }

  static Future<String> importData() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return 'Import cancelled.';

    final fileBytes = result.files.first.bytes;
    String jsonStr;

    if (fileBytes != null) {
      jsonStr = utf8.decode(fileBytes);
    } else if (!kIsWeb && result.files.first.path != null) {
      jsonStr = await File(result.files.first.path!).readAsString();
    } else {
      return 'Could not read file.';
    }

    if (!jsonStr.trimLeft().startsWith('{')) {
      return 'Invalid file — expected a Bokses JSON export.';
    }

    final Map<String, dynamic> data = json.decode(jsonStr);
    if (data['app'] != 'Bokses') return 'Invalid Bokses export file.';

    final List boxMaps = data['boxes'] ?? [];
    final List itemMaps = data['items'] ?? [];
    int boxCount = 0;
    int itemCount = 0;

    for (final bMap in boxMaps) {
      await DatabaseService.instance
          .insertBox(Box.fromMap(Map<String, dynamic>.from(bMap)));
      boxCount++;
    }

    for (final iMap in itemMaps) {
      final map = Map<String, dynamic>.from(iMap);
      final photoData = map.remove('photoData') as String?;
      map['photoPath'] =
          photoData != null ? 'data:image/jpeg;base64,$photoData' : null;
      await DatabaseService.instance.insertItem(Item.fromMap(map));
      itemCount++;
    }

    return 'Imported $boxCount box(es) and $itemCount item(s).';
  }
}
