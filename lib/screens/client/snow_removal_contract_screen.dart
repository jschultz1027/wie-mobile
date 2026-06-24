import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_menu_button.dart';
import '../../config/help_content.dart';
import '../../widgets/tap_tooltip.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/snow_removal_contract.dart';
import '../../providers/auth_provider.dart';
import '../../services/snow_removal_contract_service.dart';
import '../../utils/app_notification.dart';

/// Client Snow Removal Contract. Matches web /snow-removal-contract.
class SnowRemovalContractScreen extends StatefulWidget {
  const SnowRemovalContractScreen({super.key});

  @override
  State<SnowRemovalContractScreen> createState() =>
      _SnowRemovalContractScreenState();
}

class _SnowRemovalContractScreenState extends State<SnowRemovalContractScreen> {
  late SnowRemovalContractDetails _contract;
  int _selectedTabIndex = 0; // 0=Overview, 1=Properties, 2=Pricing, 3=Terms

  @override
  void initState() {
    super.initState();
    _contract = SnowRemovalContractService.getMockContract();
  }

  int get _daysRemaining {
    final end = DateTime.tryParse(_contract.endDate);
    if (end == null) return 0;
    final now = DateTime.now();
    final diff = end.difference(now).inDays;
    return diff > 0 ? diff : 0;
  }

