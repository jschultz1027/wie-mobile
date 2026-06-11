import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _status;
  bool _loading = true;
  String? _error;
  int _currentSlide = 0;
  Timer? _slideTimer;

  final List<Map<String, String>> _slides = [
    {
      'title': 'Real-Time Winter Monitoring',
      'description': 'Advanced sensors and AI-powered predictions for hyper-local weather conditions',
      'image': 'https://images.unsplash.com/photo-1483664852095-d6cc6870702d?w=1920&q=80',
    },
    {
      'title': 'Intelligent Zone Management',
      'description': 'Draw and manage property zones with automated risk assessment',
      'image': 'https://images.unsplash.com/photo-1611273426858-450d8e3c9fce?w=1920&q=80',
    },
    {
      'title': 'Smart Dispatch System',
      'description': 'Automated contractor assignment based on location and availability',
      'image': 'https://images.unsplash.com/photo-1603575448878-868a20723f5d?w=1920&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _startSlideTimer();
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    super.dispose();
  }

  void _startSlideTimer() {
    _slideTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _currentSlide = (_currentSlide + 1) % _slides.length;
        });
      }
    });
  }

  Future<void> _loadStatus() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      
      final apiService = context.read<ApiService>();
      final data = await apiService.getStatus();
      
      if (mounted) {
        setState(() {
          _status = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: user != null ? AppDrawer() : null,
      body: CustomScrollView(
        slivers: [
          // Full-Width Image Slider (matching web version)
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: AppColors.slate900,
            elevation: 0,
            leading: Builder(
              builder: (context) => IconButton(
                icon: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.menu, color: AppColors.slate900),
                ),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  // Image slides with AnimatedSwitcher
                  ...List.generate(_slides.length, (index) {
                    final slide = _slides[index];
                    return AnimatedOpacity(
                      duration: Duration(milliseconds: 500),
                      opacity: index == _currentSlide ? 1.0 : 0.0,
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Background Image
                            Image.network(
                              slide['image'] ?? '',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback gradient if image fails to load
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [AppColors.blue900, AppColors.blue600],
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Dark overlay gradient
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.7),
                                    Colors.black.withValues(alpha: 0.3),
                                  ],
                                ),
                              ),
                            ),
                            // Content overlay
                            if (index == _currentSlide)
                              SafeArea(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Title
                                      Text(
                                        slide['title'] ?? '',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          height: 1.2,
                                          shadows: [
                                            Shadow(
                                              blurRadius: 15,
                                              color: Colors.black.withValues(alpha: 0.6),
                                            ),
                                          ],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 8),
                                      // Description
                                      Text(
                                        slide['description'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withValues(alpha: 0.95),
                                          height: 1.4,
                                          shadows: [
                                            Shadow(
                                              blurRadius: 10,
                                              color: Colors.black.withValues(alpha: 0.5),
                                            ),
                                          ],
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  // Slide Indicators
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _slides.length,
                        (index) => GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentSlide = index;
                            });
                          },
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 300),
                            margin: EdgeInsets.symmetric(horizontal: 4),
                            width: index == _currentSlide ? 32 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: index == _currentSlide
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Card - Simple and Clean
                if (_status != null)
                  Container(
                    margin: EdgeInsets.all(20),
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.check_circle_outline,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'System Operational',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.slate900,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'All modules ready',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Loading State
                if (_loading)
                  Container(
                    padding: EdgeInsets.all(48),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(AppColors.blue500),
                      ),
                    ),
                  ),

                // Error State
                if (_error != null)
                  Container(
                    margin: EdgeInsets.all(20),
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, color: AppColors.error, size: 48),
                        SizedBox(height: 12),
                        Text(
                          'Connection Error',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.slate900,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Unable to connect to server',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadStatus,
                          icon: Icon(Icons.refresh),
                          label: Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blue500,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Modules Status - Simplified
                if (_status != null && _status!['modules'] != null) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 32, 20, 12),
                    child: Text(
                      'Active Modules',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slate900,
                      ),
                    ),
                  ),
                  
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: (_status!['modules'] as Map<String, dynamic>)
                          .entries
                          .map((entry) => _buildModuleItem(
                                entry.key.replaceAll('_', ' ').toUpperCase(),
                                entry.value == 'ready',
                              ))
                          .toList(),
                    ),
                  ),
                ],

                // System Info - Clean Stats
                if (_status != null) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 32, 20, 12),
                    child: Text(
                      'System Performance',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slate900,
                      ),
                    ),
                  ),
                  
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(child: _buildStatCard('99.2%', 'Accuracy', Icons.verified_outlined)),
                        SizedBox(width: 12),
                        Expanded(child: _buildStatCard('24/7', 'Monitoring', Icons.schedule_outlined)),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(child: _buildStatCard('3-12h', 'Forecast', Icons.wb_sunny_outlined)),
                        SizedBox(width: 12),
                        Expanded(child: _buildStatCard('Real-time', 'Updates', Icons.refresh_outlined)),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleItem(String name, bool isReady) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.slate900.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isReady ? AppColors.success : AppColors.warning,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.slate900,
              ),
            ),
          ),
          Text(
            isReady ? 'Ready' : 'Loading',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.blue500.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.blue500.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: AppColors.blue500),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.slate900,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
