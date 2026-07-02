import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/revenue_metric_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(revenueMetricsProvider);
    final defaultersAsync = ref.watch(defaultersProvider);
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      body: OracleBackground(
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(onRefresh: () {
                ref.invalidate(revenueMetricsProvider);
                ref.invalidate(defaultersProvider);
              }),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.blobSky,
                  backgroundColor: AppColors.bg2,
                  onRefresh: () async {
                    ref.invalidate(revenueMetricsProvider);
                    ref.invalidate(defaultersProvider);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Metric Cards Row ─────────────────────────
                        metricsAsync.when(
                          data: (m) => _MetricRow(metrics: m, isWide: isWide),
                          loading: () => _MetricRow(
                            metrics: RevenueMetrics.empty(),
                            isWide: isWide,
                            isLoading: true,
                          ),
                          error: (e, _) => _ErrorBanner(message: e.toString()),
                        ),
                        const SizedBox(height: 24),

                        // ── Charts Row ───────────────────────────────
                        metricsAsync.when(
                          data: (m) => isWide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _DonutChartCard(metrics: m)),
                                    const SizedBox(width: 16),
                                    Expanded(child: _MonthlyBarChartCard()),
                                  ],
                                )
                              : Column(children: [
                                  _DonutChartCard(metrics: m),
                                  const SizedBox(height: 16),
                                  _MonthlyBarChartCard(),
                                ]),
                          loading: () => const SizedBox(height: 240),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 24),

                        // ── Defaulter Table ──────────────────────────
                        _SectionHeader(
                          title: 'Defaulter Tracker',
                          subtitle: 'Ranked by days overdue × outstanding amount',
                          action: TextButton.icon(
                            onPressed: () => context.go('/org/dashboard/pending-verification'),
                            icon: const Icon(Icons.pending_actions, size: 16, color: AppColors.warning),
                            label: metricsAsync.whenData((m) => m.pendingVerification).valueOrNull != null
                                ? Text(
                                    '${metricsAsync.valueOrNull?.pendingVerification ?? 0} pending',
                                    style: const TextStyle(color: AppColors.warning, fontSize: 13),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        defaultersAsync.when(
                          data: (list) => list.isEmpty
                              ? _EmptyState(
                                  icon: Icons.check_circle_outline_rounded,
                                  message: 'No defaulters! All fees are up to date.',
                                  color: AppColors.success,
                                )
                              : _DefaulterTable(defaulters: list),
                          loading: () => const Center(
                            child: CircularProgressIndicator(color: AppColors.blobSky),
                          ),
                          error: (e, _) => _ErrorBanner(message: e.toString()),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Top Bar ─────────────────────────────────────────────────
class _TopBar extends ConsumerWidget {
  const _TopBar({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Logo mark
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppGradients.accentCard,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text('O',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ORACLE',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: 3)),
              Text(
                DateFormat('EEEE, d MMM y').format(DateTime.now()),
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const Spacer(),
          // Quick actions
          _NavButton(
            icon: Icons.add_circle_outline,
            label: 'Manual Entry',
            onTap: () => context.go('/org/dashboard/manual-entry'),
          ),
          const SizedBox(width: 8),
          _NavButton(
            icon: Icons.settings_outlined,
            label: 'Fee Structures',
            onTap: () => context.go('/org/dashboard/fee-structures'),
          ),
          const SizedBox(width: 8),
          _NavButton(
            icon: Icons.people_outline,
            label: 'Manage Users',
            onTap: () => context.go('/org/dashboard/manage-users'),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
            icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
            tooltip: 'Sign Out',
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: AppColors.glassFill,
        foregroundColor: AppColors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

// ── Metric Cards Row ─────────────────────────────────────────
class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.metrics,
    required this.isWide,
    this.isLoading = false,
  });

  final RevenueMetrics metrics;
  final bool isWide;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cards = [
      RevenueMetricCard(
        label: 'Total Collected',
        value: metrics.totalCollected,
        subtitle: 'Across all fee categories',
        icon: Icons.account_balance_wallet_outlined,
        accentColor: AppColors.success,
        trend: 12.4,
        isLoading: isLoading,
      ),
      RevenueMetricCard(
        label: 'Outstanding',
        value: metrics.totalOutstanding,
        subtitle: 'Pending from all students',
        icon: Icons.receipt_long_outlined,
        accentColor: AppColors.warning,
        trend: -3.1,
        isLoading: isLoading,
      ),
      RevenueMetricCard(
        label: 'Defaulters',
        value: metrics.defaulterCount.toDouble(),
        subtitle: 'Students past due date',
        icon: Icons.warning_amber_rounded,
        accentColor: AppColors.error,
        isLoading: isLoading,
      ),
      RevenueMetricCard(
        label: 'Pending Verification',
        value: metrics.pendingVerification.toDouble(),
        subtitle: 'Cash/Cheque awaiting confirm',
        icon: Icons.pending_outlined,
        accentColor: AppColors.pending,
        isLoading: isLoading,
      ),
    ];

    if (isWide) {
      return Row(
        children: cards
            .map((c) => Expanded(child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: c,
                )))
            .toList(),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cards,
    );
  }
}

// ── Donut Chart ──────────────────────────────────────────────
class _DonutChartCard extends StatefulWidget {
  const _DonutChartCard({required this.metrics});
  final RevenueMetrics metrics;

  @override
  State<_DonutChartCard> createState() => _DonutChartCardState();
}

class _DonutChartCardState extends State<_DonutChartCard> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final breakdown = widget.metrics.categoryBreakdown;
    final total = breakdown.values.fold(0.0, (a, b) => a + b);

    final sections = breakdown.entries.toList().asMap().entries.map((e) {
      final idx = e.key;
      final entry = e.value;
      final pct = total > 0 ? (entry.value / total) * 100 : 0.0;
      final isTouched = _touchedIndex == idx;

      return PieChartSectionData(
        color: AppColors.chartPalette[idx % AppColors.chartPalette.length],
        value: entry.value,
        title: isTouched ? '${pct.toStringAsFixed(1)}%' : '',
        radius: isTouched ? 80 : 68,
        titleStyle: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    }).toList();

    // Fallback placeholder sections
    final chartSections = sections.isEmpty
        ? [
            PieChartSectionData(color: AppColors.bg3, value: 1, title: '', radius: 68),
          ]
        : sections;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChartHeader(
            title: 'Revenue by Category',
            subtitle: 'Tap a segment for details',
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sections: chartSections,
                      centerSpaceRadius: 48,
                      sectionsSpace: 3,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            _touchedIndex =
                                response?.touchedSection?.touchedSectionIndex;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                // Legend
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: breakdown.entries.toList().asMap().entries.map((e) {
                    final color = AppColors.chartPalette[e.key % AppColors.chartPalette.length];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _capitalize(e.value.key),
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 700.ms, delay: 200.ms);
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ── Monthly Bar Chart ────────────────────────────────────────
class _MonthlyBarChartCard extends StatelessWidget {
  const _MonthlyBarChartCard();

  @override
  Widget build(BuildContext context) {
    // Mock monthly data for demo — replace with real query
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
    final collected = [180000, 220000, 195000, 310000, 275000, 340000];
    final outstanding = [80000, 60000, 95000, 45000, 70000, 55000];

    final maxY = 400000.0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChartHeader(
            title: 'Monthly Collection Trend',
            subtitle: 'Collected vs Outstanding (₹)',
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.glassBorder,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Text(
                        months[v.toInt()],
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                barGroups: List.generate(months.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: collected[i].toDouble(),
                        color: AppColors.blobSky,
                        width: 10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      BarChartRodData(
                        toY: outstanding[i].toDouble(),
                        color: AppColors.blobLavender.withOpacity(0.6),
                        width: 10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _LegendDot(color: AppColors.blobSky, label: 'Collected'),
              const SizedBox(width: 16),
              _LegendDot(color: AppColors.blobLavender, label: 'Outstanding'),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 700.ms, delay: 300.ms);
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontFamily: 'Outfit', fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ── Defaulter Table ──────────────────────────────────────────
class _DefaulterTable extends StatefulWidget {
  const _DefaulterTable({required this.defaulters});
  final List<Defaulter> defaulters;

  @override
  State<_DefaulterTable> createState() => _DefaulterTableState();
}

class _DefaulterTableState extends State<_DefaulterTable> {
  String _search = '';

  List<Defaulter> get _filtered => widget.defaulters.where((d) {
        final q = _search.toLowerCase();
        return d.studentName.toLowerCase().contains(q) ||
            d.rollNumber.toLowerCase().contains(q) ||
            d.feeTitle.toLowerCase().contains(q);
      }).toList();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(0),
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Search student, roll no, fee type…',
                      prefixIcon: Icon(Icons.search, color: AppColors.textSecondary, size: 18),
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.glassBorder),

          // Table header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: const [
                _TableHeader('#', flex: 1),
                _TableHeader('Student', flex: 4),
                _TableHeader('Fee Type', flex: 3),
                _TableHeader('Outstanding', flex: 3),
                _TableHeader('Overdue', flex: 2),
                _TableHeader('Actions', flex: 3),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.glassBorder),

          // Rows
          ..._filtered.asMap().entries.map(
                (e) => _DefaulterRow(
                  rank: e.key + 1,
                  defaulter: e.value,
                ).animate(delay: (e.key * 50).ms).fadeIn().slideX(begin: -0.05),
              ),

          if (_filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No results for "$_search"',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.text, {required this.flex});
  final String text;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _DefaulterRow extends StatelessWidget {
  const _DefaulterRow({required this.rank, required this.defaulter});
  final int rank;
  final Defaulter defaulter;

  Color get _urgencyColor {
    if (defaulter.daysOverdue > 30) return AppColors.error;
    if (defaulter.daysOverdue > 14) return AppColors.warning;
    return AppColors.pending;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Rank
              Expanded(
                flex: 1,
                child: Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: _urgencyColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _urgencyColor,
                      ),
                    ),
                  ),
                ),
              ),

              // Student name + roll
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      defaulter.studentName,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      defaulter.rollNumber,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),

              // Fee type
              Expanded(
                flex: 3,
                child: Text(
                  defaulter.feeTitle,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Outstanding amount
              Expanded(
                flex: 3,
                child: Text(
                  fmt.format(defaulter.balance.outstandingAmount),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              // Days overdue badge
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _urgencyColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${defaulter.daysOverdue}d',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _urgencyColor,
                    ),
                  ),
                ),
              ),

              // Quick Actions
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    _QuickAction(
                      icon: Icons.notifications_outlined,
                      tooltip: 'Send Reminder',
                      color: AppColors.info,
                      onTap: () => _sendReminder(context, defaulter),
                    ),
                    const SizedBox(width: 6),
                    _QuickAction(
                      icon: Icons.remove_circle_outline,
                      tooltip: 'Apply Waiver',
                      color: AppColors.warning,
                      onTap: () => _showWaiverModal(context, defaulter),
                    ),
                    const SizedBox(width: 6),
                    _QuickAction(
                      icon: Icons.open_in_new_rounded,
                      tooltip: 'View Ledger',
                      color: AppColors.blobSky,
                      onTap: () => context.go(
                        '/org/dashboard/student/${defaulter.balance.studentId}/ledger',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.glassBorder),
      ],
    );
  }

  void _sendReminder(BuildContext context, Defaulter d) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final msg =
        'Dear Parent of ${d.studentName}, your fee of ${fmt.format(d.balance.outstandingAmount)} for "${d.feeTitle}" is overdue by ${d.daysOverdue} days. Please pay immediately. — ORACLE School';
    final encoded = Uri.encodeComponent(msg);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reminder message generated for ${d.studentName}'),
        backgroundColor: AppColors.info,
        action: SnackBarAction(
          label: 'WhatsApp',
          textColor: Colors.white,
          onPressed: () {/* launch WhatsApp deep link */},
        ),
      ),
    );
  }

  void _showWaiverModal(BuildContext context, Defaulter d) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _WaiverModal(defaulter: d),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}

// ── Waiver Modal ─────────────────────────────────────────────
class _WaiverModal extends ConsumerStatefulWidget {
  const _WaiverModal({required this.defaulter});
  final Defaulter defaulter;

  @override
  ConsumerState<_WaiverModal> createState() => _WaiverModalState();
}

class _WaiverModalState extends ConsumerState<_WaiverModal> {
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _applyWaiver() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.from('adjustments').insert({
        'allocation_id': widget.defaulter.balance.allocationId,
        'type': 'WAIVER',
        'amount': amount,
        'reason': _reasonController.text.trim(),
        'applied_by': Supabase.instance.client.auth.currentUser?.id,
      });
      ref.invalidate(defaultersProvider);
      ref.invalidate(revenueMetricsProvider);
      if (mounted) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Waiver of ₹${amount.toStringAsFixed(0)} applied'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: GlassCard(
        borderRadius: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.remove_circle_outline, color: AppColors.warning),
                const SizedBox(width: 10),
                Text('Apply Waiver',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.defaulter.studentName} — ${widget.defaulter.feeTitle}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Waiver Amount (₹)',
                prefixIcon: Icon(Icons.currency_rupee, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              maxLines: 2,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Reason (e.g. Merit Scholarship 10%)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _applyWaiver,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
              child: _loading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg0))
                  : const Text('Apply Waiver'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Supporting widgets ───────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.action,
  });
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            Text(subtitle,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
        const Spacer(),
        if (action != null) action!,
      ],
    );
  }
}

class _ChartHeader extends StatelessWidget {
  const _ChartHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        Text(subtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
              child: Text(message,
                  style: const TextStyle(color: AppColors.error, fontSize: 13))),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.icon, required this.message, required this.color});
  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(icon, color: color, size: 48),
            const SizedBox(height: 12),
            Text(message,
                style: TextStyle(
                    fontFamily: 'Outfit', color: color, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