  String _formatDate(String? d) {
    if (d == null || d.isEmpty) return '—';
    final dt = DateTime.tryParse(d);
    if (dt == null) return d;
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.user != null && !auth.user!.isClient) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(title: const Text('Snow Removal Contract')),
        body: const Center(child: Text('Client only')),
      );
    }

    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: const AppMenuButton(),
        title: const Text(
          'Snow Removal Contract',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          ScreenHelpAction(
            title: 'Snow Removal Contract',
            message: HelpContent.screenSnowRemovalContract,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() =>
              _contract = SnowRemovalContractService.getMockContract());
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Contract #${_contract.contractNumber}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              _buildStatusBanner(),
              const SizedBox(height: 16),
              _buildQuickStats(),
              const SizedBox(height: 16),
              _buildTabs(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    final isActive = _contract.isActive;
    final bgColor = isActive ? Colors.green.shade50 : Colors.red.shade50;
    final borderColor = isActive ? Colors.green.shade200 : Colors.red.shade200;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isActive ? Icons.check_circle : Icons.warning_amber,
                size: 40,
                color: isActive ? AppColors.success : AppColors.error,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contract Status: ${_contract.status.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isActive
                          ? '$_daysRemaining days remaining in current season'
                          : 'Please contact us to renew your contract',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                AppNotification.info(context, 'Download contract PDF on web');
              },
              icon: const Icon(Icons.download, size: 20),
              label: const Text('Download Contract PDF'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.roleAdmin,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final totalAreaK = _contract.totalAreaSqft / 1000;
    final serviceTypeLabel = _contract.serviceType == 'pay_per_service'
        ? 'Pay-per Service'
        : _contract.serviceType == 'monthly_base'
            ? 'Monthly Base Rate'
            : 'Pre-paid Seasonal';

    final stats = <({String label, String value, Color accent})>[
      (label: 'Contract Period', value: '7 months', accent: AppColors.roleAdmin),
      (
        label: 'Properties Covered',
        value: '${_contract.properties.length}',
        accent: AppColors.blue600,
      ),
      (
        label: 'Total Area',
        value: '${totalAreaK.toStringAsFixed(1)}k sq ft',
        accent: AppColors.success,
      ),
      (label: 'Service Type', value: serviceTypeLabel, accent: Colors.orange),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        if (constraints.maxWidth >= 640) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  Expanded(
                    child: _statCard(
                      stats[i].label,
                      stats[i].value,
                      stats[i].accent,
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        // Phone / narrow: balanced 2×2 grid — equal width and equal height per row
        return Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _statCard(stats[0].label, stats[0].value, stats[0].accent),
                  ),
                  const SizedBox(width: gap),
                  Expanded(
                    child: _statCard(stats[1].label, stats[1].value, stats[1].accent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: gap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _statCard(stats[2].label, stats[2].value, stats[2].accent),
                  ),
                  const SizedBox(width: gap),
                  Expanded(
                    child: _statCard(stats[3].label, stats[3].value, stats[3].accent),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statCard(String label, String value, Color accent) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: accent.withOpacity(0.5), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  static const List<String> _tabLabels = [
    'Overview',
    'Properties',
    'Pricing',
    'Terms',
  ];

  Widget _buildTabs() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(
                _tabLabels.length,
                (i) => InkWell(
                  onTap: () => setState(() => _selectedTabIndex = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _selectedTabIndex == i
                              ? AppColors.roleAdmin
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      _tabLabels[i],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _selectedTabIndex == i
                            ? AppColors.roleAdmin
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildPropertiesTab();
      case 2:
        return _buildPricingTab();
      case 3:
        return _buildTermsTab();
      default:
        return _buildOverviewTab();
    }
  }

  Widget _buildOverviewTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Contract Information',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final periodTile = _infoTile(
              Icons.calendar_today,
              'Contract Period',
              '${_formatDate(_contract.startDate)} - ${_formatDate(_contract.endDate)}',
              AppColors.roleAdmin,
            );
            final locationsTile = _infoTile(
              Icons.location_on,
              'Service Locations',
              '${_contract.properties.length} Properties',
              AppColors.blue600,
            );
            if (constraints.maxWidth < 360) {
              return Column(
                children: [
                  periodTile,
                  const SizedBox(height: 8),
                  locationsTile,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: periodTile),
                const SizedBox(width: 8),
                Expanded(child: locationsTile),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        const Text(
          'Services Included',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ..._contract.services.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Your Account Manager',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.roleAdmin.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.roleAdmin.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.roleAdmin.withOpacity(0.3),
                    child: Text(
                      _contract.contact.accountManager
                          .split(' ')
                          .map((e) => e.isNotEmpty ? e[0] : '')
                          .join()
                          .toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _contract.contact.accountManager,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Senior Account Manager',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Phone: ${_contract.contact.phone}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade800,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Email: ${_contract.contact.email}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade800,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                '24/7 Emergency: ${_contract.contact.emergencyLine}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoTile(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertiesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Covered Properties',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._contract.properties.map(
          (p) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on,
                        color: AppColors.roleAdmin,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              p.address,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Service Area: ${p.areaSqft.toStringAsFixed(0)} sq ft',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        AppNotification.info(context, 'View details on web');
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.roleAdmin,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('View Details →'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPricingTab() {
    final p = _contract.pricing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Pricing Structure',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _pricingRateCard(
          title: 'Monthly Base Fee',
          description: 'Covers monitoring and first 5 service calls',
          amount: '\$${p.monthlyBase.toStringAsFixed(0)}/month',
          backgroundColor: AppColors.success.withOpacity(0.08),
          borderColor: AppColors.success.withOpacity(0.3),
          amountColor: AppColors.success,
        ),
        const SizedBox(height: 10),
        _pricingRateCard(
          title: 'Per-Service Rate',
          description: 'Additional services beyond monthly base',
          amount: '\$${p.perService.toStringAsFixed(0)}/service',
          backgroundColor: AppColors.blue600.withOpacity(0.08),
          borderColor: AppColors.blue600.withOpacity(0.3),
          amountColor: AppColors.blue600,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 340) {
              return Column(
                children: [
                  _pricingDetailCard(
                    title: 'Snow Removal',
                    rate: p.snowRemovalRate,
                    subtitle: 'Heavy accumulation events',
                  ),
                  const SizedBox(height: 8),
                  _pricingDetailCard(
                    title: 'Salting & Ice Control',
                    rate: p.saltingRate,
                    subtitle: 'Material cost included',
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _pricingDetailCard(
                    title: 'Snow Removal',
                    rate: p.snowRemovalRate,
                    subtitle: 'Heavy accumulation events',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _pricingDetailCard(
                    title: 'Salting & Ice Control',
                    rate: p.saltingRate,
                    subtitle: 'Material cost included',
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _pricingRateCard({
    required String title,
    required String description,
    required String amount,
    required Color backgroundColor,
    required Color borderColor,
    required Color amountColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Text(
            amount,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: amountColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _pricingDetailCard({
    required String title,
    required String rate,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.attach_money, color: Colors.grey.shade600, size: 28),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            rate,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTermsTab() {
    final t = _contract.terms;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Service Terms & Conditions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _termTile(Icons.access_time, 'Response Time', t.responseTime,
            AppColors.blue600),
        const SizedBox(height: 8),
        _termTile(Icons.calendar_today, 'Service Hours', t.serviceHours,
            AppColors.roleAdmin),
        const SizedBox(height: 8),
        _termTile(Icons.warning_amber, 'Snow Accumulation Trigger',
            t.snowAccumulationTrigger, Colors.orange),
        const SizedBox(height: 8),
        _termTile(
            Icons.check_circle, 'Ice Control Policy', t.iceControl,
            AppColors.success),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Important Notes',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _bullet('Contract automatically renews annually unless 60 days written notice is provided'),
              _bullet('Service frequency may increase during severe weather events'),
              _bullet('All services include post-service photo documentation and digital reporting'),
              _bullet('Payment terms: Net 15 days from invoice date'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _termTile(
    IconData icon,
    String title,
    String value,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
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
            style: TextStyle(
              color: Colors.amber.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade800,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
