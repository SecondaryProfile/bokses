import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';
import '../models/box.dart';
import '../models/item.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../widgets/label_badges.dart';
import '../services/vision_service.dart';
import '../theme/app_theme.dart';
import '../constants.dart';

class BoxDetailScreen extends StatefulWidget {
  final Box box;
  final Color? accentColor;
  const BoxDetailScreen({super.key, required this.box, this.accentColor});

  @override
  State<BoxDetailScreen> createState() => _BoxDetailScreenState();
}

class _BoxDetailScreenState extends State<BoxDetailScreen> {
  List<Item> _items = [];
  bool _loading = true;
  bool _loadAll = true;
  final _picker = ImagePicker();
  String _docsDir = '';

  @override
  void initState() {
    super.initState();
    getApplicationDocumentsDirectory()
        .then((d) => _docsDir = d.path)
        .catchError((_) => '');
    _loadSettings();
    _load();
  }

  Future<void> _loadSettings() async {
    final loadAll = await SettingsService.getLoadAllContent();
    if (mounted) setState(() => _loadAll = loadAll);
  }

  String? _resolvePath(String? stored) {
    if (stored == null || stored.isEmpty) return null;
    if (stored.startsWith('data:') ||
        stored.startsWith('http') ||
        stored.startsWith('blob:') ||
        stored.startsWith('/')) {
      return stored;
    }
    if (_docsDir.isEmpty) return null;
    return '$_docsDir/$stored';
  }

