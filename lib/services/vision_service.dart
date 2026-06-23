import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:onnxruntime/onnxruntime.dart';
import '../models/cv_model_def.dart';
import 'model_service.dart';

class VisionService {
  static Interpreter? _tfliteInterpreter;
  static OrtSession? _ortSession;
  static bool _ortEnvInitialized = false;
  static List<String>? _labels;
  static Float32List? _textEmbeddings;
  static int? _embedDim;
  static CvModelTier? _loadedTier;

  static Future<bool> isAvailable() async {
    final tier = await ModelService.activeTier();
    if (tier == null) return false;
    return ModelService.isInstalled(tier);
  }

  static Future<void> _load() async {
    final tier = await ModelService.activeTier();
    if (tier == null) throw Exception('No active CV model tier.');
    final installed = await ModelService.isInstalled(tier);
    if (!installed) throw Exception('Active CV model is not installed.');

    if (_loadedTier == tier &&
        ((_tfliteInterpreter != null) || (_ortSession != null))) {
      return;
    }

    _disposeCurrentModel();

    final def = kCvModels.firstWhere((m) => m.tier == tier);
    final modelPath = (await ModelService.installedModelPath(tier))!;
    final labelsPath = (await ModelService.installedLabelsPath(tier))!;

    final labelsRaw = await File(labelsPath).readAsString();
    _labels = labelsRaw
        .split('\n')
        .map((l) => l.trim())
        .toList();

    if (def.isTflite) {
      _tfliteInterpreter = Interpreter.fromFile(File(modelPath));
    } else {
      _ensureOrtEnv();
      final sessionOptions = OrtSessionOptions();
      _ortSession = OrtSession.fromFile(File(modelPath), sessionOptions);
      sessionOptions.release();
    }

    if (def.isZeroShot) {
      final embPath = (await ModelService.installedEmbeddingsPath(tier))!;
      final bytes = await File(embPath).readAsBytes();
      final byteData = bytes.buffer.asByteData();
      final numClasses = byteData.getInt32(0, Endian.little);
      final embedDim = byteData.getInt32(4, Endian.little);
      _embedDim = embedDim;
      _textEmbeddings = Float32List(numClasses * embedDim);
      for (int i = 0; i < numClasses * embedDim; i++) {
        _textEmbeddings![i] = byteData.getFloat32(8 + i * 4, Endian.little);
      }
    }

    _loadedTier = tier;
  }

  static Future<List<String>> identifyItem({required String imagePath}) async {
    await _load();
    final def = kCvModels.firstWhere((m) => m.tier == _loadedTier!);

    Uint8List bytes;
    if (imagePath.startsWith('data:')) {
      final comma = imagePath.indexOf(',');
      bytes = base64Decode(imagePath.substring(comma + 1));
    } else {
      bytes = await File(imagePath).readAsBytes();
    }

    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Failed to decode image.');
    final resized = img.copyResize(
      decoded,
      width: def.inputSize,
      height: def.inputSize,
    );

    if (def.isTflite) {
      return _runTflite(def, resized);
    } else {
      return _runOnnx(def, resized);
    }
  }

