import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../config/supabase_config.dart';
import 'providers.dart';

// ============================================================
// Payment State
// ============================================================

enum PaymentStep {
  idle,
  initiating,
  awaitingUPI,   // UPI intent launched, waiting for realtime confirm
  verifying,     // Admin manual verification for cash/cheque
  success,
  failed,
}

class PaymentState {
  const PaymentState({
    this.step = PaymentStep.idle,
    this.transactionId,
    this.orderId,
    this.upiIntent,
    this.error,
    this.transaction,
  });

  final PaymentStep step;
  final String? transactionId;
  final String? orderId;
  final String? upiIntent;
  final String? error;
  final FeeTransaction? transaction;

  bool get isLoading =>
      step == PaymentStep.initiating ||
      step == PaymentStep.awaitingUPI ||
      step == PaymentStep.verifying;

  PaymentState copyWith({
    PaymentStep? step,
    String? transactionId,
    String? orderId,
    String? upiIntent,
    String? error,
    FeeTransaction? transaction,
  }) =>
      PaymentState(
        step: step ?? this.step,
        transactionId: transactionId ?? this.transactionId,
        orderId: orderId ?? this.orderId,
        upiIntent: upiIntent ?? this.upiIntent,
        error: error ?? this.error,
        transaction: transaction ?? this.transaction,
      );
}

// ============================================================
// Payment Notifier
// ============================================================

class PaymentNotifier extends StateNotifier<PaymentState> {
  PaymentNotifier(this._ref) : super(const PaymentState());

  final Ref _ref;
  RealtimeChannel? _realtimeChannel;

  /// Initiate a UPI payment for the given allocation
  Future<void> initiateUPI({
    required String allocationId,
    required double amount,
    required String studentName,
  }) async {
    state = const PaymentState(step: PaymentStep.initiating);

    try {
      final client = _ref.read(supabaseClientProvider);

      // Call the Edge Function
      final response = await client.functions.invoke(
        'initiate-upi',
        body: {
          'allocation_id': allocationId,
          'amount': amount,
          'student_name': studentName,
        },
      );

      if (response.status != 200) {
        throw Exception(response.data?['error'] ?? 'Unknown error from gateway');
      }

      final data = response.data as Map<String, dynamic>;
      final transactionId = data['transaction_id'] as String;
      final upiIntent = data['upi_intent'] as String;
      final orderId = data['order_id'] as String;

      state = state.copyWith(
        step: PaymentStep.awaitingUPI,
        transactionId: transactionId,
        orderId: orderId,
        upiIntent: upiIntent,
      );

      // Subscribe to Realtime for this specific transaction
      _subscribeToTransaction(transactionId);
    } catch (e) {
      state = PaymentState(
        step: PaymentStep.failed,
        error: e.toString(),
      );
    }
  }

  /// Create a manual cash/cheque transaction (admin workflow)
  Future<void> createManualTransaction({
    required String allocationId,
    required double amount,
    required PaymentMethod method,
    required String referenceNumber,
    String? notes,
  }) async {
    state = const PaymentState(step: PaymentStep.initiating);

    try {
      final client = _ref.read(supabaseClientProvider);
      final adminId = client.auth.currentUser?.id;

      final res = await client.from(Tables.transactions).insert({
        'allocation_id': allocationId,
        'amount_paid': amount,
        'payment_method': method == PaymentMethod.cash ? 'CASH' : 'CHEQUE',
        'payment_status': 'PENDING',
        'reference_number': referenceNumber,
        'notes': notes,
        'verified_by_admin_id': adminId,
      }).select().single();

      state = PaymentState(
        step: PaymentStep.verifying,
        transactionId: res['id'] as String,
        transaction: FeeTransaction.fromJson(res),
      );
    } catch (e) {
      state = PaymentState(step: PaymentStep.failed, error: e.toString());
    }
  }

  /// Admin verifies a pending cash/cheque transaction
  Future<void> verifyTransaction(String transactionId) async {
    try {
      final client = _ref.read(supabaseClientProvider);
      final adminId = client.auth.currentUser?.id;

      await client.from(Tables.transactions).update({
        'payment_status': 'SUCCESS',
        'verified_by_admin_id': adminId,
        'verified_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', transactionId);

      // DB trigger recalculates allocation status automatically
      state = state.copyWith(step: PaymentStep.success);
    } catch (e) {
      state = PaymentState(step: PaymentStep.failed, error: e.toString());
    }
  }

  /// MOCK: Simulates gateway confirming payment (for hackathon demo)
  Future<void> mockConfirmUPI({required String status}) async {
    final txId = state.transactionId;
    if (txId == null) return;

    try {
      final client = _ref.read(supabaseClientProvider);
      await client.functions.invoke(
        'payment-webhook/mock-confirm',
        body: {'transaction_id': txId, 'status': status},
      );
      // Realtime listener (_subscribeToTransaction) will update state
    } catch (e) {
      state = PaymentState(step: PaymentStep.failed, error: e.toString());
    }
  }

  void _subscribeToTransaction(String transactionId) {
    final client = _ref.read(supabaseClientProvider);

    _realtimeChannel = client
        .channel('transaction-$transactionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: Tables.transactions,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: transactionId,
          ),
          callback: (payload) {
            final updated = FeeTransaction.fromJson(
              payload.newRecord as Map<String, dynamic>,
            );
            if (updated.paymentStatus == PaymentStatus.success) {
              state = state.copyWith(
                step: PaymentStep.success,
                transaction: updated,
              );
              _realtimeChannel?.unsubscribe();
            } else if (updated.paymentStatus == PaymentStatus.failed) {
              state = PaymentState(
                step: PaymentStep.failed,
                error: 'Payment failed. Please try again.',
              );
              _realtimeChannel?.unsubscribe();
            }
          },
        )
        .subscribe();
  }

  void reset() {
    _realtimeChannel?.unsubscribe();
    state = const PaymentState();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}

final paymentProvider =
    StateNotifierProvider.autoDispose<PaymentNotifier, PaymentState>(
  (ref) => PaymentNotifier(ref),
);
