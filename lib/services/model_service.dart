import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cv_model_def.dart';

class ModelService {
  static const _prefKey = 'bokses_active_cv_tier';

  static Future<CvModelTier?> activeTier() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_prefKey);
    if (name == null) return null;
    try {
      return CvModelTier.values.firstWhere((t) => t.name == name);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isInstalled(CvModelTier tier) async {
    final modelPath = await installedModelPath(tier);
    if (modelPath == null) return false;
    final def = kCvModels.firstWhere((m) => m.tier == tier);
    final labelsPath = await installedLabelsPath(tier);
    if (labelsPath == null) return false;
    if (def.embeddingsFilename != null) {
      final embPath = await installedEmbeddingsPath(tier);
      if (embPath == null) return false;
    }
    return true;
  }

  static Future<bool> isAnyInstalled() async {
    for (final def in kCvModels) {
      if (await isInstalled(def.tier)) return true;
    }
    return false;
  }

  static Future<String?> installedModelPath(CvModelTier tier) async {
    final def = kCvModels.firstWhere((m) => m.tier == tier);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${def.modelFilename}');
    return file.existsSync() ? file.path : null;
  }

  static Future<String?> installedLabelsPath(CvModelTier tier) async {
    final def = kCvModels.firstWhere((m) => m.tier == tier);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${def.labelsFilename}');
    return file.existsSync() ? file.path : null;
  }

  static Future<String?> installedEmbeddingsPath(CvModelTier tier) async {
    final def = kCvModels.firstWhere((m) => m.tier == tier);
    if (def.embeddingsFilename == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${def.embeddingsFilename!}');
    return file.existsSync() ? file.path : null;
  }

  static Future<void> download(
    CvModelTier tier, {
    void Function(double)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final def = kCvModels.firstWhere((m) => m.tier == tier);

    if (def.isZeroShot && def.embeddingsUrl == null) {
      throw Exception(
        'XL embeddings URL not configured. See tools/generate_clip_embeddings.py.',
      );
    }

    final dir = await getApplicationDocumentsDirectory();

    Future<void> downloadFile(
      String url,
      String filename,
      double progressStart,
      double progressEnd,
    ) async {
      final file = File('${dir.path}/$filename');
      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);
      final total = response.contentLength ?? 0;
      int received = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in response.stream) {
          if (isCancelled != null && isCancelled()) {
            sink.close();
            if (file.existsSync()) file.deleteSync();
            throw const _CancelException();
          }
          // Guard against HTML error responses
          if (received == 0 && chunk.isNotEmpty) {
            final firstByte = chunk[0];
            if (firstByte == 0x3C) {
              // '<' — HTML response
              sink.close();
              if (file.existsSync()) file.deleteSync();
              throw Exception('Download failed: server returned HTML for $url');
            }
          }
          sink.add(chunk);
          received += chunk.length;
          if (total > 0 && onProgress != null) {
            final fraction = received / total;
            onProgress(
              progressStart + fraction * (progressEnd - progressStart),
            );
          }
        }
      } finally {
        await sink.close();
      }
    }

    try {
      await downloadFile(def.modelUrl, def.modelFilename, 0.0, 0.90);
      if (isCancelled != null && isCancelled()) {
        throw const _CancelException();
      }
      onProgress?.call(0.90);

      await downloadFile(def.labelsUrl, def.labelsFilename, 0.90, 0.95);
      if (isCancelled != null && isCancelled()) {
        throw const _CancelException();
      }
      onProgress?.call(0.95);

      if (def.embeddingsFilename != null && def.embeddingsUrl != null) {
        await downloadFile(
          def.embeddingsUrl!,
          def.embeddingsFilename!,
          0.95,
          1.0,
        );
      }
      onProgress?.call(1.0);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, tier.name);
    } on _CancelException {
      rethrow;
    } catch (_) {
      rethrow;
    }
  }

  static Future<void> delete(CvModelTier tier) async {
    final def = kCvModels.firstWhere((m) => m.tier == tier);
    final dir = await getApplicationDocumentsDirectory();

    void tryDelete(String filename) {
      final file = File('${dir.path}/$filename');
      if (file.existsSync()) file.deleteSync();
    }

    tryDelete(def.modelFilename);
    tryDelete(def.labelsFilename);
    if (def.embeddingsFilename != null) tryDelete(def.embeddingsFilename!);

    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString(_prefKey);
    if (current == tier.name) {
      await prefs.remove(_prefKey);
    }
  }
}

class _CancelException implements Exception {
  const _CancelException();
}
