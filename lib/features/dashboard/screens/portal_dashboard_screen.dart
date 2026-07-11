import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/portal_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';

class PortalDashboardScreen extends ConsumerStatefulWidget {
  const PortalDashboardScreen({super.key});
  @override
  ConsumerState<PortalDashboardScreen> createState() => _PortalDashboardScreenState();
}

class _PortalDashboardScreenState extends ConsumerState<PortalDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(portalStudentProvider);
    ref.invalidate(portalAllocationsProvider);
    ref.invalidate(portalTransactionsProvider);
    ref.invalidate(portalFeeStructureMapProvider);
  }

  @override
  Widget build(BuildContext context) {
    final studentAsync = ref.watch(portalStudentProvider);
    final allocAsync = ref.watch(portalAllocationsProvider);
    final feeMapAsync = ref.watch(portalFeeStructureMapProvider);
    return Scaffold(
      body: OracleBackground(
        child: SafeArea(
          child: Column(
            children: [
              _PortalTopBar(onRefresh: _refresh),
              studentAsync.when(
                data: (s) => _ProfileHeader(student: s),
                loading: () => const _ProfileHeaderSkeleton(),
                error: (e, _) => const SizedBox.shrink(),
              ),
              allocAsync.when(
                data: (a) => _FeeSummaryBanner(allocations: a),
                loading: () => const SizedBox(height: 80),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _OracleTabBar(controller: _tabController),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _FeesTab(allocAsync: allocAsync, feeMapAsync: feeMapAsync),
                    const _HistoryTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Top Bar
class _PortalTopBar extends ConsumerWidget {
  const _PortalTopBar({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.blobSky, AppColors.blobLavender]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.school_rounded, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ORACLE', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              Text('Student Portal', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go('/portal/login');
            },
            icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
            tooltip: 'Sign out',
          ),
        ],
      ),
    );
  }
}

// Profile Header
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.student});
  final Map<String, dynamic>? student;

  @override
  Widget build(BuildContext context) {
    final name = student?['full_name'] as String? ??
        (student?['profile'] as Map?)?['full_name'] as String? ?? 'Student';
    final roll = student?['roll_number'] as String? ?? '--';
    final grade = student?['grade'] as String? ?? '';
    final section = student?['section'] as String? ?? '';
    final role = student?['role'] as String? ?? 'student';
    final isParent = role == 'parent';
    final words = name.trim().split(' ');
    final initials = words.take(2).map((w) => w.isEmpty ? '' : w[0]).join().toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.blobSky, AppColors.blobLavender], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(child: Text(initials, style: const TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                      if (isParent) ...[const SizedBox(width: 8), _RoleBadge(label: 'Parent', color: AppColors.blobLavender)],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.badge_outlined, size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text('Roll: $roll', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      if (grade.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.class_outlined, size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text('Grade $grade${section.isNotEmpty ? " – $section" : ""}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.05),
    );
  }
}

class _ProfileHeaderSkeleton extends StatelessWidget {
  const _ProfileHeaderSkeleton();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(width: 56, height: 56, decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(16))),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(height: 16, width: 140, decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 8),
              Container(height: 12, width: 100, decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(6))),
            ])),
          ],
        ),
      ),
    );
  }
}

// Fee Summary Banner
class _FeeSummaryBanner extends StatelessWidget {
  const _FeeSummaryBanner({required this.allocations});
  final List<AllocationBalance> allocations;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final totalPaid = allocations.fold(0.0, (s, a) => s + a.totalPaid);
    final totalOutstanding = allocations.fold(0.0, (s, a) => s + a.outstandingAmount);
    final overdueCount = allocations.where((a) => a.outstandingAmount > 0 && a.dueDate.isBefore(DateTime.now())).length;
    final paidCount = allocations.where((a) => a.status == AllocationStatus.paid).length;
    final total = allocations.length;
    final paidFraction = total == 0 ? 0.0 : paidCount / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        accentColor: totalOutstanding > 0 ? AppColors.warning : AppColors.success,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _SummaryMetric(label: 'Total Paid', value: fmt.format(totalPaid), color: AppColors.success, icon: Icons.check_circle_outline_rounded)),
                Container(width: 1, height: 44, color: AppColors.glassBorder),
                Expanded(child: _SummaryMetric(label: 'Outstanding', value: fmt.format(totalOutstanding), color: totalOutstanding > 0 ? AppColors.error : AppColors.success, icon: Icons.pending_outlined)),
                Container(width: 1, height: 44, color: AppColors.glassBorder),
                Expanded(child: _SummaryMetric(label: 'Overdue', value: overdueCount == 0 ? 'None' : '\ fee', color: overdueCount > 0 ? AppColors.error : AppColors.success, icon: Icons.warning_amber_rounded)),
              ],
            ),
            if (total > 0) ...[
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('\ of \ fees settled', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      Text('\%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: paidFraction,
                      minHeight: 6,
                      backgroundColor: AppColors.bg3,
                      valueColor: AlwaysStoppedAnimation<Color>(paidFraction >= 1.0 ? AppColors.success : AppColors.blobSky),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ).animate().fadeIn(duration: 600.ms, delay: 100.ms).slideY(begin: 0.05),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value, required this.color, required this.icon});
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w700, color: color), textAlign: TextAlign.center),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted), textAlign: TextAlign.center),
    ]);
  }
}

