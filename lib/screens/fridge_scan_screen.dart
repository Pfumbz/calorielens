import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../data/meal_plans.dart';
import '../models/meal_plan.dart';
import '../theme.dart';
import '../widgets/upgrade_modal.dart';
import 'plan_detail_screen.dart';

/// Fridge scanner: take a photo of fridge/pantry → AI identifies ingredients
/// → match against curated meal plans → show suggestions.
class FridgeScanScreen extends StatefulWidget {
  const FridgeScanScreen({super.key});

  @override
  State<FridgeScanScreen> createState() => _FridgeScanScreenState();
}

class _FridgeScanScreenState extends State<FridgeScanScreen>
    with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();

  Uint8List? _imageBytes;
  String _mediaType = 'image/jpeg';
  bool _loading = false;
  String? _error;
  List<String>? _ingredients;
  List<MealPlan> _suggestedPlans = [];

  late AnimationController _resultAnim;
  late Animation<double> _resultFade;

  @override
  void initState() {
    super.initState();
    _resultAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _resultFade =
        CurvedAnimation(parent: _resultAnim, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _resultAnim.dispose();
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
      _ingredients = null;
      _suggestedPlans = [];
      _error = null;
    });
  }

  Future<void> _scanFridge() async {
    if (_imageBytes == null) return;

    final state = context.read<AppState>();
    if (!state.canScan && !state.isPremium) {
      showUpgradeModal(context, source: 'scan_limit');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _ingredients = null;
      _suggestedPlans = [];
    });

    try {
      final ingredients = await state.backend.scanFridge(
        _imageBytes!,
        _mediaType,
      );
      await state.trackScan();

      // Match ingredients against curated plans
      final suggestions = _matchPlans(ingredients);

      setState(() {
        _ingredients = ingredients;
        _suggestedPlans = suggestions;
      });
      _resultAnim.forward(from: 0);
    } catch (e) {
      setState(
          () => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Matches identified ingredients against curated meal plans.
  /// Returns plans sorted by number of matching ingredients (descending).
  List<MealPlan> _matchPlans(List<String> ingredients) {
    final lowerIngredients =
        ingredients.map((i) => i.toLowerCase()).toList();

    final scored = <MealPlan, int>{};
    for (final plan in kMealPlans) {
      int matches = 0;
      for (final meal in plan.meals) {
        for (final ingredient in meal.ingredients) {
          final name = ingredient.name.toLowerCase();
          for (final found in lowerIngredients) {
            // Fuzzy match: either the found ingredient contains the
            // plan ingredient name, or vice versa
            if (found.contains(name) || name.contains(found)) {
              matches++;
              break;
            }
          }
        }
      }
      if (matches > 0) scored[plan] = matches;
    }

    // Sort by match count descending, take top 5
    final sorted = scored.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(5).map((e) => e.key).toList();
  }

  void _reset() {
    setState(() {
      _imageBytes = null;
      _ingredients = null;
      _suggestedPlans = [];
      _error = null;
    });
    _resultAnim.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLColors.bg,
      appBar: AppBar(
        backgroundColor: CLColors.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Scan My Fridge',
            style: TextStyle(
                color: CLColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Explainer
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CLColors.accentLo,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: CLColors.accent.withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    Text('📷', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Snap your fridge or pantry',
                            style: TextStyle(
                                color: CLColors.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'AI identifies your ingredients and suggests meal plans you can make',
                            style: TextStyle(
                                color: CLColors.muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Image picker / preview
              if (_ingredients != null)
                _buildResults()
              else ...[
                _buildImageArea(),
                const SizedBox(height: 14),
                if (_error != null) _buildError(),
                _buildScanButton(),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageArea() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _imageBytes != null
              ? CLColors.accent.withOpacity(0.5)
              : CLColors.border,
        ),
      ),
      child: _imageBytes != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(19),
                  child: Image.memory(_imageBytes!,
                      fit: BoxFit.cover, width: double.infinity),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _imageBytes = null;
                      _error = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: CLColors.accent.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: CLColors.accent.withOpacity(0.25)),
                  ),
                  child: Icon(Icons.kitchen,
                      color: CLColors.accent.withOpacity(0.7), size: 28),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Photo of your fridge or pantry',
                  style: TextStyle(
                    color: CLColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Show us what you have to work with',
                  style: TextStyle(
                      color: CLColors.muted.withOpacity(0.7),
                      fontSize: 12),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _photoActionBtn(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                    const SizedBox(width: 12),
                    _photoActionBtn(
                      icon: Icons.photo_library_outlined,
                      label: 'Gallery',
                      onTap: () => _pickImage(ImageSource.gallery),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _photoActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        decoration: BoxDecoration(
          color: CLColors.accent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CLColors.accent.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: CLColors.accent, size: 19),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: CLColors.accent,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
      child: Text('⚠ $_error',
          style: const TextStyle(color: CLColors.red, fontSize: 13)),
    );
  }

  Widget _buildScanButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (_loading || _imageBytes == null) ? null : _scanFridge,
        icon: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.search, size: 18),
        label: Text(
            _loading ? 'SCANNING YOUR FRIDGE...' : 'IDENTIFY INGREDIENTS'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildResults() {
    return FadeTransition(
      opacity: _resultFade,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fridge photo thumbnail
          if (_imageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: Image.memory(_imageBytes!, fit: BoxFit.cover),
              ),
            ),
          const SizedBox(height: 16),

          // Identified ingredients
          const Text('Found Ingredients',
              style: TextStyle(
                  color: CLColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (_ingredients ?? []).map((ing) {
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: CLColors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: CLColors.green.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        color: CLColors.green, size: 14),
                    const SizedBox(width: 6),
                    Text(ing,
                        style: const TextStyle(
                            color: CLColors.text,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),

          // Suggested plans
          if (_suggestedPlans.isNotEmpty) ...[
            const Text('Suggested Meal Plans',
                style: TextStyle(
                    color: CLColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
                'Plans that use ingredients you already have',
                style:
                    TextStyle(color: CLColors.muted, fontSize: 12)),
            const SizedBox(height: 12),
            ..._suggestedPlans.map((plan) => _SuggestionCard(
                  plan: plan,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PlanDetailScreen(plan: plan)),
                  ),
                )),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: CLColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: CLColors.border),
              ),
              child: const Column(
                children: [
                  Text('🤷', style: TextStyle(fontSize: 32)),
                  SizedBox(height: 10),
                  Text("No matching plans found",
                      style: TextStyle(
                          color: CLColors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text(
                    'Try generating a personalised plan based on these ingredients',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: CLColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Scan again button
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Scan Again'),
              style: TextButton.styleFrom(
                foregroundColor: CLColors.muted,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Suggestion Card ─────────────────────────────────────────────────────────
class _SuggestionCard extends StatelessWidget {
  final MealPlan plan;
  final VoidCallback onTap;
  const _SuggestionCard({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CLColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CLColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: CLColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(plan.emoji,
                    style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.name,
                      style: const TextStyle(
                          color: CLColors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(
                    'R${plan.estimatedCostZAR.toStringAsFixed(0)} · ${plan.totalCalories} kcal',
                    style: const TextStyle(
                        color: CLColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: CLColors.muted, size: 18),
          ],
        ),
      ),
    );
  }
}
