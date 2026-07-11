/// View names
class Views {
  static const String allocationBalances = 'allocation_balances';
  static const String defaulters         = 'defaulters';
}

/// RPC function names
class RPCs {
  static const String recalculateAllocationStatus = 'recalculate_allocation_status';
}

/// Realtime channel names
class Channels {
  static const String transactions = 'public:transactions';
  static const String allocations  = 'public:student_allocations';
}
/// ORACLE — Supabase client configuration
/// Replace SUPABASE_URL and SUPABASE_ANON_KEY with your project credentials.

const String supabaseUrl = 'https://bxfhrvlkmftouivyvpug.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ4ZmhydmxrbWZ0b3Vpdnl2cHVnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMwMDk5MjgsImV4cCI6MjA5ODU4NTkyOH0.hsCjuQa3aNIH-YRSUsNXYC4VEhPRMJ7oabd8nzqo-Ys';

/// Edge function base URL (same as supabaseUrl + /functions/v1)
const String edgeFunctionsUrl = '$supabaseUrl/functions/v1';

/// Table names (avoid magic strings)
class Tables {
  static const String profiles           = 'profiles';
  static const String students           = 'students';
  static const String feeStructures      = 'fee_structures';
  static const String studentAllocations = 'student_allocations';
  static const String adjustments        = 'adjustments';
  static const String transactions       = 'transactions';
}