// Tab Bar
class _OracleTabBar extends StatelessWidget {
  const _OracleTabBar({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.glassBorder)),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.blobSky, AppColors.blobLavender]), borderRadius: BorderRadius.circular(11)),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        tabs: const [Tab(text: '  My Fees  '), Tab(text: '  History  ')],
      ),
    );
  }
}

// Fees Tab
class _FeesTab extends ConsumerWidget {
  const _FeesTab({required this.allocAsync, required this.feeMapAsync});
  final AsyncValue<List<AllocationBalance>> allocAsync;
  final AsyncValue<Map<String, FeeStructure>> feeMapAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return allocAsync.when(
      data: (allocations) {
        if (allocations.isEmpty) {
          return const _EmptyState(icon: Icons.receipt_long_outlined, title: 'No fee allocations', subtitle: 'Your fee records will appear here once assigned.');
        }
        final feeMap = feeMapAsync.valueOrNull ?? {};
        return RefreshIndicator(
          color: AppColors.blobSky,
          backgroundColor: AppColors.bg2,
          onRefresh: () async {
            ref.invalidate(portalAllocationsProvider);
            ref.invalidate(portalFeeStructureMapProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: allocations.length,
            itemBuilder: (ctx, i) {
              final balance = allocations[i];
              final fs = feeMap[balance.feeStructureId];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FeeAllocationCard(balance: balance, feeStructure: fs).animate(delay: (i * 70).ms).fadeIn().slideY(begin: 0.06),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.blobSky)),
      error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 40),
        const SizedBox(height: 12),
        Text(e.toString(), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
      ])),
    );
  }
}

// Fee Allocation Card
class _FeeAllocationCard extends StatelessWidget {
  const _FeeAllocationCard({required this.balance, this.feeStructure});
  final AllocationBalance balance;
  final FeeStructure? feeStructure;

  Color get _statusColor => switch (balance.status) {
    AllocationStatus.paid => AppColors.success,
    AllocationStatus.partiallyPaid => AppColors.warning,
    AllocationStatus.waived => AppColors.info,
    AllocationStatus.unpaid => AppColors.error,
  };

  bool get _isOverdue => balance.outstandingAmount > 0 && balance.dueDate.isBefore(DateTime.now());

  IconData _categoryIcon(String category) => switch (category.toLowerCase()) {
    'tuition' => Icons.menu_book_rounded,
    'transport' => Icons.directions_bus_rounded,
    'lab' => Icons.science_rounded,
    'sports' => Icons.sports_soccer_rounded,
    'hostel' => Icons.hotel_rounded,
    'library' => Icons.local_library_rounded,
    _ => Icons.receipt_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final dateFmt = DateFormat('d MMM y');
    final title = feeStructure?.title ?? 'Fee';
    final category = feeStructure?.category ?? '';

    return GlassCard(
      accentColor: _isOverdue ? AppColors.error : _statusColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: _statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(_categoryIcon(category), size: 20, color: _statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  if (category.isNotEmpty)
                    Text(category.toUpperCase(), style: const TextStyle(fontSize: 10, letterSpacing: 1.0, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                ]),
              ),
              _StatusChip(status: balance.status, isOverdue: _isOverdue),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.glassBorder, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _AmountItem(label: 'Base Amount', value: fmt.format(balance.baseAmount), color: AppColors.textPrimary)),
              Expanded(child: _AmountItem(label: 'Paid', value: fmt.format(balance.totalPaid), color: AppColors.success)),
              Expanded(child: _AmountItem(label: 'Outstanding', value: fmt.format(balance.outstandingAmount), color: balance.outstandingAmount > 0 ? AppColors.error : AppColors.success)),
            ],
          ),
          if (balance.totalPenalties > 0 || balance.totalWaivers > 0) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              if (balance.totalPenalties > 0) _TagChip(label: '+  penalty', color: AppColors.error),
              if (balance.totalWaivers > 0) _TagChip(label: '-  waiver', color: AppColors.info),
            ]),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(_isOverdue ? Icons.warning_amber_rounded : Icons.calendar_today_outlined, size: 14, color: _isOverdue ? AppColors.error : AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(child: Text(
                'Due ${dateFmt.format(balance.dueDate.toLocal())}${_isOverdue ? " — OVERDUE" : ""}',
                style: TextStyle(fontSize: 12, fontWeight: _isOverdue ? FontWeight.w600 : FontWeight.normal, color: _isOverdue ? AppColors.error : AppColors.textSecondary),
              )),
              if (balance.outstandingAmount > 0) _PayButton(allocationId: balance.allocationId, amount: balance.outstandingAmount),
            ],
          ),
        ],
      ),
    );
  }
}

