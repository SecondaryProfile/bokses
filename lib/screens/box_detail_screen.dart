import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';
import '../models/box.dart';
import '../models/item.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/vision_service.dart';
import '../theme/app_theme.dart';
import '../constants.dart';

class BoxDetailScreen extends StatefulWidget {
  final Box box;
  const BoxDetailScreen({super.key, required this.box});

  @override
  State<BoxDetailScreen> createState() => _BoxDetailScreenState();
}

class _BoxDetailScreenState extends State<BoxDetailScreen> {
  List<Item> _items = [];
  bool _loading = true;
  final _picker = ImagePicker();
  String _docsDir = '';

  @override
  void initState() {
    super.initState();
    getApplicationDocumentsDirectory()
        .then((d) => _docsDir = d.path)
        .catchError((_) => '');
    _load();
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
                    _buildPhotoWidget(
                      _resolvePath(photoPath),
                      editable: true,
                      onTap: () async {
                        final path = await _capturePhoto();
                        if (path != null) setModal(() => photoPath = path);
                      },
                    ),
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
                  if (photoPath != null) ...[
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
                  const SizedBox(height: 24),
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
                  _buildPhotoWidget(
                    _resolvePath(photoPath),
                    editable: true,
                    onTap: () async {
                      final path = await _capturePhoto();
                      if (path != null) setModal(() => photoPath = path);
                    },
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
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        item.name = nameCtrl.text.trim();
                        item.photoPath = photoPath;
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
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.boksRed),
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

  Future<void> _startBoksTalk() async {
    final silenceMs = await SettingsService.getTalkSilenceMs();
    final readBack = await SettingsService.getTalkReadBack();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BoksTalkSheet(
        boxId: widget.box.id,
        onItemAdded: _load,
        silenceMs: silenceMs,
        readBack: readBack,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.box.name, overflow: TextOverflow.ellipsis),
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
          FloatingActionButton.extended(
            heroTag: 'bokstalk',
            onPressed: _startBoksTalk,
            backgroundColor: AppTheme.boksBlue,
            elevation: 2,
            icon: const Icon(Icons.mic_rounded, size: 20),
            label: const Text(
              'BoksTalk',
              style: TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w700),
            ),
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
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final item = _items[i];
        return _ItemCard(
          item: item,
          resolvedPhotoPath: _resolvePath(item.photoPath),
          index: i,
          onEdit: () => _showEditItemDialog(item),
          onDelete: () => _deleteItem(item),
          buildPhotoWidget: _buildPhotoWidget,
        )
            .animate()
            .fadeIn(delay: Duration(milliseconds: 50 * i), duration: 300.ms)
            .slideX(begin: 0.05, end: 0);
      },
    );
  }
}

// ── BoksTalk sheet ─────────────────────────────────────────────────────────────

enum _TalkState { initializing, listening, heard, speaking, submitting, error }

class BoksTalkSheet extends StatefulWidget {
  final String boxId;
  final Future<void> Function() onItemAdded;
  final int silenceMs;
  final bool readBack;

  const BoksTalkSheet({
    super.key,
    required this.boxId,
    required this.onItemAdded,
    required this.silenceMs,
    required this.readBack,
  });

  @override
  State<BoksTalkSheet> createState() => _BoksTalkSheetState();
}

class _BoksTalkSheetState extends State<BoksTalkSheet> {
  final _stt = SpeechToText();
  final _tts = FlutterTts();

