import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/payment_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';

class PaymentScreen extends ConsumerWidget {
  const PaymentScreen({super.key, required this.allocationId});
  final String allocationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentState = ref.watch(paymentProvider);
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      body: OracleBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textPrimary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text('Make Payment',
                        style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
                const SizedBox(height: 24),

                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: _buildContent(context, ref, paymentState, fmt),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext ctx, WidgetRef ref,
      PaymentState state, NumberFormat fmt) {
    if (state.step == PaymentStep.success) {
      return _SuccessCard(transaction: state.transaction);
    }

    if (state.step == PaymentStep.failed) {
      return _FailureCard(
        error: state.error ?? 'Payment failed',
        onRetry: () => ref.read(paymentProvider.notifier).reset(),
      );
    }

    if (state.step == PaymentStep.awaitingUPI) {
      return _UPIAwaitingCard(
        state: state,
        onMockSuccess: () => ref
            .read(paymentProvider.notifier)
            .mockConfirmUPI(status: 'SUCCESS'),
        onMockFail: () => ref
            .read(paymentProvider.notifier)
            .mockConfirmUPI(status: 'FAILED'),
        onCancel: () => ref.read(paymentProvider.notifier).reset(),
      );
    }

    // Default — payment initiation form
    return _PaymentForm(
      allocationId: allocationId,
      isLoading: state.isLoading,
    );
  }
}

class _PaymentForm extends ConsumerStatefulWidget {
  const _PaymentForm({required this.allocationId, required this.isLoading});
  final String allocationId;
  final bool isLoading;

  @override
  ConsumerState<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends ConsumerState<_PaymentForm> {
  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    // In a real app, fetch the allocation from DB. Here we show a demo form.
    const double demoAmount = 12000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          accentColor: AppColors.blobSky,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Payment Summary',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              _SummaryRow('Fee Type', 'Tuition Fee Q1 2025-26'),
              _SummaryRow('Base Amount', fmt.format(12000)),
              _SummaryRow('Late Penalty', fmt.format(500),
                  valueColor: AppColors.error),
              _SummaryRow('Waiver Applied', '− ${fmt.format(0)}',
                  valueColor: AppColors.success),
              const Divider(color: AppColors.glassBorder),
              _SummaryRow('Total Due', fmt.format(demoAmount + 500),
                  bold: true, valueColor: AppColors.textPrimary),
            ],
          ),
        ).animate().fadeIn(duration: 600.ms),
        const SizedBox(height: 20),

        // UPI button
        _PayButton(
          label: 'Pay via UPI',
          subtitle: 'PhonePe · GPay · Paytm · BHIM',
          icon: Icons.qr_code_rounded,
          color: AppColors.blobSky,
          isLoading: widget.isLoading,
          onTap: () => ref.read(paymentProvider.notifier).initiateUPI(
                allocationId: widget.allocationId,
                amount: demoAmount + 500,
                studentName: 'Student',
              ),
        ).animate().fadeIn(duration: 600.ms, delay: 100.ms),
        const SizedBox(height: 12),

        const Center(
          child: Text('Zero platform fee for UPI payments',
              style: TextStyle(fontSize: 11, color: AppColors.success)),
        ),
        const SizedBox(height: 20),

        GlassCard(
          child: Row(
            children: const [
              Icon(Icons.lock_outline, color: AppColors.textMuted, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Payments are secured end-to-end. Your data is encrypted and never stored on our servers.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value,
      {this.valueColor = AppColors.textSecondary, this.bold = false});
  final String label;
  final String value;
  final Color valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
          Text(value,
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: bold ? 16 : 13,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  color: valueColor)),
        ],
      ),
    );
  }
}

class _PayButton extends StatelessWidget {
  const _PayButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.25), color.withOpacity(0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: color)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            isLoading
                ? SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: color))
                : Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

// ── UPI Awaiting Card (with mock confirm for demo) ────────────
class _UPIAwaitingCard extends StatelessWidget {
  const _UPIAwaitingCard({
    required this.state,
    required this.onMockSuccess,
    required this.onMockFail,
    required this.onCancel,
  });
  final PaymentState state;
  final VoidCallback onMockSuccess;
  final VoidCallback onMockFail;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accentColor: AppColors.pending,
      child: Column(
        children: [
          const SizedBox(height: 8),
          const Icon(Icons.hourglass_top_rounded,
              size: 48, color: AppColors.pending)
              .animate(onPlay: (c) => c.repeat())
              .rotate(duration: 2000.ms),
          const SizedBox(height: 16),
          const Text('Awaiting Payment Confirmation',
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Order: ${state.orderId ?? "..."}',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete the payment in your UPI app.\nThis screen will update automatically when confirmed.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Hackathon demo buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bg3,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.science_outlined, size: 14, color: AppColors.info),
                    SizedBox(width: 6),
                    Text('Demo Controls',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.info)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onMockSuccess,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success),
                        child: const Text('✓ Mock Success'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onMockFail,
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.error)),
                        child: const Text('✗ Mock Fail',
                            style: TextStyle(color: AppColors.error)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onCancel,
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }
}

// ── Success Card ─────────────────────────────────────────────
class _SuccessCard extends StatelessWidget {
  const _SuccessCard({this.transaction});
  final FeeTransaction? transaction;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return GlassCard(
      accentColor: AppColors.success,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                size: 40, color: AppColors.success),
          )
              .animate()
              .scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut,
                  duration: 600.ms),
          const SizedBox(height: 20),
          const Text('Payment Successful!',
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success)),
          if (transaction != null) ...[
            const SizedBox(height: 8),
            Text(
              fmt.format(transaction!.amountPaid),
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            if (transaction!.referenceNumber != null) ...[
              const SizedBox(height: 8),
              Text('UTR: ${transaction!.referenceNumber}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to Home'),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }
}

// ── Failure Card ─────────────────────────────────────────────
class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accentColor: AppColors.error,
      child: Column(
        children: [
          const SizedBox(height: 8),
          const Icon(Icons.cancel_outlined, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          const Text('Payment Failed',
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error)),
          const SizedBox(height: 8),
          Text(error,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Try Again'),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }
}
