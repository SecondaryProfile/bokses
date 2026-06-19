import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:uuid/uuid.dart';
import '../models/box.dart';
import '../models/item.dart';
import '../services/database_service.dart';
import '../services/import_export_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../constants.dart';
import '../widgets/label_badges.dart';
import 'box_detail_screen.dart';
import 'about_screen.dart';
import 'settings_screen.dart';

enum BoxSort { dateAsc, dateDesc, nameAsc, nameDesc }

enum BoxViewMode { grid, list }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Box> _boxes = [];
  Map<String, int> _itemCounts = {};
  Map<String, Set<ItemLabel>> _boxLabels = {};
  bool _loading = true;
  bool _loadAll = true;
  final _menuKey = GlobalKey();
  BoxSort _sort = BoxSort.dateAsc;
  BoxViewMode _viewMode = BoxViewMode.grid;

  bool _searching = false;
  final _searchCtrl = TextEditingController();
  List<({Item item, Box box})> _searchResults = [];
  bool _searched = false;

  // Background
  AppBgType _bgType = AppBgType.none;
  Uint8List? _bgImage;
  double _bgBlur = 10.0;
  int _bgColor = 0xFF0C0C0E;

  bool get _hasCustomBg => _bgType != AppBgType.none;

  List<Box> get _sortedBoxes {
    final list = List<Box>.from(_boxes);
    switch (_sort) {
      case BoxSort.dateAsc:
        return list..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case BoxSort.dateDesc:
        return list..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case BoxSort.nameAsc:
        return list
          ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case BoxSort.nameDesc:
        return list
          ..sort(
              (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    }
  }

  @override
  void initState() {
    super.initState();
    AppTheme.modeNotifier.addListener(_rebuildOnThemeChange);
    AppTheme.presetNotifier.addListener(_rebuildOnThemeChange);
    AppTheme.bgNotifier.addListener(_onBgChanged);
    _searchCtrl.addListener(_onSearchChanged);
    _load();
    _loadBackground();
  }

  @override
  void dispose() {
    AppTheme.modeNotifier.removeListener(_rebuildOnThemeChange);
    AppTheme.presetNotifier.removeListener(_rebuildOnThemeChange);
    AppTheme.bgNotifier.removeListener(_onBgChanged);
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _rebuildOnThemeChange() => setState(() {});

  void _onBgChanged() => _loadBackground();

  Future<void> _loadBackground() async {
    final type = await SettingsService.getBackgroundType();
    final imageStr = await SettingsService.getBackgroundImage();
    final blur = await SettingsService.getBackgroundBlur();
    final color = await SettingsService.getBackgroundColor();
    if (!mounted) return;
    Uint8List? image;
    if (imageStr != null && imageStr.startsWith('data:')) {
      try {
        image = base64Decode(imageStr.split(',').last);
      } catch (_) {}
    }
    setState(() {
      _bgType = type;
      _bgImage = image;
      _bgBlur = blur;
      _bgColor = color;
    });
  }

  Widget _buildBackground() {
    switch (_bgType) {
      case AppBgType.gradient:
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.boksBlue, AppTheme.boksRed],
            ),
          ),
        );
      case AppBgType.solid:
        return Container(color: Color(_bgColor));
      case AppBgType.image:
        if (_bgImage == null) return Container(color: AppTheme.background);
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(_bgImage!, fit: BoxFit.cover),
            if (_bgBlur > 0)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: _bgBlur, sigmaY: _bgBlur),
                child: Container(color: Colors.black.withValues(alpha: 0.15)),
              ),
          ],
        );
      default:
        return Container(color: AppTheme.background);
    }
  }

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
    if (mounted) {
      setState(() {
        _searchResults = results;
        _searched = true;
      });
    }
  }

  Future<void> _load() async {
    try {
      final boxes = await DatabaseService.instance.getBoxes();
      final counts = <String, int>{};
      for (final b in boxes) {
        counts[b.id] = await DatabaseService.instance.getItemCount(b.id);
      }
      final labelsMap = await DatabaseService.instance.getAllBoxItemLabels();
      final loadAll = await SettingsService.getLoadAllContent();
      if (mounted) {
        setState(() {
          _boxes = boxes;
          _itemCounts = counts;
          _boxLabels = labelsMap;
          _loadAll = loadAll;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
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
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(32)),
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
                  decoration:
                      const InputDecoration(labelText: 'Box name *'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Name required';
                    }
                    final name = v.trim().toLowerCase();
                    if (_boxes
                        .any((b) => b.name.toLowerCase() == name)) {
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
    final descCtrl =
        TextEditingController(text: box.description ?? '');
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(32)),
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
                  decoration:
                      const InputDecoration(labelText: 'Box name *'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Name required';
                    }
                    final name = v.trim().toLowerCase();
                    if (_boxes.any((b) =>
                        b.id != box.id &&
                        b.name.toLowerCase() == name)) {
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
                      box.description =
                          descCtrl.text.trim().isEmpty
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

  // All deletion paths (popup menu, swipe action, full-swipe dismiss) use
  // the same undo-snackbar pattern so behaviour is consistent.
  Future<void> _deleteBox(Box box) => _swipeDeleteBox(box);

  Future<void> _swipeDeleteBox(Box box) async {
    final items = await DatabaseService.instance.getItemsForBox(box.id);
    setState(() {
      _boxes.removeWhere((b) => b.id == box.id);
      _itemCounts.remove(box.id);
      _boxLabels.remove(box.id);
    });
    await DatabaseService.instance.deleteBox(box.id);
    if (!mounted) return;

    final itemWord = items.length == 1 ? 'item' : 'items';
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(
          items.isEmpty
              ? '"${box.name}" removed'
              : '"${box.name}" and ${items.length} $itemWord removed',
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await DatabaseService.instance.insertBox(box);
            for (final item in items) {
              await DatabaseService.instance.insertItem(item);
            }
            if (mounted) await _load();
          },
        ),
      ));
  }

  Rect? _getMenuRect() {
    final box =
        _menuKey.currentContext?.findRenderObject() as RenderBox?;
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
                fontFamily: kFontFamily,
                fontWeight: FontWeight.w800)),
        content: const Text(
          'This will permanently delete all boxes and items. This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935)),
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
      await ImportExportService.exportData(
          sharePositionOrigin: _getMenuRect());
      _showSnack(kIsWeb ? 'Export downloaded!' : 'Export saved!');
    } catch (e) {
      _showSnack('Export failed: $e');
    }
  }

  Future<void> _doImport() async {
    try {
      final jsonStr = await ImportExportService.pickImportJson();
      if (jsonStr == null) return;
      if (!mounted) return;

      final progress = ValueNotifier<(int, int)?>(null);

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ImportProgressDialog(progress: progress),
      );

      // Yield a frame so the dialog is visible before processing starts.
      await WidgetsBinding.instance.endOfFrame;

      String msg;
      try {
        msg = await ImportExportService.processImportJson(
          jsonStr,
          onProgress: (done, total) => progress.value = (done, total),
        );
      } finally {
        if (mounted) Navigator.of(context).pop();
      }

      _showSnack(msg);
      _load();
    } catch (e) {
      _showSnack('Import failed: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final _scaffold = Scaffold(
      backgroundColor:
          _hasCustomBg ? Colors.transparent : AppTheme.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        backgroundColor:
            _hasCustomBg ? Colors.transparent : AppTheme.background,
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
            : ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [AppTheme.boksBlue, AppTheme.boksRed],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ).createShader(bounds),
                child: const Text(
                  'Bokses',
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontWeight: FontWeight.w900,
                    fontSize: 30,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
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
                  margin: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: AppTheme.bubblePurple, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: _openSearch,
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(22)),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 11),
                          child:
                              Icon(Icons.search_rounded, size: 23),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 22,
                        color: AppTheme.bubblePurple,
                      ),
                      PopupMenuButton<String>(
                        key: _menuKey,
                        padding: EdgeInsets.zero,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 11),
                          child: Icon(Icons.more_horiz_rounded,
                              size: 23),
                        ),
                        onSelected: (val) async {
                          final nav = Navigator.of(context);
                          if (val == 'export') _doExport();
                          if (val == 'import') _doImport();
                          if (val == 'clear') _doClearAll();
                          if (val == 'settings') {
                            await nav.push(MaterialPageRoute(
                                builder: (_) =>
                                    const SettingsScreen()));
                            _load();
                          }
                          if (val == 'about') {
                            nav.push(MaterialPageRoute(
                                builder: (_) =>
                                    const AboutScreen()));
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'export',
                            child: ListTile(
                              leading: Icon(Icons.upload_rounded),
                              title: Text('Export Data',
                                  style: TextStyle(
                                      fontFamily: kFontFamily,
                                      fontWeight:
                                          FontWeight.w600)),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'import',
                            child: ListTile(
                              leading: Icon(Icons.download_rounded),
                              title: Text('Import Data',
                                  style: TextStyle(
                                      fontFamily: kFontFamily,
                                      fontWeight:
                                          FontWeight.w600)),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'clear',
                            child: ListTile(
                              leading: Icon(
                                  Icons.delete_sweep_rounded,
                                  color: Color(0xFFE53935)),
                              title: Text('Delete All Data',
                                  style: TextStyle(
                                      fontFamily: kFontFamily,
                                      color: Color(0xFFE53935),
                                      fontWeight:
                                          FontWeight.w600)),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'settings',
                            child: ListTile(
                              leading:
                                  Icon(Icons.settings_rounded),
                              title: Text('Settings',
                                  style: TextStyle(
                                      fontFamily: kFontFamily,
                                      fontWeight:
                                          FontWeight.w600)),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'about',
                            child: ListTile(
                              leading: Icon(
                                  Icons.info_outline_rounded),
                              title: Text('About',
                                  style: TextStyle(
                                      fontFamily: kFontFamily,
                                      fontWeight:
                                          FontWeight.w600)),
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
                      child: _boxes.isEmpty
                          ? _emptyState()
                          : _viewMode == BoxViewMode.grid
                              ? _boxGrid()
                              : _boxList(),
                    ),
                  ],
                ),
      floatingActionButton: _searching
          ? null
          : _GradientFab(onPressed: _showAddBoxDialog)
              .animate()
              .scale(
                  delay: 300.ms,
                  duration: 400.ms,
                  curve: Curves.elasticOut),
    );
    if (!_hasCustomBg) return _scaffold;
    return Stack(
      children: [
        SizedBox.expand(child: _buildBackground()),
        _scaffold,
      ],
    );
  }

  Widget _searchBody() {
    final query = _searchCtrl.text.trim();
    if (query.length < 3) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded,
                size: 64, color: AppTheme.boksBlueLight),
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
            Icon(Icons.inbox_rounded,
                size: 64, color: AppTheme.boksBlueLight),
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
                label:
                    '${_searchResults.length} result${_searchResults.length == 1 ? '' : 's'}',
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
                loadAll: _loadAll,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            BoxDetailScreen(box: r.box)),
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
            label:
                '${_boxes.length} box${_boxes.length == 1 ? '' : 'es'}',
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
          const Spacer(),
          _SortButton(
            sort: _sort,
            onChanged: (s) => setState(() => _sort = s),
          ),
          const SizedBox(width: 8),
          _ViewToggleButton(
            mode: _viewMode,
            onChanged: (m) => setState(() => _viewMode = m),
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
    final boxes = _sortedBoxes;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:
            MediaQuery.of(context).size.width > 700 ? 3 : 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      itemCount: boxes.length,
      itemBuilder: (_, i) {
        final box = boxes[i];
        final count = _itemCounts[box.id] ?? 0;
        final labels = _boxLabels[box.id] ?? {};
        final card = _BoxCard(
          box: box,
          itemCount: count,
          index: i,
          totalBoxes: boxes.length,
          labels: labels,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => BoxDetailScreen(box: box)),
            );
            _load();
          },
          onDelete: () => _deleteBox(box),
          onEdit: () => _showEditBoxDialog(box),
        );
        if (_loadAll) return card;
        return card
            .animate()
            .fadeIn(
                delay: Duration(milliseconds: 60 * i),
                duration: 300.ms)
            .slideY(begin: 0.1, end: 0);
      },
    );
  }

  Widget _boxList() {
    final boxes = _sortedBoxes;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      itemCount: boxes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final box = boxes[i];
        final count = _itemCounts[box.id] ?? 0;
        final labels = _boxLabels[box.id] ?? {};
        final tile = _BoxListTile(
          box: box,
          itemCount: count,
          index: i,
          totalBoxes: boxes.length,
          labels: labels,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => BoxDetailScreen(box: box)),
            );
            _load();
          },
          onEdit: () => _showEditBoxDialog(box),
          onDelete: () => _deleteBox(box),
          onDeleteImmediate: () => _swipeDeleteBox(box),
        );
        if (_loadAll) return tile;
        return tile
            .animate()
            .fadeIn(
                delay: Duration(milliseconds: 40 * i),
                duration: 200.ms)
            .slideX(begin: 0.04, end: 0);
      },
    );
  }
}

