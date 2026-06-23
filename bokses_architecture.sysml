// bokses_architecture.sysml
// Bokses v0.10 — Offline-First Storage Management App (Android)
// SysML v2 Architecture Model
// Generated from source: lib/models, lib/services, lib/screens, lib/theme, lib/widgets

// ─────────────────────────────────────────────────────────────────────────────
// 1. DOMAIN — Core data model
// ─────────────────────────────────────────────────────────────────────────────

package BoksesDomain {
    doc /* Core data entities. Box and Item are the only persistent domain
         objects. ItemLabel is the fixed classification vocabulary. No network
         types exist here — the model is 100% offline-first. */

    enum def ItemLabel {
        doc /* Classification badges attached to any Item. Multiple labels per
             item are allowed. Propagated up to the parent Box card/tile via
             DatabaseService.getAllBoxItemLabels(). */
        enum fragile;
        enum battery;
        enum liquid;
    }

    item def BoxRecord {
        doc /* A named physical storage container.
             'fragile' is a box-level flag (v0.8) distinct from the
             item-level ItemLabel::fragile badge (v0.8).
             Serialised as JSON via toMap()/fromMap()/toExportMap(). */
        attribute id          : String;   // UUID v4
        attribute name        : String;   // unique within the user's collection
        attribute description : String[0..1];
        attribute fragile     : Boolean;
        attribute createdAt   : String;   // ISO-8601 DateTime
    }

    item def ItemRecord {
        doc /* A single catalogued object stored inside a Box.
             photoPath is either an absolute fs path (on-device camera capture)
             or a data-URI (imported export, web fallback).
             Serialised as JSON via toMap()/fromMap()/toExportMap(). */
        attribute id        : String;
        attribute name      : String;
        attribute photoPath : String[0..1];  // fs path or data:image/...;base64,...
        attribute boxId     : String;        // FK → BoxRecord.id
        attribute createdAt : String;        // ISO-8601 DateTime
        attribute labels    : ItemLabel[0..*];
    }

    part def BoxContents {
        doc /* Logical aggregate: one Box owns zero-or-more Items.
             Cascade-delete is enforced by DatabaseService.deleteBox(). */
        part box   : BoxRecord;
        part items : ItemRecord[0..*];

        // Containment: items belong to exactly one box
        flow ItemRecord[0..*] from box to items;
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// 2. PERSISTENCE — Local storage and settings
// ─────────────────────────────────────────────────────────────────────────────

package BoksesPersistence {
    doc /* All reads and writes go through SharedPreferences. No SQLite, no
         remote database. DatabaseService serialises domain objects to JSON
         strings under two fixed keys. SettingsService holds every other
         preference as individual typed keys. Both services back onto the same
         PrefsStore instance. */

    import BoksesDomain::*;

    item def StorageKeys {
        doc /* Every SharedPreferences key used by the app. Centralised here
             so the full persistence contract is visible in one place. */
        attribute localBoxesKey      : String = 'local_boxes';
        attribute localItemsKey      : String = 'local_items';
        attribute isDarkModeKey      : String = 'is_dark_mode';
        attribute themePresetKey     : String = 'theme_preset';
        attribute cvEnabledKey       : String = 'cv_enabled';
        attribute talkSilenceMsKey   : String = 'talk_silence_ms';
        attribute talkReadBackKey    : String = 'talk_read_back';
        attribute autoBoksSuccessKey : String = 'autoboks_success_count';
        attribute autoBoksCameraKey  : String = 'autoboks_camera_enabled';
        attribute loadAllContentKey  : String = 'load_all_content';
        attribute bgTypeKey          : String = 'bg_type';
        attribute bgImageKey         : String = 'bg_image';  // data-URI
        attribute bgBlurKey          : String = 'bg_blur';
        attribute bgColorKey         : String = 'bg_color';  // ARGB int
    }

    // ── DatabaseService ───────────────────────────────────────────────────────

    part def DatabaseService {
        doc /* Singleton managing Box and Item CRUD. Upsert pattern: each write
             deserialises the full JSON list, modifies it, then re-serialises.
             Deleting a Box cascades to remove all child Items in one write. */

        // Backing store: SharedPreferencesStore (keys: local_boxes, local_items).
        // All CRUD reads and writes go through the platform SharedPreferences instance.

        // Boxes
        action insertBox {
            doc /* Upsert: removes any existing Box with the same id before appending. */
            in box : BoxRecord;
        }
        action getBoxes {
            doc /* Returns all boxes sorted ascending by createdAt. */
            out boxes : BoxRecord[0..*];
        }
        action updateBox {
            doc /* Alias for insertBox — replaces the box record in-place. */
            in box : BoxRecord;
        }
        action deleteBox {
            doc /* Cascades: removes all Items whose boxId matches, then removes the Box. */
            in id : String;
        }

        // Items
        action insertItem {
            doc /* Upsert: removes any existing Item with the same id before appending. */
            in item : ItemRecord;
        }
        action getItemsForBox {
            doc /* Returns items belonging to boxId, sorted ascending by createdAt. */
            in  boxId : String;
            out items : ItemRecord[0..*];
        }
        action getAllItems {
            doc /* Returns all items across all boxes, sorted ascending by createdAt. */
            out items : ItemRecord[0..*];
        }
        action updateItem {
            doc /* Alias for insertItem — replaces the item record in-place. */
            in item : ItemRecord;
        }
        action deleteItem {
            doc /* Removes the item with the given id. No cascade. */
            in id : String;
        }
        action getItemCount {
            doc /* Returns the count of items belonging to boxId. */
            in  boxId : String;
            out count : Integer;
        }

        // Cross-entity
        action searchItems {
            doc /* Case-insensitive name match. Minimum 3 chars. Returns
                 paired (Item, Box) results sorted by item name. */
            in  query   : String;
            out results : ItemRecord[0..*];
        }
        action getAllBoxItemLabels {
            doc /* Aggregates item labels per boxId. Used by HomeScreen to
                 show badges on box cards without loading all items. */
            out labelMap : ItemLabel[0..*];
        }
        action clearAll {
            doc /* Removes local_boxes and local_items keys. Irreversible. */
        }
    }

    // ── SettingsService ───────────────────────────────────────────────────────

    enum def AppBgType {
        doc /* Background display mode for the HomeScreen scaffold. */
        enum none;
        enum gradient; // linear lerp between theme primary and accent
        enum image;    // user-picked photo with optional blur sigma
        enum solid;    // single ARGB colour
    }

    part def SettingsService {
        doc /* Static service. Every setting is independently persisted.
             Defaults are hardcoded as fallback values in each getter — there
             is no defaults file or migration layer. */

        // Getter/setter pairs modelled as attributes; defaults shown inline.
        attribute isDarkMode            : Boolean;      // default: true
        attribute themePreset           : Integer;      // default: 0 (BoksOtter)
        attribute cvEnabled             : Boolean;      // default: false
        attribute talkSilenceMs         : Integer;      // default: 1500 ms
        attribute talkReadBack          : Boolean;      // default: false
        attribute autoBoksCameraEnabled : Boolean;      // default: true
        attribute autoBoksSuccessCount  : Integer;      // default: 0; gates intro dialog
        attribute loadAllContent        : Boolean;      // default: true (Instant Load)
        attribute backgroundType        : AppBgType;    // default: none
        attribute backgroundImage       : String[0..1]; // data-URI or null
        attribute backgroundBlur        : Real;         // default: 10.0
        attribute backgroundColor       : Integer;      // default: 0xFF0C0C0E (ARGB)

        action incrementAutoBoksSuccessCount {
            doc /* Atomically increments autoBoksSuccessCount after each successful
                 AutoBoks capture. Gates the first-use intro dialog display. */
        }
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// 3. COMPUTER VISION — On-device ML inference
// ─────────────────────────────────────────────────────────────────────────────

package BoksesCV {
    doc /* Entirely optional subsystem. Disabled by default; user enables in
         Settings and triggers a one-time model download (~3.5 MB). Once
         installed, inference runs 100% on-device via TFLite — no internet
         connection needed at capture time.
         Model: MobileNet V2 1.0 224 quant, 1000 ImageNet classes. */

    item def CVModelAsset {
        doc /* Describes the two artefact files in the app documents directory.
             Both must be present for VisionService to initialise the
             TFLite interpreter. */
        attribute modelFilename  : String = 'bokses_cv_model.tflite';
        attribute labelsFilename : String = 'bokses_cv_labels.txt';
        attribute displayName    : String = 'MobileNet V2';
        attribute sizeLabel      : String = '~3.5 MB';
        attribute labelCount     : Integer = 1000;
    }

    item def InferenceInput {
        doc /* Pre-processed input tensor passed into VisionService.identifyItem().
             Pixel data is resized to H×W read from the model's input shape[1,2]
             and packed as flat uint8 RGB (no normalisation — quantised model). */
        attribute imagePath  : String;   // fs path or data-URI
        attribute tensorH    : Integer;  // model input shape[1]
        attribute tensorW    : Integer;  // model input shape[2]
        attribute pixelBytes : Integer;  // H × W × 3
    }

    item def InferenceResult {
        doc /* Top-5 label strings from the output tensor, sorted descending by
             confidence score. Index 0 (background class) is always skipped. */
        attribute suggestions : String[0..5];
    }

    // ── Download state machine ────────────────────────────────────────────────

    state def ModelInstallState {
        doc /* Lifecycle of the optional CV model artefacts on-device.
             Model weight accounts for 95% of download progress; labels 5%.
             isCancelled is polled between HTTP chunks; partial files deleted
             on cancel or error. Binary validation guards against HTML 404 pages
             being saved as the .tflite file.
             Transitions:
               notInstalled → downloading  : startDownload
               downloading  → installed    : downloadComplete
               downloading  → notInstalled : cancelledOrFailed
               installed    → notInstalled : deleteModel */
        state notInstalled;
        state downloading;
        state installed;
    }

    // ── ModelService ──────────────────────────────────────────────────────────

    part def ModelService {
        doc /* Static service. Manages download, fs path resolution, binary
             validation, and deletion of the TFLite model + labels file. */

        // Tracks the current install lifecycle
        attribute installState : ModelInstallState;

        action isInstalled {
            doc /* True iff both .tflite and .txt files exist on disk. */
            out result : Boolean;
        }
        action installedModelPath {
            doc /* Returns the absolute fs path to the .tflite file, or null if not installed. */
            out path : String[0..1];
        }
        action installedLabelsPath {
            doc /* Returns the absolute fs path to the labels .txt file, or null if not installed. */
            out path : String[0..1];
        }
        action download {
            doc /* HTTP GET model then labels. Streams progress 0.0→1.0.
                 Throws on non-200; validates binary to reject HTML 404 pages. */
            in  isCancelled : Boolean[0..1];
            out progress    : Real;
        }
        action delete {
            doc /* Removes both artefact files; swallows all IO errors. */
        }
    }

    // ── VisionService ─────────────────────────────────────────────────────────

    part def VisionService {
        doc /* Static service wrapping the TFLite interpreter. Lazy-loads on
             first identifyItem() call; interpreter and labels are cached for
             the app lifetime. Call invalidate() when the model is replaced. */

        // Delegates path resolution and availability checks to ModelService
        part modelSvc : ModelService;

        // Internal: model file paths flow from modelSvc into the interpreter load
        flow String from modelSvc to modelSvc; // installedModelPath/installedLabelsPath
                                               // → Interpreter.fromFile + File.readAsString

        action isAvailable {
            doc /* Delegates to modelSvc.isInstalled(). */
            out available : Boolean;
        }
        action identifyItem {
            doc /* Full pipeline:
                 1. Decode image (file path or data-URI).
                 2. Resize to tensor H×W via the `image` package.
                 3. Pack flat uint8 RGB input buffer.
                 4. Allocate uint8 output buffer from output tensor shape.
                 5. Run interpreter.run(input, output).
                 6. Sort descending; skip index 0; return top-5 labels.
                 Throws if output is all-zero (model/image mismatch). */
            in  input   : InferenceInput;
            out results : InferenceResult;
        }
        action dispose {
            doc /* Closes interpreter; clears cached state. Also exposed as
                 invalidate() — same implementation. */
        }
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// 4. AUTOBOKS — Hands-free voice + camera capture mode
// ─────────────────────────────────────────────────────────────────────────────

package BoksesAuto {
    doc /* AutoBoks is the hands-free item-cataloguing mode (v0.8).
         The user speaks an item name; a configurable silence window fires a
         ding sound and triggers the rear camera simultaneously. The captured
         photo and recognised name create a new Item with no manual tapping.
         BoksTalk (v0.8) is obsolete — AutoBoks supersedes it entirely. */

    import BoksesDomain::ItemRecord;

    // ── External hardware boundaries ──────────────────────────────────────────

    part def MicrophoneHardware {
        doc /* Device microphone via the speech_to_text plugin.
             Requires RECORD_AUDIO permission (Android). Streams partial and
             final STT results to AutoBoksController.onSpeechResult(). */
        attribute permissionGranted : Boolean;
    }

    part def CameraHardware {
        doc /* Device camera via the `camera` plugin.
             A toggle button in the live preview switches facing direction.
             Requires CAMERA permission (Android). */
        attribute facing            : String;  // 'rear' (default) or 'front'
        attribute permissionGranted : Boolean;
    }

    part def TTSEngine {
        doc /* Text-to-speech via flutter_tts. Speaks the recognised item name
             after a successful capture. Enabled via SettingsService.getTalkReadBack().
             Only fires if readBackEnabled is true in the active AutoBoksConfig. */
    }

    // ── Session configuration ─────────────────────────────────────────────────

    item def AutoBoksConfig {
        doc /* Snapshot of all AutoBoks-relevant settings read from
             SettingsService at the moment startSession() is called. */
        attribute silenceWindowMs : Integer;  // getTalkSilenceMs() — default 1500
        attribute readBackEnabled : Boolean;  // getTalkReadBack()
        attribute cameraEnabled   : Boolean;  // getAutoBoksCameraEnabled()
        attribute targetBoxId     : String;   // box the session records into
    }

    item def AutoBoksCaptureEvent {
        doc /* Emitted when the silence window expires and both the snap sound
             and camera shutter fire. If cameraEnabled is false, photoPath is
             null and only the sound fires. */
        attribute recognisedName : String;
        attribute photoPath      : String[0..1];
        attribute capturedAt     : String;       // ISO-8601
    }

    // ── AutoBoks state machine ────────────────────────────────────────────────

    state def AutoBoksState {
        doc /* Full session lifecycle scoped to one BoxDetailScreen session.
             'silenceCancelled' re-enters listening when the user continues
             speaking before the silence window expires.
             Transitions:
               idle                  → requestingPermissions : startSession
               requestingPermissions → listening             : permissionsGranted
               requestingPermissions → error                 : permissionsDenied
               listening             → silenceCountdown      : speechDetected
               silenceCountdown      → listening             : silenceCancelled
               silenceCountdown      → capturing             : silenceWindowExpired
               capturing             → readingBack           : captureSucceeded
               capturing             → listening             : captureFailed
               readingBack           → listening             : readBackComplete
               listening             → idle                  : stopSession
               silenceCountdown      → idle                  : stopSession */
        state idle;
        state requestingPermissions;
        state listening;        // STT active, awaiting first word
        state silenceCountdown; // speech detected, timing the silence window
        state capturing;        // window expired — photo + sound fire together
        state readingBack;      // TTS speaking item name (if readBack enabled)
        state error;            // permission denied or STT unavailable
    }

    // ── AutoBoks controller ───────────────────────────────────────────────────

    part def AutoBoksController {
        doc /* Orchestrates the voice + camera capture pipeline inside
             BoxDetailScreen. Manages the STT stream, silence timer, camera
             controller, snap sound playback, and item persistence.
             SuccessCount in SettingsService gates the intro dialog — it is
             incremented here after each successful capture. */

        // Hardware sub-parts
        part mic    : MicrophoneHardware;
        part camera : CameraHardware;
        part tts    : TTSEngine;

        // Active session state (lifecycle defined by AutoBoksState state machine above)

        // Internal capture pipeline:
        // mic streams STT text → silence timer arms → camera fires (+ snap sound)
        // → AutoBoksCaptureEvent → ItemRecord persisted → tts reads back name
        flow String              from mic    to camera;  // recognised speech arms silence timer → triggers camera
        flow AutoBoksCaptureEvent from camera to tts;    // capture event feeds optional TTS readback

        action startSession {
            doc /* Reads AutoBoksConfig from SettingsService, requests hardware
                 permissions, initialises STT + camera controller. */
            in config : AutoBoksConfig;
        }
        action stopSession {
            doc /* Terminates the active STT stream, disposes the camera controller,
                 and resets state to idle. Safe to call from any active state. */
        }
        action onSpeechResult {
            doc /* Called on each STT partial/final result. Resets the silence
                 timer and updates the in-progress recognised text. */
            in text    : String;
            in isFinal : Boolean;
        }
        action fireSilenceCapture {
            doc /* Simultaneously plays the snap sound and triggers the camera.
                 Both fire in the same async frame — not sequentially. */
            in  recognisedName : String;
            out captureEvt     : AutoBoksCaptureEvent;
        }
        action persistCapturedItem {
            doc /* Creates an ItemRecord and calls DatabaseService.insertItem().
                 Then increments AutoBoksSuccessCount in SettingsService. */
            in captureEvt : AutoBoksCaptureEvent;
        }
        action toggleCamera {
            doc /* Switches facing direction in the live preview.
                 Persists via SettingsService.setAutoBoksCameraEnabled(). */
        }
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// 5. IMPORT/EXPORT — Data portability
// ─────────────────────────────────────────────────────────────────────────────

package BoksesImportExport {
    doc /* JSON-based data portability. Export embeds item photos as base64 so
         the backup file is fully self-contained. Import is split into two
         distinct steps (pick file → process) so the UI can show a progress
         dialog between them without blocking the picker. Schema version: 1.1. */

    import BoksesDomain::*;

    item def ExportPayload {
        doc /* Root JSON object of a Bokses export file.
             Filename format: bokses_export_YYYYMMDD_HHMMSS.json
             The 'app' field is validated on import to reject foreign files. */
        attribute version    : String = '1.1';
        attribute app        : String = 'Bokses';
        attribute exportedAt : String;
        attribute boxes      : BoxRecord[0..*];
        attribute items      : ExportedItem[0..*];
    }

    item def ExportedItem {
        doc /* ItemRecord extended with an optional photo payload.
             photoData (base64 JPEG, no prefix) is stripped from photoPath
             during export and re-injected as a data-URI on import. Omitted
             if the item has no photo. */
        attribute id        : String;
        attribute name      : String;
        attribute boxId     : String;
        attribute createdAt : String;
        attribute labels    : ItemLabel[0..*];
        attribute photoData : String[0..1];  // base64 JPEG body only
    }

    part def ImportExportService {
        doc /* Static service. Export destination is platform-conditional:
               Web     → triggerWebDownload (browser download API)
               Native  → FilePicker.saveFile if available; else temp file + share_plus
             Import always uses FilePicker (.json filter). */

        action buildExportPayload {
            doc /* Reads all boxes + items from DatabaseService. For each item
                 with a photoPath, base64-encodes the file bytes into photoData. */
            out payload : ExportPayload;
        }
        action exportData {
            doc /* Calls buildExportPayload, pretty-prints JSON (2-space indent),
                 then routes to the correct platform download mechanism. */
            in sharePositionOrigin : String[0..1]; // Rect for iPad share popover
        }
        action pickImportJson {
            doc /* Opens FilePicker for .json files. Returns raw JSON string or
                 null if cancelled. Step 1 of 2. */
            out jsonString : String[0..1];
        }
        action processImportJson {
            doc /* Parses ExportPayload; validates app=='Bokses'; upserts all
                 boxes and items via DatabaseService. Photos reconstructed as
                 data-URIs. Calls onProgress(done, total) after each record.
                 Step 2 of 2. */
            in  jsonString : String;
            out resultMsg  : String;   // 'Imported N box(es) and M item(s).'
        }
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// 6. THEME — Adaptive visual identity
// ─────────────────────────────────────────────────────────────────────────────

package BoksesTheme {
    doc /* AppTheme is a static singleton (no InheritedWidget or Provider).
         Theme changes broadcast through three ValueNotifiers that UI widgets
         subscribe to directly: modeNotifier, presetNotifier, bgNotifier. */

    item def ThemePreset {
        doc /* One colour scheme: a primary (boksBlue) and an accent (boksRed).
             The gradient UI lerps between them across cards and the title. */
        attribute name    : String;
        attribute primary : String;  // ARGB hex
        attribute accent  : String;  // ARGB hex
    }

    item def BuiltInPresets {
        doc /* All 8 shipped colour presets. Index 0 (BoksOtter) is the default. */
        attribute boksOtter      : ThemePreset; // #3A7BF7 / #E8394A
        attribute moonlightJelly : ThemePreset; // #5C6BC0 / #26C6DA
        attribute plantPond      : ThemePreset; // #27AE60 / #F4A223
        attribute ginger         : ThemePreset; // #FF6B35 / #9B59B6
        attribute sweetDevil     : ThemePreset; // #E91E8C / #00ACC1
        attribute sunsetPark     : ThemePreset; // #E53935 / #FFB300
        attribute creator        : ThemePreset; // #7C3AED / #10B981
        attribute robin          : ThemePreset; // #546E7A / #FF7043
    }

    item def AdaptivePalette {
        doc /* All colours derived from the active ThemePreset + brightness via
             lerp against dark/light neutral bases. Nothing in the UI is
             hardcoded except the destructive-red (#E53935) at call sites. */
        attribute background     : String;  // primary-tinted near-black or near-white
        attribute surface        : String;  // one step lighter than background
        attribute cardBg         : String;
        attribute textDark       : String;  // #E8EEF8 dark / #1A2240 light
        attribute textMid        : String;  // #7A90B8 dark / #5A6A8A light
        attribute bubblePurple   : String;  // tinted border colour
        attribute boksBlueLight  : String;
        attribute boksRedLight   : String;
        attribute boksBlueBright : String;
        attribute boksRedBright  : String;
    }

    part def AppTheme {
        doc /* Initialised in main() from SharedPreferences before runApp() so
             the first frame renders with the correct theme. Changes propagate
             through ValueNotifiers; BoksesApp and HomeScreen listen to them
             and call setState() to trigger rebuilds. */

        // Internal composition
        part presets     : BuiltInPresets;    // the 8 constant colour schemes
        part palette     : AdaptivePalette;   // derived colours for the active preset
        attribute activePreset : ThemePreset; // currently selected entry from presets
        attribute isDark       : Boolean;
        attribute presetIndex  : Integer;     // index into presets (0–7)

        // Preset selection drives palette derivation
        flow ThemePreset   from presets to palette;
        // Brightness toggle also re-derives the palette
        flow Boolean       from palette to palette; // dark flag re-computes all colours

        // Reactive broadcast channels (ValueNotifier<T>)
        attribute modeNotifier   : String;  // ValueNotifier<bool>
        attribute presetNotifier : String;  // ValueNotifier<int>
        attribute bgNotifier     : String;  // ValueNotifier<int> — increment-to-notify

        action setMode {
            doc /* Updates isDark and fires modeNotifier to trigger MaterialApp rebuild. */
            in dark : Boolean;
        }
        action setPreset {
            doc /* Clamps index to 0–7, updates activePreset, fires presetNotifier. */
            in index : Integer;
        }
        action notifyBgChanged {
            doc /* Increments bgNotifier value; HomeScreen _onBgChanged reloads background. */
        }
        action buildTheme {
            doc /* Constructs a full Material 3 ThemeData from the active preset
                 and brightness. Configures: AppBarTheme, ElevatedButtonTheme,
                 FloatingActionButtonTheme, InputDecorationTheme, CardTheme,
                 DialogTheme, PopupMenuTheme, SnackBarTheme. */
            in  dark  : Boolean;
            out theme : String;   // ThemeData (opaque Flutter type)
        }
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// 7. UI — Screens, navigation, and widget library
// ─────────────────────────────────────────────────────────────────────────────

package BoksesUI {
    doc /* Single-activity Flutter app. Navigation is imperative (Navigator.push).
         No routing library. All screens are StatefulWidgets that subscribe
         directly to AppTheme ValueNotifiers for theme-driven rebuilds. */

    import BoksesDomain::*;
    import BoksesPersistence::AppBgType;
    import BoksesTheme::AdaptivePalette;

    enum def BoxSort {
        doc /* Box list sort order. Controlled via the summary bar. */
        enum dateAsc;   // oldest first (default)
        enum dateDesc;
        enum nameAsc;   // A → Z
        enum nameDesc;  // Z → A
    }

    enum def BoxViewMode {
        doc /* Toggle between dot-matrix grid cards and swipeable list tiles. */
        enum grid;
        enum list;
    }

    // ── Navigation router ─────────────────────────────────────────────────────

    part def NavigationRouter {
        doc /* Imperative Navigator stack. SplashScreen is the initial route.
             BoxDetailScreen uses a custom Rect-based expand transition derived
             from the tapped card's screen coordinates (BoxOpenRoute).
             SearchScreen is not a separate route — it is an in-place mode
             within HomeScreen, modelled here as a peer for clarity. */

        part splash    : SplashScreen;
        part home      : HomeScreen;
        part search    : SearchScreen;    // in-place mode within HomeScreen
        part boxDetail : BoxDetailScreen;
        part settings  : SettingsScreen;
        part aboutScreen : AboutScreen;
        part history   : VersionHistoryScreen;

        // Navigation flows (screen transitions)
        flow BoxRecord from home      to boxDetail; // box passed on push
        flow BoxRecord from search    to boxDetail; // result tap navigates to box
    }

    // ── Screen: SplashScreen ─────────────────────────────────────────────────

    part def SplashScreen {
        doc /* Animated logo fade at cold start. No data loading. Navigates to
             HomeScreen on completion. Duration: ~600 ms. */
    }

    // ── Screen: HomeScreen ────────────────────────────────────────────────────

    part def HomeScreen {
        doc /* Root screen. Manages: box grid/list, inline search mode, summary
             bar (count chips, sort picker, view toggle), custom background
             rendering, and the New Box FAB. Background is a Stack underlay;
             the Scaffold is transparent when a custom background is active.
             Subscribes to modeNotifier, presetNotifier, and bgNotifier. */

        attribute boxes      : BoxRecord[0..*];
        attribute itemCounts : Integer[0..*];       // per-box, parallel to boxes
        attribute boxLabels  : ItemLabel[0..*];     // aggregated per-box labels
        attribute sort       : BoxSort;
        attribute viewMode   : BoxViewMode;
        attribute searching  : Boolean;
        attribute bgType     : AppBgType;

        // Widget composition
        part fab       : GradientFAB;
        part boxCards  : BoxCard[0..*];     // active when viewMode == grid
        part listTiles : BoxListTile[0..*]; // active when viewMode == list
        part labelRows : LabelBadgesRow[0..*];

        // Widget data flows
        flow BoxRecord  from boxCards  to boxCards;   // box data populates each card
        flow BoxRecord  from listTiles to listTiles;  // box data populates each tile
        flow ItemLabel[0..*] from labelRows to labelRows;

        action load {
            doc /* Reads boxes, per-box item counts, per-box label aggregates,
                 and the loadAll performance setting from their respective services. */
        }
        action loadBackground {
            doc /* Reads background type, photo data-URI, blur sigma, and solid
                 colour from SettingsService; decodes photo bytes if present. */
        }
        action showAddBoxDialog {
            doc /* Opens a modal bottom sheet with name + description fields. Validates uniqueness. */
        }
        action showEditBoxDialog {
            doc /* Opens edit sheet pre-populated with the box's current name and description. */
            in box : BoxRecord;
        }
        action deleteBox {
            doc /* Removes the box immediately, shows undo snackbar for 2500 ms. */
            in box : BoxRecord;
        }
        action doExport {
            doc /* Calls ImportExportService.exportData(); shows success or error snackbar. */
        }
        action doImport {
            doc /* Two-phase: pickImportJson → show progress dialog → processImportJson. */
        }
        action doClearAll {
            doc /* Shows confirmation AlertDialog before calling DatabaseService.clearAll(). */
        }
        action runSearch {
            doc /* Delegates to DatabaseService.searchItems(); updates _searchResults state. */
            in  query   : String;
            out results : ItemRecord[0..*];
        }
    }

    // ── Screen: SearchScreen (in-place mode) ──────────────────────────────────

    part def SearchScreen {
        doc /* Inline search within HomeScreen. Not a separate Navigator route.
             Minimum query length: 3 characters. Results show item name with
             highlighted match substring, parent box name, and item labels.
             Implemented entirely within HomeScreen's StatefulWidget state. */

        attribute query   : String;
        attribute results : ItemRecord[0..*];
    }

    // ── Screen: BoxDetailScreen ───────────────────────────────────────────────

    part def BoxDetailScreen {
        doc /* Shows all items in a single box. Hosts the AutoBoks session,
             image_picker photo capture, item add/edit dialogs, Slidable swipe
             actions (edit / delete / move), and the Move to Box popup.
             Item card borders inherit the gradient accent colour passed from
             HomeScreen based on the box's position in the sorted list. */

        attribute box    : BoxRecord;
        attribute items  : ItemRecord[0..*];
        attribute accent : String;            // interpolated Color from HomeScreen

        // Widget composition
        part labelBadges : LabelBadgesRow;    // shown per item and in appbar

        // Label data populates badge widget
        flow ItemLabel[0..*] from labelBadges to labelBadges;

        action load {
            doc /* Reads all items for the box from DatabaseService and updates _items state. */
        }
        action capturePhoto {
            doc /* Opens ImagePicker for camera; saves file to documents dir; returns path or null. */
            out photoPath : String[0..1];
        }
        action showAddItemDialog {
            doc /* Opens add-item bottom sheet; validates name; persists via DatabaseService. */
        }
        action showEditItemDialog {
            doc /* Opens edit-item bottom sheet pre-populated with the item's name and labels. */
            in item : ItemRecord;
        }
        action deleteItem {
            doc /* Removes the item immediately; shows undo snackbar; restores on Undo tap. */
            in item : ItemRecord;
        }
        action moveItemToBox {
            doc /* Updates item.boxId and calls DatabaseService.updateItem(); triggers reload. */
            in item        : ItemRecord;
            in targetBoxId : String;
        }
        action startAutoBoks {
            doc /* Checks permissions then delegates to AutoBoksController.startSession(). */
        }
        action stopAutoBoks {
            doc /* Delegates to AutoBoksController.stopSession() and clears the live preview. */
        }
    }

    // ── Screen: SettingsScreen ────────────────────────────────────────────────

    part def SettingsScreen {
        doc /* Grouped settings UI:
               Appearance   — dark/light toggle + 8 colour preset chips
               Background   — none / gradient / photo (blur slider) / solid
               AutoBoks     — silence window slider, read-back toggle, camera toggle
               CV Model     — enable toggle, download/delete button + progress bar
               Performance  — Instant Load toggle
               App Info     — version string + link to VersionHistoryScreen */

        attribute isDark           : Boolean;
        attribute presetIndex      : Integer;
        attribute bgType           : AppBgType;
        attribute cvEnabled        : Boolean;
        attribute modelInstalled   : Boolean;
        attribute downloading      : Boolean;
        attribute downloadProgress : Real;     // 0.0 → 1.0
        attribute loadAll          : Boolean;
    }

    // ── Screen: AboutScreen ───────────────────────────────────────────────────

    part def AboutScreen {
        doc /* Static informational screen: app name, version, description.
             Accessed from the HomeScreen overflow menu. */
    }

    // ── Screen: VersionHistoryScreen ─────────────────────────────────────────

    part def VersionHistoryScreen {
        doc /* Scrollable changelog derived from kChangelog in constants.dart.
             Each entry: version number, date, bulleted change list. */
    }

    // ── Shared widget library ─────────────────────────────────────────────────

    part def LabelBadgesRow {
        doc /* Inline row of label badges. Two visual variants:
               LabelBadgesRow  — square icon chips (list tiles, box detail)
               LabelPillsRow   — text pills (grid cards)
             Both consume the same ItemLabel set. */
        attribute labels : ItemLabel[0..*];
    }

    part def BoxCard {
        doc /* Grid view card. Dot-matrix of 15 slots visualises item count; slot
             15 shows '+' overflow. Border and name colour lerp from boksBlue
             to boksRed based on the card's index in the sorted list. */
        attribute box         : BoxRecord;
        attribute itemCount   : Integer;
        attribute labels      : ItemLabel[0..*];
        attribute accentColor : String;   // lerped gradient position

        // Label badges shown at card bottom
        part badges : LabelBadgesRow;
        flow ItemLabel[0..*] from badges to badges;
    }

    part def BoxListTile {
        doc /* List view tile with Slidable swipe actions (DrawerMotion).
             Short swipe reveals Edit + Delete; full swipe is a dismissible
             that triggers immediate delete with undo snackbar. Left accent
             bar colour matches the grid card gradient position. */
        attribute box         : BoxRecord;
        attribute itemCount   : Integer;
        attribute labels      : ItemLabel[0..*];
        attribute accentColor : String;

        // Label badges shown in tile body
        part badges : LabelBadgesRow;
        flow ItemLabel[0..*] from badges to badges;
    }

    part def GradientFAB {
        doc /* "New Box" floating action button. Blue→Red linear gradient fill.
             Animates in with elastic scale (300 ms delay, 400 ms duration).
             Hidden during search mode. */
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// 8. SYSTEM — Top-level composition and all cross-subsystem flows
// ─────────────────────────────────────────────────────────────────────────────

package BoksesSystem {
    doc /* Composes all subsystems into a single BoksesApp block and defines
         every cross-subsystem data flow. All flows are declared inside BoksesApp
         so their source and target parts are unambiguous. Network access is
         limited to the one-time CV model download; everything else is offline. */

    import BoksesDomain::*;
    import BoksesPersistence::*;
    import BoksesCV::*;
    import BoksesAuto::*;
    import BoksesImportExport::*;
    import BoksesTheme::*;
    import BoksesUI::*;

    // ── External interfaces (device / OS boundary) ────────────────────────────

    part def FileSystem {
        doc /* Device file system (app documents + temp directories).
               Documents dir — TFLite model, labels file, captured photos
               Temp dir      — export JSON before share sheet hand-off
             No cloud sync. Paths are absolute strings resolved via path_provider. */
    }

    part def NetworkInterface {
        doc /* Internet access used only for the one-time CV model download.
             Both URLs point to the google-coral GitHub test_data repo.
             All other operations function in airplane mode. */
        attribute modelSourceUrl  : String; // MobileNet V2 .tflite
        attribute labelsSourceUrl : String; // ImageNet labels .txt
    }

    part def PlatformPermissions {
        doc /* Android runtime permissions requested by the app:
               CAMERA       — BoxDetailScreen photo capture + AutoBoks live preview
               RECORD_AUDIO — AutoBoks STT
               Storage      — implicit via FilePicker for export/import
             Grants are checked before each relevant session; results flow to
             the requesting subsystem. */
        attribute camera      : Boolean;
        attribute recordAudio : Boolean;
    }

    part def PrefsStore {
        doc /* Android SharedPreferences XML file at
             /data/data/com.example.bokses/shared_prefs/FlutterSharedPreferences.xml.
             Holds the entire app dataset. No migration layer — schema changes
             require manual key renaming (see StorageKeys). */
        part keys : StorageKeys;  // catalogue of all used preference keys
    }

    // ── Top-level system block ────────────────────────────────────────────────

    part def BoksesApp {
        doc /* Root Flutter application. main() reads dark-mode and theme-preset
             from SharedPreferences before runApp() so the first frame renders
             with the correct theme. All services are singletons or static classes.
             The startup sequence is:
               SharedPreferences.getInstance()
               → SettingsService.getIsDarkMode() + getThemePreset()
               → AppTheme.setMode() + setPreset()
               → runApp(BoksesApp) */

        // ── Subsystem parts ───────────────────────────────────────────────────
        part domain   : BoxContents[0..*];      // in-memory domain aggregate
        part db       : DatabaseService;
        part settings : SettingsService;
        part cv       : VisionService;
        part modelMgr : ModelService;
        part autoBoks : AutoBoksController;
        part io       : ImportExportService;
        part theme    : AppTheme;
        part ui       : NavigationRouter;

        // ── Device interface parts ────────────────────────────────────────────
        part fs          : FileSystem;
        part net         : NetworkInterface;
        part permissions : PlatformPermissions;
        part prefs       : PrefsStore;

        // ═════════════════════════════════════════════════════════════════════
        // CROSS-SUBSYSTEM DATA FLOWS
        // ═════════════════════════════════════════════════════════════════════

        // ── Persistence backing store ─────────────────────────────────────────
        // Both DatabaseService and SettingsService read/write the same platform store.
        flow String from db       to prefs;    // serialised JSON written to local_boxes / local_items
        flow String from prefs    to db;       // JSON read back on every CRUD operation
        flow String from settings to prefs;    // individual preference values written
        flow String from prefs    to settings; // individual preference values read

        // ── Startup: settings seed the theme before first frame ───────────────
        flow Boolean from settings to theme;   // getIsDarkMode() → AppTheme.setMode()
        flow Integer from settings to theme;   // getThemePreset() → AppTheme.setPreset()

        // ── Theme broadcasts drive all screen rebuilds ────────────────────────
        flow AdaptivePalette from theme to ui; // ValueNotifier subscriptions in each screen

        // ── Domain aggregate populated from database ──────────────────────────
        flow domainBoxes : BoxRecord[0..*]  from db to domain; // in-memory box list
        flow domainItems : ItemRecord[0..*] from db to domain; // in-memory item list per box

        // ── UI ↔ DatabaseService (all CRUD operations) ────────────────────────
        flow uiBoxList   : BoxRecord[0..*]  from db to ui;     // getBoxes() → HomeScreen box list
        flow uiItemList  : ItemRecord[0..*] from db to ui;     // getItemsForBox() → BoxDetailScreen
        flow uiLabelMap  : ItemLabel[0..*]  from db to ui;     // getAllBoxItemLabels() → badge aggregation
        flow persistBox  : BoxRecord        from ui to db;     // insertBox / updateBox / deleteBox
        flow persistItem : ItemRecord       from ui to db;     // insertItem / updateItem / deleteItem

        // ── UI ↔ SettingsService (screen reads and writes) ────────────────────
        flow AppBgType from settings to ui;      // background type → HomeScreen rendering
        flow Boolean   from settings to ui;      // loadAll, cvEnabled, readBack, etc.
        flow Integer   from settings to ui;      // silenceMs, presetIndex, successCount
        flow Boolean   from ui       to settings; // dark mode, readBack, camera toggle writes
        flow Integer   from ui       to settings; // preset index, silence ms writes
        flow AppBgType from ui       to settings; // background type write

        // ── UI → FileSystem (photo capture and display) ───────────────────────
        flow capturedPhoto  : ItemRecord from ui to fs; // photo captured by BoxDetailScreen → written to docs dir
        flow resolvedPhoto  : ItemRecord from fs to ui; // photo path resolved → image bytes displayed

        // ── UI → PlatformPermissions (permission requests) ────────────────────
        flow String  from ui          to permissions; // CAMERA / RECORD_AUDIO requests
        flow Boolean from permissions to ui;          // grant results back to BoxDetailScreen

        // ── AutoBoks ↔ Settings (config in, success count out) ────────────────
        flow AutoBoksConfig from settings to autoBoks; // session config snapshot at startSession()
        flow Integer        from autoBoks to settings; // incrementAutoBoksSuccessCount after capture

        // ── AutoBoks → PlatformPermissions (hardware access) ──────────────────
        flow Boolean from permissions to autoBoks; // CAMERA + RECORD_AUDIO grant results
        flow String  from autoBoks    to permissions; // permission requests from session start

        // ── AutoBoks → DatabaseService (item persistence) ─────────────────────
        flow captureEvent : AutoBoksCaptureEvent from autoBoks to db; // capture event contains ItemRecord data
        flow capturedItem : ItemRecord           from autoBoks to db; // persistCapturedItem → insertItem()

        // ── CV model lifecycle: network → manager → file system → interpreter ─
        flow CVModelAsset from net      to modelMgr; // HTTP download (model 95% + labels 5%)
        flow CVModelAsset from modelMgr to fs;       // artefacts written to documents dir
        flow CVModelAsset from fs       to cv;       // VisionService loads interpreter from file

        // ── ModelService → VisionService (path delegation) ────────────────────
        // VisionService.isAvailable() delegates to ModelService.isInstalled().
        // VisionService._load() calls installedModelPath() + installedLabelsPath().
        flow String  from modelMgr to cv;           // resolved fs paths for model + labels files

        // ── Settings → ModelService (CV feature gate) ─────────────────────────
        flow Boolean from settings to modelMgr;     // cvEnabled flag gates download availability

        // ── UI → ModelService (download trigger and progress feedback) ─────────
        flow Boolean from ui       to modelMgr;     // SettingsScreen triggers download / delete
        flow Real    from modelMgr to ui;           // downloadProgress 0.0→1.0 → progress bar

        // ── CV → UI (inference suggestions) ───────────────────────────────────
        flow InferenceInput  from ui to cv;         // image path sent when CV enabled + photo taken
        flow InferenceResult from cv to ui;         // top-5 label suggestions → item name field

        // ── Import/Export ↔ DatabaseService (full dataset) ────────────────────
        flow ExportPayload   from db to io;          // buildExportPayload reads all boxes + items
        flow importedBoxes : BoxRecord[0..*]  from io to db; // processImportJson upserts boxes
        flow importedItems : ItemRecord[0..*] from io to db; // processImportJson upserts items

        // ── Import/Export ↔ FileSystem (file I/O) ────────────────────────────
        flow ExportPayload from io to fs;            // export JSON written to temp dir or save dialog
        flow String        from fs to io;            // import: FilePicker result JSON read from fs
    }

    // Root system instantiation — satisfies unused-definition for BoksesApp.
    part boksesApp : BoksesApp;
}


// ─────────────────────────────────────────────────────────────────────────────
// 9. SYSTEM REQUIREMENTS — Formal requirements derived from the Flutter test suite
// ─────────────────────────────────────────────────────────────────────────────

package System_Requirements {
    doc /* Each requirement def is traced to a specific Flutter test group and
         case in test/widget_test.dart (unit, widget, or E2E layer) via a
         paired verification def. Requirements with no current test coverage are
         marked coverageStatus = 'pending' so the gap is visible in the model.
         Test helper: test/helpers/fake_database_service.dart provides the
         in-memory DatabaseService override used across all unit tests. */

    import BoksesDomain::*;
    import BoksesPersistence::*;
    import BoksesCV::*;
    import BoksesAuto::*;
    import BoksesImportExport::*;
    import BoksesTheme::*;
    import BoksesUI::*;

    // ═════════════════════════════════════════════════════════════════════════
    // DOMAIN MODEL — BoxRecord serialization
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_BOX_SERIALIZATION {
        doc /* BoxRecord round-trip serialisation integrity via toMap/fromMap and toExportMap. */
        id   = 'REQ-BOX-001';
        text = 'BoxRecord shall round-trip losslessly through toMap() and fromMap(), '
             + 'preserving id, name, description (including null), fragile, and createdAt. '
             + 'toExportMap() shall include at minimum id, name, and createdAt keys.';
    }

    part def VER_BOX_SERIALIZATION {
        doc /* Verified by unit tests in the "Box model" group.
             Covers: full field round-trip, null description survival, and
             presence of required fields in the export map. */
        // verifies REQ_BOX_SERIALIZATION;
        attribute testFile   : String = 'test/widget_test.dart';
        attribute testGroup  : String = 'Box model';
        attribute testCases  : String = 'round-trips through toMap / fromMap'
                             + ', null description survives round-trip'
                             + ', toExportMap contains required fields';
        attribute coverageStatus : String = 'covered';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // DOMAIN MODEL — ItemRecord serialization
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_ITEM_SERIALIZATION {
        doc /* ItemRecord round-trip serialisation including labels, null photoPath, and toExportMap contract. */
        id   = 'REQ-ITEM-001';
        text = 'ItemRecord shall round-trip losslessly through toMap() and fromMap(), '
             + 'preserving id, name, photoPath (including null), boxId, and createdAt. '
             + 'toExportMap() shall omit photoPath and include the labels list. '
             + 'Unknown label strings encountered in fromMap() shall be silently dropped '
             + 'without throwing. Empty labels lists shall survive the round-trip.';
    }

    part def VER_ITEM_SERIALIZATION {
        doc /* Verified by the "Item model" and "Item model — labels" unit groups.
             The labels group specifically covers the label enum round-trip,
             silent dropping of unknown label strings, toExportMap inclusion of
             labels, and empty-list survival. */
        // verifies REQ_ITEM_SERIALIZATION;
        attribute testFile   : String = 'test/widget_test.dart';
        attribute testGroups : String = 'Item model, Item model — labels';
        attribute testCases  : String = 'round-trips through toMap / fromMap'
                             + ', null photoPath survives round-trip'
                             + ', toExportMap omits photoPath'
                             + ', labels round-trip through toMap/fromMap'
                             + ', unknown label in fromMap is silently dropped'
                             + ', toExportMap includes labels'
                             + ', empty labels survive round-trip';
        attribute coverageStatus : String = 'covered';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // PERSISTENCE — DatabaseService box CRUD
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_DB_BOX_CRUD {
        doc /* DatabaseService Box CRUD operations including upsert, createdAt sort, and cascade delete. */
        id   = 'REQ-DB-001';
        text = 'DatabaseService shall support inserting a Box, returning all Boxes sorted '
             + 'ascending by createdAt, upserting on duplicate id, updating mutable fields, '
             + 'and deleting a Box by id. Deleting a Box shall cascade-delete all Items '
             + 'whose boxId matches. All operations shall be idempotent with respect to '
             + 'the backing store.';
    }

    part def VER_DB_BOX_CRUD {
        doc /* Verified against FakeDatabaseService (test/helpers/fake_database_service.dart),
             which overrides all DatabaseService methods with in-memory list operations.
             The cascade-delete test explicitly inserts an item before deleting the
             parent box and asserts getAllItems() is empty afterwards. */
        // verifies REQ_DB_BOX_CRUD;
        attribute testFile   : String = 'test/widget_test.dart';
        attribute helperFile : String = 'test/helpers/fake_database_service.dart';
        attribute testGroup  : String = 'FakeDatabaseService — boxes';
        attribute testCases  : String = 'insertBox adds a box'
                             + ', getBoxes returns sorted by createdAt'
                             + ', insertBox upserts on same id'
                             + ', updateBox changes name'
                             + ', deleteBox removes box'
                             + ', deleteBox cascades items';
        attribute coverageStatus : String = 'covered';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // PERSISTENCE — DatabaseService item CRUD
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_DB_ITEM_CRUD {
        doc /* DatabaseService Item CRUD operations including box-scoped filtering, counts, and clearAll. */
        id   = 'REQ-DB-002';
        text = 'DatabaseService shall support inserting an Item, returning Items for a '
             + 'specific boxId (sorted ascending by createdAt, filtered to that box only), '
             + 'returning all Items across all boxes, updating mutable Item fields, '
             + 'deleting an Item by id, returning the count of Items for a given boxId, '
             + 'and clearing all boxes and items in a single operation.';
    }

    part def VER_DB_ITEM_CRUD {
        doc /* Verified against FakeDatabaseService. The filter test inserts items
             into two different boxes and asserts getItemsForBox returns only items
             belonging to the requested box. */
        // verifies REQ_DB_ITEM_CRUD;
        attribute testFile   : String = 'test/widget_test.dart';
        attribute helperFile : String = 'test/helpers/fake_database_service.dart';
        attribute testGroup  : String = 'FakeDatabaseService — items';
        attribute testCases  : String = 'insertItem adds an item'
                             + ', getItemsForBox filters by box'
                             + ', getAllItems returns all'
                             + ', updateItem saves changes'
                             + ', deleteItem removes item'
                             + ', getItemCount returns correct count'
                             + ', clearAll removes everything';
        attribute coverageStatus : String = 'covered';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // PERSISTENCE — DatabaseService item search
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_DB_SEARCH {
        doc /* DatabaseService item search: 3-char minimum guard, case-insensitive match, alphabetical results with parent box. */
        id   = 'REQ-DB-003';
        text = 'DatabaseService.searchItems() shall return an empty list for queries '
             + 'shorter than 3 characters. For qualifying queries it shall perform a '
             + 'case-insensitive substring match on Item.name, return each matching '
             + 'Item paired with its parent Box, sort results alphabetically by item '
             + 'name, and return an empty list when no items match.';
    }

    part def VER_DB_SEARCH {
        doc /* Verified against FakeDatabaseService with fixture items "Red Plate"
             and "Fork". The alphabetical sort test adds a third item "Soup Bowl"
             and asserts the returned name list equals its own sorted copy. */
        // verifies REQ_DB_SEARCH;
        attribute testFile   : String = 'test/widget_test.dart';
        attribute helperFile : String = 'test/helpers/fake_database_service.dart';
        attribute testGroup  : String = 'FakeDatabaseService — search';
        attribute testCases  : String = 'query < 3 chars returns empty'
                             + ', matching query returns results'
                             + ', case-insensitive match'
                             + ', no match returns empty'
                             + ', results sorted alphabetically'
                             + ', result includes parent box';
        attribute coverageStatus : String = 'covered';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // IMPORT/EXPORT — Export payload construction
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_IO_EXPORT_PAYLOAD {
        doc /* Export payload schema: required fields, correct data population, and JSON serialisability. */
        id   = 'REQ-IO-001';
        text = 'ImportExportService.buildExportPayload() shall produce a Map containing '
             + 'app == "Bokses", version == "1.1", an exportedAt ISO-8601 timestamp, '
             + 'and boxes and items arrays derived from DatabaseService. The payload '
             + 'shall serialise to valid JSON via jsonEncode() without throwing. '
             + 'An empty database shall produce empty arrays for boxes and items.';
    }

    part def VER_IO_EXPORT_PAYLOAD {
        doc /* Verified with FakeDatabaseService as the DatabaseService.instance.
             The JSON validity test calls jsonEncode() on the payload and asserts
             it returns normally (no exception). */
        // verifies REQ_IO_EXPORT_PAYLOAD;
        attribute testFile   : String = 'test/widget_test.dart';
        attribute testGroup  : String = 'buildExportPayload';
        attribute testCases  : String = 'empty database produces valid structure'
                             + ', boxes and items appear in payload'
                             + ', payload serialises to valid JSON';
        attribute coverageStatus : String = 'covered';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // IMPORT/EXPORT — Import validation and processing
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_IO_IMPORT {
        doc /* Import processing: HTML and wrong-app rejection, record upsert, photoData reconstruction, result message. */
        id   = 'REQ-IO-002';
        text = 'ImportExportService.processImportJson() shall reject input that does not '
             + 'begin with "{" (e.g. HTML) with a message containing "Invalid file". '
             + 'It shall reject payloads where app != "Bokses" with a message containing '
             + '"Invalid Bokses". Valid payloads shall upsert all boxes and items via '
             + 'DatabaseService. An item payload containing a photoData field shall '
             + 'have its photoPath reconstructed as a data:image/jpeg;base64,<data> URI. '
             + 'Empty boxes/items arrays shall be accepted without error. '
             + 'The function shall return a human-readable result message reporting counts.';
    }

    part def VER_IO_IMPORT {
        doc /* Verified against FakeDatabaseService. The round-trip test exports
             from one FakeDatabaseService instance and imports into a fresh one,
             asserting name equality on the restored records. The photoData test
             embeds 'abc123' as photoData and asserts the stored photoPath
             contains 'base64,abc123'. */
        // verifies REQ_IO_IMPORT;
        attribute testFile   : String = 'test/widget_test.dart';
        attribute testGroup  : String = 'processImportJson';
        attribute testCases  : String = 'rejects HTML input'
                             + ', rejects wrong app field'
                             + ', imports boxes and items'
                             + ', handles empty arrays'
                             + ', round-trip: export → import restores data'
                             + ', import with photoData restores data: URI on item';
        attribute coverageStatus : String = 'covered';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // UI — Box name validation
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_BOX_NAME_VALIDATION {
        doc /* Box name form validation: empty, whitespace-only, case-insensitive duplicate, and optional description. */
        id   = 'REQ-UI-001';
        text = 'The New Box and Edit Box forms shall reject an empty name with the '
             + 'message "Name required". A whitespace-only name shall also be rejected '
             + 'with "Name required". A name that matches an existing box name '
             + '(case-insensitive comparison) shall be rejected with '
             + '"A box with this name already exists". A valid, unique name shall be '
             + 'accepted; an optional description field shall be saved when provided. '
             + 'The same duplicate-name rule applies during edit, excluding the box '
             + 'being edited from the uniqueness check.';
    }

    part def VER_BOX_NAME_VALIDATION {
        doc /* Verified by widget tests in the add-box and edit-box groups.
             The duplicate-name tests use fixtures box1() ("Kitchen Stuff") and
             box2() ("Books"). The case-insensitivity test submits "kitchen stuff"
             and expects the same error message. */
        // verifies REQ_BOX_NAME_VALIDATION;
        attribute testFile    : String = 'test/widget_test.dart';
        attribute testGroups  : String = 'HomeScreen — add box, HomeScreen — edit box';
        attribute testCases   : String = 'empty name → validation error'
                              + ', whitespace-only name → validation error'
                              + ', duplicate name → validation error'
                              + ', duplicate name is case-insensitive'
                              + ', valid name creates box'
                              + ', optional description is saved'
                              + ', empty name during edit → validation error'
                              + ', duplicate name during edit → validation error';
        attribute coverageStatus : String = 'covered';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // UI — Box deletion with undo
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_BOX_DELETE_UNDO {
        doc /* Box deletion with undo snackbar, item cascade, and permanent delete on dismiss. */
        id   = 'REQ-UI-002';
        text = 'Deleting a box from the HomeScreen shall immediately remove it from '
             + 'the UI and the backing store. A snackbar with an "Undo" action shall '
             + 'appear for at least 2500 ms. Tapping Undo shall restore the box and '
             + 'all of its items to the backing store and redisplay the box in the UI. '
             + 'If Undo is not tapped before the snackbar dismisses, the deletion is '
             + 'permanent. Deleting a box shall also delete all child items.';
    }

    part def VER_BOX_DELETE_UNDO {
        doc /* Widget tests drive the popup menu "Delete" action on a rendered
             HomeScreen. The cascade test pre-inserts item1() into the fake db
             and asserts _fakeDb.items is empty after the box is deleted. */
        // verifies REQ_BOX_DELETE_UNDO;
        attribute testFile   : String = 'test/widget_test.dart';
        attribute testGroup  : String = 'HomeScreen — delete box';
        attribute testCases  : String = 'delete removes box immediately'
                             + ', delete shows undo snackbar'
                             + ', undo restores deleted box'
                             + ', deleting box also removes its items';
        attribute coverageStatus : String = 'covered';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // UI — HomeScreen summary display
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_HOME_DISPLAY {
        doc /* HomeScreen summary display: wordmark, singular/plural count chips, empty state, box cards, and FAB. */
        id   = 'REQ-UI-003';
        text = 'HomeScreen shall display a "Bokses" wordmark, box and item count chips '
             + 'with correct singular/plural grammar (e.g. "1 box", "2 items"), and a '
             + '"New Box" FAB. When no boxes exist it shall show the empty state message '
             + '"No boxes yet!". When boxes exist the empty state shall be hidden. '
             + 'Box cards shall show the box name and optional description. '
             + 'Item count chips shall reflect the live count from DatabaseService.';
    }

    part def VER_HOME_DISPLAY {
        doc /* Verified by the "HomeScreen — empty state" and "HomeScreen — box grid"
             widget groups. The count chip tests pass explicit box and item lists
             via pumpApp(). Singular/plural coverage is explicit for both boxes
             and items. */
        // verifies REQ_HOME_DISPLAY;
        attribute testFile    : String = 'test/widget_test.dart';
        attribute testGroups  : String = 'HomeScreen — empty state, HomeScreen — box grid';
        attribute testCases   : String = 'shows Bokses wordmark'
                              + ', shows 0 boxes and 0 items chips'
                              + ', shows empty state message'
                              + ', shows New Box FAB'
                              + ', shows box names'
                              + ', correct box count chip'
                              + ', singular: 1 box'
                              + ', item count chip'
                              + ', singular: 1 item'
                              + ', box description shows on card'
                              + ', empty state hidden when boxes exist';
        attribute coverageStatus : String = 'covered';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // UI — Item search behaviour
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_SEARCH_UI {
        doc /* HomeScreen inline search: activation, 3-char minimum, result tiles, clear button, and exit. */
        id   = 'REQ-UI-004';
        text = 'Activating search on HomeScreen shall open an inline text field and '
             + 'hide the New Box FAB. Entering fewer than 3 characters shall display '
             + '"Type at least 3 characters". A query with no matching items shall '
             + 'display "No items found". A matching query shall display a result tile '
             + 'showing the item name and the parent box name. A clear button shall '
             + 'appear when the field is non-empty and shall reset the search state. '
             + 'The back arrow shall exit search mode and restore the box list.';
    }

    part def VER_SEARCH_UI {
        doc /* Widget tests in "HomeScreen — search" drive the search icon tap,
             text entry, and result rendering against FakeDatabaseService seeded
             with box1() and item1() ("Red Plate"). */
        // verifies REQ_SEARCH_UI;
        attribute testFile   : String = 'test/widget_test.dart';
        attribute testGroup  : String = 'HomeScreen — search';
        attribute testCases  : String = 'search icon opens text field'
                             + ', FAB hidden in search mode'
                             + ', back arrow exits search'
                             + ', typing < 3 chars shows prompt'
                             + ', no match shows empty message'
                             + ', matching query shows result tile'
                             + ', result tile shows parent box name'
                             + ', clear button appears when text entered'
                             + ', clear button clears field and resets state';
        attribute coverageStatus : String = 'covered';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // UI — Item CRUD in BoxDetailScreen
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_ITEM_CRUD_UI {
        doc /* BoxDetailScreen item CRUD: add/edit name validation, delete with undo, empty state, photo placeholder. */
        id   = 'REQ-UI-005';
        text = 'BoxDetailScreen shall show an "Add Item" FAB and item list or the '
             + '"Box is empty!" empty state. Tapping "Add Item" shall open a form; '
             + 'submitting an empty name shall show "Name required". A valid name shall '
             + 'create an Item persisted to DatabaseService with the correct boxId. '
             + 'The edit flow shall pre-populate the existing name; saving with an '
             + 'empty name shall show "Name required". Deleting an item shall remove it '
             + 'immediately, show an "Undo" snackbar, allow restoration via Undo, '
             + 'and show the empty state when the last item is deleted. '
             + 'Items without a photo shall show a placeholder icon.';
    }

    part def VER_ITEM_CRUD_UI {
        doc /* Verified by four BoxDetailScreen widget groups.
             pumpBoxDetail() seeds FakeDatabaseService with the box and optional
             items, then pumps BoxDetailScreen directly. The "created item belongs
             to correct box" test asserts _fakeDb.items.first.boxId == 'box-1'. */
        // verifies REQ_ITEM_CRUD_UI;
        attribute testFile    : String = 'test/widget_test.dart';
        attribute testGroups  : String = 'BoxDetailScreen — empty state'
                              + ', BoxDetailScreen — item list'
                              + ', BoxDetailScreen — add item'
                              + ', BoxDetailScreen — edit item'
                              + ', BoxDetailScreen — delete item';
        attribute testCases   : String = 'shows box name in app bar'
                              + ', shows empty box message'
                              + ', shows Add Item FAB'
                              + ', shows item names'
                              + ', shows no-photo icon for item without photo'
                              + ', empty state hidden when items exist'
                              + ', Add Item FAB opens sheet'
                              + ', empty name → validation error'
                              + ', valid name creates item'
                              + ', created item belongs to correct box'
                              + ', edit opens sheet with existing name'
                              + ', renaming item saves new name'
                              + ', empty name during edit → validation error'
                              + ', delete removes item immediately'
                              + ', delete shows undo snackbar'
                              + ', undo restores deleted item'
                              + ', deleting last item shows empty state';
        attribute coverageStatus : String = 'covered';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // UI — ItemLabel badge display and picker
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_LABEL_UI {
        doc /* ItemLabel badge rendering, LabelPickerSheet selection, and end-to-end label assignment flow. */
        id   = 'REQ-UI-006';
        text = 'Individual label badge widgets (FragileBadge, BatteryBadge, LiquidBadge) '
             + 'shall render their respective label text ("FRAGILE", "BATTERY", "LIQUID"). '
             + 'LabelBadgesRow shall render no badges for an empty set, and exactly one '
             + 'badge per label in the provided set. LabelPickerSheet shall show all '
             + 'three label names, toggle selection state on tap, pre-check any '
             + 'initially-selected labels, and return the selected list when "Done" '
             + 'is tapped. The end-to-end label assignment flow shall show the badge '
             + 'in the item list after saving.';
    }

    part def VER_LABEL_UI {
        doc /* Label badge widgets are tested in isolation via wrapWidget().
             LabelPickerSheet is pumped via showModalBottomSheet in a dedicated
             pumpSheet() helper. The E2E test opens the edit dialog, taps "Add Labels",
             selects Fragile, taps Done, saves, and asserts find.text('FRAGILE'). */
        // verifies REQ_LABEL_UI;
        attribute testFile    : String = 'test/widget_test.dart';
        attribute testGroups  : String = 'FragileBadge, BatteryBadge, LiquidBadge'
                              + ', LabelBadgesRow, LabelPickerSheet'
                              + ', E2E — label assignment flow';
        attribute testCases   : String = 'renders FRAGILE text'
                              + ', renders BATTERY text'
                              + ', renders LIQUID text'
                              + ', empty set renders nothing'
                              + ', fragile label shows badge'
                              + ', all three labels render three badges'
                              + ', shows all three label names'
                              + ', tapping a label toggles its selection'
                              + ', initial selection is pre-checked'
                              + ', Done pops with selected labels'
                              + ', assigning fragile label to item shows badge on item list';
        attribute coverageStatus : String = 'covered';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // UI — HomeScreen sort picker
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_HOME_SORT {
        doc /* HomeScreen sort picker: tapping each option reorders the box list immediately. */
        id   = 'REQ-UI-007';
        text = 'Tapping a sort option in the HomeScreen summary bar shall immediately '
             + 're-sort the displayed box list without navigating away. '
             + 'dateAsc shall order oldest boxes first; dateDesc newest first; '
             + 'nameAsc alphabetically A→Z; nameDesc Z→A. '
             + 'The active sort option shall be visually distinguished from inactive ones. '
             + 'Sort state shall be preserved for the lifetime of the HomeScreen session.';
    }

    part def VER_HOME_SORT {
        doc /* NO TEST COVERAGE as of v0.10.
             Recommended: pump HomeScreen with multiple boxes having distinct names
             and createdAt values; tap each sort chip; assert the displayed box name
             order matches the expected sorted sequence. */
        // verifies REQ_HOME_SORT;
        attribute testFile       : String = 'test/widget_test.dart';
        attribute testGroup      : String = 'HomeScreen — sort';
        attribute testCases      : String = 'dateAsc orders oldest first'
                                 + ', dateDesc orders newest first'
                                 + ', nameAsc orders A→Z'
                                 + ', nameDesc orders Z→A'
                                 + ', active sort option visually indicated';
        attribute coverageStatus : String = 'pending';
        attribute pendingNote    : String = 'Sort picker interaction not yet widget-tested';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // UI — HomeScreen grid/list view mode toggle
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_HOME_VIEW_TOGGLE {
        doc /* HomeScreen view toggle: switches between BoxCard grid and BoxListTile list. */
        id   = 'REQ-UI-008';
        text = 'Tapping the view mode toggle in the HomeScreen summary bar shall switch '
             + 'between BoxCard grid layout and BoxListTile list layout. '
             + 'Grid mode shall render dot-matrix BoxCards; list mode shall render '
             + 'Slidable BoxListTiles. Both modes shall display box name, item count, '
             + 'and label badges. The toggle control shall reflect the current mode. '
             + 'Mode state shall be preserved for the lifetime of the HomeScreen session.';
    }

    part def VER_HOME_VIEW_TOGGLE {
        doc /* NO TEST COVERAGE as of v0.10.
             Recommended: pump HomeScreen in grid mode, assert BoxCard widgets present
             and BoxListTile absent; tap the toggle; assert BoxListTile widgets appear
             and BoxCard widgets are absent. */
        // verifies REQ_HOME_VIEW_TOGGLE;
        attribute testFile       : String = 'test/widget_test.dart';
        attribute testGroup      : String = 'HomeScreen — view toggle';
        attribute testCases      : String = 'default mode renders grid cards'
                                 + ', toggle switches to list tiles'
                                 + ', toggle back restores grid cards'
                                 + ', both modes show item count and labels';
        attribute coverageStatus : String = 'pending';
        attribute pendingNote    : String = 'Grid/list toggle not yet widget-tested';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // UI — BoxListTile swipe-to-reveal actions
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_LIST_TILE_SWIPE {
        doc /* BoxListTile Slidable: short swipe reveals Edit and Delete; full swipe triggers delete+undo. */
        id   = 'REQ-UI-009';
        text = 'In list view mode, dragging a BoxListTile with a short swipe shall '
             + 'reveal an Edit action button and a Delete action button via the Slidable '
             + 'DrawerMotion. Tapping the revealed Edit action shall open the edit box '
             + 'sheet pre-populated with the box\'s current name and description. '
             + 'Tapping the revealed Delete action shall immediately remove the box, '
             + 'show the Undo snackbar, and cascade-delete all child items — identical '
             + 'in behaviour to the popup-menu delete path (REQ-UI-002). '
             + 'A full-swipe dismiss shall also trigger the delete-with-undo flow.';
    }

    part def VER_LIST_TILE_SWIPE {
        doc /* NO TEST COVERAGE as of v0.10.
             Recommended: pump HomeScreen in list view mode with a seeded box;
             use WidgetTester.drag() with sufficient dx offset; assert Edit and Delete
             action buttons appear; tap Delete; assert box removed and snackbar shown. */
        // verifies REQ_LIST_TILE_SWIPE;
        attribute testFile       : String = 'test/widget_test.dart';
        attribute testGroup      : String = 'HomeScreen — list tile swipe';
        attribute testCases      : String = 'short swipe reveals Edit action'
                                 + ', short swipe reveals Delete action'
                                 + ', tapping Edit opens pre-populated sheet'
                                 + ', tapping Delete removes box with undo snackbar'
                                 + ', full swipe triggers delete-with-undo';
        attribute coverageStatus : String = 'pending';
        attribute pendingNote    : String = 'Slidable drag gestures require widget-level integration test';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // UI — HomeScreen Clear All confirmation dialog
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_CLEAR_ALL_DIALOG {
        doc /* Clear All: overflow menu tap opens confirmation dialog; cancel preserves data; confirm erases all. */
        id   = 'REQ-UI-010';
        text = 'Tapping "Clear All" from the HomeScreen overflow menu shall open an '
             + 'AlertDialog requiring explicit confirmation before any data is deleted. '
             + 'Tapping the cancel button shall dismiss the dialog and leave all boxes '
             + 'and items intact. Tapping the confirm button shall call '
             + 'DatabaseService.clearAll() and update HomeScreen to show the empty state. '
             + 'The dialog shall not be dismissible by tapping outside its bounds.';
    }

    part def VER_CLEAR_ALL_DIALOG {
        doc /* NO TEST COVERAGE as of v0.10.
             Recommended: pump HomeScreen with seeded boxes, open overflow menu, tap
             Clear All, assert AlertDialog present; tap cancel and assert boxes still
             render; repeat with tap confirm and assert empty state shown and
             _fakeDb.boxes is empty. */
        // verifies REQ_CLEAR_ALL_DIALOG;
        attribute testFile       : String = 'test/widget_test.dart';
        attribute testGroup      : String = 'HomeScreen — clear all dialog';
        attribute testCases      : String = 'Clear All menu item opens confirmation dialog'
                                 + ', cancel dismisses dialog and preserves data'
                                 + ', confirm calls clearAll and shows empty state'
                                 + ', dialog not dismissible by outside tap';
        attribute coverageStatus : String = 'pending';
        attribute pendingNote    : String = 'Clear All dialog interaction not yet widget-tested';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // UI — BoxDetailScreen move item to box
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_MOVE_ITEM_UI {
        doc /* BoxDetailScreen move-item action: swipe reveals Move; popup lists other boxes; selection updates boxId. */
        id   = 'REQ-UI-011';
        text = 'In BoxDetailScreen, swiping an item tile shall reveal a Move action '
             + 'alongside the Edit and Delete actions. Tapping Move shall present a '
             + 'popup listing all other boxes by name. Selecting a target box shall call '
             + 'DatabaseService.updateItem() with the updated boxId, remove the item '
             + 'from the current screen immediately, and reflect the updated item count '
             + 'on HomeScreen when returning. If no other boxes exist, the Move action '
             + 'shall be disabled or absent.';
    }

    part def VER_MOVE_ITEM_UI {
        doc /* NO TEST COVERAGE as of v0.10.
             Recommended: seed FakeDatabaseService with two boxes and an item in the
             first; pump BoxDetailScreen; swipe to reveal Move; tap it; assert popup
             lists the second box; select it; assert item absent from first box and
             present in second via _fakeDb.items.first.boxId. */
        // verifies REQ_MOVE_ITEM_UI;
        attribute testFile       : String = 'test/widget_test.dart';
        attribute testGroup      : String = 'BoxDetailScreen — move item';
        attribute testCases      : String = 'swipe reveals Move action'
                                 + ', Move opens box selection popup'
                                 + ', popup lists other boxes by name'
                                 + ', selecting target removes item from current screen'
                                 + ', item persisted with new boxId'
                                 + ', Move absent when no other boxes exist';
        attribute coverageStatus : String = 'pending';
        attribute pendingNote    : String = 'Move item flow requires Slidable integration and multi-box fixture';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // UI — BoxDetailScreen photo capture button and item photo display
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_PHOTO_UI {
        doc /* Add/Edit Item camera button invokes ImagePicker; captured photo previewed in form and displayed in item tile. */
        id   = 'REQ-UI-012';
        text = 'The Add Item and Edit Item forms shall each contain a camera icon button. '
             + 'Tapping the button shall invoke ImagePicker for the device camera. '
             + 'If the picker returns a path, a thumbnail preview shall appear in the '
             + 'form before the item is saved. Submitting the form shall persist the '
             + 'returned path as ItemRecord.photoPath. '
             + 'If ImagePicker returns null (user cancelled), the form state shall '
             + 'remain unchanged. Items with a stored photoPath shall display the photo '
             + 'image in the item tile; items without a photo shall display the '
             + 'placeholder icon (covered by REQ-UI-005).';
    }

    part def VER_PHOTO_UI {
        doc /* NO TEST COVERAGE as of v0.10.
             Recommended: mock image_picker via platform channel to return a known
             test image path; pump the add-item sheet; tap the camera button; assert
             thumbnail widget appears; save; assert _fakeDb.items.first.photoPath is
             non-null and item tile shows the photo widget rather than the placeholder. */
        // verifies REQ_PHOTO_UI;
        attribute testFile       : String = 'test/widget_test.dart';
        attribute testGroup      : String = 'BoxDetailScreen — photo capture';
        attribute testCases      : String = 'camera button present in add-item form'
                                 + ', tapping camera button invokes ImagePicker'
                                 + ', returned path shows thumbnail preview in form'
                                 + ', saved item persists photoPath'
                                 + ', cancelled picker leaves form unchanged'
                                 + ', item tile shows photo when photoPath set';
        attribute coverageStatus : String = 'pending';
        attribute pendingNote    : String = 'image_picker requires platform channel mock';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // UI — Box fragile toggle in Add/Edit Box forms
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_BOX_FRAGILE_TOGGLE {
        doc /* Add/Edit Box form fragile toggle: defaults off for new boxes; pre-set on edit; persists correctly. */
        id   = 'REQ-UI-013';
        text = 'The New Box and Edit Box forms shall contain a toggle labelled "Fragile" '
             + 'corresponding to BoxRecord.fragile. The toggle shall default to off for '
             + 'new boxes. In the Edit Box form the toggle shall be pre-set to the '
             + 'box\'s current fragile value. Saving with the toggle on shall persist '
             + 'BoxRecord.fragile = true via DatabaseService.insertBox() or updateBox(). '
             + 'Saving with the toggle off shall persist BoxRecord.fragile = false.';
    }

    part def VER_BOX_FRAGILE_TOGGLE {
        doc /* NO TEST COVERAGE as of v0.10.
             Recommended: pump HomeScreen, open the New Box dialog, assert toggle
             defaults off; tap the fragile toggle, submit a valid name, assert
             _fakeDb.boxes.first.fragile == true. For edit: pre-seed a fragile box,
             open edit dialog, assert toggle pre-checked, toggle off, save, assert
             fragile == false. */
        // verifies REQ_BOX_FRAGILE_TOGGLE;
        attribute testFile       : String = 'test/widget_test.dart';
        attribute testGroup      : String = 'HomeScreen — box fragile toggle';
        attribute testCases      : String = 'fragile toggle defaults to off for new box'
                                 + ', toggling on persists fragile = true'
                                 + ', edit dialog pre-checks toggle for fragile box'
                                 + ', toggling off during edit persists fragile = false';
        attribute coverageStatus : String = 'pending';
        attribute pendingNote    : String = 'Box fragile toggle in form not yet widget-tested';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // SETTINGS — Persistence defaults and round-trips
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_SETTINGS_PERSISTENCE {
        doc /* SettingsService hardcoded defaults and SharedPreferences round-trip persistence for every key. */
        id   = 'REQ-SETTINGS-001';
        text = 'SettingsService shall return correct hardcoded defaults for every key '
             + 'when SharedPreferences has no stored value: isDarkMode=true, '
             + 'themePreset=0, backgroundType=none, talkSilenceMs=1500, '
             + 'talkReadBack=false, loadAllContent=true, autoBoksCameraEnabled=true, '
             + 'backgroundBlur=10.0, backgroundColor=0xFF0C0C0E, autoBoksSuccessCount=0. '
             + 'Every setter shall persist its value so the corresponding getter '
             + 'returns the new value in the same session. '
             + 'incrementAutoBoksSuccessCount() shall be additive across calls.';
    }

    part def VER_SETTINGS_PERSISTENCE {
        doc /* Verified via unit tests in the "SettingsService" group.
             SharedPreferences.setMockInitialValues({}) is called in setUp()
             to ensure a clean slate before each test. Each default test reads
             without any prior write; each persist test writes then reads. */
        // verifies REQ_SETTINGS_PERSISTENCE;
        attribute testFile   : String = 'test/widget_test.dart';
        attribute testGroup  : String = 'SettingsService';
        attribute testCases  : String = 'dark mode defaults to true'
                             + ', dark mode persists'
                             + ', theme preset defaults to 0'
                             + ', theme preset persists'
                             + ', bg type defaults to none'
                             + ', bg type persists'
                             + ', talkSilenceMs defaults to 1500'
                             + ', talkSilenceMs persists'
                             + ', talkReadBack defaults to false'
                             + ', talkReadBack persists'
                             + ', loadAllContent defaults to true'
                             + ', loadAllContent persists'
                             + ', autoBoksCamera defaults to true'
                             + ', autoBoksCamera persists'
                             + ', bgBlur defaults to 10.0'
                             + ', bgBlur persists'
                             + ', bgColor defaults to 0xFF0C0C0E'
                             + ', bgColor persists'
                             + ', autoBoksSuccessCount defaults to 0'
                             + ', incrementAutoBoksSuccessCount increments';
        attribute coverageStatus : String = 'covered';
    }

    requirement def REQ_SETTINGS_SCREEN_DARK_MODE {
        doc /* SettingsScreen dark mode toggle writes to SharedPreferences immediately on change. */
        id   = 'REQ-SETTINGS-002';
        text = 'The SettingsScreen dark mode toggle shall write the new value to '
             + 'SharedPreferences under the key "is_dark_mode" immediately when '
             + 'toggled. The SettingsScreen shall render a "Dark Mode" labelled '
             + 'control and a "Camera" toggle in the AutoBoks section.';
    }

    part def VER_SETTINGS_SCREEN_DARK_MODE {
        doc /* The dark mode persistence test sets the mock initial value to true,
             pumps SettingsScreen, taps the first Switch widget, then reads
             SharedPreferences.getInstance() and asserts is_dark_mode == false.
             The Camera toggle test expands the viewport to 800×2000 to ensure
             the AutoBoks section is in the render tree. */
        // verifies REQ_SETTINGS_SCREEN_DARK_MODE;
        attribute testFile   : String = 'test/widget_test.dart';
        attribute testGroup  : String = 'SettingsScreen';
        attribute testCases  : String = 'renders Settings appBar'
                             + ', shows Dark Mode toggle'
                             + ', shows Camera toggle in AutoBoks section'
                             + ', dark mode toggle persists to SharedPreferences';
        attribute coverageStatus : String = 'covered';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // SETTINGS — Theme preset chip selection
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_SETTINGS_THEME_PRESETS {
        doc /* SettingsScreen: tapping each of the 8 preset chips applies and persists the colour theme. */
        id   = 'REQ-SETTINGS-003';
        text = 'The SettingsScreen Appearance section shall render all 8 colour preset '
             + 'chips (BoksOtter through Robin). Tapping a preset chip shall immediately '
             + 'call AppTheme.setPreset() with the corresponding index and persist the '
             + 'selection via SettingsService.setThemePreset(). The active chip shall be '
             + 'visually distinguished from inactive chips. After a ValueNotifier-driven '
             + 'rebuild the correct chip shall remain selected.';
    }

    part def VER_SETTINGS_THEME_PRESETS {
        doc /* NO TEST COVERAGE as of v0.10.
             Recommended: pump SettingsScreen with presetIndex=0; assert 8 chips render;
             tap the second chip; assert SettingsService.getThemePreset() == 1 and
             the second chip shows the active visual state. */
        // verifies REQ_SETTINGS_THEME_PRESETS;
        attribute testFile       : String = 'test/widget_test.dart';
        attribute testGroup      : String = 'SettingsScreen — theme presets';
        attribute testCases      : String = 'all 8 preset chips render'
                                 + ', tapping a chip persists the preset index'
                                 + ', active chip is visually distinguished'
                                 + ', chip state survives ValueNotifier rebuild';
        attribute coverageStatus : String = 'pending';
        attribute pendingNote    : String = 'Preset chip tap and visual state not yet widget-tested';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // SETTINGS — Background type controls
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_SETTINGS_BACKGROUND {
        doc /* SettingsScreen Background section: selecting each type persists it and shows the correct sub-controls. */
        id   = 'REQ-SETTINGS-004';
        text = 'The SettingsScreen Background section shall render controls for all four '
             + 'AppBgType options (none, gradient, image, solid). Selecting "none" shall '
             + 'persist AppBgType.none and hide any sub-controls. Selecting "gradient" '
             + 'shall persist AppBgType.gradient with no additional input. Selecting '
             + '"image" shall show a blur sigma slider (range 0–20); dragging it shall '
             + 'call SettingsService.setBackgroundBlur() and trigger '
             + 'AppTheme.notifyBgChanged(). Selecting "solid" shall show a colour input. '
             + 'Each selection shall persist the chosen AppBgType via '
             + 'SettingsService.setBackgroundType().';
    }

    part def VER_SETTINGS_BACKGROUND {
        doc /* NO TEST COVERAGE as of v0.10.
             Recommended: pump SettingsScreen with bgType=none; tap each option;
             assert correct type persisted; for "image" assert blur slider visible;
             drag slider to midpoint, assert setBackgroundBlur called with the
             expected value. */
        // verifies REQ_SETTINGS_BACKGROUND;
        attribute testFile       : String = 'test/widget_test.dart';
        attribute testGroup      : String = 'SettingsScreen — background controls';
        attribute testCases      : String = 'all four background type options render'
                                 + ', selecting none persists AppBgType.none'
                                 + ', selecting gradient persists AppBgType.gradient'
                                 + ', selecting image shows blur slider'
                                 + ', dragging blur slider persists new value'
                                 + ', selecting solid persists AppBgType.solid';
        attribute coverageStatus : String = 'pending';
        attribute pendingNote    : String = 'Background type controls and blur slider not yet widget-tested';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // SETTINGS — CV model download/delete button and progress bar
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_SETTINGS_CV_BUTTONS {
        doc /* SettingsScreen CV section: download/delete button visibility and progress bar driven by ModelInstallState. */
        id   = 'REQ-SETTINGS-005';
        text = 'The SettingsScreen CV Model section shall show a download button when '
             + 'CV is enabled and the model is not installed. Tapping the download button '
             + 'shall begin the download and replace the button with a progress bar '
             + 'filling 0.0→1.0 as ModelService.download() emits progress. A cancel '
             + 'button shall be available during download; tapping it shall abort the '
             + 'download and return to the not-installed state. Once installed, a delete '
             + 'button shall replace the progress bar; tapping it shall call '
             + 'ModelService.delete() and revert the section to the not-installed state. '
             + 'When the CV toggle is disabled, neither button nor progress bar shall appear.';
    }

    part def VER_SETTINGS_CV_BUTTONS {
        doc /* NO TEST COVERAGE as of v0.10.
             Recommended: mock ModelService with a fake that exposes a controllable
             progress stream; pump SettingsScreen with cvEnabled=true and
             modelInstalled=false; assert download button visible; tap it; assert
             progress bar present; mock completion; assert delete button appears. */
        // verifies REQ_SETTINGS_CV_BUTTONS;
        attribute testFile       : String = 'test/widget_test.dart';
        attribute testGroup      : String = 'SettingsScreen — CV model buttons';
        attribute testCases      : String = 'download button visible when CV enabled and not installed'
                                 + ', download button absent when CV disabled'
                                 + ', tapping download shows progress bar'
                                 + ', progress bar fills as download progresses'
                                 + ', cancel button aborts download and restores not-installed state'
                                 + ', delete button appears after install'
                                 + ', tapping delete reverts to not-installed state';
        attribute coverageStatus : String = 'pending';
        attribute pendingNote    : String = 'ModelService download lifecycle requires controllable stream mock';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // NAVIGATION — Screen transitions
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_NAVIGATION {
        doc /* Screen navigation flows: box card, back button, search result tap, settings, and about. */
        id   = 'REQ-NAV-001';
        text = 'Tapping a box card on HomeScreen shall navigate to BoxDetailScreen '
             + 'showing that box\'s content. The back button on BoxDetailScreen shall '
             + 'return to HomeScreen. Tapping a search result tile shall navigate to '
             + 'the BoxDetailScreen for the item\'s parent box. The settings icon shall '
             + 'open SettingsScreen. The back button from SettingsScreen shall return '
             + 'to HomeScreen. The "About" overflow menu item shall open AboutScreen.';
    }

    part def VER_NAVIGATION {
        doc /* Navigation tests span four E2E groups plus the dedicated "Navigation"
             widget group. pumpApp() injects the FakeDatabaseService and pumps
             HomeScreen; navigation is driven by tap interactions only. */
        // verifies REQ_NAVIGATION;
        attribute testFile    : String = 'test/widget_test.dart';
        attribute testGroups  : String = 'Navigation'
                              + ', E2E — search result navigation'
                              + ', E2E — settings navigation'
                              + ', E2E — three-dots menu';
        attribute testCases   : String = 'tapping box card opens BoxDetailScreen'
                              + ', back from BoxDetail returns to HomeScreen'
                              + ', tapping search result opens correct BoxDetailScreen'
                              + ', settings button from home opens SettingsScreen'
                              + ', back from Settings returns to HomeScreen'
                              + ', About menu item opens AboutScreen';
        attribute coverageStatus : String = 'covered';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // NAVIGATION — Version History link from SettingsScreen
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_VERSION_HISTORY_NAV {
        doc /* SettingsScreen App Info link navigates to VersionHistoryScreen; back returns to Settings. */
        id   = 'REQ-NAV-002';
        text = 'The App Info section of SettingsScreen shall display the current app '
             + 'version string and a tappable element labelled "Version History". '
             + 'Tapping it shall push VersionHistoryScreen onto the Navigator stack. '
             + 'The back button from VersionHistoryScreen shall return to SettingsScreen.';
    }

    part def VER_VERSION_HISTORY_NAV {
        doc /* NO TEST COVERAGE as of v0.10.
             Recommended: pump SettingsScreen, scroll to the App Info section, tap the
             Version History element, assert VersionHistoryScreen present in the widget
             tree, tap back, assert SettingsScreen returns. */
        // verifies REQ_VERSION_HISTORY_NAV;
        attribute testFile       : String = 'test/widget_test.dart';
        attribute testGroup      : String = 'Navigation — version history';
        attribute testCases      : String = 'Version History link present in App Info section'
                                 + ', tapping link opens VersionHistoryScreen'
                                 + ', back from VersionHistoryScreen returns to SettingsScreen';
        attribute coverageStatus : String = 'pending';
        attribute pendingNote    : String = 'Version History link navigation not yet widget-tested';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // E2E — Item count accuracy across screens
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_ITEM_COUNT_ACCURACY {
        doc /* HomeScreen item count chip accuracy reflects live DatabaseService count after BoxDetailScreen adds. */
        id   = 'REQ-E2E-001';
        text = 'The item count displayed on a box card or list tile on HomeScreen '
             + 'shall reflect the live count in DatabaseService after returning from '
             + 'BoxDetailScreen. Adding one item and navigating back shall show '
             + '"1 item". Adding three items to the same box shall show "3 items".';
    }

    part def VER_ITEM_COUNT_ACCURACY {
        doc /* E2E tests navigate from HomeScreen → BoxDetailScreen → add item(s)
             → back, then assert the chip text on the home card. The multiple-items
             test loops over ['Spoon', 'Bowl', 'Cup'] in a single test. */
        // verifies REQ_ITEM_COUNT_ACCURACY;
        attribute testFile   : String = 'test/widget_test.dart';
        attribute testGroup  : String = 'E2E — create box then add items';
        attribute testCases  : String = 'item count on home card updates after adding items'
                             + ', multiple items added to same box count correctly';
        attribute coverageStatus : String = 'covered';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // WIDGETS — Shared component rendering
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_SHARED_WIDGETS {
        doc /* BoksCard, BoksBadge, AboutScreen, and VersionHistoryScreen rendering and interaction contracts. */
        id   = 'REQ-WIDGET-001';
        text = 'BoksCard shall render its child widget and fire its onTap callback '
             + 'when tapped. BoksBadge shall render its label text. AboutScreen shall '
             + 'display an "About" app bar title and the application name "Bokses" '
             + 'in the body. VersionHistoryScreen shall display a "Version History" '
             + 'app bar title and at least one version badge containing "v0.".';
    }

    part def VER_SHARED_WIDGETS {
        doc /* BoksCard and BoksBadge are tested via wrapWidget() helper that
             wraps the widget in a MaterialApp + Scaffold. AboutScreen and
             VersionHistoryScreen are pumped directly with AppTheme pre-configured. */
        // verifies REQ_SHARED_WIDGETS;
        attribute testFile    : String = 'test/widget_test.dart';
        attribute testGroups  : String = 'BoksCard, BoksBadge, AboutScreen, VersionHistoryScreen';
        attribute testCases   : String = 'renders its child'
                              + ', onTap fires when tapped'
                              + ', renders label text'
                              + ', renders About appBar'
                              + ', shows Bokses name in body'
                              + ', renders Version History appBar'
                              + ', shows at least one version badge';
        attribute coverageStatus : String = 'covered';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // WIDGETS — BoxCard dot-matrix slot rendering and item count overflow
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_BOX_CARD_DOTS {
        doc /* BoxCard dot-matrix: filled slots reflect itemCount up to 14; slot 15 shows '+' overflow. */
        id   = 'REQ-WIDGET-002';
        text = 'The BoxCard dot-matrix shall render 15 slots. Filled slots (indices 0 to '
             + 'itemCount − 1, capped at 14) shall be visually distinct from empty slots. '
             + 'When itemCount is 0, all 15 slots shall appear empty. When itemCount '
             + 'exceeds 14, slot 14 shall display a "+" overflow indicator instead of '
             + 'a filled dot. The card border colour shall lerp from boksBlue (index 0) '
             + 'to boksRed (last index in the sorted list) via the accentColor value.';
    }

    part def VER_BOX_CARD_DOTS {
        doc /* NO TEST COVERAGE as of v0.10.
             Recommended: pump BoxCard with itemCount=0 and assert all dot slots empty;
             pump with itemCount=3 and assert 3 filled, 12 empty; pump with itemCount=15
             and assert the last slot contains the "+" text widget. */
        // verifies REQ_BOX_CARD_DOTS;
        attribute testFile       : String = 'test/widget_test.dart';
        attribute testGroup      : String = 'BoxCard — dot matrix';
        attribute testCases      : String = 'itemCount=0 renders no filled slots'
                                 + ', itemCount=3 renders 3 filled slots'
                                 + ', itemCount=15 renders overflow indicator in slot 15'
                                 + ', accentColor applied to card border';
        attribute coverageStatus : String = 'pending';
        attribute pendingNote    : String = 'Dot-matrix slot rendering not yet widget-tested';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // WIDGETS — Box fragile flag display on BoxCard and BoxListTile
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_BOX_FRAGILE_DISPLAY {
        doc /* BoxCard and BoxListTile display a fragile indicator when BoxRecord.fragile is true. */
        id   = 'REQ-WIDGET-003';
        text = 'When BoxRecord.fragile is true, both BoxCard and BoxListTile shall '
             + 'display a fragile indicator on the card or tile surface. When '
             + 'BoxRecord.fragile is false, no fragile indicator shall appear. '
             + 'The box-level fragile flag is distinct from the item-level '
             + 'ItemLabel::fragile badge; both may appear simultaneously if the box '
             + 'is fragile and also contains fragile-labelled items.';
    }

    part def VER_BOX_FRAGILE_DISPLAY {
        doc /* NO TEST COVERAGE as of v0.10.
             Recommended: pump BoxCard with a box where fragile=true, assert the
             fragile indicator present; pump with fragile=false, assert absent.
             Repeat for BoxListTile. */
        // verifies REQ_BOX_FRAGILE_DISPLAY;
        attribute testFile       : String = 'test/widget_test.dart';
        attribute testGroup      : String = 'BoxCard — fragile flag, BoxListTile — fragile flag';
        attribute testCases      : String = 'BoxCard shows fragile indicator when fragile=true'
                                 + ', BoxCard hides fragile indicator when fragile=false'
                                 + ', BoxListTile shows fragile indicator when fragile=true'
                                 + ', BoxListTile hides fragile indicator when fragile=false';
        attribute coverageStatus : String = 'pending';
        attribute pendingNote    : String = 'Box-level fragile flag display not yet widget-tested';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // AUTOBOKS — Session state machine  [NO CURRENT TEST COVERAGE]
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_AUTOBOKS_SESSION {
        doc /* AutoBoksController session state machine: permissions gate, voice listen, silence capture, TTS readback. */
        id   = 'REQ-AUTO-001';
        text = 'AutoBoksController shall enforce the AutoBoksState machine across its '
             + 'full session lifecycle: idle → requestingPermissions → listening → '
             + 'silenceCountdown → capturing → readingBack → listening. Transitions '
             + 'shall be atomic; simultaneous snap-sound and camera capture shall fire '
             + 'in the same async frame. A permission-denied result shall transition '
             + 'to the error state and prevent the session from starting. Calling '
             + 'stopSession() from listening or silenceCountdown shall return to idle. '
             + 'Each successful capture shall increment SettingsService.autoBoksSuccessCount.';
    }

    part def VER_AUTOBOKS_SESSION {
        doc /* NO TEST COVERAGE as of v0.10. AutoBoksController depends on
             speech_to_text, camera, and flutter_tts — all requiring real hardware
             or platform-channel fakes not yet implemented in the test harness.
             Recommended verification approach: mock SpeechToText with a fake
             stream, mock CameraController.takePicture(), and assert state
             transitions and DatabaseService.insertItem() calls via FakeDatabaseService. */
        // verifies REQ_AUTOBOKS_SESSION;
        attribute testFile       : String = 'test/widget_test.dart';
        attribute testGroup      : String = 'AutoBoks — session state machine';
        attribute testCases      : String = '';
        attribute coverageStatus : String = 'pending';
        attribute pendingNote    : String = 'Requires hardware plugin fakes (speech_to_text, camera, flutter_tts)';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // AUTOBOKS — Start/stop button states in BoxDetailScreen  [NO CURRENT TEST COVERAGE]
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_AUTOBOKS_UI {
        doc /* BoxDetailScreen AutoBoks button: tapping toggles session and camera preview visibility. */
        id   = 'REQ-AUTO-002';
        text = 'BoxDetailScreen shall display an AutoBoks activation button. Tapping it '
             + 'shall call AutoBoksController.startSession() and display the live camera '
             + 'preview. While a session is active, a stop button shall be visible; '
             + 'tapping it shall call AutoBoksController.stopSession() and hide the '
             + 'camera preview. If permission is denied during startSession(), the button '
             + 'shall revert to its inactive state and present an error message. '
             + 'The button shall be absent when AutoBoks is unavailable or unconfigured.';
    }

    part def VER_AUTOBOKS_UI {
        doc /* NO TEST COVERAGE as of v0.10.
             Recommended: mock AutoBoksController with a fake that exposes a controllable
             state stream; pump BoxDetailScreen; tap the start button; assert live preview
             widget present and stop button visible; tap stop; assert preview hidden.
             Integrate with the hardware-mock approach described in VER_AUTOBOKS_SESSION. */
        // verifies REQ_AUTOBOKS_UI;
        attribute testFile       : String = 'test/widget_test.dart';
        attribute testGroup      : String = 'AutoBoks — UI button states';
        attribute testCases      : String = '';
        attribute coverageStatus : String = 'pending';
        attribute pendingNote    : String = 'Requires AutoBoksController fake and camera live-preview mock';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // CV / TFLITE — Model install lifecycle  [NO CURRENT TEST COVERAGE]
    // ═════════════════════════════════════════════════════════════════════════

    requirement def REQ_CV_MODEL_LIFECYCLE {
        doc /* ModelService install state machine and VisionService availability check and all-zero inference guard. */
        id   = 'REQ-CV-001';
        text = 'ModelService shall correctly track the ModelInstallState machine: '
             + 'notInstalled → downloading (on startDownload) → installed (on '
             + 'downloadComplete) or back to notInstalled (on cancelledOrFailed). '
             + 'download() shall reject a downloaded file whose first 5 bytes begin '
             + 'with "<" (HTML guard) and transition to cancelledOrFailed. '
             + 'VisionService.isAvailable() shall return false when ModelService '
             + 'reports notInstalled, and true when installed. '
             + 'identifyItem() shall throw a descriptive exception if the output '
             + 'tensor is all-zero.';
    }

    part def VER_CV_MODEL_LIFECYCLE {
        doc /* NO TEST COVERAGE as of v0.10. VisionService and ModelService
             depend on tflite_flutter (native .so / .dylib) and live file I/O
             that are not available in the Flutter test environment.
             Recommended verification approach: mock http.Client for the download
             path, mock File.existsSync() / File.readAsBytes() using package:mocktail,
             and inject a pre-built fake .tflite buffer to test the HTML guard
             and interpreter lifecycle without native binaries. */
        // verifies REQ_CV_MODEL_LIFECYCLE;
        attribute testFile       : String = 'test/widget_test.dart';
        attribute testGroup      : String = 'CV — model install lifecycle';
        attribute testCases      : String = '';
        attribute coverageStatus : String = 'pending';
        attribute pendingNote    : String = 'Requires http.Client mock, File I/O mock, and a fake TFLite binary; '
                                          + 'tflite_flutter native binaries are unavailable in flutter test';
    }

    // ── Verification instantiations ───────────────────────────────────────────
    // Each part usage below references its VER_XXX definition, satisfying the
    // unused-definition constraint so all verification cases are reachable.
    part verBoxSerialization    : VER_BOX_SERIALIZATION;
    part verItemSerialization   : VER_ITEM_SERIALIZATION;
    part verDbBoxCrud           : VER_DB_BOX_CRUD;
    part verDbItemCrud          : VER_DB_ITEM_CRUD;
    part verDbSearch            : VER_DB_SEARCH;
    part verIoExportPayload     : VER_IO_EXPORT_PAYLOAD;
    part verIoImport            : VER_IO_IMPORT;
    part verBoxNameValidation   : VER_BOX_NAME_VALIDATION;
    part verBoxDeleteUndo       : VER_BOX_DELETE_UNDO;
    part verHomeDisplay         : VER_HOME_DISPLAY;
    part verSearchUi            : VER_SEARCH_UI;
    part verItemCrudUi          : VER_ITEM_CRUD_UI;
    part verLabelUi             : VER_LABEL_UI;
    part verSettingsPersistence : VER_SETTINGS_PERSISTENCE;
    part verSettingsDarkMode    : VER_SETTINGS_SCREEN_DARK_MODE;
    part verNavigation          : VER_NAVIGATION;
    part verItemCountAccuracy   : VER_ITEM_COUNT_ACCURACY;
    part verSharedWidgets       : VER_SHARED_WIDGETS;
    part verAutoBoksSession     : VER_AUTOBOKS_SESSION;
    part verCvModelLifecycle    : VER_CV_MODEL_LIFECYCLE;
    part verHomeSort            : VER_HOME_SORT;
    part verHomeViewToggle      : VER_HOME_VIEW_TOGGLE;
    part verListTileSwipe       : VER_LIST_TILE_SWIPE;
    part verClearAllDialog      : VER_CLEAR_ALL_DIALOG;
    part verMoveItemUi          : VER_MOVE_ITEM_UI;
    part verPhotoUi             : VER_PHOTO_UI;
    part verBoxFragileToggle    : VER_BOX_FRAGILE_TOGGLE;
    part verSettingsThemePresets : VER_SETTINGS_THEME_PRESETS;
    part verSettingsBackground  : VER_SETTINGS_BACKGROUND;
    part verSettingsCvButtons   : VER_SETTINGS_CV_BUTTONS;
    part verVersionHistoryNav   : VER_VERSION_HISTORY_NAV;
    part verBoxCardDots         : VER_BOX_CARD_DOTS;
    part verBoxFragileDisplay   : VER_BOX_FRAGILE_DISPLAY;
    part verAutoBoksUi          : VER_AUTOBOKS_UI;
}
