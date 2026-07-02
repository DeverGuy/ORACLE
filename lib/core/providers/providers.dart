import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../config/supabase_config.dart';

// ── Supabase client singleton ────────────────────────────────
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

// ============================================================
// AUTH
// ============================================================

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(supabaseClientProvider).auth.currentUser;
});

final currentProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from(Tables.profiles)
      .select()
      .eq('id', user.id)
      .single();
  return response;
});

// ============================================================
// REVENUE METRICS
// ============================================================

final revenueMetricsProvider = FutureProvider.autoDispose<RevenueMetrics>((ref) async {
  final client = ref.watch(supabaseClientProvider);

  // Total collected (SUCCESS transactions)
  final collectedRes = await client
      .from(Tables.transactions)
      .select('amount_paid')
      .eq('payment_status', 'SUCCESS');

  final double totalCollected = (collectedRes as List)
      .fold(0.0, (sum, row) => sum + (row['amount_paid'] as num).toDouble());

  // Outstanding from view
  final outstandingRes = await client
      .from(Views.allocationBalances)
      .select('outstanding_amount')
      .gt('outstanding_amount', 0);

  final double totalOutstanding = (outstandingRes as List)
      .fold(0.0, (sum, row) => sum + (row['outstanding_amount'] as num).toDouble());

  // Defaulter count
  final defaulterRes = await client
      .from(Views.defaulters)
      .select('allocation_id');
  final int defaulterCount = (defaulterRes as List).length;

  // Pending verification (cash/cheque PENDING)
  final pendingRes = await client
      .from(Tables.transactions)
      .select('id')
      .eq('payment_status', 'PENDING')
      .inFilter('payment_method', ['CASH', 'CHEQUE']);
  final int pendingCount = (pendingRes as List).length;

  // Category breakdown (collected per category)
  final breakdownRes = await client
      .from(Tables.transactions)
      .select('amount_paid, ${Tables.studentAllocations}!inner(${Tables.feeStructures}!inner(category))')
      .eq('payment_status', 'SUCCESS');

  final Map<String, double> breakdown = {};
  for (final row in breakdownRes as List) {
    final category = row['student_allocations']?['fee_structures']?['category'] as String? ?? 'other';
    breakdown[category] = (breakdown[category] ?? 0) + (row['amount_paid'] as num).toDouble();
  }

  return RevenueMetrics(
    totalCollected: totalCollected,
    totalOutstanding: totalOutstanding,
    defaulterCount: defaulterCount,
    pendingVerification: pendingCount,
    categoryBreakdown: breakdown,
  );
});

// ============================================================
// REALTIME TRANSACTIONS STREAM
// ============================================================

final transactionsStreamProvider = StreamProvider.autoDispose<List<FeeTransaction>>((ref) {
  final client = ref.watch(supabaseClientProvider);

  return client
      .from(Tables.transactions)
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(50)
      .map((rows) => rows.map((r) => FeeTransaction.fromJson(r)).toList());
});

// ============================================================
// DEFAULTERS
// ============================================================

final defaultersProvider = FutureProvider.autoDispose<List<Defaulter>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final res = await client
      .from(Views.defaulters)
      .select()
      .order('priority_score', ascending: false)
      .limit(100);
  return res.map((row) => Defaulter.fromJson(row as Map<String, dynamic>)).toList();
});

// ============================================================
// FEE STRUCTURES
// ============================================================

final feeStructuresProvider = FutureProvider.autoDispose<List<FeeStructure>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final res = await client
      .from(Tables.feeStructures)
      .select()
      .eq('is_active', true)
      .order('created_at', ascending: false);
  return res.map((row) => FeeStructure.fromJson(row as Map<String, dynamic>)).toList();
});

// ============================================================
// PENDING VERIFICATION QUEUE (cash/cheque)
// ============================================================

final pendingVerificationProvider =
    FutureProvider.autoDispose<List<FeeTransaction>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final res = await client
      .from(Tables.transactions)
      .select()
      .eq('payment_status', 'PENDING')
      .inFilter('payment_method', ['CASH', 'CHEQUE'])
      .order('created_at', ascending: true); // oldest first — most urgent
  return res.map((row) => FeeTransaction.fromJson(row as Map<String, dynamic>)).toList();
});

// ============================================================
// STUDENT ALLOCATIONS (per student)
// ============================================================

final studentAllocationsProvider =
    FutureProvider.family.autoDispose<List<AllocationBalance>, String>(
  (ref, studentId) async {
    final client = ref.watch(supabaseClientProvider);
    final res = await client
        .from(Views.allocationBalances)
        .select()
        .eq('student_id', studentId)
        .order('due_date', ascending: true);
    return res.map((row) => AllocationBalance.fromJson(row as Map<String, dynamic>)).toList();
  },
);