// ── Sort button ────────────────────────────────────────────────────────────────

class _SortButton extends StatelessWidget {
  final BoxSort sort;
  final ValueChanged<BoxSort> onChanged;

  const _SortButton({required this.sort, required this.onChanged});

  static const _labels = {
    BoxSort.dateAsc: 'Oldest first',
    BoxSort.dateDesc: 'Newest first',
    BoxSort.nameAsc: 'A → Z',
    BoxSort.nameDesc: 'Z → A',
  };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<BoxSort>(
      initialValue: sort,
      onSelected: onChanged,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: AppTheme.bubblePurple, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort_rounded,
                size: 14, color: AppTheme.textMid),
            const SizedBox(width: 4),
            Text(
              _labels[sort]!,
              style: TextStyle(
                fontFamily: kFontFamily,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMid,
              ),
            ),
          ],
        ),
      ),
      itemBuilder: (_) => BoxSort.values.map((s) {
        final selected = s == sort;
        return PopupMenuItem(
          value: s,
          child: Row(
            children: [
              Icon(
                s == BoxSort.nameAsc || s == BoxSort.nameDesc
                    ? Icons.sort_by_alpha_rounded
                    : s == BoxSort.dateAsc
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                size: 16,
                color: selected
                    ? AppTheme.boksBlueBright
                    : AppTheme.textMid,
              ),
              const SizedBox(width: 8),
              Text(
                _labels[s]!,
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontWeight: selected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: selected
                      ? AppTheme.boksBlueBright
                      : AppTheme.textDark,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── View toggle button ─────────────────────────────────────────────────────────

class _ViewToggleButton extends StatelessWidget {
  final BoxViewMode mode;
  final ValueChanged<BoxViewMode> onChanged;

  const _ViewToggleButton(
      {required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(mode == BoxViewMode.grid
          ? BoxViewMode.list
          : BoxViewMode.grid),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: AppTheme.bubblePurple, width: 1.5),
        ),
        child: Icon(
          mode == BoxViewMode.grid
              ? Icons.view_list_rounded
              : Icons.grid_view_rounded,
          size: 16,
          color: AppTheme.textMid,
        ),
      ),
    );
  }
}

// ── Gradient FAB ───────────────────────────────────────────────────────────────

class _GradientFab extends StatelessWidget {
  final VoidCallback onPressed;
  const _GradientFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.boksBlue, AppTheme.boksRed],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.boksBlue.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(30),
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          child: const Padding(
            padding:
                EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text(
                  'New Box',
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Box card (grid) ────────────────────────────────────────────────────────────

class _BoxCard extends StatelessWidget {
  final Box box;
  final int itemCount;
  final int index;
  final int totalBoxes;
  final Set<ItemLabel> labels;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _BoxCard({
    required this.box,
    required this.itemCount,
    required this.index,
    required this.totalBoxes,
    required this.labels,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final t = totalBoxes > 1 ? index / (totalBoxes - 1) : 0.0;
    final accentColor =
        Color.lerp(AppTheme.boksBlue, AppTheme.boksRed, t)!;
    final accentDim = Color.lerp(
        AppTheme.boksBlueLight, AppTheme.boksRedLight, t)!;
    final accentBright = Color.lerp(
        AppTheme.boksBlueBright, AppTheme.boksRedBright, t)!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border:
              Border.all(color: AppTheme.bubblePurple, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name + menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      box.name,
                      style: TextStyle(
                        fontFamily: kFontFamily,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline_rounded,
                              color: Color(0xFFE53935)),
                          title: Text('Delete',
                              style: TextStyle(
                                  fontFamily: kFontFamily,
                                  color: Color(0xFFE53935),
                                  fontWeight: FontWeight.w600)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Dot matrix
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(3, (row) {
                    return Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: List.generate(5, (col) {
                        final i = row * 5 + col;
                        final isOverflowSlot =
                            i == 14 && itemCount > 15;
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
                                  size: 9,
                                  color: AppTheme.background),
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
              if (box.description != null) ...[
                const SizedBox(height: 4),
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
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '$itemCount item${itemCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accentBright,
                    ),
                  ),
                  if (labels.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Expanded(child: LabelPillsRow(labels: labels)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Box list tile (list view) ──────────────────────────────────────────────────

class _BoxListTile extends StatelessWidget {
  final Box box;
  final int itemCount;
  final int index;
  final int totalBoxes;
  final Set<ItemLabel> labels;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDeleteImmediate;

  const _BoxListTile({
    required this.box,
    required this.itemCount,
    required this.index,
    required this.totalBoxes,
    required this.labels,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onDeleteImmediate,
  });

  @override
  Widget build(BuildContext context) {
    final t = totalBoxes > 1 ? index / (totalBoxes - 1) : 0.0;
    final accentColor =
        Color.lerp(AppTheme.boksBlue, AppTheme.boksRed, t)!;
    final accentBright = Color.lerp(
        AppTheme.boksBlueBright, AppTheme.boksRedBright, t)!;

    return Slidable(
      key: ValueKey(box.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        dismissible: DismissiblePane(onDismissed: onDeleteImmediate),
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            icon: Icons.edit_rounded,
            label: 'Edit',
          ),
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: const Color(0xFFE53935),
            foregroundColor: Colors.white,
            icon: Icons.delete_rounded,
            label: 'Delete',
          ),
        ],
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AppTheme.bubblePurple, width: 1.5),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(19)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          box.name,
                          style: TextStyle(
                            fontFamily: kFontFamily,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                          ),
                        ),
                        if (box.description != null &&
                            box.description!.isNotEmpty) ...[
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
                        if (labels.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          LabelBadgesRow(labels: labels),
                        ],
                        const SizedBox(height: 3),
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
                Icon(Icons.chevron_right_rounded,
                    color: AppTheme.textMid, size: 20),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Stat chip ──────────────────────────────────────────────────────────────────

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
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

// ── Search result tile ─────────────────────────────────────────────────────────

class _ResultTile extends StatelessWidget {
  final Item item;
  final Box box;
  final String query;
  final int index;
  final bool loadAll;
  final VoidCallback onTap;

  const _ResultTile({
    required this.item,
    required this.box,
    required this.query,
    required this.index,
    required this.loadAll,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tile = GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: AppTheme.bubblePurple, width: 1.5),
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
                          size: 12,
                          color: AppTheme.textMid),
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
                      if (item.labels.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        LabelBadgesRow(
                            labels: item.labels.toSet()),
                      ],
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
    );
    if (loadAll) return tile;
    return tile
        .animate()
        .fadeIn(
            delay: Duration(milliseconds: 40 * index),
            duration: 200.ms)
        .slideX(begin: 0.05, end: 0);
  }
}

// ── Highlighted text ───────────────────────────────────────────────────────────

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
              backgroundColor:
                  highlightColor.withValues(alpha: 0.15),
            ),
          ),
          if (idx + query.length < text.length)
            TextSpan(text: text.substring(idx + query.length)),
        ],
      ),
    );
  }
}

// ── Import progress dialog ─────────────────────────────────────────────────────

class _ImportProgressDialog extends StatelessWidget {
  final ValueNotifier<(int, int)?> progress;
  const _ImportProgressDialog({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
        child: ValueListenableBuilder<(int, int)?>(
          valueListenable: progress,
          builder: (_, value, __) {
            final done = value?.$1 ?? 0;
            final total = value?.$2 ?? 0;
            final frac = total > 0 ? done / total : null;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.boksBlueLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.download_rounded,
                      color: AppTheme.boksBlue, size: 26),
                ),
                const SizedBox(height: 20),
                Text(
                  'Importing…',
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  total > 0
                      ? '$done of $total records'
                      : 'Please wait',
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontSize: 13,
                    color: AppTheme.textMid,
                  ),
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 8,
                    backgroundColor: AppTheme.boksBlueLight,
                    valueColor:
                        AlwaysStoppedAnimation(AppTheme.boksBlue),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