class _PayButton extends StatelessWidget {
  const _PayButton({required this.allocationId, required this.amount});
  final String allocationId;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return GestureDetector(
      onTap: () => context.go('/portal/dashboard/payment/$allocationId'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.blobSky, AppColors.blobLavender]),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: AppColors.blobSky.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.payment_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text('Pay ${fmt.format(amount)}', style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
      ),
    );
  }
}

// History Tab
class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(portalTransactionsProvider);
    return txAsync.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return const _EmptyState(icon: Icons.history_rounded, title: 'No payment history', subtitle: 'Your completed payments will appear here.');
        }
        return RefreshIndicator(
          color: AppColors.blobSky,
          backgroundColor: AppColors.bg2,
          onRefresh: () async => ref.invalidate(portalTransactionsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: transactions.length,
            itemBuilder: (ctx, i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TransactionTile(tx: transactions[i]).animate(delay: (i * 50).ms).fadeIn().slideX(begin: 0.04),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.blobSky)),
      error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.error))),
    );
  }
}

// Transaction Tile
class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx});
  final FeeTransaction tx;

  Color get _statusColor => switch (tx.paymentStatus) {
    PaymentStatus.success => AppColors.success,
    PaymentStatus.failed => AppColors.error,
    PaymentStatus.pending => AppColors.warning,
  };

  IconData get _methodIcon => switch (tx.paymentMethod) {
    PaymentMethod.upi => Icons.qr_code_rounded,
    PaymentMethod.cash => Icons.payments_rounded,
    PaymentMethod.cheque => Icons.receipt_long_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '\u20b9', decimalDigits: 0);
    final dateFmt = DateFormat('d MMM y, h:mm a');

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      accentColor: _statusColor,
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: _statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(_methodIcon, size: 20, color: _statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(tx.paymentMethod.label, style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(width: 6),
                  _MiniStatusBadge(status: tx.paymentStatus),
                ]),
                const SizedBox(height: 2),
                Text(dateFmt.format(tx.createdAt.toLocal()), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                if (tx.referenceNumber != null) ...[
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: tx.referenceNumber!));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reference copied'), duration: Duration(seconds: 1), backgroundColor: AppColors.bg2));
                    },
                    child: Row(children: [
                      const Icon(Icons.copy_rounded, size: 11, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text('Ref: ', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ]),
                  ),
                ],
              ],
            ),
          ),
          Text(fmt.format(tx.amountPaid), style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w700, color: _statusColor)),
        ],
      ),
    );
  }
}

// Shared small widgets
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, this.isOverdue = false});
  final AllocationStatus status;
  final bool isOverdue;

  Color get _color => isOverdue ? AppColors.error : switch (status) {
    AllocationStatus.paid => AppColors.success,
    AllocationStatus.partiallyPaid => AppColors.warning,
    AllocationStatus.waived => AppColors.info,
    AllocationStatus.unpaid => AppColors.error,
  };

  String get _label => isOverdue ? 'OVERDUE' : switch (status) {
    AllocationStatus.paid => 'PAID',
    AllocationStatus.partiallyPaid => 'PARTIAL',
    AllocationStatus.waived => 'WAIVED',
    AllocationStatus.unpaid => 'UNPAID',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: _color.withOpacity(0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: _color.withOpacity(0.3))),
      child: Text(_label, style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.w700, color: _color, letterSpacing: 0.5)),
    );
  }
}

class _MiniStatusBadge extends StatelessWidget {
  const _MiniStatusBadge({required this.status});
  final PaymentStatus status;

  Color get _color => switch (status) {
    PaymentStatus.success => AppColors.success,
    PaymentStatus.failed => AppColors.error,
    PaymentStatus.pending => AppColors.warning,
  };

  String get _label => switch (status) {
    PaymentStatus.success => 'SUCCESS',
    PaymentStatus.failed => 'FAILED',
    PaymentStatus.pending => 'PENDING',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: _color.withOpacity(0.12), borderRadius: BorderRadius.circular(5)),
      child: Text(_label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _color, letterSpacing: 0.4)),
    );
  }
}

class _AmountItem extends StatelessWidget {
  const _AmountItem({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ]);
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.25))),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 56, color: AppColors.textMuted),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textMuted), textAlign: TextAlign.center),
      ]).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }
}
