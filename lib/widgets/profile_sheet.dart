import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../theme.dart';

/// Opens the profile editing bottom sheet from anywhere in the app.
void showProfileSheet(BuildContext context) {
  final state = context.read<AppState>();
  final nameCtrl = TextEditingController(text: state.profile.name);
  final ageCtrl = TextEditingController(
      text: state.profile.age > 0 ? '${state.profile.age}' : '');
  final weightCtrl = TextEditingController(
      text: state.profile.weight > 0 ? '${state.profile.weight}' : '');
  final heightCtrl = TextEditingController(
      text: state.profile.height > 0 ? '${state.profile.height}' : '');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: CLColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: CLColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: CLColors.blue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_outline,
                        color: CLColors.blue, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Edit Profile',
                          style: TextStyle(
                              color: CLColors.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      Text('Used to calculate your calorie target',
                          style:
                              TextStyle(color: CLColors.muted, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Fields
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: CLColors.text),
                decoration: const InputDecoration(
                  hintText: 'Name',
                  prefixIcon: Icon(Icons.badge_outlined,
                      color: CLColors.muted, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ageCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: CLColors.text),
                      decoration: const InputDecoration(
                        hintText: 'Age',
                        suffixText: 'yrs',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: weightCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: CLColors.text),
                      decoration: const InputDecoration(
                        hintText: 'Weight',
                        suffixText: 'kg',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: heightCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: CLColors.text),
                decoration: const InputDecoration(
                  hintText: 'Height',
                  suffixText: 'cm',
                ),
              ),
              const SizedBox(height: 20),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final appState = ctx.read<AppState>();
                    final p = appState.profile.copyWith(
                      name: nameCtrl.text.trim(),
                      age: int.tryParse(ageCtrl.text) ?? 0,
                      weight: double.tryParse(weightCtrl.text) ?? 0,
                      height: int.tryParse(heightCtrl.text) ?? 0,
                    );
                    // Auto-calculate calorie goal
                    if (p.age > 0 && p.weight > 0 && p.height > 0) {
                      final bmr = p.sex == 'm'
                          ? 10 * p.weight + 6.25 * p.height - 5 * p.age + 5
                          : 10 * p.weight + 6.25 * p.height - 5 * p.age - 161;
                      final tdee = (bmr * p.activity).round();
                      await appState.saveCalorieGoal(tdee);
                    }
                    await appState.saveProfile(p);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: const Text('Profile saved'),
                          backgroundColor: CLColors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text('SAVE CHANGES'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
