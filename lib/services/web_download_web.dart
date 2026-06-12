import 'package:web/web.dart' as web;

void triggerWebDownload(String content, String filename) {
  final dataUri = 'data:application/json;charset=utf-8,${Uri.encodeComponent(content)}';
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = dataUri
    ..download = filename;
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
}