  Future<void> _load() async {
    final items = await DatabaseService.instance.getItemsForBox(widget.box.id);
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  Future<String?> _capturePhoto() async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 800,
      );
      if (xfile == null) return null;
      final bytes = await xfile.readAsBytes();
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera unavailable: $e')),
        );
      }
      return null;
    }
  }

  Widget _buildPhotoWidget(String? path,
      {double height = 120, bool editable = false, VoidCallback? onTap}) {
    Widget inner;
    if (path != null && path.isNotEmpty) {
      Widget img;
      if (kIsWeb || path.startsWith('blob:') || path.startsWith('http')) {
        img = Image.network(path,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Center(
                child: Icon(Icons.broken_image_rounded,
                    color: AppTheme.textMid)));
      } else if (path.startsWith('data:')) {
        img = Image.memory(base64Decode(path.split(',').last),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Center(
                child: Icon(Icons.broken_image_rounded,
                    color: AppTheme.textMid)));
      } else {
        img = Image.file(File(path),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Center(
                child: Icon(Icons.broken_image_rounded,
                    color: AppTheme.textMid)));
      }
      inner = Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(19), child: img),
          if (editable)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration:
                    BoxDecoration(color: AppTheme.surface, shape: BoxShape.circle),
                child: Icon(Icons.camera_alt_rounded,
                    size: 18, color: AppTheme.boksBlue),
              ),
            ),
        ],
      );
    } else {
      inner = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.camera_alt_rounded, color: AppTheme.boksBlue, size: 36),
          const SizedBox(height: 8),
          Text(
            editable ? 'Tap to take photo' : 'No photo',
            style: TextStyle(
                fontFamily: kFontFamily,
                color: AppTheme.boksBlue,
                fontWeight: FontWeight.w700),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.boksBlueLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppTheme.boksBlue.withValues(alpha: 0.3), width: 1.5),
        ),
        child: inner,
      ),
    );
  }

  Future<void> _showAddItemDialog() async {
    final cvEnabled = await SettingsService.getCvEnabled();
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? photoPath;
    bool analyzing = false;
    List<String>? suggestions;
    List<ItemLabel> selectedLabels = [];

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
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
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Add Item',
                      style: TextStyle(
                          fontFamily: kFontFamily,
                          fontSize: 24,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 20),
                  if (!cvEnabled) ...[
                    TextFormField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration:
                          const InputDecoration(labelText: 'Item name *'),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 110,
                          child: _buildPhotoWidget(
                            _resolvePath(photoPath),
                            height: 110,
                            editable: true,
                            onTap: () async {
                              final path = await _capturePhoto();
                              if (path != null) setModal(() => photoPath = path);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _LabelPickerRow(
                            labels: selectedLabels,
                            onTap: () async {
                              final result =
                                  await showModalBottomSheet<List<ItemLabel>>(
                                context: ctx,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) =>
                                    LabelPickerSheet(initial: selectedLabels),
                              );
                              if (result != null) {
                                setModal(() => selectedLabels = result);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (photoPath != null) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => setModal(() => photoPath = null),
                        icon: Icon(Icons.close_rounded,
                            size: 18, color: AppTheme.boksRed),
                        label: Text('Remove photo',
                            style: TextStyle(
                                fontFamily: kFontFamily,
                                color: AppTheme.boksRed,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                  if (cvEnabled) ...[
                    _buildPhotoWidget(
                      _resolvePath(photoPath),
                      editable: true,
                      onTap: () async {
                        final path = await _capturePhoto();
                        if (path == null) return;
                        setModal(() {
                          photoPath = path;
                          suggestions = null;
                        });
                        setModal(() => analyzing = true);
                        try {
                          final guesses = await VisionService.identifyItem(
                            imagePath: _resolvePath(path) ?? path,
                          );
                          setModal(() {
                            analyzing = false;
                            suggestions = guesses;
                          });
                        } catch (e) {
                          setModal(() => analyzing = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                  content: Text('Could not identify item: $e')),
                            );
                          }
                        }
                      },
                    ),
                    if (analyzing) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.boksBlue),
                          ),
                          const SizedBox(width: 10),
                          Text('Identifying item…',
                              style: TextStyle(
                                  fontFamily: kFontFamily,
                                  fontSize: 13,
                                  color: AppTheme.textMid)),
                        ],
                      ),
                    ],
                    if (suggestions != null && suggestions!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text('SUGGESTIONS — tap to use',
                          style: TextStyle(
                              fontFamily: kFontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: AppTheme.textMid)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: suggestions!.map((guess) {
                          return GestureDetector(
                            onTap: () {
                              nameCtrl.text = guess;
                              setModal(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: AppTheme.boksBlueLight,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: AppTheme.boksBlue, width: 1.5),
                              ),
                              child: Text(guess,
                                  style: TextStyle(
                                    fontFamily: kFontFamily,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.boksBlueBright,
                                  )),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Item name *'),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name required'
                          : null,
                    ),
                  ],
                  if (cvEnabled && photoPath != null) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => setModal(() {
                        photoPath = null;
                        suggestions = null;
                      }),
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: AppTheme.boksRed),
                      label: Text('Remove photo',
                          style: TextStyle(
                              fontFamily: kFontFamily,
                              color: AppTheme.boksRed,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                  if (cvEnabled) ...[
                    const SizedBox(height: 12),
                    _LabelPickerRow(
                      labels: selectedLabels,
                      onTap: () async {
                        final result =
                            await showModalBottomSheet<List<ItemLabel>>(
                          context: ctx,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) =>
                              LabelPickerSheet(initial: selectedLabels),
                        );
                        if (result != null) {
                          setModal(() => selectedLabels = result);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final item = Item(
                          id: const Uuid().v4(),
                          name: nameCtrl.text.trim(),
                          photoPath: photoPath,
                          boxId: widget.box.id,
                          createdAt: DateTime.now(),
                          labels: selectedLabels,
                        );
                        await DatabaseService.instance.insertItem(item);
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _load();
                      },
                      child: const Text('Add Item'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditItemDialog(Item item) async {
    final nameCtrl = TextEditingController(text: item.name);
    final formKey = GlobalKey<FormState>();
    String? photoPath = item.photoPath;
    List<ItemLabel> selectedLabels = List.from(item.labels);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
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
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Edit Item',
                      style: TextStyle(
                          fontFamily: kFontFamily,
                          fontSize: 24,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Item name *'),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Name required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: _buildPhotoWidget(
                          _resolvePath(photoPath),
                          height: 110,
                          editable: true,
                          onTap: () async {
                            final path = await _capturePhoto();
                            if (path != null) setModal(() => photoPath = path);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _LabelPickerRow(
                          labels: selectedLabels,
                          onTap: () async {
                            final result =
                                await showModalBottomSheet<List<ItemLabel>>(
                              context: ctx,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) =>
                                  LabelPickerSheet(initial: selectedLabels),
                            );
                            if (result != null) {
                              setModal(() => selectedLabels = result);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (photoPath != null) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => setModal(() => photoPath = null),
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: AppTheme.boksRed),
                      label: Text('Remove photo',
                          style: TextStyle(
                              fontFamily: kFontFamily,
                              color: AppTheme.boksRed,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        item.name = nameCtrl.text.trim();
                        item.photoPath = photoPath;
                        item.labels = selectedLabels;
                        await DatabaseService.instance.updateItem(item);
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
      ),
    );
  }

  Future<void> _deleteItem(Item item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${item.name}"?',
            style: const TextStyle(
                fontFamily: kFontFamily, fontWeight: FontWeight.w800)),
        content: const Text('This item will be permanently removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseService.instance.deleteItem(item.id);
      _load();
    }
  }

  Future<void> _swipeDeleteItem(Item item) async {
    setState(() => _items.removeWhere((i) => i.id == item.id));
    await DatabaseService.instance.deleteItem(item.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('"${item.name}" removed'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await DatabaseService.instance.insertItem(item);
            if (mounted) await _load();
          },
        ),
      ));
  }

  Future<void> _startAutoBoks() async {
    final silenceMs = await SettingsService.getTalkSilenceMs();
    final readBack = await SettingsService.getTalkReadBack();
    final cameraEnabled = await SettingsService.getAutoBoksCameraEnabled();
    final usageCount = await SettingsService.getAutoBoksSuccessCount();
    if (!mounted) return;

    // Request camera permission while BoxDetailScreen is fully visible.
    // Android's system dialog cannot reliably interrupt a bottom sheet animation,
    // so this must happen before showModalBottomSheet is called.
    if (cameraEnabled && !kIsWeb) {
      try {
        final status = await Permission.camera.request();
        if (status.isPermanentlyDenied && mounted) {
          // ignore: use_build_context_synchronously
          final goSettings = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Camera Permission',
                  style: TextStyle(
                      fontFamily: kFontFamily, fontWeight: FontWeight.w800)),
              content: const Text(
                'Camera permission was denied. Open Settings to enable it, '
                'or disable Camera in AutoBoks settings to use mic-only mode.',
                style: TextStyle(fontFamily: kFontFamily),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Skip'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
          if (goSettings == true) openAppSettings();
          return;
        }
      } catch (_) {
        // permission_handler unavailable; let camera package surface the error.
      }
      if (!mounted) return;
    }

    if (usageCount < 10) {
      // ignore: use_build_context_synchronously
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => _AutoBoksIntroDialog(
            silenceMs: silenceMs, cameraEnabled: cameraEnabled),
      );
      if (confirmed != true || !mounted) return;
    }

    int addedInSession = 0;
    // ignore: use_build_context_synchronously
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AutoBoksSheet(
        boxId: widget.box.id,
        onItemAdded: () async {
          addedInSession++;
          await _load();
        },
        silenceMs: silenceMs,
        readBack: readBack,
        cameraEnabled: cameraEnabled,
      ),
    );

    if (addedInSession > 0) {
      await SettingsService.incrementAutoBoksSuccessCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.box.name, overflow: TextOverflow.ellipsis),
        bottom: (widget.box.description != null &&
                widget.box.description!.isNotEmpty)
            ? PreferredSize(
                preferredSize: const Size.fromHeight(26),
                child: Padding(
                  padding:
                      const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                  child: Text(
                    widget.box.description!,
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: 13,
                      color: AppTheme.textMid,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _emptyState()
              : _itemList(),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'autoboks',
            onPressed: _startAutoBoks,
            backgroundColor: AppTheme.boksBlue,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: CircleBorder(
              side: BorderSide(color: AppTheme.boksRed, width: 2.5),
            ),
            child: const Icon(Icons.mic_rounded, size: 22),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'additem',
            onPressed: _showAddItemDialog,
            backgroundColor: AppTheme.boksRed,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Item'),
          ),
        ],
      )
          .animate()
          .scale(delay: 200.ms, duration: 400.ms, curve: Curves.elasticOut),
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
              color: AppTheme.boksRedLight,
              borderRadius: BorderRadius.circular(32),
            ),
            child:
                Icon(Icons.category_outlined, size: 52, color: AppTheme.boksRed),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 28),
          const Text('Box is empty!',
                  style: TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: 26,
                      fontWeight: FontWeight.w800))
              .animate()
              .fadeIn(delay: 200.ms),
          const SizedBox(height: 8),
          Text(
            'Add items to keep track of\nwhat\'s inside.',
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

  Widget _itemList() {
    final itemBorderColor =
        (widget.accentColor ?? AppTheme.boksBlue).withValues(alpha: 0.5);
    return SlidableAutoCloseBehavior(
      child: ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final item = _items[i];
        final card = ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFBC02D),
                  Color(0xFFFBC02D),
                  Color(0xFF1976D2),
                  Color(0xFF1976D2),
                ],
                stops: [0.0, 0.39, 0.39, 1.0],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Slidable(
              key: ValueKey(item.id),
              startActionPane: ActionPane(
                motion: const DrawerMotion(),
                extentRatio: 0.28,
                children: [
                  SlidableAction(
                    onPressed: (_) => _showMoveItemDialog(item),
                    backgroundColor: const Color(0xFFFBC02D),
                    foregroundColor: Colors.black87,
                    icon: Icons.drive_file_move_rounded,
                    label: 'Move',
                  ),
                ],
              ),
              endActionPane: ActionPane(
                motion: const DrawerMotion(),
                extentRatio: 0.5,
                dismissible: DismissiblePane(
                    onDismissed: () => _swipeDeleteItem(item)),
                children: [
                  SlidableAction(
                    onPressed: (_) => _showEditItemDialog(item),
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    icon: Icons.edit_rounded,
                    label: 'Edit',
                  ),
                  SlidableAction(
                    onPressed: (_) => _deleteItem(item),
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    icon: Icons.delete_rounded,
                    label: 'Delete',
                  ),
                ],
              ),
              child: _ItemCard(
                item: item,
                resolvedPhotoPath: _resolvePath(item.photoPath),
                borderColor: itemBorderColor,
                index: i,
                onEdit: () => _showEditItemDialog(item),
                onDelete: () => _deleteItem(item),
                onMove: () => _showMoveItemDialog(item),
                buildPhotoWidget: _buildPhotoWidget,
              ),
            ),
          ),
        );
        if (_loadAll) return card;
        return card
            .animate()
            .fadeIn(
                delay: Duration(milliseconds: 50 * i), duration: 300.ms)
            .slideX(begin: 0.05, end: 0);
      },
    ),
    );
  }

  Future<void> _showMoveItemDialog(Item item) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 56),
        child: _MoveToBoxSheet(
          currentBoxId: widget.box.id,
          onMove: (targetBox) async {
            Navigator.of(ctx).pop();
            final moved = Item(
              id: item.id,
              name: item.name,
              photoPath: item.photoPath,
              boxId: targetBox.id,
              createdAt: item.createdAt,
              labels: List.from(item.labels),
            );
            await DatabaseService.instance.updateItem(moved);
            await _load();
            if (mounted) {
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(SnackBar(
                  content: Text('"${item.name}" moved to ${targetBox.name}'),
                  duration: const Duration(seconds: 3),
                ));
            }
          },
        ),
      ),
    );
  }
}

