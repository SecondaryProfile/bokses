import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/box.dart';
import '../models/item.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../constants.dart';
import 'box_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  List<({Item item, Box box})> _results = [];
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    AppTheme.modeNotifier.addListener(_rebuild);
    AppTheme.presetNotifier.addListener(_rebuild);
    _ctrl.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    AppTheme.modeNotifier.removeListener(_rebuild);
    AppTheme.presetNotifier.removeListener(_rebuild);
    _ctrl.removeListener(_onQueryChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _onQueryChanged() {
    final q = _ctrl.text.trim();
    if (q.length < 3) {
      if (_searched || _results.isNotEmpty) {
        setState(() {
          _results = [];
          _searched = false;
        });
      }
      return;
    }
    _runSearch(q);
  }

  Future<void> _runSearch(String q) async {
    final results = await DatabaseService.instance.searchItems(q);
    if (mounted) {
      setState(() {
        _results = results;
        _searched = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _ctrl.text.trim();
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
          decoration: const InputDecoration(
            hintText: 'Search items…',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            fillColor: Colors.transparent,
            filled: false,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: _ctrl.clear,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(query),
    );
  }

  Widget _buildBody(String query) {
    if (query.length < 3) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: 64, color: AppTheme.boksBlueLight),
            const SizedBox(height: 16),
            Text(
              'Type at least 3 characters',
              style: TextStyle(
                fontFamily: kFontFamily,
                fontSize: 16,
                color: AppTheme.textMid,
              ),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty && _searched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 64, color: AppTheme.boksBlueLight),
            const SizedBox(height: 16),
            Text(
              'No items found',
              style: TextStyle(
                fontFamily: kFontFamily,
                fontSize: 16,
                color: AppTheme.textMid,
              ),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(
              bottom: BorderSide(color: AppTheme.bubblePurple, width: 1),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded,
                  size: 15, color: AppTheme.boksBlueBright),
              const SizedBox(width: 8),
              Text(
                '${_results.length} result${_results.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMid,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: _results.length,
            itemBuilder: (_, i) {
              final r = _results[i];
              return _ResultTile(
                item: r.item,
                box: r.box,
                query: query,
                index: i,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => BoxDetailScreen(box: r.box)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  final Item item;
  final Box box;
  final String query;
  final int index;
  final VoidCallback onTap;

  const _ResultTile({
    required this.item,
    required this.box,
    required this.query,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.bubblePurple, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.boksBlueLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.label_rounded,
                  color: AppTheme.boksBlue, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HighlightedText(
                    text: item.name,
                    query: query,
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                    highlightColor: AppTheme.boksBlueBright,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.inventory_2_rounded,
                          size: 12, color: AppTheme.textMid),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          box.name,
                          style: TextStyle(
                            fontFamily: kFontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMid,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppTheme.textMid, size: 20),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 40 * index), duration: 200.ms)
        .slideX(begin: 0.05, end: 0);
  }
}

class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final Color highlightColor;

  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: style);
    final lower = text.toLowerCase();
    final lowerQ = query.toLowerCase();
    final idx = lower.indexOf(lowerQ);
    if (idx == -1) return Text(text, style: style);
    return RichText(
      text: TextSpan(
        style: style,
        children: [
          if (idx > 0) TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + query.length),
            style: style.copyWith(
              color: highlightColor,
              backgroundColor: highlightColor.withValues(alpha: 0.15),
            ),
          ),
          if (idx + query.length < text.length)
            TextSpan(text: text.substring(idx + query.length)),
        ],
      ),
    );
  }
}
