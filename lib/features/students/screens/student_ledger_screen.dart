import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';

class StudentLedgerScreen extends ConsumerWidget {
  const StudentLedgerScreen({super.key, required this.studentId});
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allocAsync = ref.watch(studentAllocationsProvider(studentId));
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
                        Text('Student Fee Ledger',
                            style: Theme.of(context).textTheme.titleLarge),
                        Text('ID: $studentId',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => _showAllocateFeeModal(context, ref, studentId),
                      icon: const Icon(Icons.add_circle_outline, color: AppColors.blobSky),
                    ),
                    IconButton(
                      onPressed: () =>
                          ref.invalidate(studentAllocationsProvider(studentId)),
                      icon: const Icon(Icons.refresh_rounded,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: allocAsync.when(
                  data: (allocations) {
                    if (allocations.isEmpty) {
                      return const Center(
                        child: Text('No fee allocations found.',
                            style: TextStyle(color: AppColors.textSecondary)),
                      );
                    }

                    final totalOutstanding = allocations.fold(
                        0.0, (s, a) => s + a.outstandingAmount);
                    final totalPaid =
                        allocations.fold(0.0, (s, a) => s + a.totalPaid);

                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Summary card
                        GlassCard(
                          child: Row(
                            children: [
                              _SummaryItem(
                                label: 'Total Paid',
                                value: fmt.format(totalPaid),
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 20),
                              const VerticalDivider(
                                  color: AppColors.glassBorder, width: 1),
                              const SizedBox(width: 20),
                              _SummaryItem(
                                label: 'Outstanding',
                                value: fmt.format(totalOutstanding),
                                color: AppColors.error,
                              ),
                            ],
                          ),
                        ).animate().fadeIn(duration: 500.ms),
                        const SizedBox(height: 20),

                        // Allocation cards
                        ...allocations.asMap().entries.map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _AllocationCard(
                                  balance: e.value,
                                ).animate(delay: (e.key * 80).ms).fadeIn().slideY(begin: 0.05),
                              ),
                            ),
                      ],
                    );
                  },
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

  void _showAllocateFeeModal(BuildContext context, WidgetRef ref, String studentId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AllocateFeeModal(
        studentId: studentId,
        onAllocated: () => ref.invalidate(studentAllocationsProvider(studentId)),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }
}

class _AllocationCard extends StatelessWidget {
  const _AllocationCard({required this.balance});
  final AllocationBalance balance;

  Color get _statusColor => switch (balance.status) {
        AllocationStatus.paid          => AppColors.success,
        AllocationStatus.partiallyPaid => AppColors.warning,
        AllocationStatus.waived        => AppColors.info,
        AllocationStatus.unpaid        => AppColors.error,
      };

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final dateFmt = DateFormat('d MMM y');

    return GlassCard(
      accentColor: _statusColor,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                fmt.format(balance.baseAmount),
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              _StatusChip(status: balance.status),
            ],
          ),
          const SizedBox(height: 12),
          _LedgerRow('Due Date',
              dateFmt.format(balance.dueDate.toLocal()),
              balance.dueDate.isBefore(DateTime.now()) &&
                      balance.status != AllocationStatus.paid
                  ? AppColors.error
                  : AppColors.textSecondary),
          _LedgerRow('Paid', fmt.format(balance.totalPaid), AppColors.success),
          if (balance.totalPenalties > 0)
            _LedgerRow('Penalties', '+ ${fmt.format(balance.totalPenalties)}',
                AppColors.error),
          if (balance.totalWaivers > 0)
            _LedgerRow('Waivers', '− ${fmt.format(balance.totalWaivers)}',
                AppColors.info),
          const Divider(color: AppColors.glassBorder),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Outstanding',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              Text(
                fmt.format(balance.outstandingAmount),
                style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: balance.outstandingAmount > 0
                        ? AppColors.error
                        : AppColors.success),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow(this.label, this.value, this.valueColor);
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final AllocationStatus status;

  Color get color => switch (status) {
        AllocationStatus.paid          => AppColors.success,
        AllocationStatus.partiallyPaid => AppColors.warning,
        AllocationStatus.waived        => AppColors.info,
        AllocationStatus.unpaid        => AppColors.error,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color),
      ),
    );
  }
}

class _AllocateFeeModal extends ConsumerStatefulWidget {
  const _AllocateFeeModal({required this.studentId, required this.onAllocated});
  final String studentId;
  final VoidCallback onAllocated;

  @override
  ConsumerState<_AllocateFeeModal> createState() => _AllocateFeeModalState();
}

class _AllocateFeeModalState extends ConsumerState<_AllocateFeeModal> {
  FeeStructure? _selectedFee;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _loading = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _allocate() async {
    if (_selectedFee == null) return;
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.from('student_allocations').insert({
        'student_id': widget.studentId,
        'fee_structure_id': _selectedFee!.id,
        'due_date': _dueDate.toIso8601String(),
        'base_amount': _selectedFee!.baseAmount,
        'status': 'UNPAID',
      });
      widget.onAllocated();
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
    final feeAsync = ref.watch(feeStructuresProvider);
    final fmt = DateFormat('MMM dd, yyyy');

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.add_circle_outline, color: AppColors.blobSky),
              const SizedBox(width: 12),
              Text('Allocate Fee', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          feeAsync.when(
            data: (fees) {
              if (fees.isEmpty) {
                return const Text('No fee structures available.', style: TextStyle(color: AppColors.textSecondary));
              }
              return DropdownButtonFormField<FeeStructure>(
                value: _selectedFee,
                dropdownColor: AppColors.bg2,
                hint: const Text('Select Fee Structure', style: TextStyle(color: AppColors.textMuted)),
                style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Outfit'),
                decoration: const InputDecoration(labelText: 'Fee Structure'),
                items: fees.map((f) => DropdownMenuItem(
                  value: f,
                  child: Text('${f.title} (₹${f.baseAmount.toStringAsFixed(0)})'),
                )).toList(),
                onChanged: (v) => setState(() => _selectedFee = v),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error loading fees: $e', style: const TextStyle(color: AppColors.error)),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Due Date',
                suffixIcon: Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary),
              ),
              child: Text(fmt.format(_dueDate), style: const TextStyle(color: AppColors.textPrimary)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: (_loading || _selectedFee == null) ? null : _allocate,
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Allocate to Student'),
          ),
        ],
      ),
    );
  }
}
