import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../app_state.dart';
import '../models/models.dart';
import '../services/openfoodfacts_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../utils/error_helpers.dart';
import '../widgets/analysis_loading.dart';
import '../widgets/upgrade_modal.dart';


enum _ScanMode { photo, text, barcode }

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  /// Whether the scan screen currently has a result showing (used by AppShell for back nav).
  static bool hasResult = false;

  /// Clears the result and goes back to scan input (called by AppShell on back press).
  static VoidCallback? clearResult;

  /// Whether the scan screen is on the default Photo tab (used by AppShell for back nav).
  static bool isOnPhotoMode = true;

  /// Resets the scan mode back to Photo (called by AppShell on back press).
  static VoidCallback? resetToPhotoMode;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with TickerProviderStateMixin {
  final _picker = ImagePicker();
  final _textCtrl = TextEditingController();
  final _barcodeNameCtrl = TextEditingController();

  Uint8List? _imageBytes;
  String _mediaType = 'image/jpeg';
  Uint8List? _secondImageBytes;   // Optional second angle photo
  String _secondMediaType = 'image/jpeg';
  _ScanMode _scanMode = _ScanMode.photo;
  bool _loading = false;
  String? _error;
  ScanResult? _result;

  /// Whether the user has content ready to analyse (image selected or text typed).
  bool get _hasContentToAnalyse =>
      _scanMode == _ScanMode.text ? _textCtrl.text.trim().length > 3 : _imageBytes != null;

  // Barcode state
  bool _barcodeScanned = false;
  String? _scannedBarcode;
  BarcodeResult? _barcodeResult;
  bool _showServingPicker = false; // true = barcode found, awaiting serving size choice
  bool _pendingAiScanTrack = false; // true = AI was used for barcode, track on log

  // Voice input state
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  // Animation for result panel appearing
  late AnimationController _resultAnim;
  late Animation<double> _resultFade;
  late Animation<Offset> _resultSlide;

  @override
  void initState() {
    super.initState();
    _resultAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _resultFade =
        CurvedAnimation(parent: _resultAnim, curve: Curves.easeOut);
    _resultSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _resultAnim, curve: Curves.easeOut));
    _recoverLostImage();

    // Wire up static callbacks for AppShell back-button handling
    ScanScreen.clearResult = _discardResult;
    ScanScreen.resetToPhotoMode = _resetToPhoto;
  }

  @override
  void dispose() {
    ScanScreen.clearResult = null;
    ScanScreen.resetToPhotoMode = null;
    ScanScreen.hasResult = false;
    ScanScreen.isOnPhotoMode = true;
    _textCtrl.dispose();
    _barcodeNameCtrl.dispose();
    _customServingCtrl.dispose();
    _resultAnim.dispose();
    _speech.stop();
    super.dispose();
  }

  // ── Image picking ─────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    try {
      final img = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (img == null) return;
      final bytes = await img.readAsBytes();
      final ext = img.path.toLowerCase();
      setState(() {
        _imageBytes = bytes;
        _mediaType = ext.endsWith('.png') ? 'image/png' : 'image/jpeg';
        _result = null;
        _error = null;
      });
    } catch (e) {
      debugPrint('Image pick error: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('permission') ||
          errStr.contains('denied') ||
          errStr.contains('photo_access_denied') ||
          errStr.contains('camera_access_denied')) {
        if (!mounted) return;
        final sourceName = source == ImageSource.camera ? 'Camera' : 'Photo library';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$sourceName access denied. Please enable it in your device settings.'),
            backgroundColor: CLColors.surface2,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        await _recoverLostImage();
      }
    }
  }

  /// Pick a second angle photo for better portion depth estimation.
  Future<void> _pickSecondImage(ImageSource source) async {
    try {
      final img = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (img == null) return;
      final bytes = await img.readAsBytes();
      final ext = img.path.toLowerCase();
      setState(() {
        _secondImageBytes = bytes;
        _secondMediaType = ext.endsWith('.png') ? 'image/png' : 'image/jpeg';
      });
    } catch (e) {
      debugPrint('Second image pick error: $e');
    }
  }

  Future<void> _recoverLostImage() async {
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty || response.file == null) return;
      final bytes = await response.file!.readAsBytes();
      final ext = response.file!.path.toLowerCase();
      setState(() {
        _imageBytes = bytes;
        _mediaType = ext.endsWith('.png') ? 'image/png' : 'image/jpeg';
        _result = null;
        _error = null;
      });
    } catch (_) {}
  }

  // ── Analysis ──────────────────────────────────────────────────────────
  Future<void> _analyse() async {
    final state = context.read<AppState>();
    if (!state.canScan) {
      showUpgradeModal(context, source: 'scan_limit');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final svc = state.backend;
      ScanResult res;
      if (_scanMode == _ScanMode.text) {
        final desc = _textCtrl.text.trim();
        if (desc.isEmpty) throw Exception('Enter a description first.');
        res = await svc.scanText(desc);
      } else {
        if (_imageBytes == null) throw Exception('Select an image first.');
        res = await svc.scanImage(
          _imageBytes!, _mediaType,
          secondImageBytes: _secondImageBytes,
          secondMediaType: _secondImageBytes != null ? _secondMediaType : null,
        );
      }
      await state.trackScan();
      setState(() { _result = res; _updateResultFlag(); });
      _resultAnim.forward(from: 0);
    } catch (e) {
      setState(
          () => _error = friendlyError(e));
      // Refresh usage from server so UI counter stays accurate after errors
      if (state.isSignedIn) {
        state.refreshUsage();
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _logMeal() async {
    final r = _result;
    if (r == null) return;
    final now = TimeOfDay.now();
    final entry = DiaryEntry(
      id: DateTime.now().millisecondsSinceEpoch,
      time:
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      name: r.mealName,
      calories: r.totalCalories,
      protein: r.proteinG,
      carbs: r.carbsG,
      fat: r.fatG,
      fiber: r.fiberG,
    );
    final state = context.read<AppState>();
    await state.addEntry(entry);

    // Track scan if AI was used for barcode fallback (deferred from _aiEstimateFromBarcode)
    if (_pendingAiScanTrack) {
      await state.trackScan();
      _pendingAiScanTrack = false;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${r.mealName} logged — ${r.totalCalories} Cal'),
          backgroundColor: CLColors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
      setState(() {
        _result = null;
        _imageBytes = null;
        _secondImageBytes = null;
        _error = null;
        _textCtrl.clear();
        _barcodeScanned = false;
        _scannedBarcode = null;
        _barcodeResult = null;
        _showServingPicker = false;
        _pendingAiScanTrack = false;
      });
      _resultAnim.reset();
    }
  }

  /// Update static hasResult flag whenever _result changes
  void _updateResultFlag() {
    ScanScreen.hasResult = _result != null || _barcodeResult != null;
  }

  void _discardResult() {
    // If user discards an AI barcode result without logging, sync the counter
    // with the server (the Edge Function already counted it)
    if (_pendingAiScanTrack) {
      final state = Provider.of<AppState>(context, listen: false);
      state.trackScan();
      _pendingAiScanTrack = false;
    }
    setState(() {
      _result = null;
      _imageBytes = null;
      _secondImageBytes = null;
      _error = null;
      _textCtrl.clear();
      _barcodeScanned = false;
      _scannedBarcode = null;
      _barcodeResult = null;
      _showServingPicker = false;
      _updateResultFlag();
    });
    _resultAnim.reset();
  }

  void _switchMode(_ScanMode mode) {
    // Stop voice input if switching away from Describe
    if (_isListening) { _speech.stop(); _isListening = false; }
    setState(() {
      _scanMode = mode;
      _result = null;
      _error = null;
      if (mode != _ScanMode.barcode) {
        _barcodeScanned = false;
        _scannedBarcode = null;
        _barcodeResult = null;
        _showServingPicker = false;
      }
    });
    ScanScreen.isOnPhotoMode = mode == _ScanMode.photo;
  }

  /// Called by AppShell when back is pressed while on a non-Photo tab.
  void _resetToPhoto() {
    _switchMode(_ScanMode.photo);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildHeader(state),
              const SizedBox(height: 18),
              if (_result != null)
                _buildResultPanel(_result!)
              else ...[
                _buildModeToggle(),
                const SizedBox(height: 16),
                if (_scanMode == _ScanMode.text)
                  _buildTextInput()
                else if (_scanMode == _ScanMode.barcode)
                  _buildBarcodeScanner()
                else
                  _buildPhotoArea(),
                const SizedBox(height: 14),
                if (_error != null && _scanMode != _ScanMode.barcode) _buildError(),
                // Show premium loading animation while analysing
                if (_loading && _scanMode != _ScanMode.barcode)
                  const AnalysisLoadingWidget()
                // Describe mode: always show Analyse button (greyed → active)
                // Photo mode: show banner on landing, Analyse button when image selected
                else if (_scanMode == _ScanMode.text)
                  _buildAnalyseBtn()
                else if (_scanMode == _ScanMode.photo && _imageBytes != null)
                  _buildAnalyseBtn()
                else if (_scanMode == _ScanMode.photo)
                  _buildMealIntelligenceBanner(),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── HEADER ──────────────────────────────────────────────────────────────
  Widget _buildHeader(AppState state) {
    return Row(
      children: [
        // CalNova branding
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: CLColors.text,
                ),
                children: [
                  TextSpan(text: 'Cal'),
                  TextSpan(
                    text: 'Nova',
                    style: TextStyle(color: CLColors.accent, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const Text(
              'AI Nutrition Companion',
              style: TextStyle(
                color: CLColors.muted,
                fontSize: 11,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const Spacer(),
        // Status pill — combines PRO badge + scan count into one element
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: state.isPremium
                ? const Color(0xFF2A1A04)
                : CLColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: state.isPremium
                  ? CLColors.gold.withOpacity(0.5)
                  : (state.isSignedIn || state.hasApiKey)
                      ? CLColors.green.withOpacity(0.4)
                      : CLColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.isPremium) ...[
                Icon(Icons.star, color: CLColors.gold, size: 12),
                const SizedBox(width: 5),
              ] else ...[
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: state.hasApiKey
                        ? CLColors.green
                        : (state.isSignedIn && !state.isAnonymous) ? CLColors.green : CLColors.gold,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                state.hasApiKey
                    ? 'Unlimited'
                    : state.isAnonymous
                        ? 'Guest · ${state.scansRemainingToday} left'
                        : state.isPremium
                            ? 'PRO · ${state.scansRemainingToday} left'
                            : state.isSignedIn
                                ? '${state.scansRemainingToday} left today'
                                : 'Guest',
                style: TextStyle(
                  color: state.isPremium
                      ? CLColors.gold
                      : (state.isSignedIn || state.hasApiKey) ? CLColors.text : CLColors.muted,
                  fontSize: 11,
                  fontWeight: state.isPremium ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── MODE TOGGLE ─────────────────────────────────────────────────────────
  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CLColors.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _modeTab(Icons.camera_alt_outlined, 'Photo', _scanMode == _ScanMode.photo,
              () => _switchMode(_ScanMode.photo)),
          _modeTab(Icons.edit_outlined, 'Describe', _scanMode == _ScanMode.text,
              () => _switchMode(_ScanMode.text)),
          _modeTab(Icons.qr_code_scanner, 'Barcode', _scanMode == _ScanMode.barcode,
              () => _switchMode(_ScanMode.barcode)),
        ],
      ),
    );
  }

  Widget _modeTab(IconData icon, String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? CLColors.accent.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active ? Border.all(color: CLColors.accent.withOpacity(0.5)) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? CLColors.accent : CLColors.muted),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    color: active ? CLColors.accent : CLColors.muted,
                    fontSize: 13, fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  // ── PHOTO AREA (redesigned) ─────────────────────────────────────────────
  Widget _buildPhotoArea() {
    if (_imageBytes != null) return _buildImagePreview();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CLColors.border),
      ),
      child: Column(
        children: [
          // Circular icon with decorative ring
          SizedBox(
            width: 150, height: 150,
            child: CustomPaint(
              painter: _DashedCirclePainter(
                color: CLColors.accent.withOpacity(0.2),
                strokeWidth: 1.5,
                dashLength: 6,
                gapLength: 4,
              ),
              child: Center(
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: CLColors.accentLo,
                    border: Border.all(color: CLColors.accent.withOpacity(0.5), width: 2),
                  ),
                  child: const Icon(Icons.restaurant, color: CLColors.accent, size: 40),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Add your meal photo',
              style: TextStyle(color: CLColors.text, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Take a photo or choose from gallery',
              style: TextStyle(color: CLColors.muted.withOpacity(0.7), fontSize: 13)),
          const SizedBox(height: 28),
          // Camera + Gallery buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: _actionButton(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: CLColors.accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CLColors.accent.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: CLColors.accent, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(color: CLColors.accent, fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Column(
      children: [
        Container(
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: CLColors.accent.withOpacity(0.5), width: 1.5),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: Image.memory(_imageBytes!, fit: BoxFit.cover, width: double.infinity),
              ),
              // Close button
              Positioned(
                top: 10, right: 10,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _imageBytes = null;
                    _secondImageBytes = null;
                    _result = null;
                    _error = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ),
              // Retake button
              Positioned(
                bottom: 12, right: 14,
                child: GestureDetector(
                  onTap: _showImageSourceOptions,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54, borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh, color: Colors.white, size: 13),
                        SizedBox(width: 5),
                        Text('Retake', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              // Second image thumbnail (if present)
              if (_secondImageBytes != null)
                Positioned(
                  bottom: 12, left: 14,
                  child: GestureDetector(
                    onTap: () => setState(() => _secondImageBytes = null),
                    child: Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: CLColors.accent, width: 1.5),
                        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 6)],
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: Image.memory(_secondImageBytes!, fit: BoxFit.cover, width: 56, height: 56),
                          ),
                          Positioned(
                            top: -2, right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // "+ Add angle" button (only if no second image yet)
        if (_secondImageBytes == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: () => _showSecondImageOptions(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: CLColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CLColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: CLColors.muted, size: 15),
                    const SizedBox(width: 6),
                    const Text('Add angle for better accuracy',
                        style: TextStyle(color: CLColors.muted, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showSecondImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: CLColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: CLColors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Add a side-angle photo to help estimate portion depth',
                style: TextStyle(color: CLColors.muted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: CLColors.accent),
              title: const Text('Take Photo', style: TextStyle(color: CLColors.text)),
              onTap: () { Navigator.pop(context); _pickSecondImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: CLColors.accent),
              title: const Text('Choose from Gallery', style: TextStyle(color: CLColors.text)),
              onTap: () { Navigator.pop(context); _pickSecondImage(ImageSource.gallery); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: CLColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: CLColors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: CLColors.accent),
              title: const Text('Take Photo', style: TextStyle(color: CLColors.text)),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: CLColors.accent),
              title: const Text('Choose from Gallery', style: TextStyle(color: CLColors.text)),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── PRO UPSELL (single line, matches mockup) ─────────────────────────
  Widget _buildProUpsell() {
    return GestureDetector(
      onTap: () => showUpgradeModal(context, source: 'scan_limit'),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, color: CLColors.muted, size: 14),
          const SizedBox(width: 6),
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 12),
              children: [
                TextSpan(text: 'Go Pro', style: TextStyle(color: CLColors.gold, fontWeight: FontWeight.w600)),
                TextSpan(text: ' for more scans, meal plans and AI insights.', style: TextStyle(color: CLColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── TEXT INPUT ──────────────────────────────────────────────────────────
  // ── SPEECH-TO-TEXT ──────────────────────────────────────────────────────
  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (error) {
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (status) {
        // 'done' or 'notListening' means the engine stopped
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
    );
    if (mounted) setState(() {});
  }

  void _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    // Lazy-init: only request mic permission when user first taps the button
    if (!_speechAvailable) {
      await _initSpeech();
    }

    if (!_speechAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Voice input is not available on this device. Please allow microphone access.'),
            backgroundColor: CLColors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _textCtrl.text = result.recognizedWords;
          _textCtrl.selection = TextSelection.fromPosition(
            TextPosition(offset: _textCtrl.text.length),
          );
        });
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
    );
  }

  Widget _buildTextInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _textCtrl,
          maxLines: 5,
          style: const TextStyle(color: CLColors.text, fontSize: 14),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'e.g. "Grilled chicken breast with brown rice and salad"',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 10),
        // Mic button
        Center(
          child: GestureDetector(
            onTap: _toggleListening,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _isListening ? CLColors.accent.withOpacity(0.15) : CLColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isListening ? CLColors.accent : CLColors.border,
                  width: _isListening ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isListening ? Icons.stop_circle_outlined : Icons.mic_outlined,
                    color: _isListening ? CLColors.accent : CLColors.muted,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isListening ? 'Listening…  Tap to stop' : 'Tap to describe by voice',
                    style: TextStyle(
                      color: _isListening ? CLColors.accent : CLColors.muted,
                      fontSize: 13,
                      fontWeight: _isListening ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  if (_isListening) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: CLColors.accent.withOpacity(0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── BARCODE SCANNER ────────────────────────────────────────────────────
  Widget _buildBarcodeScanner() {
    if (_barcodeScanned) return _buildBarcodeResultCard();

    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CLColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          MobileScanner(onDetect: _onBarcodeDetected),
          Center(
            child: Container(
              width: 220, height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CLColors.accent, width: 2),
              ),
            ),
          ),
          Positioned(
            bottom: 16, left: 0, right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Point camera at barcode',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_barcodeScanned) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty || barcodes.first.rawValue == null) return;
    final code = barcodes.first.rawValue!;
    setState(() { _barcodeScanned = true; _scannedBarcode = code; _loading = true; });
    _lookupBarcode(code);
  }

  Future<void> _lookupBarcode(String barcode) async {
    try {
      final result = await OpenFoodFactsService.lookup(barcode);
      if (!mounted) return;
      if (result != null && result.nutrition != null) {
        // Show serving size picker before committing result
        setState(() { _barcodeResult = result; _showServingPicker = true; _loading = false; _updateResultFlag(); });
      } else if (result != null && result.productName.isNotEmpty) {
        setState(() { _barcodeResult = result; _loading = false; _updateResultFlag(); });
        // Include package/serving size so AI can estimate more accurately
        String description = result.displayName;
        if (result.packageSize != null) {
          description += ' (${result.packageSize}g package)';
        }
        if (result.servingSize != null) {
          description += ', serving size: ${result.servingSize}';
        }
        _aiEstimateFromBarcode(description);
      } else {
        setState(() { _barcodeResult = result; _loading = false; _updateResultFlag(); });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = friendlyError(e); });
    }
  }

  Future<void> _aiEstimateFromBarcode(String productDescription) async {
    setState(() { _loading = true; _error = null; });
    try {
      final state = Provider.of<AppState>(context, listen: false);
      final result = await state.backend.scanText(productDescription);
      if (!mounted) return;
      // Don't track scan yet — wait until the user taps LOG MEAL
      // The server-side counter was already incremented by the Edge Function,
      // but we defer the local UI update so the pill count doesn't drop prematurely.
      setState(() { _result = result; _loading = false; _pendingAiScanTrack = true; _updateResultFlag(); });
      _resultAnim.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = friendlyError(e); });
      // Refresh usage from server so UI counter stays accurate after errors
      final state = Provider.of<AppState>(context, listen: false);
      if (state.isSignedIn) {
        state.refreshUsage();
      }
    }
  }

  Widget _buildBarcodeResultCard() {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: CLColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: CLColors.border)),
        child: Column(
          children: [
            const CircularProgressIndicator(color: CLColors.accent),
            const SizedBox(height: 16),
            Text('Looking up barcode $_scannedBarcode...',
                style: const TextStyle(color: CLColors.muted, fontSize: 13), textAlign: TextAlign.center),
          ],
        ),
      );
    }
    if (_showServingPicker && _barcodeResult != null) return _buildServingSizePicker();
    if (_result != null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: CLColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: CLColors.border)),
      child: Column(
        children: [
          const Icon(Icons.search_off, color: CLColors.muted, size: 40),
          const SizedBox(height: 12),
          Text('Product not found for barcode $_scannedBarcode',
              style: const TextStyle(color: CLColors.muted, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          const Text('Type the product name and we\'ll estimate the nutrition with AI.',
              style: TextStyle(color: CLColors.muted, fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 14),
          TextField(
            controller: _barcodeNameCtrl,
            style: const TextStyle(color: CLColors.text, fontSize: 14),
            decoration: const InputDecoration(hintText: 'e.g. Simba Chips Original 125g', isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 14)),
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _submitBarcodeName(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitBarcodeName,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('ESTIMATE WITH AI', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              style: ElevatedButton.styleFrom(backgroundColor: CLColors.accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () { setState(() { _barcodeScanned = false; _scannedBarcode = null; _barcodeResult = null; _showServingPicker = false; _error = null; }); },
            icon: const Icon(Icons.qr_code_scanner, size: 16),
            label: const Text('Scan Another Barcode'),
            style: TextButton.styleFrom(foregroundColor: CLColors.muted, padding: const EdgeInsets.symmetric(vertical: 8)),
          ),
        ],
      ),
    );
  }

  /// Serving size picker shown after a successful barcode lookup.
  Widget _buildServingSizePicker() {
    final br = _barcodeResult!;
    final nutrition = br.nutrition!;
    final servingLabel = br.servingSize ?? 'serving';
    final packageLabel = br.packageSize != null ? '${br.packageSize}' : null;

    // Calculate how many servings in the package (rough estimate)
    // We'll offer: 1 serving, ½ serving, whole package (if package size known), custom
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CLColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product header
          Row(
            children: [
              const Icon(Icons.check_circle, color: CLColors.green, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(br.displayName,
                    style: const TextStyle(color: CLColors.text, fontSize: 15, fontWeight: FontWeight.w600),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Serving size: $servingLabel${packageLabel != null ? '  ·  Package: $packageLabel' : ''}',
              style: const TextStyle(color: CLColors.muted, fontSize: 12)),
          Text('${nutrition.totalCalories} Cal per serving',
              style: const TextStyle(color: CLColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          const Text('How much did you eat?',
              style: TextStyle(color: CLColors.text, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          // Quick options
          _servingOption('1 serving ($servingLabel)', 1.0),
          const SizedBox(height: 6),
          _servingOption('½ serving', 0.5),
          const SizedBox(height: 6),
          _servingOption('2 servings', 2.0),
          if (packageLabel != null) ...[
            const SizedBox(height: 6),
            _servingOption('Whole package ($packageLabel)', _estimatePackageMultiplier(br)),
          ],
          const SizedBox(height: 12),
          // Custom amount
          _buildCustomServingRow(),
          const SizedBox(height: 12),
          // Scan another
          Center(
            child: TextButton.icon(
              onPressed: () { setState(() { _barcodeScanned = false; _scannedBarcode = null; _barcodeResult = null; _showServingPicker = false; _error = null; }); },
              icon: const Icon(Icons.qr_code_scanner, size: 16),
              label: const Text('Scan Another Barcode'),
              style: TextButton.styleFrom(foregroundColor: CLColors.muted, padding: const EdgeInsets.symmetric(vertical: 8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _servingOption(String label, double multiplier) {
    final cals = (_barcodeResult!.nutrition!.totalCalories * multiplier).round();
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => _applyServingMultiplier(multiplier, label),
        style: OutlinedButton.styleFrom(
          foregroundColor: CLColors.text,
          side: const BorderSide(color: CLColors.border),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            Text('$cals Cal', style: const TextStyle(color: CLColors.accent, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  final _customServingCtrl = TextEditingController();

  Widget _buildCustomServingRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _customServingCtrl,
            style: const TextStyle(color: CLColors.text, fontSize: 13),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: 'Custom (e.g. 1.5)',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            final val = double.tryParse(_customServingCtrl.text.trim());
            if (val != null && val > 0) {
              _applyServingMultiplier(val, '${_customServingCtrl.text.trim()} servings');
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: CLColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          ),
          child: const Text('GO', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  double _estimatePackageMultiplier(BarcodeResult br) {
    // Try to figure out how many servings in the package
    // If we can parse both values, calculate the ratio
    if (br.packageSize != null && br.servingSize != null) {
      final pkgG = _parseGrams(br.packageSize!);
      final srvG = _parseGrams(br.servingSize!);
      if (pkgG != null && srvG != null && srvG > 0) {
        return pkgG / srvG;
      }
    }
    // Fallback: can't determine, assume 3 servings (reasonable default)
    return 3.0;
  }

  double? _parseGrams(String s) {
    // Try to extract a number (possibly with "g", "ml", "kg", "l")
    final match = RegExp(r'([\d.]+)\s*(kg|g|l|ml)?', caseSensitive: false).firstMatch(s);
    if (match == null) return null;
    final num = double.tryParse(match.group(1)!);
    if (num == null) return null;
    final unit = (match.group(2) ?? 'g').toLowerCase();
    if (unit == 'kg' || unit == 'l') return num * 1000;
    return num; // g or ml
  }

  void _applyServingMultiplier(double multiplier, String label) {
    final nutrition = _barcodeResult!.nutrition!;
    final scaled = ScanResult(
      mealName: nutrition.mealName,
      totalCalories: (nutrition.totalCalories * multiplier).round(),
      proteinG: (nutrition.proteinG * multiplier).round(),
      carbsG: (nutrition.carbsG * multiplier).round(),
      fatG: (nutrition.fatG * multiplier).round(),
      fiberG: (nutrition.fiberG * multiplier).round(),
      items: nutrition.items.map((item) => FoodItem(
        name: item.name,
        portion: label,
        calories: (item.calories * multiplier).round(),
        note: item.note,
      )).toList(),
      overallNotes: nutrition.overallNotes,
    );
    setState(() {
      _result = scaled;
      _showServingPicker = false;
      _updateResultFlag();
    });
    _resultAnim.forward(from: 0);
  }

  void _submitBarcodeName() {
    final name = _barcodeNameCtrl.text.trim();
    if (name.isEmpty) return;
    _barcodeNameCtrl.clear();
    _aiEstimateFromBarcode(name);
  }

  // ── SCAN LIMIT BAR ──────────────────────────────────────────────────────
  // ── ERROR ────────────────────────────────────────────────────────────────
  Widget _buildError() {
    final isRetryable = _error != null &&
        !_error!.contains('limit') &&
        !_error!.contains('Limit') &&
        !_error!.contains('Enter a description') &&
        !_error!.contains('Select an image');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CLColors.redLo, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CLColors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('$_error',
                style: const TextStyle(color: CLColors.red, fontSize: 13)),
          ),
          if (isRetryable) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _analyse,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: CLColors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Retry',
                    style: TextStyle(
                        color: CLColors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── MEAL INTELLIGENCE BANNER (shown on landing before image/text is ready) ─
  Widget _buildMealIntelligenceBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1814),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CLColors.accent.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          // Sparkle icon in circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: CLColors.accent.withOpacity(0.5), width: 1.5),
            ),
            child: const Center(
              child: Text('✨', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 14),
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Meal Intelligence',
                  style: TextStyle(
                    color: CLColors.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Calories  •  Protein  •  Carbs  •  Fat',
                  style: TextStyle(
                    color: CLColors.text.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'AI-powered nutrition breakdown',
                  style: TextStyle(
                    color: CLColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── ANALYSE BUTTON (redesigned as gradient CTA) ──────────────────────────
  Widget _buildAnalyseBtn() {
    if (_scanMode == _ScanMode.barcode) return const SizedBox.shrink();
    final canGo = _scanMode == _ScanMode.text ? _textCtrl.text.trim().length > 3 : _imageBytes != null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: !canGo
              ? [CLColors.muted2, CLColors.muted2]
              : [CLColors.accent, const Color(0xFFE8943A)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: !canGo ? null : _analyse,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ANALYSE MY MEAL',
                          style: TextStyle(
                            color: Colors.white.withOpacity(canGo ? 1 : 0.5),
                            fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5,
                          )),
                      const SizedBox(height: 2),
                      Text('Get calories, macros and insights',
                          style: TextStyle(color: Colors.white.withOpacity(canGo ? 0.7 : 0.3), fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.white.withOpacity(canGo ? 0.8 : 0.3), size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── RESULT PANEL ────────────────────────────────────────────────────────
  void _showEditSheet(ScanResult r) {
    final itemCtrls = r.items.map((item) => TextEditingController(text: '${item.portion} ${item.name}')).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CLColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Correct Food Items',
                        style: TextStyle(color: CLColors.text, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text('Fix any item names or quantities the AI got wrong, then re-analyse to recalculate nutrition.',
                        style: TextStyle(color: CLColors.muted, fontSize: 12)),
                    const SizedBox(height: 14),
                    ...List.generate(itemCtrls.length, (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: itemCtrls[i],
                              style: const TextStyle(color: CLColors.text, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Food item ${i + 1}',
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.only(left: 12, right: 8),
                                  child: Text('${i + 1}.',
                                      style: const TextStyle(color: CLColors.accent, fontSize: 14, fontWeight: FontWeight.w600)),
                                ),
                                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              ),
                            ),
                          ),
                          if (itemCtrls.length > 1)
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: CLColors.muted),
                              onPressed: () { setSheetState(() { itemCtrls[i].dispose(); itemCtrls.removeAt(i); }); },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            ),
                        ],
                      ),
                    )),
                    TextButton.icon(
                      onPressed: () { setSheetState(() { itemCtrls.add(TextEditingController()); }); },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add item'),
                      style: TextButton.styleFrom(foregroundColor: CLColors.accent, padding: const EdgeInsets.symmetric(horizontal: 8)),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final items = itemCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                          if (items.isEmpty) return;
                          Navigator.pop(ctx);
                          _reAnalyse(items, r);
                        },
                        icon: const Icon(Icons.auto_fix_high, size: 18),
                        label: const Text('RE-ANALYSE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1)),
                        style: ElevatedButton.styleFrom(backgroundColor: CLColors.accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _reAnalyse(List<String> items, ScanResult original) async {
    final description = items.join(', ');
    setState(() { _loading = true; _result = null; _updateResultFlag(); });
    _resultAnim.reset();
    try {
      final state = Provider.of<AppState>(context, listen: false);
      // Pass isCorrection: true so neither the Edge Function nor local
      // counter charge a scan — the user already spent one on the original.
      final result = await state.backend.scanText(
        description,
        isCorrection: true,
        originalContext: {
          'name': original.mealName,
          'calories': original.totalCalories,
          'protein': original.proteinG,
          'carbs': original.carbsG,
          'fat': original.fatG,
          'fiber': original.fiberG,
        },
      );
      setState(() { _result = result; _loading = false; _updateResultFlag(); });
      _resultAnim.forward(from: 0);
      // No trackScan() here — corrections are free
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Widget _buildResultPanel(ScanResult r) {
    return FadeTransition(
      opacity: _resultFade,
      child: SlideTransition(
        position: _resultSlide,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1A1208), Color(0xFF110F0D)], begin: Alignment.topLeft),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: CLColors.accent.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(r.mealName,
                      style: const TextStyle(color: CLColors.text, fontSize: 18, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${r.totalCalories}',
                          style: const TextStyle(color: CLColors.accent, fontSize: 56, fontWeight: FontWeight.w800, height: 1)),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10, left: 6),
                        child: Text('kcal', style: TextStyle(color: CLColors.muted, fontSize: 16)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _macroChip('Protein', '${r.proteinG}g', CLColors.blue),
                      _macroChip('Carbs', '${r.carbsG}g', CLColors.green),
                      _macroChip('Fat', '${r.fatG}g', CLColors.accent),
                      _macroChip('Fibre', '${r.fiberG}g', CLColors.muted),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...r.items.map((item) => _itemRow(item)),
            const SizedBox(height: 10),
            if (r.overallNotes.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: CLColors.surface2, borderRadius: BorderRadius.circular(12)),
                child: Text(r.overallNotes, style: const TextStyle(color: CLColors.muted, fontSize: 13, height: 1.5)),
              ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _logMeal,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('LOG MEAL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1)),
                    style: ElevatedButton.styleFrom(backgroundColor: CLColors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditSheet(r),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Correct'),
                    style: OutlinedButton.styleFrom(foregroundColor: CLColors.accent, side: BorderSide(color: CLColors.accent.withOpacity(0.4)), padding: const EdgeInsets.symmetric(horizontal: 16)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _discardResult,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Scan Another Meal'),
                style: TextButton.styleFrom(foregroundColor: CLColors.muted, padding: const EdgeInsets.symmetric(vertical: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _macroChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: CLColors.muted, fontSize: 11)),
      ],
    );
  }

  Widget _itemRow(FoodItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(item.name, style: const TextStyle(color: CLColors.text, fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                    if (item.source == 'usda') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'USDA',
                          style: TextStyle(color: Color(0xFF66BB6A), fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(item.portion, style: const TextStyle(color: CLColors.muted, fontSize: 11)),
              ],
            ),
          ),
          Text('${item.calories}', style: const TextStyle(color: CLColors.accent, fontSize: 14, fontWeight: FontWeight.w600)),
          const Text(' kcal', style: TextStyle(color: CLColors.muted, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Dashed circle painter for the photo area ──────────────────────────────
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  _DashedCirclePainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashLength = 6,
    this.gapLength = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final radius = math.min(size.width, size.height) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final circumference = 2 * math.pi * radius;
    final dashCount = (circumference / (dashLength + gapLength)).floor();
    final anglePerDash = 2 * math.pi / dashCount;
    final sweepAngle = anglePerDash * (dashLength / (dashLength + gapLength));

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * anglePerDash;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
