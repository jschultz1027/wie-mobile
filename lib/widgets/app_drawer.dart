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
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),

                  // Divider
                  Divider(color: Color(0xFF334155), height: 1),
                  
                  // Try Demo
                  _buildMenuItem(
                    context,
                    icon: Icons.play_circle_outline,
                    title: 'Try Demo',
                    subtitle: 'See WIE in action',
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

                  // Divider
                  Divider(color: Color(0xFF334155), height: 1),

                  // Tools Section Header
                  _buildSectionHeader('Tools'),

                  // Winter Hazard Monitor (All users)
                  _buildMenuItem(
                    context,
                    icon: Icons.warning_amber,
                    title: 'Winter Hazard Monitor',
                    subtitle: user.isClient
                        ? 'Your properties risk'
                        : 'Real-time risk assessment',
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
                      icon: Icons.account_tree,
                      title: 'Complete Pipeline Demo',
                      subtitle: 'End-to-end system demo',
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

                  // Legal
                  Divider(color: Color(0xFF334155), height: 1),
                  _buildMenuItem(
                    context,
                    icon: Icons.gavel,
                    title: 'Terms & Privacy',
                    subtitle: 'Terms and Privacy Policy',
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

  Widget _buildSectionHeader(String title) {
    return Padding(
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
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
