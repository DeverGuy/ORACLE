import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';

class PendingVerificationScreen extends ConsumerWidget {
  const PendingVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingVerificationProvider);

    return Scaffold(
      body: OracleBackground(
        child: SafeArea(
          child: Column(
            children: [
              // App bar
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
                        Text('Pending Verification',
                            style: Theme.of(context).textTheme.titleLarge),
                        const Text('Cash & Cheque awaiting admin confirmation',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: pendingAsync.when(
                  data: (list) => list.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  size: 64, color: AppColors.success),
                              const SizedBox(height: 16),
                              const Text('All clear!',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary)),
                              const SizedBox(height: 8),
                              const Text(
                                  'No cash or cheque payments awaiting verification.',
                                  style: TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) => _PendingTile(
                            transaction: list[i],
                            onVerified: () {
                              ref.invalidate(pendingVerificationProvider);
                              ref.invalidate(revenueMetricsProvider);
                            },
                          ).animate(delay: (i * 60).ms).fadeIn().slideX(begin: 0.05),
                        ),
                  loading: () => const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.blobSky)),
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
}

class _PendingTile extends ConsumerStatefulWidget {
  const _PendingTile({required this.transaction, required this.onVerified});
  final FeeTransaction transaction;
  final VoidCallback onVerified;

  @override
  ConsumerState<_PendingTile> createState() => _PendingTileState();
}

class _PendingTileState extends ConsumerState<_PendingTile> {
  bool _loading = false;

  Future<void> _verify() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg2,
        title: const Text('Confirm Payment',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Mark ₹${widget.transaction.amountPaid.toStringAsFixed(0)} as successfully received?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm')),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _loading = true);

    try {
      final adminId = Supabase.instance.client.auth.currentUser?.id;
      await Supabase.instance.client.from('transactions').update({
        'payment_status': 'SUCCESS',
        'verified_by_admin_id': adminId,
        'verified_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.transaction.id);

      widget.onVerified();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment verified successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
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
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final dateFmt = DateFormat('d MMM y, h:mm a');
    final t = widget.transaction;

    return GlassCard(
      accentColor: AppColors.warning,
      child: Row(
        children: [
          // Method icon
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Icon(
                t.paymentMethod == PaymentMethod.cheque
                    ? Icons.description_outlined
                    : Icons.payments_outlined,
                color: AppColors.warning,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      fmt.format(t.amountPaid),
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _MethodBadge(method: t.paymentMethod),
                  ],
                ),
                const SizedBox(height: 4),
                if (t.referenceNumber != null)
                  Text(
                    'Ref: ${t.referenceNumber}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                Text(
                  'Submitted: ${dateFmt.format(t.createdAt.toLocal())}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                if (t.notes != null && t.notes!.isNotEmpty)
                  Text(t.notes!,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted,
                          fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Verify button
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _verify,
              icon: _loading
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg0))
                  : const Icon(Icons.check_rounded, size: 16),
              label: const Text('Verify'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodBadge extends StatelessWidget {
  const _MethodBadge({required this.method});
  final PaymentMethod method;

  @override
  Widget build(BuildContext context) {
    final color = method == PaymentMethod.cheque ? AppColors.blobLavender : AppColors.blobGold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        method.label,
        style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color),
      ),
    );
  }
}
