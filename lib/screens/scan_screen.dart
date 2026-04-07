import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models/models.dart';
import '../services/anthropic_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/upgrade_modal.dart';
import 'settings_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _picker = ImagePicker();
  final _textCtrl = TextEditingController();

  Uint8List? _imageBytes;
  String _mediaType = 'image/jpeg';
  bool _textMode = false;
  bool _loading = false;
  String? _error;
  ScanResult? _result;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final img = await _picker.pickImage(source: source, imageQuality: 85);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    final ext = img.path.toLowerCase();
    setState(() {
      _imageBytes = bytes;
      _mediaType = ext.endsWith('.png') ? 'image/png' : 'image/jpeg';
      _result = null;
      _error = null;
    });
  }

  Future<void> _analyse() async {
    final state = context.read<AppState>();
    if (!state.hasApiKey) {
      setState(() => _error = 'Add your Anthropic API key in Settings first.');
      return;
    }
    if (!state.canScan && !state.isPremium) {
      showUpgradeModal(context, source: 'scan_limit');
      return;
    }

    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final svc = AnthropicService(state.apiKey);
      ScanResult res;
      if (_textMode) {
        final desc = _textCtrl.text.trim();
        if (desc.isEmpty) throw Exception('Enter a description first.');
        res = await svc.scanText(desc);
      } else {
        if (_imageBytes == null) throw Exception('Select an image first.');
        res = await svc.scanImage(_imageBytes!, _mediaType);
      }
      await state.trackScan();
      setState(() => _result = res);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
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
      time: '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}',
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      setState(() => _result = null);
    }
  }

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
              const SizedBox(height: 20),
              _buildHeader(context, state),
              const SizedBox(height: 20),
              _buildModeToggle(),
              const SizedBox(height: 16),
              if (_textMode) _buildTextInput() else _buildImagePicker(),
              if (!state.isPremium) _buildScanLimit(state),
              const SizedBox(height: 12),
              if (_error != null) _buildError(),
              _buildAnalyseBtn(),
              if (_result != null) _buildResult(_result!),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: CLColors.text,
            ),
            children: [
              TextSpan(text: 'Calorie'),
              TextSpan(text: 'Lens', style: TextStyle(color: CLColors.accent, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
        Row(
          children: [
            if (state.isPremium)
              GestureDetector(
                onTap: () => showUpgradeModal(context, source: 'settings'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF433510), Color(0xFF2A1A04)]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: CLColors.gold.withOpacity(0.5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.star, color: CLColors.gold, size: 10),
                      SizedBox(width: 4),
                      Text('PRO', style: TextStyle(color: CLColors.gold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    ],
                  ),
                ),
              ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: CLColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: state.hasApiKey ? CLColors.green.withOpacity(0.4) : CLColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: state.hasApiKey ? CLColors.green : CLColors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('Settings', style: TextStyle(color: state.hasApiKey ? CLColors.text : CLColors.muted, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CLColors.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _modeBtn('📸  Photo', !_textMode, () => setState(() { _textMode = false; _result = null; })),
          _modeBtn('✏️  Describe', _textMode, () => setState(() { _textMode = true; _result = null; })),
        ],
      ),
    );
  }

  Widget _modeBtn(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? CLColors.accent.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: active ? Border.all(color: CLColors.accent.withOpacity(0.5)) : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? CLColors.accent : CLColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: () => _showImageSourceSheet(),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: CLColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _imageBytes != null ? CLColors.accent.withOpacity(0.4) : CLColors.border,
            width: _imageBytes != null ? 1.5 : 1,
          ),
        ),
        child: _imageBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Image.memory(_imageBytes!, fit: BoxFit.cover, width: double.infinity),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined, color: CLColors.muted, size: 36),
                  const SizedBox(height: 10),
                  Text('Tap to take or select a photo', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  Text('of your meal', style: TextStyle(color: CLColors.muted.withOpacity(0.6), fontSize: 12)),
                ],
              ),
      ),
    );
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: CLColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: CLColors.border, borderRadius: BorderRadius.circular(2))),
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

  Widget _buildTextInput() {
    return TextField(
      controller: _textCtrl,
      maxLines: 4,
      style: const TextStyle(color: CLColors.text, fontSize: 14),
      decoration: const InputDecoration(
        hintText: 'e.g. "Grilled chicken breast with brown rice and salad"',
        alignLabelWithHint: true,
      ),
    );
  }

  Widget _buildScanLimit(AppState state) {
    final used = StorageService().scanCountToday;
    final left = (3 - used).clamp(0, 3);
    final pct  = used / 3.0;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: CLColors.border,
                color: left == 0 ? CLColors.red : left == 1 ? CLColors.accent : CLColors.green,
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            left == 0 ? 'Limit reached' : '$left scan${left == 1 ? '' : 's'} left',
            style: TextStyle(
              fontSize: 11,
              color: left == 0 ? CLColors.red : CLColors.muted,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => showUpgradeModal(context, source: 'scan_limit'),
            child: const Text('Go Pro', style: TextStyle(fontSize: 11, color: CLColors.gold, decoration: TextDecoration.underline)),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CLColors.redLo,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CLColors.red.withOpacity(0.3)),
      ),
      child: Text('⚠ $_error', style: const TextStyle(color: CLColors.red, fontSize: 13)),
    );
  }

  Widget _buildAnalyseBtn() {
    final canGo = _textMode
        ? _textCtrl.text.trim().length > 3
        : _imageBytes != null;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_loading || !canGo) ? null : _analyse,
        child: _loading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text('ANALYSE MY MEAL'),
      ),
    );
  }

  Widget _buildResult(ScanResult r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        // Hero
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A1208), Color(0xFF110F0D)],
              begin: Alignment.topLeft,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: CLColors.accent.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(r.mealName, style: const TextStyle(color: CLColors.text, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${r.totalCalories}', style: const TextStyle(color: CLColors.accent, fontSize: 52, fontWeight: FontWeight.w700, height: 1)),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10, left: 6),
                    child: Text('kcal', style: TextStyle(color: CLColors.muted, fontSize: 16)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
        const SizedBox(height: 12),
        // Items
        ...r.items.map((item) => _itemRow(item)),
        const SizedBox(height: 8),
        // Notes
        if (r.overallNotes.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CLColors.surface2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(r.overallNotes, style: const TextStyle(color: CLColors.muted, fontSize: 13, height: 1.45)),
          ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _logMeal,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('LOG THIS MEAL'),
            style: ElevatedButton.styleFrom(backgroundColor: CLColors.green, foregroundColor: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _macroChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: CLColors.muted, fontSize: 11)),
      ],
    );
  }

  Widget _itemRow(FoodItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
