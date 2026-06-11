// ML Kit image labeling is not supported on web.
// CV suggestions are disabled; this stub keeps the rest of the codebase unchanged.
class VisionService {
  static Future<List<String>> identifyItem({required String imagePath}) async {
    return [];
  }

  static void dispose() {}
}
