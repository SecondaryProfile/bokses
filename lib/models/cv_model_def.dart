enum CvModelTier { small, medium, large, xl }

class CvModelDef {
  final CvModelTier tier;
  final String displayName;
  final String modelName;
  final String paramCount;
  final String downloadSize;
  final String topFiveAccuracy;
  final String description;
  final bool isTflite;
  final String modelUrl;
  final String labelsUrl;
  final String? embeddingsUrl;
  final String modelFilename;
  final String labelsFilename;
  final String? embeddingsFilename;
  final int inputSize;
  final bool usesFloat32;
  final bool isZeroShot;
  final bool hasBackgroundClass;
  final List<double> normMean;
  final List<double> normStd;

  const CvModelDef({
    required this.tier,
    required this.displayName,
    required this.modelName,
    required this.paramCount,
    required this.downloadSize,
    required this.topFiveAccuracy,
    required this.description,
    required this.isTflite,
    required this.modelUrl,
    required this.labelsUrl,
    this.embeddingsUrl,
    required this.modelFilename,
    required this.labelsFilename,
    this.embeddingsFilename,
    required this.inputSize,
    this.usesFloat32 = false,
    this.isZeroShot = false,
    this.hasBackgroundClass = true,
    this.normMean = const [0.5, 0.5, 0.5],
    this.normStd = const [0.5, 0.5, 0.5],
  });
}

const kSmallModel = CvModelDef(
  tier: CvModelTier.small,
  displayName: 'Small',
  modelName: 'MobileNet V3 Large',
  paramCount: '5.4 M params',
  downloadSize: '~22 MB',
  topFiveAccuracy: 'Top-5 ~92%',
  description: 'Fastest inference on any Android device. 1,000 ImageNet categories.',
  isTflite: true,
  modelUrl:
      'https://storage.googleapis.com/download.tensorflow.org/models/tflite/task_lib/image_classification/android/lite-model_imagenet_mobilenet_v3_large_100_224_classification_5_default_1.tflite',
  labelsUrl:
      'https://raw.githubusercontent.com/google-coral/test_data/master/imagenet_labels.txt',
  embeddingsUrl: null,
  modelFilename: 'bokses_cv_small.tflite',
  labelsFilename: 'bokses_cv_small_labels.txt',
  embeddingsFilename: null,
  inputSize: 224,
  usesFloat32: false,
  isZeroShot: false,
  hasBackgroundClass: true,
);

const kMediumModel = CvModelDef(
  tier: CvModelTier.medium,
  displayName: 'Medium',
  modelName: 'EfficientNet-Lite4',
  paramCount: '13 M params',
  downloadSize: '~49 MB',
  topFiveAccuracy: 'Top-5 ~95%',
  description: 'Noticeably better accuracy. Recommended for most devices.',
  isTflite: true,
  modelUrl:
      'https://storage.googleapis.com/download.tensorflow.org/models/tflite/task_lib/image_classification/android/lite-model_efficientnet_lite4_int8_2.tflite',
  labelsUrl:
      'https://raw.githubusercontent.com/google-coral/test_data/master/imagenet_labels.txt',
  embeddingsUrl: null,
  modelFilename: 'bokses_cv_medium.tflite',
  labelsFilename: 'bokses_cv_medium_labels.txt',
  embeddingsFilename: null,
  inputSize: 300,
  usesFloat32: false,
  isZeroShot: false,
  hasBackgroundClass: false,
);

const kLargeModel = CvModelDef(
  tier: CvModelTier.large,
  displayName: 'Large',
  modelName: 'ViT-B/16',
  paramCount: '86 M params',
  downloadSize: '~335 MB',
  topFiveAccuracy: 'Top-5 ~97%',
  description: 'Vision Transformer. Requires a recent mid-range or flagship device.',
  isTflite: false,
  modelUrl: 'https://huggingface.co/Xenova/vit-base-patch16-224/resolve/main/onnx/model.onnx',
  labelsUrl:
      'https://raw.githubusercontent.com/google-coral/test_data/master/imagenet_labels.txt',
  embeddingsUrl: null,
  modelFilename: 'bokses_cv_large.onnx',
  labelsFilename: 'bokses_cv_large_labels.txt',
  embeddingsFilename: null,
  inputSize: 224,
  usesFloat32: true,
  isZeroShot: false,
  hasBackgroundClass: false,
  normMean: const [0.5, 0.5, 0.5],
  normStd: const [0.5, 0.5, 0.5],
);

const kXlModel = CvModelDef(
  tier: CvModelTier.xl,
  displayName: 'XL',
  modelName: 'OpenCLIP ViT-L/14',
  paramCount: '307 M params',
  downloadSize: '~900 MB',
  topFiveAccuracy: 'Top-5 ~98%+',
  description:
      'Maximum accuracy. Zero-shot recognition. Requires 2–3 GB RAM. Flagship only.',
  isTflite: false,
  modelUrl:
      'https://huggingface.co/Xenova/clip-vit-large-patch14/resolve/main/onnx/vision_model.onnx',
  labelsUrl:
      'https://raw.githubusercontent.com/google-coral/test_data/master/imagenet_labels.txt',
  embeddingsUrl: null,
  modelFilename: 'bokses_cv_xl.onnx',
  labelsFilename: 'bokses_cv_xl_labels.txt',
  embeddingsFilename: 'bokses_cv_xl_embeddings.bin',
  inputSize: 224,
  usesFloat32: true,
  isZeroShot: true,
  hasBackgroundClass: false,
  normMean: const [0.48145466, 0.4578275, 0.40821073],
  normStd: const [0.26862954, 0.26130258, 0.27577711],
);

const kCvModels = [kSmallModel, kMediumModel, kLargeModel, kXlModel];
