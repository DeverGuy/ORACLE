import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import '../models/models.dart';
import 'providers.dart';

// ============================================================
// PORTAL — Student profile linked to the logged-in auth user
// ============================================================

final portalStudentProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final client = ref.watch(supabaseClientProvider);

  final profile = await client
      .from(Tables.profiles)
      .select()
      .eq('id', user.id)
      .maybeSingle();

  if (profile == null) return null;

  final role = profile['role'] as String?;

  if (role == 'student') {
    final studentId = profile['student_id'] as String?;
    if (studentId != null) {
      final studentRow = await client
          .from(Tables.students)
          .select()
          .eq('id', studentId)
          .maybeSingle();
      if (studentRow != null) {
        return {
          ...studentRow,
          'role': 'student',
          'profile': profile,
        };
      }
    }
  } else if (role == 'parent') {
    final studentId = profile['student_id'] as String?;
    if (studentId != null) {
      final studentRow = await client
          .from(Tables.students)
          .select()
          .eq('id', studentId)
          .maybeSingle();
      if (studentRow != null) {
        return {
          ...studentRow,
          'role': 'parent',
          'profile': profile,
        };
      }
    }
  }

  return {'role': role ?? 'unknown', 'profile': profile, 'id': null};
});

// ============================================================
// PORTAL — Fee allocations for the portal student
// ============================================================

final portalAllocationsProvider =
    FutureProvider.autoDispose<List<AllocationBalance>>((ref) async {
  final studentData = await ref.watch(portalStudentProvider.future);
  if (studentData == null) return [];
  final studentId = studentData['id'] as String?;
  if (studentId == null) return [];

  final client = ref.watch(supabaseClientProvider);
  final res = await client
      .from(Views.allocationBalances)
      .select()
      .eq('student_id', studentId)
      .order('due_date', ascending: true);

  return res
      .map((row) => AllocationBalance.fromJson(row))
      .toList();
});

// ============================================================
// PORTAL — Recent transactions for the portal student
// ============================================================

final portalTransactionsProvider =
    FutureProvider.autoDispose<List<FeeTransaction>>((ref) async {
  final studentData = await ref.watch(portalStudentProvider.future);
  if (studentData == null) return [];
  final studentId = studentData['id'] as String?;
  if (studentId == null) return [];

  final client = ref.watch(supabaseClientProvider);

  final allocations = await client
      .from(Tables.studentAllocations)
      .select('id')
      .eq('student_id', studentId);

  final allocationIds =
      allocations.map((r) => r['id'] as String).toList();

  if (allocationIds.isEmpty) return [];

  final res = await client
      .from(Tables.transactions)
      .select()
      .inFilter('allocation_id', allocationIds)
      .order('created_at', ascending: false)
      .limit(30);

  return res
      .map((row) => FeeTransaction.fromJson(row))
      .toList();
});

// ============================================================
// PORTAL — Fee structure map (id -> FeeStructure)
// ============================================================

final portalFeeStructureMapProvider =
    FutureProvider.autoDispose<Map<String, FeeStructure>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final res = await client.from(Tables.feeStructures).select();
  final map = <String, FeeStructure>{};
  for (final row in res) {
    final fs = FeeStructure.fromJson(row);
    map[fs.id] = fs;
  }
  return map;
});