// ── AutoBoks sheet ─────────────────────────────────────────────────────────────

enum _AutoBoksState {
  initializing,
  listening,
  heard,
  capturing,
  speaking,
  submitting,
  error,
}

class AutoBoksSheet extends StatefulWidget {
  final String boxId;
  final Future<void> Function() onItemAdded;
  final int silenceMs;
  final bool readBack;
  final bool cameraEnabled;

  const AutoBoksSheet({
    super.key,
    required this.boxId,
    required this.onItemAdded,
    required this.silenceMs,
    required this.readBack,
    required this.cameraEnabled,
  });

  @override
  State<AutoBoksSheet> createState() => _AutoBoksSheetState();
}

class _AutoBoksSheetState extends State<AutoBoksSheet> {
  final _stt = SpeechToText();
  final _tts = FlutterTts();

  _AutoBoksState _state = _AutoBoksState.initializing;
  String _words = '';
  String _errorMsg = '';
  int _addedCount = 0;
  bool _processing = false;
  bool _speechDetected = false;
  Timer? _silenceTimer;

  CameraController? _cameraController;
  bool _cameraReady = false;
  String? _cameraError;
  bool _useFrontCamera = false;
  bool _switchingCamera = false;
  List<CameraDescription> _availableCameras = [];

  @override
  void initState() {
    super.initState();
    if (widget.cameraEnabled) _initCamera();
    _init();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _stt.cancel();
    _tts.stop();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initCamera({bool useFront = false}) async {
    try {
      final cameras = await availableCameras();
      if (mounted) setState(() => _availableCameras = cameras);
      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraError = 'No camera found');
        return;
      }
      final direction =
          useFront ? CameraLensDirection.front : CameraLensDirection.back;
      final target = cameras.firstWhere(
        (c) => c.lensDirection == direction,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        target,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      _cameraController = controller;
      setState(() => _cameraReady = true);
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _cameraError = e.description?.isNotEmpty == true
            ? e.description!
            : 'Camera error (${e.code})');
      }
    } catch (e) {
      if (mounted) setState(() => _cameraError = 'Camera error: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_switchingCamera || _processing) return;
    setState(() {
      _switchingCamera = true;
      _cameraReady = false;
      _useFrontCamera = !_useFrontCamera;
    });
    await _cameraController?.dispose();
    _cameraController = null;
    await _initCamera(useFront: _useFrontCamera);
    if (mounted) setState(() => _switchingCamera = false);
  }


  Future<void> _init() async {
    bool available = false;
    try {
      available = await _stt
          .initialize(
            onError: (e) {
              if (mounted) {
                setState(() {
                  _state = _AutoBoksState.error;
                  _errorMsg = e.errorMsg;
                });
              }
            },
          )
          .timeout(const Duration(seconds: 6), onTimeout: () => false);
    } catch (_) {}

    // TTS setup — awaitSpeakCompletion hangs on web, so skip it there
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      if (!kIsWeb) await _tts.awaitSpeakCompletion(true);
    } catch (_) {}

    if (!mounted) return;
    if (available) {
      _startListening();
    } else {
      setState(() {
        _state = _AutoBoksState.error;
        _errorMsg = kIsWeb
            ? 'Speech recognition requires Chrome or Edge on web'
            : 'Microphone not available';
      });
    }
  }

  Future<void> _startListening() async {
    if (!mounted || _processing) return;
    _speechDetected = false;
    _silenceTimer?.cancel();
    _silenceTimer = null;
    setState(() {
      _words = '';
      _state = _AutoBoksState.listening;
    });

    try {
      await _stt.listen(
        onResult: (result) {
          if (!mounted || _processing) return;
          setState(() => _words = result.recognizedWords);

          if (result.recognizedWords.trim().isNotEmpty) {
            // Speech started — (re)arm the silence timer on every partial update.
            _speechDetected = true;
            _silenceTimer?.cancel();
            _silenceTimer =
                Timer(Duration(milliseconds: widget.silenceMs), () {
              if (_processing || !mounted) return;
              _processing = true;
              _stt.stop();
              _handleFinal(_words.trim());
            });
          }

          // If the STT engine itself fires a final result (e.g. max listen
          // duration) only act on it when we already heard something.
          if (result.finalResult && _speechDetected && !_processing) {
            _silenceTimer?.cancel();
            _processing = true;
            _handleFinal(_words.trim());
          }
        },
        listenOptions: SpeechListenOptions(
          // Use a very long pauseFor — silence detection is handled manually
          // via _silenceTimer so the engine won't cut us off early.
          pauseFor: const Duration(seconds: 60),
          listenFor: const Duration(seconds: 60),
          partialResults: true,
          cancelOnError: true,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _AutoBoksState.error;
          _errorMsg = e.toString();
        });
      }
    }
  }

  void _handleFinal(String text) {
    if (!mounted) return;
    if (text.isEmpty) {
      _processing = false;
      _startListening();
      return;
    }
    Future.microtask(() => _submitItem(text));
  }

  Future<void> _submitItem(String text) async {
    if (!mounted) return;

    String? photoPath;

    if (widget.cameraEnabled && _cameraReady && _cameraController != null) {
      setState(() => _state = _AutoBoksState.capturing);
      HapticFeedback.heavyImpact();
      await Future.wait([
        () async {
          try { await _tts.speak('snap'); } catch (_) {}
        }(),
        () async {
          try {
            final xfile = await _cameraController!.takePicture();
            final bytes = await xfile.readAsBytes();
            photoPath = 'data:image/jpeg;base64,${base64Encode(bytes)}';
          } catch (_) {}
        }(),
      ]);
    }

    if (!mounted) return;

    if (widget.readBack) {
      setState(() => _state = _AutoBoksState.speaking);
      try {
        await _tts.speak(text).timeout(const Duration(seconds: 8));
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _state = _AutoBoksState.submitting);

    try {
      final item = Item(
        id: const Uuid().v4(),
        name: text,
        photoPath: photoPath,
        boxId: widget.boxId,
        createdAt: DateTime.now(),
      );
      await DatabaseService.instance.insertItem(item);
      await widget.onItemAdded();
      if (mounted) setState(() => _addedCount++);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not add item: $e')));
      }
    }

    _processing = false;
    if (mounted) {
      _silenceTimer?.cancel();
      try { await _stt.stop(); } catch (_) {}
      // Give the STT engine time to fully close before re-opening.
      await Future.delayed(const Duration(milliseconds: 500));
      _startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.bubblePurple,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),

          // Camera preview
          if (widget.cameraEnabled) ...[
            _buildCameraPreview(),
            const SizedBox(height: 20),
          ],

          // Header row
          Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                    children: [
                      TextSpan(
                        text: 'Auto',
                        style: TextStyle(color: AppTheme.boksBlue),
                      ),
                      TextSpan(
                        text: 'Boks',
                        style: TextStyle(color: AppTheme.boksRed),
                      ),
                    ],
                  ),
                ),
              ),
              if (_addedCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.boksBlueLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_addedCount added',
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.boksBlueBright,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),

          _buildStatus(),

          if (_words.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.boksBlueLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppTheme.boksBlue.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Text(
                '"$_words"',
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.boksBlueBright,
                ),
              ),
            ),
          ],

          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Stop Session'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textMid,
                side: BorderSide(color: AppTheme.bubblePurple, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraReady && _cameraController != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: CameraPreview(_cameraController!),
            ),
          ),
          if (_state == _AutoBoksState.capturing)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 200,
                width: double.infinity,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          if (_availableCameras.length > 1)
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: _switchingCamera ? null : _switchCamera,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _switchingCamera ? 0.4 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.flip_camera_ios_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }
    // Camera initialising or error placeholder
    final hasError = _cameraError != null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 200,
        width: double.infinity,
        color: AppTheme.cardBg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasError ? Icons.camera_alt_outlined : Icons.camera_alt_rounded,
              color: hasError ? AppTheme.boksRed : AppTheme.textMid,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              hasError ? _cameraError! : 'Starting camera…',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kFontFamily,
                fontSize: 13,
                color: hasError ? AppTheme.boksRed : AppTheme.textMid,
              ),
            ),
            if (hasError) ...[
              const SizedBox(height: 12),
              Text(
                'Items will be added without a photo',
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: 11,
                  color: AppTheme.textMid,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatus() {
    final (IconData icon, String label, Color color, bool pulse) =
        switch (_state) {
      _AutoBoksState.initializing => (
          Icons.hourglass_top_rounded,
          'Starting…',
          AppTheme.textMid,
          false,
        ),
      _AutoBoksState.listening => (
          Icons.mic_rounded,
          'Listening…',
          AppTheme.boksBlue,
          true,
        ),
      _AutoBoksState.heard => (
          Icons.check_circle_rounded,
          'Got it!',
          AppTheme.boksBlue,
          false,
        ),
      _AutoBoksState.capturing => (
          Icons.camera_rounded,
          'Capturing…',
          AppTheme.boksRed,
          false,
        ),
      _AutoBoksState.speaking => (
          Icons.volume_up_rounded,
          'Reading back…',
          AppTheme.boksRed,
          true,
        ),
      _AutoBoksState.submitting => (
          Icons.playlist_add_rounded,
          'Adding item…',
          AppTheme.boksRed,
          false,
        ),
      _AutoBoksState.error => (
          Icons.error_outline_rounded,
          _errorMsg.isNotEmpty ? _errorMsg : 'Microphone unavailable',
          AppTheme.boksRed,
          false,
        ),
    };

    Widget iconWidget = Icon(icon, size: 36, color: color);
    if (pulse) {
      iconWidget = iconWidget
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(end: 1.18, duration: 700.ms, curve: Curves.easeInOut)
          .fadeIn(begin: 0.6, duration: 700.ms);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        iconWidget,
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: kFontFamily,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Item card ──────────────────────────────────────────────────────────────────

class _ItemCard extends StatefulWidget {
  final Item item;
  final String? resolvedPhotoPath;
  final Color borderColor;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMove;
  final Widget Function(String? path,
      {double height, bool editable, VoidCallback? onTap}) buildPhotoWidget;

  const _ItemCard({
    required this.item,
    required this.resolvedPhotoPath,
    required this.borderColor,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    required this.onMove,
    required this.buildPhotoWidget,
  });

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  OverlayEntry? _overlayEntry;
  final _overlayKey = GlobalKey<_PhotoOverlayState>();

  void _showPhotoOverlay() {
    final path = widget.resolvedPhotoPath;
    if (path == null || path.isEmpty) return;
    _overlayEntry = OverlayEntry(
      builder: (_) => _PhotoOverlay(
        key: _overlayKey,
        path: path,
        onDismissed: _cleanupOverlay,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _cleanupOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _removeOverlay() {
    final state = _overlayKey.currentState;
    if (state != null) {
      state.dismiss();
    } else {
      _cleanupOverlay();
    }
  }

  @override
  void dispose() {
    _cleanupOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        widget.resolvedPhotoPath != null && widget.resolvedPhotoPath!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: widget.borderColor, width: 2.0),
      ),
      child: Row(
        children: [
          GestureDetector(
            onLongPressStart: (_) => _showPhotoOverlay(),
            onLongPressEnd: (_) => _removeOverlay(),
            onLongPressCancel: _removeOverlay,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(22)),
              child: SizedBox(
                width: 90,
                height: 90,
                child: hasPhoto
                    ? widget.buildPhotoWidget(widget.resolvedPhotoPath,
                        height: 90)
                    : Container(
                        color: AppTheme.cardBg,
                        child: Icon(Icons.image_not_supported_outlined,
                            color: AppTheme.textMid, size: 32),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.item.name,
                  style: TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark),
                ),
                if (widget.item.labels.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  LabelBadgesRow(labels: widget.item.labels.toSet()),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded,
                color: AppTheme.textMid, size: 20),
            onSelected: (v) {
              if (v == 'edit') widget.onEdit();
              if (v == 'move') widget.onMove();
              if (v == 'delete') widget.onDelete();
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
                value: 'move',
                child: ListTile(
                  leading: Icon(Icons.drive_file_move_rounded),
                  title: Text('Move to Box',
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
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ── AutoBoks intro dialog ──────────────────────────────────────────────────────

class _AutoBoksIntroDialog extends StatelessWidget {
  final int silenceMs;
  final bool cameraEnabled;
  const _AutoBoksIntroDialog(
      {required this.silenceMs, required this.cameraEnabled});

  @override
  Widget build(BuildContext context) {
    final seconds = (silenceMs / 1000).toStringAsFixed(1);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                children: [
                  TextSpan(
                      text: 'Auto',
                      style: TextStyle(color: AppTheme.boksBlue)),
                  TextSpan(
                      text: 'Boks',
                      style: TextStyle(color: AppTheme.boksRed)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (cameraEnabled) ...[
              const _AutoBoksStep(
                icon: Icons.camera_alt_rounded,
                text: 'Point the camera at the item and say its name',
              ),
              const SizedBox(height: 12),
              _AutoBoksStep(
                icon: Icons.notifications_active_rounded,
                text:
                    'After ${seconds}s of silence a ding sounds — keep the item in frame',
              ),
              const SizedBox(height: 12),
              const _AutoBoksStep(
                icon: Icons.photo_camera_rounded,
                text: 'Photo is captured automatically right after the ding',
              ),
              const SizedBox(height: 12),
              const _AutoBoksStep(
                icon: Icons.loop_rounded,
                text: 'Keeps going — point at the next item and speak',
              ),
            ] else ...[
              const _AutoBoksStep(
                icon: Icons.mic_rounded,
                text: 'Speak an item name clearly',
              ),
              const SizedBox(height: 12),
              _AutoBoksStep(
                icon: Icons.timer_rounded,
                text: "After ${seconds}s of silence it's added automatically",
              ),
              const SizedBox(height: 12),
              const _AutoBoksStep(
                icon: Icons.loop_rounded,
                text: 'Keeps listening — say as many items as you like',
              ),
            ],
            const SizedBox(height: 12),
            const _AutoBoksStep(
              icon: Icons.stop_circle_outlined,
              text: "Tap Stop Session when you're done",
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textMid,
                      side:
                          BorderSide(color: AppTheme.bubblePurple, width: 1.5),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Start'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AutoBoksStep extends StatelessWidget {
  final IconData icon;
  final String text;
  const _AutoBoksStep({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.boksBlueLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.boksBlue, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              text,
              style: TextStyle(
                fontFamily: kFontFamily,
                fontSize: 13,
                color: AppTheme.textMid,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Move-to-box sheet ──────────────────────────────────────────────────────────

class _MoveToBoxSheet extends StatefulWidget {
  final String currentBoxId;
  final Future<void> Function(Box) onMove;

  const _MoveToBoxSheet({
    required this.currentBoxId,
    required this.onMove,
  });

  @override
  State<_MoveToBoxSheet> createState() => _MoveToBoxSheetState();
}

class _MoveToBoxSheetState extends State<_MoveToBoxSheet> {
  List<Box> _boxes = [];
  Map<String, int> _counts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBoxes();
  }

  Future<void> _loadBoxes() async {
    final all = await DatabaseService.instance.getBoxes();
    final others = all.where((b) => b.id != widget.currentBoxId).toList();
    final counts = <String, int>{};
    for (final b in others) {
      counts[b.id] = await DatabaseService.instance.getItemCount(b.id);
    }
    if (mounted) {
      setState(() {
        _boxes = others;
        _counts = counts;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Move to Box',
            style: TextStyle(
              fontFamily: kFontFamily,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a destination',
            style: TextStyle(
              fontFamily: kFontFamily,
              fontSize: 13,
              color: AppTheme.textMid,
            ),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_boxes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No other boxes to move to.',
                  style: TextStyle(
                      fontFamily: kFontFamily, color: AppTheme.textMid),
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _boxes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final box = _boxes[i];
                  final count = _counts[box.id] ?? 0;
                  return InkWell(
                    onTap: () => widget.onMove(box),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppTheme.bubblePurple, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.boksBlueLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.inventory_2_rounded,
                                color: AppTheme.boksBlue, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  box.name,
                                  style: TextStyle(
                                    fontFamily: kFontFamily,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                Text(
                                  '$count item${count == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    fontFamily: kFontFamily,
                                    fontSize: 12,
                                    color: AppTheme.textMid,
                                  ),
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
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Label picker row (used in add/edit item dialogs) ────────────────────────────

class _LabelPickerRow extends StatelessWidget {
  final List<ItemLabel> labels;
  final VoidCallback onTap;

  const _LabelPickerRow({required this.labels, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (labels.isNotEmpty) ...[
          LabelBadgesRow(labels: labels.toSet()),
          const SizedBox(width: 8),
        ],
        TextButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.label_outline_rounded, size: 16),
          label:
              Text(labels.isEmpty ? 'Add Labels' : 'Edit Labels'),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.textMid,
            textStyle: const TextStyle(
              fontFamily: kFontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
          ),
        ),
      ],
    );
  }
}

// ── Photo overlay (animated long-press viewer) ─────────────────────────────────

class _PhotoOverlay extends StatefulWidget {
  final String path;
  final VoidCallback onDismissed;
  const _PhotoOverlay({super.key, required this.path, required this.onDismissed});

  @override
  State<_PhotoOverlay> createState() => _PhotoOverlayState();
}

class _PhotoOverlayState extends State<_PhotoOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  Uint8List? _bytes;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    final path = widget.path;
    if (path.startsWith('data:')) {
      _bytes = base64Decode(path.split(',').last);
    }
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> dismiss() async {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    _ctrl.duration = const Duration(milliseconds: 160);
    try {
      await _ctrl.reverse();
    } catch (_) {
      return;
    }
    widget.onDismissed();
  }

  Widget _buildImage() {
    final path = widget.path;
    if (kIsWeb || path.startsWith('http') || path.startsWith('blob:')) {
      return Image.network(path,
          fit: BoxFit.contain, filterQuality: FilterQuality.medium);
    } else if (_bytes != null) {
      return Image.memory(_bytes!,
          fit: BoxFit.contain, filterQuality: FilterQuality.medium);
    } else {
      return Image.file(File(path),
          fit: BoxFit.contain, filterQuality: FilterQuality.medium);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FadeTransition(
        opacity: _ctrl,
        child: ColoredBox(
          color: Colors.black,
          child: SizedBox.expand(
            child: Center(
              child: ScaleTransition(
                scale: _scale,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _buildImage(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
