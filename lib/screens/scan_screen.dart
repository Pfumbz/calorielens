import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models/models.dart';
import '../services/openfoodfacts_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/upgrade_modal.dart';


enum _ScanMode { photo, text, barcode }

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  /// Whether the scan screen currently has a result showing (used by AppShell for back nav).
  static bool hasResult = false;

  /// Clears the result and goes back to scan input (called by AppShell on back press).
  static VoidCallback? clearResult;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();
  final _textCtrl = TextEditingController();
  final _barcodeNameCtrl = TextEditingController();

  Uint8List? _imageBytes;
  String _mediaType = 'image/jpeg';
  _ScanMode _scanMode = _ScanMode.photo;
  bool _loading = false;
  String? _error;
  ScanResult? _result;

  // Barcode state
  bool _barcodeScanned = false;
  String? _scannedBarcode;
  BarcodeResult? _barcodeResult;

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
  }

  @override
  void dispose() {
    ScanScreen.clearResult = null;
    ScanScreen.hasResult = false;
    _textCtrl.dispose();
    _barcodeNameCtrl.dispose();
    _resultAnim.dispose();
    super.dispose();
  }

  // ── Image picking ─────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    try {
      final img = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
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
    if (!state.canScan && !state.isPremium) {
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
        res = await svc.scanImage(_imageBytes!, _mediaType);
      }
      await state.trackScan();
      setState(() { _result = res; _updateResultFlag(); });
      _resultAnim.forward(from: 0);
    } catch (e) {
      setState(
          () => _error = e.toString().replaceFirst('Exception: ', ''));
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
    await context.read<AppState>().addEntry(entry);
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
        _error = null;
        _textCtrl.clear();
        _barcodeScanned = false;
        _scannedBarcode = null;
        _barcodeResult = null;
      });
      _resultAnim.reset();
    }
  }

  /// Update static hasResult flag whenever _result changes
  void _updateResultFlag() {
    ScanScreen.hasResult = _result != null || _barcodeResult != null;
  }

  void _discardResult() {
    setState(() {
      _result = null;
      _imageBytes = null;
      _error = null;
      _textCtrl.clear();
      _barcodeScanned = false;
      _scannedBarcode = null;
      _barcodeResult = null;
      _updateResultFlag();
    });
    _resultAnim.reset();
  }

  void _switchMode(_ScanMode mode) {
    setState(() {
      _scanMode = mode;
      _result = null;
      _error = null;
      if (mode != _ScanMode.barcode) {
        _barcodeScanned = false;
        _scannedBarcode = null;
        _barcodeResult = null;
      }
    });
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
                // Analyse button
                _buildAnalyseBtn(),
                if (!state.isPremium && !state.hasApiKey) ...[
                  const SizedBox(height: 14),
                  _buildProUpsell(),
                ],
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
        // CalorieLens branding — flexible to shrink on narrow screens
        Flexible(
          child: RichText(
            overflow: TextOverflow.ellipsis,
            text: const TextSpan(
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: CLColors.text,
              ),
              children: [
                TextSpan(text: 'Calorie'),
                TextSpan(
                  text: 'Lens',
                  style: TextStyle(color: CLColors.accent, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // PRO badge
        if (state.isPremium)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF433510), Color(0xFF2A1A04)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: CLColors.gold.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, color: CLColors.gold, size: 12),
                const SizedBox(width: 4),
                const Text('PRO',
                    style: TextStyle(color: CLColors.gold, fontSize: 10,
                        fontWeight: FontWeight.w800, letterSpacing: 1)),
              ],
            ),
          ),
        // Scan counter pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: CLColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (state.isSignedIn || state.hasApiKey)
                  ? CLColors.green.withOpacity(0.4)
                  : CLColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: (state.isPremium || state.hasApiKey)
                      ? CLColors.green
                      : (state.isSignedIn && !state.isAnonymous) ? CLColors.green : CLColors.gold,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                state.hasApiKey
                    ? 'Unlimited'
                    : state.isAnonymous
                        ? 'Guest · ${state.scansRemainingToday} left'
                        : state.isPremium
                            ? 'Pro · ${state.scansRemainingToday} left today'
                            : state.isSignedIn
                                ? '${state.scansRemainingToday} left today'
                                : 'Guest',
                style: TextStyle(
                  color: (state.isSignedIn || state.hasApiKey) ? CLColors.text : CLColors.muted,
                  fontSize: 11,
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
    return Container(
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
          Positioned(
            top: 10, right: 10,
            child: GestureDetector(
              onTap: () => setState(() {
                _imageBytes = null;
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
        ],
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
  Widget _buildTextInput() {
    return TextField(
      controller: _textCtrl,
      maxLines: 5,
      style: const TextStyle(color: CLColors.text, fontSize: 14),
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        hintText: 'e.g. "Grilled chicken breast with brown rice and salad"',
        alignLabelWithHint: true,
      ),
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
        setState(() { _barcodeResult = result; _result = result.nutrition; _loading = false; _updateResultFlag(); });
        _resultAnim.forward(from: 0);
      } else if (result != null && result.productName.isNotEmpty) {
        setState(() { _barcodeResult = result; _loading = false; _updateResultFlag(); });
        _aiEstimateFromBarcode(result.displayName);
      } else {
        setState(() { _barcodeResult = result; _loading = false; _updateResultFlag(); });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Lookup failed: ${e.toString().replaceFirst("Exception: ", "")}'; });
    }
  }

  Future<void> _aiEstimateFromBarcode(String productDescription) async {
    setState(() { _loading = true; _error = null; });
    try {
      final state = Provider.of<AppState>(context, listen: false);
      final result = await state.backend.scanText(productDescription);
      if (!mounted) return;
      setState(() { _result = result; _loading = false; _updateResultFlag(); });
      _resultAnim.forward(from: 0);
      await state.trackScan();
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString().replaceFirst('Exception: ', ''); });
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
            onPressed: () { setState(() { _barcodeScanned = false; _scannedBarcode = null; _barcodeResult = null; _error = null; }); },
            icon: const Icon(Icons.qr_code_scanner, size: 16),
            label: const Text('Scan Another Barcode'),
            style: TextButton.styleFrom(foregroundColor: CLColors.muted, padding: const EdgeInsets.symmetric(vertical: 8)),
          ),
        ],
      ),
    );
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CLColors.redLo, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CLColors.red.withOpacity(0.3)),
      ),
      child: Text('$_error', style: const TextStyle(color: CLColors.red, fontSize: 13)),
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
          colors: (_loading || !canGo)
              ? [CLColors.muted2, CLColors.muted2]
              : [CLColors.accent, const Color(0xFFE8943A)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (_loading || !canGo) ? null : _analyse,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            child: _loading
                ? const Center(
                    child: SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)))
                : Row(
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
    final itemCtrls = r.items.map((item) => TextEditingController(text: item.name)).toList();

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
                    const Text('Fix any item names the AI got wrong, then re-analyse to recalculate nutrition.',
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
                          _reAnalyse(items);
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

  Future<void> _reAnalyse(List<String> items) async {
    final description = items.join(', ');
    setState(() { _loading = true; _result = null; _updateResultFlag(); });
    _resultAnim.reset();
    try {
      final state = Provider.of<AppState>(context, listen: false);
      final result = await state.backend.scanText(description);
      setState(() { _result = result; _loading = false; _updateResultFlag(); });
      _resultAnim.forward(from: 0);
      await state.trackScan();
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red.shade700),
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
                Text(item.name, style: const TextStyle(color: CLColors.text, fontSize: 13, fontWeight: FontWeight.w500)),
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
