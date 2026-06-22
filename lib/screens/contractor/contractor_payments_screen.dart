import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_menu_button.dart';
import '../../config/help_content.dart';
import '../../widgets/tap_tooltip.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/contractor_payments.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import '../../services/contractor_payments_service.dart';
import '../../utils/app_notification.dart';
import '../auth/login_screen.dart';

/// Contractor Payments / My Earnings. Matches web: /contractor/payments.
/// Current period summary, recent services, payment history, payment schedule info.
class ContractorPaymentsScreen extends StatefulWidget {
  const ContractorPaymentsScreen({super.key});

  @override
  State<ContractorPaymentsScreen> createState() => _ContractorPaymentsScreenState();
}

class _ContractorPaymentsScreenState extends State<ContractorPaymentsScreen> {
  final ContractorPaymentsService _service = ContractorPaymentsService();
  PaymentSummary? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = StorageService().getToken();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (token == null || token.isEmpty || user == null) {
      if (mounted) _handleSessionExpired();
      return;
    }
    if (user.role != 'contractor' && user.role != 'worker') {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await _service.getSummary();
      if (mounted) {
        setState(() {
          _summary = summary;
          _loading = false;
        });
      }
    } on ContractorPaymentsException catch (e) {
      if (e.isUnauthorized && mounted) {
        _handleSessionExpired();
        return;
      }
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _handleSessionExpired() async {
    await StorageService().clearAll();
    if (!mounted) return;
    Provider.of<AuthProvider>(context, listen: false).logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  static String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  static String _formatDate(String dateStr) {
    try {
      final d = DateTime.tryParse(dateStr);
      if (d == null) return dateStr;
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return dateStr;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
      case 'completed':
        return AppColors.success;
      case 'processing':
      case 'approved':
        return AppColors.blue600;
      case 'pending':
        return AppColors.warning;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: const AppMenuButton(),
        title: const Text(
          'My Earnings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          ScreenHelpAction(
            title: 'Payments',
            message: HelpContent.screenContractorPayments,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading && _summary == null
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.blue600),
                    ),
                    SizedBox(height: 16),
                    Text('Loading payment data…', style: TextStyle(color: AppColors.textMuted)),
                  ],
                ),
              )
            : _error != null && _summary == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: AppColors.error),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: const TextStyle(color: AppColors.error, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh, size: 20),
                            label: const Text('Retry'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.blue600,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    child: _summary == null
                        ? const SizedBox.shrink()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSubtitle(),
                              const SizedBox(height: 20),
                              _buildCurrentPeriodCards(_summary!.currentPeriod),
                              const SizedBox(height: 24),
                              _buildRecentServices(_summary!.recentServices),
                              const SizedBox(height: 24),
                              _buildPaymentHistory(_summary!.historicalPayouts),
                              const SizedBox(height: 24),
                              _buildPaymentScheduleInfo(),
                            ],
                          ),
                  ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return Text(
      'Track your income and payment history',
      style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
    );
  }

  Widget _buildCurrentPeriodCards(CurrentPeriod period) {
    final avgPerJob = period.completedJobs > 0
        ? period.totalEarnings / period.completedJobs
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                title: 'Current Period',
                value: _formatCurrency(period.totalEarnings),
                subtitle: '${_formatDate(period.startDate)} – ${_formatDate(period.endDate)}',
                gradient: true,
                icon: Icons.attach_money,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                title: 'Completed Jobs',
                value: '${period.completedJobs}',
                subtitle: 'This period',
                icon: Icons.check_circle_outline,
                iconColor: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                title: 'Pending Jobs',
                value: '${period.pendingJobs}',
                subtitle: 'Awaiting approval',
                icon: Icons.schedule,
                iconColor: AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                title: 'Avg per Job',
                value: _formatCurrency(avgPerJob),
                subtitle: 'This period',
                icon: Icons.trending_up,
                iconColor: AppColors.blue600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required String subtitle,
    bool gradient = false,
    IconData? icon,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
              )
            : null,
        color: gradient ? null : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: gradient ? Colors.white.withOpacity(0.9) : Colors.grey.shade600,
                ),
              ),
              if (icon != null)
                Icon(
                  icon,
                  size: 20,
                  color: gradient ? Colors.white.withOpacity(0.8) : (iconColor ?? Colors.grey),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: gradient ? Colors.white : Colors.grey.shade900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: gradient ? Colors.white.withOpacity(0.8) : Colors.grey.shade500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentServices(List<ServiceRecord> services) {
    return _sectionCard(
      title: 'Recent Services',
      subtitle: 'Latest completed work',
      child: Column(
        children: [
          for (int i = 0; i < services.length; i++) ...[
            if (i > 0) Divider(height: 1, color: Colors.grey.shade200),
            _serviceRow(services[i]),
          ],
        ],
      ),
    );
  }

  Widget _serviceRow(ServiceRecord s) {
    final color = _statusColor(s.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(s.date),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  s.propertyName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  s.serviceType,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Text(
              s.status.toUpperCase(),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatCurrency(s.amount),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistory(List<PayoutRecord> payouts) {
    return _sectionCard(
      title: 'Payment History',
      subtitle: 'Previous period payouts',
      trailing: TextButton.icon(
        onPressed: () {
          AppNotification.info(context, 'Export available on web');
        },
        icon: const Icon(Icons.download, size: 18),
        label: const Text('Export'),
        style: TextButton.styleFrom(foregroundColor: AppColors.blue600),
      ),
      child: Column(
        children: [
          for (int i = 0; i < payouts.length; i++) ...[
            if (i > 0) Divider(height: 1, color: Colors.grey.shade200),
            _payoutRow(payouts[i]),
          ],
        ],
      ),
    );
  }

  Widget _payoutRow(PayoutRecord p) {
    final color = _statusColor(p.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatDate(p.periodStart)} – ${_formatDate(p.periodEnd)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  '${p.jobsCount} jobs · ${p.paymentMethod}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  'Paid ${_formatDate(p.paidDate)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Text(
              p.status.toUpperCase(),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatCurrency(p.totalAmount),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentScheduleInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.blue600.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.blue600.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 22, color: AppColors.blue600),
              const SizedBox(width: 10),
              Text(
                'Payment Schedule',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Payments are processed on the 5th of each month for work completed in the previous month.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.4),
          ),
          const SizedBox(height: 10),
          _bullet('Jobs must be marked as "Completed" to be included in payment'),
          _bullet('Property managers review and approve services within 48 hours'),
          _bullet('Direct deposit typically takes 2–3 business days'),
          _bullet('For payment inquiries, contact support@winterimp.com'),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(fontSize: 14, color: AppColors.blue600, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
