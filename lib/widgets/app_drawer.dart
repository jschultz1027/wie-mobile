import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/weather/weather_aggregator_screen.dart';
import '../screens/demo/demo_screen.dart';
import '../screens/hazard/winter_hazard_monitor_screen.dart';
import '../screens/historical/historical_risk_screen.dart';
import '../screens/client/payments_billing_screen.dart';
import '../screens/client/service_reports_screen.dart';
import '../screens/client/snow_removal_contract_screen.dart';
import '../screens/client/client_portal_screen.dart';
import '../screens/client/property_dashboard_screen.dart';
import '../screens/pipeline/complete_pipeline_screen.dart';
import '../screens/weather/multi_property_monitor_screen.dart';
import '../screens/weather/weather_forecast_screen.dart';
import '../screens/contractor/my_equipment_screen.dart';
import '../screens/contractor/shift_history_screen.dart';
import '../screens/contractor/my_level_screen.dart';
import '../screens/contractor/get_verified_screen.dart';
import '../screens/contractor/contractor_payments_screen.dart';
import '../screens/contractor/contractor_availability_screen.dart';
import '../screens/contractor/contractor_dispatches_screen.dart';
import '../screens/admin/availability_calendar_screen.dart';
import '../screens/admin/zone_manager_list_screen.dart';
import '../screens/admin/dispatch_intelligence_screen.dart';
import '../screens/admin/dispatch_queue_screen.dart';
import '../screens/admin/contractor_management_screen.dart';
import '../screens/legal/terms_and_privacy_screen.dart';
import '../config/help_content.dart';
import 'help_overlay.dart';
import 'tap_tooltip.dart';
import '../screens/support/support_ticket_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    if (user == null) {
      return Drawer(
        child: Container(
          color: Color(0xFFF9FAFB),
          child: Center(child: Text('Not logged in')),
        ),
      );
    }

    return Drawer(
      child: Container(
        color: AppColors.slate900, // slate-900 background
        child: Column(
          children: [
            // Drawer Header with gradient - Compact inline layout
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(16, 50, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.slate900, // slate-900
                    AppColors.blue900, // blue-900
                  ],
                ),
              ),
              child: Row(
                children: [
                  // User Avatar
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.blue500, Color(0xFF2563EB)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Icon(Icons.person, color: Colors.white, size: 28),
                  ),
                  SizedBox(width: 12),
                  // User Info (Name + Role inline)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.fullName ?? user.email,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 6),
                        // User Role Badge
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: user.isAdmin
                                ? Color(0xFF7C3AED) // purple
                                : user.isClient
                                    ? AppColors.blue500 // blue
                                    : Color(0xFF16A34A), // green
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            user.isAdmin
                                ? 'Admin'
                                : user.isClient
                                    ? 'Client'
                                    : 'Contractor',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Menu Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Home
                  _buildMenuItem(
                    context,
                    icon: Icons.home,
                    title: 'Home',
                    help: HelpContent.home,
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),

                  // Divider
                  Divider(color: Color(0xFF334155), height: 1),

                  // Tools Section Header
                  _buildSectionHeader('Tools', HelpContent.toolsSection),

                  // Winter Hazard Monitor (All users)
                  _buildMenuItem(
                    context,
                    icon: Icons.warning_amber,
                    title: 'Winter Hazard Monitor',
                    subtitle: user.isClient
                        ? 'Your properties risk'
                        : 'Real-time risk assessment',
                    help: HelpContent.winterHazard,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WinterHazardMonitorScreen(),
                        ),
                      );
                    },
                  ),

                  // Client-specific Tools
                  if (user.isClient) ...[
                    _buildMenuItem(
                      context,
                      icon: Icons.dashboard,
                      title: 'Property Dashboard',
                      subtitle: 'Real-time safety monitoring',
                      help: HelpContent.propertyDashboard,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PropertyDashboardScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.map,
                      title: 'Client Portal',
                      subtitle: 'Property management & zones',
                      help: HelpContent.clientPortal,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ClientPortalScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.history,
                      title: 'Historical Risk Scores',
                      subtitle: 'Dispute resolution',
                      help: HelpContent.historicalRisk,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HistoricalRiskScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.payment,
                      title: 'Payments & Billing',
                      subtitle: 'Invoices & history',
                      help: HelpContent.paymentsBilling,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PaymentsBillingScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.description,
                      title: 'Service Reports',
                      subtitle: 'Past service history',
                      help: HelpContent.serviceReports,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ServiceReportsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.file_present,
                      title: 'Snow Removal Contract',
                      subtitle: 'Contract details',
                      help: HelpContent.snowRemovalContract,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SnowRemovalContractScreen(),
                          ),
                        );
                      },
                    ),
                  ],

                  // Admin-specific Tools
                  if (user.isAdmin) ...[
                    _buildMenuItem(
                      context,
                      icon: Icons.play_circle_outline,
                      title: 'Try Demo',
                      subtitle: 'See WIE in action',
                      help: HelpContent.tryDemo,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DemoScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.account_tree,
                      title: 'Complete Pipeline Demo',
                      subtitle: 'End-to-end system demo',
                      help: HelpContent.completePipeline,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CompletePipelineScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.history,
                      title: 'Historical Risk Scores',
                      subtitle: 'Audit trails',
                      help: HelpContent.historicalRisk,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HistoricalRiskScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.layers,
                      title: 'Zone Manager',
                      subtitle: 'Define risk zones',
                      help: HelpContent.zoneManager,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => const ZoneManagerListScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.map,
                      title: 'Multi-Property Monitor',
                      subtitle: 'Monitor locations',
                      help: HelpContent.multiPropertyMonitor,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MultiPropertyMonitorScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.people,
                      title: 'Contractor Management',
                      subtitle: 'Profiles & compliance',
                      help: HelpContent.contractorManagement,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ContractorManagementScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.send,
                      title: 'Dispatch Intelligence',
                      subtitle: 'AI-powered dispatch',
                      help: HelpContent.dispatchIntelligence,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DispatchIntelligenceScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.queue,
                      title: 'Dispatch Queue',
                      subtitle: 'Assign contractors',
                      help: HelpContent.dispatchQueue,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DispatchQueueScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.calendar_month,
                      title: 'Availability Calendar',
                      subtitle: 'Contractor schedules',
                      help: HelpContent.availabilityCalendar,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AvailabilityCalendarScreen(),
                          ),
                        );
                      },
                    ),
                  ],

                  // Contractor-specific Tools
                  if (user.isContractor) ...[
                    _buildMenuItem(
                      context,
                      icon: Icons.work,
                      title: 'My Shifts',
                      subtitle: 'Shift management & assignments',
                      help: HelpContent.myShifts,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ContractorDispatchesScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.calendar_today,
                      title: 'My Availability',
                      subtitle: 'Manage your schedule',
                      help: HelpContent.myAvailability,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ContractorAvailabilityScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.history,
                      title: 'Shift History',
                      subtitle: 'Past shifts & earnings',
                      help: HelpContent.shiftHistory,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ShiftHistoryScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.local_shipping,
                      title: 'My Equipment',
                      subtitle: 'Manage your fleet',
                      help: HelpContent.myEquipment,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyEquipmentScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.emoji_events,
                      title: 'My Level',
                      subtitle: 'Rankings & advancement',
                      help: HelpContent.myLevel,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyLevelScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.verified_user,
                      title: 'Get Verified',
                      subtitle: 'Upload documents',
                      help: HelpContent.getVerified,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GetVerifiedScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.payment,
                      title: 'Payments',
                      subtitle: 'Earnings & invoices',
                      help: HelpContent.contractorPayments,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ContractorPaymentsScreen(),
                          ),
                        );
                      },
                    ),
                  ],

                  // Public Tools
                  Divider(color: Color(0xFF334155), height: 1),
                  _buildMenuItem(
                    context,
                    icon: Icons.cloud,
                    title: 'Weather Aggregator',
                    subtitle: 'Multi-source data',
                    help: HelpContent.weatherAggregator,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WeatherAggregatorScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.wb_cloudy,
                    title: 'Weather Forecast',
                    subtitle: '48-hour predictions',
                    help: HelpContent.weatherForecast,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WeatherForecastScreen(),
                        ),
                      );
                    },
                  ),

                  // Support (clients & contractors only — matches web)
                  if (!user.isAdmin) ...[
                    Divider(color: Color(0xFF334155), height: 1),
                    _buildMenuItem(
                      context,
                      icon: Icons.support_agent,
                      title: 'Open Support Ticket',
                      subtitle: 'Billing, service issues, app help',
                      help: HelpContent.supportTicket,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SupportTicketScreen(),
                          ),
                        );
                      },
                    ),
                  ],

                  // Legal
                  Divider(color: Color(0xFF334155), height: 1),
                  _buildMenuItem(
                    context,
                    icon: Icons.gavel,
                    title: 'Terms & Privacy',
                    subtitle: 'Terms and Privacy Policy',
                    help: HelpContent.termsPrivacy,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TermsAndPrivacyScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Logout Button
            Divider(color: Color(0xFF334155), height: 1),
            _buildMenuItem(
              context,
              icon: Icons.logout,
              title: 'Logout',
              isDestructive: true,
              help: HelpContent.logout,
              onTap: () {
                authProvider.logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, [String? help]) {
    final header = Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Color(0xFF9CA3AF), // gray-400
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
    if (help == null) return header;
    return TapTooltip(
      title: title,
      message: help,
      child: header,
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    String? help,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: help != null
            ? () => showHelpSheet(context, title: title, message: help)
            : null,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? AppColors.error.withOpacity(0.1)
                      : AppColors.slate800, // slate-800
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? AppColors.error : Color(0xFF60A5FA), // blue-400
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDestructive ? AppColors.error : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Color(0xFF9CA3AF), // gray-400
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (help != null)
                HelpIcon(
                  message: help,
                  title: title,
                  color: Color(0xFF94A3B8),
                  size: 16,
                ),
              if (help != null) SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: Color(0xFF475569), // slate-600
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