  _TalkState _state = _TalkState.initializing;
  String _words = '';
  String _errorMsg = '';
  int _addedCount = 0;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _stt.cancel();
    _tts.stop();
    super.dispose();
  }

  Future<void> _init() async {
    bool available = false;
    try {
      available = await _stt
          .initialize(
            onError: (e) {
              if (mounted) {
                setState(() {
                  _state = _TalkState.error;
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
        _state = _TalkState.error;
        _errorMsg = kIsWeb
            ? 'Speech recognition requires Chrome or Edge on web'
            : 'Microphone not available';
      });
    }
  }

  Future<void> _startListening() async {
    if (!mounted || _processing) return;
    setState(() {
      _words = '';
      _state = _TalkState.listening;
    });

    try {
      await _stt.listen(
        onResult: (result) {
          if (!mounted || _processing) return;
          setState(() => _words = result.recognizedWords);
          if (result.finalResult) {
            _processing = true;
            _handleFinal(_words.trim());
          }
        },
        listenOptions: SpeechListenOptions(
          pauseFor: Duration(milliseconds: widget.silenceMs),
          listenFor: const Duration(seconds: 60),
          partialResults: true,
          cancelOnError: true,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _TalkState.error;
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

    if (widget.readBack) {
      setState(() => _state = _TalkState.speaking);
      try {
        await _tts.speak(text).timeout(const Duration(seconds: 8));
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _state = _TalkState.submitting);

    try {
      final item = Item(
        id: const Uuid().v4(),
        name: text,
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
      await Future.delayed(const Duration(milliseconds: 350));
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

          // Header row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.boksBlueLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    Icon(Icons.mic_rounded, color: AppTheme.boksBlue, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'BoksTalk',
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
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

          // Status indicator
          _buildStatus(),

          // Heard words
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

  Widget _buildStatus() {
    final (IconData icon, String label, Color color, bool pulse) =
        switch (_state) {
      _TalkState.initializing => (
          Icons.hourglass_top_rounded,
          'Starting…',
          AppTheme.textMid,
          false,
        ),
      _TalkState.listening => (
          Icons.mic_rounded,
          'Listening…',
          AppTheme.boksBlue,
          true,
        ),
      _TalkState.heard => (
          Icons.check_circle_rounded,
          'Got it!',
          AppTheme.boksBlue,
          false,
        ),
      _TalkState.speaking => (
          Icons.volume_up_rounded,
          'Reading back…',
          AppTheme.boksRed,
          true,
        ),
      _TalkState.submitting => (
          Icons.playlist_add_rounded,
          'Adding item…',
          AppTheme.boksRed,
          false,
        ),
      _TalkState.error => (
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
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Widget Function(String? path,
      {double height, bool editable, VoidCallback? onTap}) buildPhotoWidget;

  const _ItemCard({
    required this.item,
    required this.resolvedPhotoPath,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    required this.buildPhotoWidget,
  });

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  OverlayEntry? _overlayEntry;

  void _showPhotoOverlay() {
    final path = widget.resolvedPhotoPath;
    if (path == null || path.isEmpty) return;
    _overlayEntry = OverlayEntry(
      builder: (_) => GestureDetector(
        onLongPressEnd: (_) => _removeOverlay(),
        onLongPressCancel: _removeOverlay,
        child: Container(
          color: Colors.black87,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: kIsWeb ||
                        path.startsWith('http') ||
                        path.startsWith('blob:')
                    ? Image.network(path, fit: BoxFit.contain)
                    : path.startsWith('data:')
                        ? Image.memory(base64Decode(path.split(',').last),
                            fit: BoxFit.contain)
                        : Image.file(File(path), fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeOverlay();
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
        border: Border.all(color: AppTheme.bubblePurple, width: 1.5),
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
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      hasPhoto
                          ? Icons.camera_alt_rounded
                          : Icons.camera_alt_outlined,
                      size: 14,
                      color: hasPhoto ? AppTheme.boksBlue : AppTheme.textMid,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasPhoto ? 'Has photo' : 'No photo',
                      style: TextStyle(
                          fontFamily: kFontFamily,
                          fontSize: 12,
                          color: hasPhoto
                              ? AppTheme.boksBlue
                              : AppTheme.textMid),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded,
                color: AppTheme.textMid, size: 20),
            onSelected: (v) {
              if (v == 'edit') widget.onEdit();
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
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
