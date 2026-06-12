import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../models/box.dart';
import '../models/item.dart';
import '../services/database_service.dart';
import '../services/import_export_service.dart';
import '../theme/app_theme.dart';
import '../constants.dart';
import 'box_detail_screen.dart';
import 'about_screen.dart';
import 'settings_screen.dart';
import 'version_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Box> _boxes = [];
  Map<String, int> _itemCounts = {};
  bool _loading = true;
  final _menuKey = GlobalKey();

  bool _searching = false;
  final _searchCtrl = TextEditingController();
  List<({Item item, Box box})> _searchResults = [];
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    AppTheme.modeNotifier.addListener(_rebuildOnThemeChange);
    AppTheme.presetNotifier.addListener(_rebuildOnThemeChange);
    _searchCtrl.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    AppTheme.modeNotifier.removeListener(_rebuildOnThemeChange);
    AppTheme.presetNotifier.removeListener(_rebuildOnThemeChange);
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _rebuildOnThemeChange() => setState(() {});

  void _openSearch() => setState(() => _searching = true);

  void _closeSearch() {
    _searchCtrl.clear();
    setState(() {
      _searching = false;
      _searchResults = [];
      _searched = false;
    });
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim();
    if (q.length < 3) {
      if (_searched || _searchResults.isNotEmpty) {
        setState(() {
          _searchResults = [];
          _searched = false;
        });
      }
      return;
    }
    _runSearch(q);
  }

  Future<void> _runSearch(String q) async {
    final results = await DatabaseService.instance.searchItems(q);
    if (mounted) setState(() { _searchResults = results; _searched = true; });
  }

  Future<void> _load() async {
    try {
      final boxes = await DatabaseService.instance.getBoxes();
      final counts = <String, int>{};
      for (final b in boxes) {
        counts[b.id] = await DatabaseService.instance.getItemCount(b.id);
      }
      if (mounted) {
        setState(() {
          _boxes = boxes;
          _itemCounts = counts;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backend not reachable — data will load when deployed.')),
        );
      }
    }
  }

  Future<void> _showAddBoxDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.bubblePurple,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('New Box',
                    style: TextStyle(
                        fontFamily: kFontFamily,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Box name *'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Name required';
                    final name = v.trim().toLowerCase();
                    if (_boxes.any((b) => b.name.toLowerCase() == name)) {
                      return 'A box with this name already exists';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Description (optional)'),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final box = Box(
                        id: const Uuid().v4(),
                        name: nameCtrl.text.trim(),
                        description: descCtrl.text.trim().isEmpty
                            ? null
                            : descCtrl.text.trim(),
                        createdAt: DateTime.now(),
                      );
                      await DatabaseService.instance.insertBox(box);
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _load();
                    },
                    child: const Text('Create Box'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditBoxDialog(Box box) async {
    final nameCtrl = TextEditingController(text: box.name);
    final descCtrl = TextEditingController(text: box.description ?? '');
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.bubblePurple,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Edit Box',
                    style: TextStyle(
                        fontFamily: kFontFamily,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Box name *'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Name required';
                    final name = v.trim().toLowerCase();
                    if (_boxes.any((b) =>
                        b.id != box.id && b.name.toLowerCase() == name)) {
                      return 'A box with this name already exists';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Description (optional)'),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      box.name = nameCtrl.text.trim();
                      box.description = descCtrl.text.trim().isEmpty
                          ? null
                          : descCtrl.text.trim();
                      await DatabaseService.instance.updateBox(box);
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _load();
                    },
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteBox(Box box) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"${box.name}"?',
            style: const TextStyle(
                fontFamily: kFontFamily, fontWeight: FontWeight.w800)),
        content: const Text(
          'This will permanently delete the box and all its items.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.boksRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseService.instance.deleteBox(box.id);
      _load();
    }
  }

  Rect? _getMenuRect() {
    final box = _menuKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final pos = box.localToGlobal(Offset.zero);
    return pos & box.size;
  }

  Future<void> _doClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all data?',
            style: TextStyle(
                fontFamily: kFontFamily, fontWeight: FontWeight.w800)),
        content: const Text(
          'This will permanently delete all boxes and items. This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.boksRed),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseService.instance.clearAll();
      await _load();
    }
  }

  Future<void> _doExport() async {
    try {
      await ImportExportService.exportData(sharePositionOrigin: _getMenuRect());
      _showSnack(kIsWeb ? 'Export downloaded!' : 'Export shared!');
    } catch (e) {
      _showSnack('Export failed: $e');
    }
  }

  Future<void> _doImport() async {
    try {
      final msg = await ImportExportService.importData();
      _showSnack(msg);
      _load();
    } catch (e) {
      _showSnack('Import failed: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppTheme.background,
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: AppTheme.bubblePurple.withValues(alpha: 0.35),
          ),
        ),
        leading: _searching
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _closeSearch,
              )
            : null,
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: 17,
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
              )
            : Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.boksBlue, AppTheme.boksRed],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        'B',
                        style: TextStyle(
                          fontFamily: kFontFamily,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Bokses',
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      fontWeight: FontWeight.w900,
                      fontSize: 21,
                      letterSpacing: -0.3,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
        actions: _searching
            ? [
                if (_searchCtrl.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: _searchCtrl.clear,
                  ),
                const SizedBox(width: 8),
              ]
            : [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.bubblePurple, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: _openSearch,
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Icon(Icons.search_rounded, size: 17),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 18,
                        color: AppTheme.bubblePurple,
                      ),
                      PopupMenuButton<String>(
                        key: _menuKey,
                        padding: EdgeInsets.zero,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Icon(Icons.more_horiz_rounded, size: 17),
                        ),
                        onSelected: (val) async {
                          if (val == 'export') _doExport();
                          if (val == 'import') _doImport();
                          if (val == 'clear') _doClearAll();
                          if (val == 'settings') {
                            Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const SettingsScreen()));
                          }
                          if (val == 'about') {
                            Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const AboutScreen()));
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'export',
                            child: ListTile(
                              leading: Icon(Icons.upload_rounded),
                              title: Text('Export Data',
                                  style: TextStyle(fontFamily: kFontFamily, fontWeight: FontWeight.w600)),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'import',
                            child: ListTile(
                              leading: Icon(Icons.download_rounded),
                              title: Text('Import Data',
                                  style: TextStyle(fontFamily: kFontFamily, fontWeight: FontWeight.w600)),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'clear',
                            child: ListTile(
                              leading: Icon(Icons.delete_sweep_rounded, color: AppTheme.boksRed),
                              title: Text('Delete All Data',
                                  style: TextStyle(fontFamily: kFontFamily, color: AppTheme.boksRed, fontWeight: FontWeight.w600)),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'settings',
                            child: ListTile(
                              leading: Icon(Icons.settings_rounded),
                              title: Text('Settings',
                                  style: TextStyle(fontFamily: kFontFamily, fontWeight: FontWeight.w600)),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'about',
                            child: ListTile(
                              leading: Icon(Icons.info_outline_rounded),
                              title: Text('About',
                                  style: TextStyle(fontFamily: kFontFamily, fontWeight: FontWeight.w600)),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _searching
              ? _searchBody()
              : Column(
                  children: [
                    _summaryBar(),
                    Expanded(
                      child: _boxes.isEmpty ? _emptyState() : _boxGrid(),
                    ),
                    _footer(),
                  ],
                ),
      floatingActionButton: _searching
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddBoxDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Box'),
            )
              .animate()
              .scale(delay: 300.ms, duration: 400.ms, curve: Curves.elasticOut),
    );
  }

  Widget _footer() {
    final changes = kChangelog.first.changes;
    final tooltip = changes.map((c) => '• $c').join('\n');
    return Padding(
      padding: const EdgeInsets.only(bottom: 80, top: 4),
      child: Center(
        child: Tooltip(
          message: tooltip,
          waitDuration: Duration.zero,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VersionHistoryScreen()),
              ),
              child: Text(
                'v$kAppVersion',
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: 11,
                  color: AppTheme.textMid.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchBody() {
    final query = _searchCtrl.text.trim();
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
    if (_searched && _searchResults.isEmpty) {
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
    if (_searchResults.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Row(
            children: [
              _StatChip(
                icon: Icons.search_rounded,
                label: '${_searchResults.length} result${_searchResults.length == 1 ? '' : 's'}',
                color: AppTheme.boksBlueBright,
                bgColor: AppTheme.boksBlueLight,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: _searchResults.length,
            itemBuilder: (_, i) {
              final r = _searchResults[i];
              return _ResultTile(
                item: r.item,
                box: r.box,
                query: query,
                index: i,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => BoxDetailScreen(box: r.box)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _summaryBar() {
    final totalItems = _itemCounts.values.fold(0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.inventory_2_rounded,
            label: '${_boxes.length} box${_boxes.length == 1 ? '' : 'es'}',
            color: AppTheme.boksBlueBright,
            bgColor: AppTheme.boksBlueLight,
          ),
          const SizedBox(width: 8),
          _StatChip(
            icon: Icons.layers_rounded,
            label: '$totalItems item${totalItems == 1 ? '' : 's'}',
            color: AppTheme.boksRedBright,
            bgColor: AppTheme.boksRedLight,
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.boksBlueLight,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(Icons.inventory_2_outlined,
                size: 52, color: AppTheme.boksBlue),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 28),
          const Text('No boxes yet!',
                  style: TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: 28,
                      fontWeight: FontWeight.w800))
              .animate()
              .fadeIn(delay: 200.ms),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to create\nyour first box.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: kFontFamily,
                fontSize: 16,
                color: AppTheme.textMid),
          ).animate().fadeIn(delay: 300.ms),
        ],
      ),
    );
  }

  Widget _boxGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      itemCount: _boxes.length,
      itemBuilder: (_, i) {
        final box = _boxes[i];
        final count = _itemCounts[box.id] ?? 0;
        return _BoxCard(
          box: box,
          itemCount: count,
          index: i,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BoxDetailScreen(box: box)),
            );
            _load();
          },
          onDelete: () => _deleteBox(box),
          onEdit: () => _showEditBoxDialog(box),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: kFontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoxCard extends StatelessWidget {
  final Box box;
  final int itemCount;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _BoxCard({
    required this.box,
    required this.itemCount,
    required this.index,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isBlue = index.isEven;
    final accentColor = isBlue ? AppTheme.boksBlue : AppTheme.boksRed;
    final accentDim = isBlue ? AppTheme.boksBlueLight : AppTheme.boksRedLight;
    final accentBright =
        isBlue ? AppTheme.boksBlueBright : AppTheme.boksRedBright;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.bubblePurple, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: icon + menu (no count badge)
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentDim,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.inventory_2_rounded,
                        color: accentColor, size: 24),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz_rounded,
                        color: AppTheme.textMid, size: 20),
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_rounded),
                          title: Text('Edit',
                              style: TextStyle(
                                  fontFamily: kFontFamily,
                                  fontWeight: FontWeight.w600)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline_rounded,
                              color: AppTheme.boksRed),
                          title: Text('Delete',
                              style: TextStyle(
                                  fontFamily: kFontFamily,
                                  color: AppTheme.boksRed,
                                  fontWeight: FontWeight.w600)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 5×4 grid of dots that fills all remaining vertical space
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(3, (row) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(5, (col) {
                        final i = row * 5 + col;
                        final isOverflowSlot = i == 14 && itemCount > 15;
                        final filled = i < itemCount;
                        if (isOverflowSlot) {
                          return Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(Icons.add,
                                  size: 9, color: AppTheme.background),
                            ),
                          );
                        }
                        return Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: filled ? accentColor : accentDim,
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    );
                  }),
                ),
              ),
              // Box name
              Text(
                box.name,
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (box.description != null) ...[
                const SizedBox(height: 2),
                Text(
                  box.description!,
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontSize: 12,
                    color: AppTheme.textMid,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 6),
              Text(
                '$itemCount item${itemCount == 1 ? '' : 's'}',
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accentBright,
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 60 * index), duration: 300.ms)
        .slideY(begin: 0.1, end: 0);
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
              child: Icon(Icons.label_rounded, color: AppTheme.boksBlue, size: 20),
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
                      Icon(Icons.inventory_2_rounded, size: 12, color: AppTheme.textMid),
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
            Icon(Icons.chevron_right_rounded, color: AppTheme.textMid, size: 20),
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
