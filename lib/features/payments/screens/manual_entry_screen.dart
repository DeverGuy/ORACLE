import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/payment_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';

class ManualEntryScreen extends ConsumerStatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  ConsumerState<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends ConsumerState<ManualEntryScreen> {
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  PaymentMethod _method = PaymentMethod.cash;
  String? _selectedAllocationId;
  bool _loading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0 || _selectedAllocationId == null) return;
    if (_method == PaymentMethod.cheque && _referenceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the cheque number'),
            backgroundColor: AppColors.warning),
      );
      return;
    }

    setState(() => _loading = true);
    await ref.read(paymentProvider.notifier).createManualTransaction(
          allocationId: _selectedAllocationId!,
          amount: amount,
          method: _method,
          referenceNumber: _referenceController.text.trim().isEmpty
              ? 'CASH-${DateTime.now().millisecondsSinceEpoch}'
              : _referenceController.text.trim(),
          notes: _notesController.text.trim(),
        );
    setState(() => _loading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${_method.label} entry created — pending verification'),
          backgroundColor: AppColors.warning,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OracleBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button + title
                Row(
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
                        Text('Manual Entry',
                            style: Theme.of(context).textTheme.titleLarge),
                        const Text('Record cash or cheque payment',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Payment method selector
                        Text('Payment Method',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _MethodChip(
                              label: 'Cash',
                              icon: Icons.payments_outlined,
                              selected: _method == PaymentMethod.cash,
                              color: AppColors.blobGold,
                              onTap: () => setState(() => _method = PaymentMethod.cash),
                            ),
                            const SizedBox(width: 12),
                            _MethodChip(
                              label: 'Cheque',
                              icon: Icons.description_outlined,
                              selected: _method == PaymentMethod.cheque,
                              color: AppColors.blobLavender,
                              onTap: () =>
                                  setState(() => _method = PaymentMethod.cheque),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Student / Allocation picker (simplified — search by roll no)
                        _AllocationPicker(
                          onSelected: (id, name) => setState(() {
                            _selectedAllocationId = id;
                          }),
                        ),
                        const SizedBox(height: 16),

                        // Amount
                        TextField(
                          controller: _amountController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Amount (₹)',
                            prefixIcon: Icon(Icons.currency_rupee,
                                color: AppColors.textSecondary),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Reference number
                        TextField(
                          controller: _referenceController,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            labelText: _method == PaymentMethod.cheque
                                ? 'Cheque Number *'
                                : 'Reference (optional)',
                            prefixIcon: const Icon(Icons.tag,
                                color: AppColors.textSecondary),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Notes
                        TextField(
                          controller: _notesController,
                          maxLines: 2,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Notes (optional)',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 28),

                        ElevatedButton.icon(
                          onPressed: (_loading ||
                                  _selectedAllocationId == null)
                              ? null
                              : _submit,
                          icon: _loading
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppColors.bg0))
                              : const Icon(Icons.save_outlined, size: 18),
                          label: const Text('Create Pending Entry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warning,
                            foregroundColor: AppColors.bg0,
                          ),
                        ),

                        const SizedBox(height: 12),
                        const Center(
                          child: Text(
                            'Entry will appear in Pending Verification queue',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.05),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Simplified allocation picker — fetches unpaid allocations
class _AllocationPicker extends StatefulWidget {
  const _AllocationPicker({required this.onSelected});
  final void Function(String id, String name) onSelected;

  @override
  State<_AllocationPicker> createState() => _AllocationPickerState();
}

class _AllocationPickerState extends State<_AllocationPicker> {
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  final _searchController = TextEditingController();

  Future<void> _search(String query) async {
    if (query.length < 2) return;
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('students')
          .select('id, roll_number, profiles!inner(full_name), student_allocations!inner(id, status, fee_structures!inner(title))')
          .or('roll_number.ilike.%$query%,profiles.full_name.ilike.%$query%')
          .neq('student_allocations.status', 'PAID')
          .limit(10);
      setState(() => _results = (res as List).cast<Map<String, dynamic>>());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: _search,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'Search student (name or roll no.)',
            prefixIcon: const Icon(Icons.person_search_outlined,
                color: AppColors.textSecondary),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.blobSky)))
                : null,
          ),
        ),
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              children: _results.expand((student) {
                final allocations = student['student_allocations'] as List? ?? [];
                return allocations.map((alloc) {
                  final allocationId = alloc['id'] as String;
                  final feeName =
                      alloc['fee_structures']?['title'] as String? ?? 'Fee';
                  final studentName =
                      student['profiles']?['full_name'] as String? ?? 'Student';
                  final roll = student['roll_number'] as String;
                  return ListTile(
                    dense: true,
                    title: Text('$studentName ($roll)',
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 13)),
                    subtitle: Text(feeName,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                    onTap: () {
                      _searchController.text = '$studentName — $feeName';
                      setState(() => _results = []);
                      widget.onSelected(allocationId, studentName);
                    },
                  );
                });
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.2) : AppColors.glassFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : AppColors.glassBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? color : AppColors.textSecondary, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? color : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
