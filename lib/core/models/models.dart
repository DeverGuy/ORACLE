// ============================================================
// ORACLE — Data Models
// ============================================================

// ── FeeStructure ────────────────────────────────────────────
class FeeStructure {
  const FeeStructure({
    required this.id,
    required this.title,
    this.description,
    required this.baseAmount,
    required this.category,
    required this.academicYear,
    this.applicableGrades,
    this.isActive = true,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String? description;
  final double baseAmount;
  final String category;
  final String academicYear;
  final List<String>? applicableGrades;
  final bool isActive;
  final DateTime createdAt;

  factory FeeStructure.fromJson(Map<String, dynamic> json) => FeeStructure(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        baseAmount: (json['base_amount'] as num).toDouble(),
        category: json['category'] as String,
        academicYear: json['academic_year'] as String,
        applicableGrades: (json['applicable_grades'] as List?)?.cast<String>(),
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'base_amount': baseAmount,
        'category': category,
        'academic_year': academicYear,
        'applicable_grades': applicableGrades,
        'is_active': isActive,
      };
}

// ── StudentProfile ───────────────────────────────────────────
class StudentProfile {
  const StudentProfile({
    required this.id,
    required this.studentId,
    required this.fullName,
    required this.rollNumber,
    required this.grade,
    this.section,
    this.avatarUrl,
    this.parentId,
  });

  final String id;         // profile id
  final String studentId;  // students.id
  final String fullName;
  final String rollNumber;
  final String grade;
  final String? section;
  final String? avatarUrl;
  final String? parentId;

  factory StudentProfile.fromJson(Map<String, dynamic> json) => StudentProfile(
        id: json['id'] as String,
        studentId: json['student_id'] as String,
        fullName: json['full_name'] as String,
        rollNumber: json['roll_number'] as String,
        grade: json['grade'] as String,
        section: json['section'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        parentId: json['parent_id'] as String?,
      );
}

// ── StudentAllocation ───────────────────────────────────────
class StudentAllocation {
  const StudentAllocation({
    required this.id,
    required this.studentId,
    required this.feeStructureId,
    required this.dueDate,
    required this.baseAmount,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String studentId;
  final String feeStructureId;
  final DateTime dueDate;
  final double baseAmount;
  final AllocationStatus status;
  final DateTime createdAt;

  bool get isOverdue =>
      status != AllocationStatus.paid && DateTime.now().isAfter(dueDate);

  factory StudentAllocation.fromJson(Map<String, dynamic> json) =>
      StudentAllocation(
        id: json['id'] as String,
        studentId: json['student_id'] as String,
        feeStructureId: json['fee_structure_id'] as String,
        dueDate: DateTime.parse(json['due_date'] as String),
        baseAmount: (json['base_amount'] as num).toDouble(),
        status: AllocationStatus.fromString(json['status'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

enum AllocationStatus {
  unpaid,
  partiallyPaid,
  paid,
  waived;

  static AllocationStatus fromString(String s) => switch (s) {
        'PAID'           => AllocationStatus.paid,
        'PARTIALLY_PAID' => AllocationStatus.partiallyPaid,
        'WAIVED'         => AllocationStatus.waived,
        _                => AllocationStatus.unpaid,
      };

  String get label => switch (this) {
        AllocationStatus.paid          => 'Paid',
        AllocationStatus.partiallyPaid => 'Partial',
        AllocationStatus.waived        => 'Waived',
        AllocationStatus.unpaid        => 'Unpaid',
      };
}

// ── Adjustment ──────────────────────────────────────────────
class Adjustment {
  const Adjustment({
    required this.id,
    required this.allocationId,
    required this.type,
    required this.amount,
    required this.reason,
    this.appliedBy,
    required this.createdAt,
  });

  final String id;
  final String allocationId;
  final AdjustmentType type;
  final double amount;
  final String reason;
  final String? appliedBy;
  final DateTime createdAt;

  factory Adjustment.fromJson(Map<String, dynamic> json) => Adjustment(
        id: json['id'] as String,
        allocationId: json['allocation_id'] as String,
        type: json['type'] == 'WAIVER'
            ? AdjustmentType.waiver
            : AdjustmentType.penalty,
        amount: (json['amount'] as num).toDouble(),
        reason: json['reason'] as String,
        appliedBy: json['applied_by'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

enum AdjustmentType { waiver, penalty }

// ── Transaction ─────────────────────────────────────────────
class FeeTransaction {
  const FeeTransaction({
    required this.id,
    required this.allocationId,
    required this.amountPaid,
    required this.paymentMethod,
    required this.paymentStatus,
    this.referenceNumber,
    this.gatewayOrderId,
    this.verifiedByAdminId,
    this.verifiedAt,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String allocationId;
  final double amountPaid;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final String? referenceNumber;
  final String? gatewayOrderId;
  final String? verifiedByAdminId;
  final DateTime? verifiedAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory FeeTransaction.fromJson(Map<String, dynamic> json) => FeeTransaction(
        id: json['id'] as String,
        allocationId: json['allocation_id'] as String,
        amountPaid: (json['amount_paid'] as num).toDouble(),
        paymentMethod: PaymentMethod.fromString(json['payment_method'] as String),
        paymentStatus: PaymentStatus.fromString(json['payment_status'] as String),
        referenceNumber: json['reference_number'] as String?,
        gatewayOrderId: json['gateway_order_id'] as String?,
        verifiedByAdminId: json['verified_by_admin_id'] as String?,
        verifiedAt: json['verified_at'] != null
            ? DateTime.parse(json['verified_at'] as String)
            : null,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

enum PaymentMethod {
  upi,
  cash,
  cheque;

  static PaymentMethod fromString(String s) => switch (s) {
        'UPI'    => PaymentMethod.upi,
        'CHEQUE' => PaymentMethod.cheque,
        _        => PaymentMethod.cash,
      };

  String get label => switch (this) {
        PaymentMethod.upi    => 'UPI',
        PaymentMethod.cash   => 'Cash',
        PaymentMethod.cheque => 'Cheque',
      };
}

enum PaymentStatus {
  pending,
  success,
  failed;

  static PaymentStatus fromString(String s) => switch (s) {
        'SUCCESS' => PaymentStatus.success,
        'FAILED'  => PaymentStatus.failed,
        _         => PaymentStatus.pending,
      };
}

// ── AllocationBalance (from view) ───────────────────────────
class AllocationBalance {
  const AllocationBalance({
    required this.allocationId,
    required this.studentId,
    required this.feeStructureId,
    required this.dueDate,
    required this.status,
    required this.baseAmount,
    required this.totalPenalties,
    required this.totalWaivers,
    required this.totalPaid,
    required this.outstandingAmount,
  });

  final String allocationId;
  final String studentId;
  final String feeStructureId;
  final DateTime dueDate;
  final AllocationStatus status;
  final double baseAmount;
  final double totalPenalties;
  final double totalWaivers;
  final double totalPaid;
  final double outstandingAmount;

  factory AllocationBalance.fromJson(Map<String, dynamic> json) =>
      AllocationBalance(
        allocationId: json['allocation_id'] as String,
        studentId: json['student_id'] as String,
        feeStructureId: json['fee_structure_id'] as String,
        dueDate: DateTime.parse(json['due_date'] as String),
        status: AllocationStatus.fromString(json['status'] as String),
        baseAmount: (json['base_amount'] as num).toDouble(),
        totalPenalties: (json['total_penalties'] as num).toDouble(),
        totalWaivers: (json['total_waivers'] as num).toDouble(),
        totalPaid: (json['total_paid'] as num).toDouble(),
        outstandingAmount: (json['outstanding_amount'] as num).toDouble(),
      );
}

// ── Defaulter (from view) ────────────────────────────────────
class Defaulter {
  const Defaulter({
    required this.balance,
    required this.rollNumber,
    required this.studentName,
    required this.feeTitle,
    required this.category,
    required this.daysOverdue,
    required this.priorityScore,
  });

  final AllocationBalance balance;
  final String rollNumber;
  final String studentName;
  final String feeTitle;
  final String category;
  final int daysOverdue;
  final double priorityScore;

  factory Defaulter.fromJson(Map<String, dynamic> json) => Defaulter(
        balance: AllocationBalance.fromJson(json),
        rollNumber: json['roll_number'] as String,
        studentName: json['student_name'] as String,
        feeTitle: json['fee_title'] as String,
        category: json['category'] as String,
        daysOverdue: (json['days_overdue'] as num).toInt(),
        priorityScore: (json['priority_score'] as num).toDouble(),
      );
}

// ── RevenueMetrics ───────────────────────────────────────────
class RevenueMetrics {
  const RevenueMetrics({
    required this.totalCollected,
    required this.totalOutstanding,
    required this.defaulterCount,
    required this.pendingVerification,
    required this.categoryBreakdown,
  });

  final double totalCollected;
  final double totalOutstanding;
  final int defaulterCount;
  final int pendingVerification;
  final Map<String, double> categoryBreakdown;

  static RevenueMetrics empty() => const RevenueMetrics(
        totalCollected: 0,
        totalOutstanding: 0,
        defaulterCount: 0,
        pendingVerification: 0,
        categoryBreakdown: {},
      );
}