  static List<String> _runTflite(CvModelDef def, img.Image resized) {
    final inputShape = _tfliteInterpreter!.getInputTensor(0).shape;
    final h = inputShape[1];
    final w = inputShape[2];

    final inputBytes = Uint8List(1 * h * w * 3);
    int idx = 0;
    final uint8Image = resized.convert(numChannels: 3);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final pixel = uint8Image.getPixel(x, y);
        inputBytes[idx++] = pixel.r.toInt();
        inputBytes[idx++] = pixel.g.toInt();
        inputBytes[idx++] = pixel.b.toInt();
      }
    }

    final outputShape = _tfliteInterpreter!.getOutputTensor(0).shape;
    int outputSize = 1;
    for (final d in outputShape) {
      outputSize *= d;
    }
    final outputBytes = Uint8List(outputSize);

    _tfliteInterpreter!.run(inputBytes.buffer, outputBytes.buffer);

    return _rankUint8(outputBytes, def.hasBackgroundClass);
  }

  static List<String> _runOnnx(CvModelDef def, img.Image resized) {
    final h = def.inputSize;
    final w = def.inputSize;
    final inputData = Float32List(1 * 3 * h * w);

    final mean = def.normMean;
    final std = def.normStd;
    final uint8Image = resized.convert(numChannels: 3);

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final pixel = uint8Image.getPixel(x, y);
        final r = pixel.r / 255.0;
        final g = pixel.g / 255.0;
        final b = pixel.b / 255.0;
        inputData[0 * h * w + y * w + x] = (r - mean[0]) / std[0];
        inputData[1 * h * w + y * w + x] = (g - mean[1]) / std[1];
        inputData[2 * h * w + y * w + x] = (b - mean[2]) / std[2];
      }
    }

    final inputName = _ortSession!.inputNames.isNotEmpty
        ? _ortSession!.inputNames.first
        : 'pixel_values';

    final inputTensor = OrtValueTensor.createTensorWithDataList(
      inputData,
      [1, 3, h, w],
    );

    final runOptions = OrtRunOptions();
    List<OrtValue?>? outputs;
    try {
      outputs = _ortSession!.run(runOptions, {inputName: inputTensor});
    } finally {
      inputTensor.release();
      runOptions.release();
    }

    try {
      if (def.isZeroShot) {
        return _rankZeroShot(outputs?.first?.value);
      } else {
        return _rankFloat(outputs?.first?.value, def.hasBackgroundClass);
      }
    } finally {
      if (outputs != null) {
        for (final o in outputs) {
          o?.release();
        }
      }
    }
  }

  static List<String> _rankUint8(Uint8List output, bool hasBackground) {
    final labels = _labels!;
    final indices = List<int>.generate(output.length, (i) => i);
    indices.sort((a, b) => output[b].compareTo(output[a]));

    final results = <String>[];
    for (final j in indices) {
      if (results.length >= 5) break;
      String label;
      if (hasBackground) {
        if (j == 0) continue;
        if (j >= labels.length) continue;
        label = labels[j];
      } else {
        final li = j + 1;
        if (li >= labels.length) continue;
        label = labels[li];
      }
      label = label.trim();
      if (label.isEmpty || label.toLowerCase() == 'background') continue;
      results.add(label);
    }
    return results;
  }

  static List<String> _rankFloat(dynamic outputValue, bool hasBackground) {
    List<double> scores;
    if (outputValue is List) {
      try {
        scores = (outputValue[0] as List).cast<double>();
      } catch (_) {
        scores = (outputValue as List).cast<double>();
      }
    } else {
      return [];
    }

    final labels = _labels!;
    final indices = List<int>.generate(scores.length, (i) => i);
    indices.sort((a, b) => scores[b].compareTo(scores[a]));

    final results = <String>[];
    for (final j in indices) {
      if (results.length >= 5) break;
      String label;
      if (hasBackground) {
        if (j == 0) continue;
        if (j >= labels.length) continue;
        label = labels[j];
      } else {
        final li = j + 1;
        if (li >= labels.length) continue;
        label = labels[li];
      }
      label = label.trim();
      if (label.isEmpty || label.toLowerCase() == 'background') continue;
      results.add(label);
    }
    return results;
  }

  static List<String> _rankZeroShot(dynamic outputValue) {
    List<double> embedding;
    if (outputValue is List) {
      try {
        embedding = (outputValue[0] as List).cast<double>();
      } catch (_) {
        embedding = (outputValue as List).cast<double>();
      }
    } else {
      return [];
    }

    final embedDim = _embedDim!;
    final textEmb = _textEmbeddings!;
    final numClasses = textEmb.length ~/ embedDim;

    double norm = 0.0;
    for (final v in embedding) {
      norm += v * v;
    }
    norm = math.sqrt(norm) + 1e-8;
    final normEmb = Float32List(embedding.length);
    for (int i = 0; i < embedding.length; i++) {
      normEmb[i] = embedding[i] / norm;
    }

    final scores = Float32List(numClasses);
    for (int c = 0; c < numClasses; c++) {
      double dot = 0.0;
      final offset = c * embedDim;
      for (int d = 0; d < embedDim; d++) {
        dot += normEmb[d] * textEmb[offset + d];
      }
      scores[c] = dot;
    }

    final labels = _labels!;
    final indices = List<int>.generate(numClasses, (i) => i);
    indices.sort((a, b) => scores[b].compareTo(scores[a]));

    final results = <String>[];
    for (final j in indices) {
      if (results.length >= 5) break;
      final li = j + 1;
      if (li >= labels.length) continue;
      final label = labels[li].trim();
      if (label.isEmpty || label.toLowerCase() == 'background') continue;
      results.add(label);
    }
    return results;
  }

  static void _disposeCurrentModel() {
    _tfliteInterpreter?.close();
    _tfliteInterpreter = null;
    _ortSession?.release();
    _ortSession = null;
    _labels = null;
    _textEmbeddings = null;
    _embedDim = null;
    _loadedTier = null;
  }

  static void _ensureOrtEnv() {
    if (!_ortEnvInitialized) {
      OrtEnv.instance.init();
      _ortEnvInitialized = true;
    }
  }

  static void dispose() => _disposeCurrentModel();

  static void invalidate() => _disposeCurrentModel();
}
