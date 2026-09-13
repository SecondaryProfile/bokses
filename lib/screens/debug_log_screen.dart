import 'package:flutter/material.dart';
import '../services/app_logger.dart';
import '../services/web_download.dart'
    if (dart.library.html) '../services/web_download_web.dart';
import '../theme/app_theme.dart';
import '../constants.dart';

class DebugLogScreen extends StatefulWidget {
  const DebugLogScreen({super.key});

  @override
  State<DebugLogScreen> createState() => _DebugLogScreenState();
}

class _DebugLogScreenState extends State<DebugLogScreen> {
  String _log = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final log = await AppLogger.readLog();
    if (mounted) {
      setState(() {
        _log = log;
        _loading = false;
      });
    }
  }

  Future<void> _download() async {
    final log = await AppLogger.readLog();
    triggerWebDownload(log, 'bokses_debug_log.txt', mimeType: 'text/plain');
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Log?'),
        content: Text(
          'This will erase the debug log for this session.',
          style: TextStyle(fontFamily: kFontFamily, color: AppTheme.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(fontFamily: kFontFamily, color: AppTheme.textMid),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AppLogger.clear();
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _reload,
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Download',
            onPressed: _log.isEmpty ? null : _download,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Clear',
            onPressed: _log.isEmpty ? null : _clear,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _log.isEmpty
              ? Center(
                  child: Text(
                    'No log entries yet.',
                    style: TextStyle(fontFamily: kFontFamily, color: AppTheme.textMid),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    _log,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, height: 1.4),
                  ),
                ),
    );
  }
}
