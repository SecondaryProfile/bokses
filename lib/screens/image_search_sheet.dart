import 'package:flutter/material.dart';
import '../services/image_search_service.dart';
import '../theme/app_theme.dart';
import '../constants.dart';

/// Bottom sheet that searches the web for images and returns a selected image
/// as a base64 data URI. Returns null if dismissed without selection.
class ImageSearchSheet extends StatefulWidget {
  final String initialQuery;
  const ImageSearchSheet({super.key, required this.initialQuery});

  @override
  State<ImageSearchSheet> createState() => _ImageSearchSheetState();
}

class _ImageSearchSheetState extends State<ImageSearchSheet> {
  late final TextEditingController _queryCtrl;
  List<ImageSearchResult> _results = [];
  bool _loading = false;
  String? _error;
  int? _downloadingIndex;

  @override
  void initState() {
    super.initState();
    _queryCtrl = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _queryCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() { _loading = true; _error = null; _results = []; });
    try {
      final results = await ImageSearchService.search(q);
      if (mounted) setState(() { _results = results; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _pick(int index) async {
    setState(() => _downloadingIndex = index);
    try {
      final uri = await ImageSearchService.downloadAsDataUri(
        _results[index].thumbnailUrl,
      );
      if (mounted) Navigator.pop(context, uri);
    } catch (e) {
      if (mounted) {
        setState(() => _downloadingIndex = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not download image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 14, bottom: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.bubblePurple,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Find a Photo Online',
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
                Icon(Icons.language_rounded, size: 20, color: AppTheme.textMid),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    style: TextStyle(fontFamily: kFontFamily, color: AppTheme.textDark),
                    decoration: InputDecoration(
                      hintText: 'Search for an image…',
                      hintStyle: TextStyle(color: AppTheme.textMid),
                      prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textMid),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _loading ? null : _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.boksBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Search',
                      style: TextStyle(fontFamily: kFontFamily, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              'Images sourced from Openverse (Creative Commons)',
              style: TextStyle(fontFamily: kFontFamily, fontSize: 11, color: AppTheme.textMid),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.boksBlue));
    }
    if (_error != null) {
      final isConnectivity = _error!.contains('SocketException') ||
          _error!.contains('host lookup') ||
          _error!.contains('NetworkException') ||
          _error!.contains('TimeoutException') ||
          _error!.contains('timeout');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: AppTheme.textMid),
            const SizedBox(height: 16),
            Text(
              isConnectivity ? 'No Internet Connection' : 'Search Unavailable',
              style: TextStyle(
                fontFamily: kFontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isConnectivity
                  ? 'Connect to the internet to search for photos.'
                  : 'Image search is currently unavailable.\nPlease check your connection and try again.',
              style: TextStyle(fontFamily: kFontFamily, fontSize: 13, color: AppTheme.textMid),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      );
    }
    if (_results.isEmpty && _queryCtrl.text.trim().isNotEmpty) {
      return Center(
        child: Text('No images found', style: TextStyle(fontFamily: kFontFamily, color: AppTheme.textMid)),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text('Enter a search term above', style: TextStyle(fontFamily: kFontFamily, color: AppTheme.textMid)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final downloading = _downloadingIndex == i;
        return GestureDetector(
          onTap: _downloadingIndex != null ? null : () => _pick(i),
          child: AnimatedOpacity(
            opacity: _downloadingIndex != null && !downloading ? 0.4 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.bubblePurple, width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(fit: StackFit.expand, children: [
                Image.network(
                  _results[i].thumbnailUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : Center(child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.boksBlue)),
                  errorBuilder: (_, __, ___) => Container(
                    color: AppTheme.cardBg,
                    child: Icon(Icons.broken_image_rounded, color: AppTheme.textMid),
                  ),
                ),
                if (downloading)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    ),
                  ),
              ]),
            ),
          ),
        );
      },
    );
  }
}
