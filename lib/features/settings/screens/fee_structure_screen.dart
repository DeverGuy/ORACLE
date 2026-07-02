import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';

class FeeStructureScreen extends ConsumerWidget {
  const FeeStructureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final structuresAsync = ref.watch(feeStructuresProvider);
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      body: OracleBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textPrimary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Fee Structures',
                            style: Theme.of(context).textTheme.titleLarge),
                        const Text('Manage fee definitions & categories',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _showAddFeeModal(context, ref),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Fee'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: structuresAsync.when(
                  data: (list) => list.isEmpty
                      ? const Center(
                          child: Text('No fee structures yet. Add one!',
                              style: TextStyle(color: AppColors.textSecondary)),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: list.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final fs = list[i];
                            return GlassCard(
                              accentColor: AppColors.chartPalette[
                                  i % AppColors.chartPalette.length],
                              child: Row(
                                children: [
                                  Container(
                                    width: 48, height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.chartPalette[
                                          i % AppColors.chartPalette.length]
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      _categoryIcon(fs.category),
                                      color: AppColors.chartPalette[
                                          i % AppColors.chartPalette.length],
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(fs.title,
                                            style: const TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary)),
                                        Row(
                                          children: [
                                            _Badge(fs.category),
                                            const SizedBox(width: 8),
                                            _Badge(fs.academicYear,
                                                color: AppColors.info),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    fmt.format(fs.baseAmount),
                                    style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                            ).animate(delay: (i * 60).ms).fadeIn().slideY(begin: 0.04);
                          },
                        ),
                  loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.blobSky)),
                  error: (e, _) => Center(
                      child: Text(e.toString(),
                          style: const TextStyle(color: AppColors.error))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(String cat) => switch (cat) {
        'tuition'   => Icons.school_outlined,
        'transport' => Icons.directions_bus_outlined,
        'lab'       => Icons.science_outlined,
        'sports'    => Icons.sports_soccer_outlined,
        'hostel'    => Icons.hotel_outlined,
        'library'   => Icons.library_books_outlined,
        _           => Icons.receipt_outlined,
      };

  void _showAddFeeModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddFeeModal(onAdded: () => ref.invalidate(feeStructuresProvider)),
    );
  }
}

class _AddFeeModal extends StatefulWidget {
  const _AddFeeModal({required this.onAdded});
  final VoidCallback onAdded;

  @override
  State<_AddFeeModal> createState() => _AddFeeModalState();
}

class _AddFeeModalState extends State<_AddFeeModal> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _category = 'tuition';
  String _year = '2025-26';
  bool _loading = false;

  final _categories = [
    'tuition', 'transport', 'lab', 'sports', 'hostel', 'library', 'other'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text);
    if (title.isEmpty || amount == null || amount <= 0) return;
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.from('fee_structures').insert({
        'title': title,
        'base_amount': amount,
        'category': _category,
        'academic_year': _year,
      });
      widget.onAdded();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: GlassCard(
        borderRadius: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.add_circle_outline, color: AppColors.blobSky),
                const SizedBox(width: 10),
                Text('New Fee Structure',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Fee Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Base Amount (₹)',
                prefixIcon: Icon(Icons.currency_rupee, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              dropdownColor: AppColors.bg2,
              style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Outfit'),
              decoration: const InputDecoration(labelText: 'Category'),
              items: _categories.map((c) => DropdownMenuItem(
                value: c,
                child: Text(c[0].toUpperCase() + c.substring(1)),
              )).toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _year,
              dropdownColor: AppColors.bg2,
              style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Outfit'),
              decoration: const InputDecoration(labelText: 'Academic Year'),
              items: ['2024-25', '2025-26', '2026-27'].map((y) =>
                  DropdownMenuItem(value: y, child: Text(y))).toList(),
              onChanged: (v) => setState(() => _year = v!),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.bg0))
                  : const Text('Create Fee Structure'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, {this.color = AppColors.blobSky});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color),
      ),
    );
  }
}
