import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/my_level.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import '../../services/my_level_service.dart';
import '../auth/login_screen.dart';

/// Contractor My Level. Matches web: 5 tiers (Starter → Elite), GET /api/v1/contractors/level.
class MyLevelScreen extends StatefulWidget {
  const MyLevelScreen({super.key});

  @override
  State<MyLevelScreen> createState() => _MyLevelScreenState();
}

class _MyLevelScreenState extends State<MyLevelScreen> {
  final MyLevelService _service = MyLevelService();
  ContractorLevelResponse? _data;
  bool _loading = true;
  String? _error;

  static const List<LevelDefinition> _tiers = [
    LevelDefinition(
      id: 1,
      name: 'Starter',
      tier: 1,
      serviceRangeLabel: '0–99 completed services',
      payoutMultiplier: '1.00',
      access: ['Small / low-risk properties', 'Lower queue priority'],
      requirements: ['≥ 85% On-Time Rate', '≥ 90% Report Compliance', 'No major incidents', 'Low decline rate'],
    ),
    LevelDefinition(
      id: 2,
      name: 'Standard',
      tier: 2,
      serviceRangeLabel: '100–299 completed services',
      payoutMultiplier: '1.03',
      access: ['Medium properties', 'Standard dispatch queue access'],
      requirements: ['≥ 90% On-Time', '≥ 95% Completion Rate', 'Quality Score ≥ 4.2', 'Controlled decline behavior'],
    ),
    LevelDefinition(
      id: 3,
      name: 'Reliable',
      tier: 3,
      serviceRangeLabel: '300–699 completed services',
      payoutMultiplier: '1.06',
      access: ['Larger properties', 'Early queue visibility', 'Route bundles'],
      requirements: ['≥ 93% On-Time', '≥ 97% Completion', 'Low rework rate', 'Strong Site Stability Score'],
    ),
    LevelDefinition(
      id: 4,
      name: 'Pro',
      tier: 4,
      serviceRangeLabel: '700–1499 completed services',
      payoutMultiplier: '1.10',
      access: ['High-value properties', 'Priority queue positioning', 'Urgent dispatch access'],
      requirements: ['≥ 95% On-Time', '≥ 98% Compliance', 'High storm availability', 'Minimal decline frequency'],
    ),
    LevelDefinition(
      id: 5,
      name: 'Elite',
      tier: 5,
      serviceRangeLabel: 'Top 5–10% network',
      payoutMultiplier: '1.15–1.20',
      access: ['Premium contracts', 'Emergency override dispatch', 'Early seasonal assignment'],
      requirements: ['≥ 97% On-Time', 'Near-zero incident rate', 'High storm responsiveness', 'Strongest Site Stability Score'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = StorageService().getToken();
    if (token == null || token.isEmpty) {
      if (mounted) _handleSessionExpired();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getMyLevel();
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } on MyLevelException catch (e) {
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

  int _progressToNext(ContractorLevelResponse d, LevelDefinition? next) {
    if (next == null) return 100;
    if (next.serviceRangeLabel.startsWith('Top')) return 0;
    final curMinNum = next.tier > 1
        ? (int.tryParse(_tiers[next.tier - 2].serviceRangeLabel.split('–').first.trim()) ?? 0)
        : 0;
    final nxtMinNum = int.tryParse(next.serviceRangeLabel.split('–').first.trim()) ?? 0;
    if (nxtMinNum <= curMinNum) return 100;
    final total = nxtMinNum - curMinNum;
    final progress = (d.completedServices - curMinNum).clamp(0, total);
    return ((progress / total) * 100).round().clamp(0, 100);
  }

  bool _isRequirementMet(String req, ContractorLevelResponse d) {
    if (req.contains('85%')) return d.onTimeRate >= 85;
    if (req.contains('90% On-Time') || req.contains('90%')) return d.onTimeRate >= 90;
    if (req.contains('93%')) return d.onTimeRate >= 93;
    if (req.contains('95% On-Time') || req.contains('95%')) return d.onTimeRate >= 95 && d.completionRate >= 95;
    if (req.contains('97%')) return d.onTimeRate >= 97;
    if (req.contains('98%')) return d.completionRate >= 98;
    if (req.contains('Report Compliance')) return d.reportCompliance >= 90;
    if (req.contains('Quality Score ≥ 4.2')) return d.qualityScore >= 4.2;
    if (req.contains('No major incidents')) return d.incidentCount == 0;
    if (req.contains('Near-zero incident')) return d.incidentCount <= 1;
    if (req.contains('decline')) return d.declineRate <= 8;
    if (req.contains('rework')) return d.reworkRate <= 3;
    if (req.contains('Site Stability')) return d.siteStabilityScore >= 70;
    if (req.contains('Strongest Site Stability')) return d.siteStabilityScore >= 85;
    return false;
  }

  Color _tierColor(int tier) {
    switch (tier) {
      case 1:
        return const Color(0xFF475569); // slate
      case 2:
        return AppColors.blue600;
      case 3:
        return const Color(0xFF059669); // emerald
      case 4:
        return const Color(0xFF7C3AED); // violet
      case 5:
        return const Color(0xFFD97706); // amber
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final currentTierNum = data?.tier ?? 1;
    final currentTier = currentTierNum >= 1 && currentTierNum <= _tiers.length
        ? _tiers[currentTierNum - 1]
        : _tiers.first;
    final nextTier = currentTierNum < _tiers.length ? _tiers[currentTierNum] : null;
    final progress = data != null && nextTier != null ? _progressToNext(data, nextTier) : 0;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Level',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading && data == null
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
                    Text('Loading your level...'),
                  ],
                ),
              )
            : _error != null && data == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            style: TextStyle(color: Colors.grey.shade700),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(onPressed: _load, child: const Text('Retry')),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Level',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tiers drive dispatch priority, site access, and payout.',
                          style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                        ),
                        if (_error != null && data != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Text(_error!, style: TextStyle(fontSize: 13, color: Colors.amber.shade900)),
                          ),
                        ],
                        const SizedBox(height: 24),
                        // Current tier card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _tierColor(currentTier.tier),
                                _tierColor(currentTier.tier).withOpacity(0.85),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: _tierColor(currentTier.tier).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.emoji_events, color: Colors.white, size: 40),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Current Tier', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9))),
                                          Text(
                                            currentTier.name,
                                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Icon(Icons.star, color: Colors.white.withOpacity(0.3), size: 56),
                                ],
                              ),
                              if (data != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  currentTier.serviceRangeLabel,
                                  style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9)),
                                ),
                              ],
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Payout', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9))),
                                      Text(
                                        'Base × ${currentTier.payoutMultiplier}',
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                  if (data != null) ...[
                                    const SizedBox(width: 24),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Completed', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9))),
                                        Text(
                                          '${data.completedServices} services',
                                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Stats
                        if (data != null) ...[
                          Text(
                            'Your performance',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _StatChip(label: 'On-Time', value: '${data.onTimeRate.toInt()}%', icon: Icons.schedule),
                                const SizedBox(width: 10),
                                _StatChip(label: 'Completion', value: '${data.completionRate.toInt()}%', icon: Icons.check_circle),
                                const SizedBox(width: 10),
                                _StatChip(label: 'Report', value: '${data.reportCompliance.toInt()}%', icon: Icons.description),
                                const SizedBox(width: 10),
                                _StatChip(label: 'Quality', value: data.qualityScore.toStringAsFixed(1), icon: Icons.star),
                                const SizedBox(width: 10),
                                _StatChip(label: 'Decline', value: '${data.declineRate.toInt()}%', icon: Icons.trending_down),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                        // Progress to next tier
                        if (nextTier != null && data != null) ...[
                          Text(
                            'Progress to ${nextTier.name}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 10),
                          Card(
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.trending_up, color: AppColors.blue600, size: 22),
                                          const SizedBox(width: 8),
                                          Text('$progress%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.blue600)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: progress / 100,
                                      minHeight: 10,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.blue600),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Requirements', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                                            const SizedBox(height: 8),
                                            ...nextTier.requirements.map((req) {
                                              final met = _isRequirementMet(req, data);
                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 6),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(
                                                      met ? Icons.check_circle : Icons.radio_button_unchecked,
                                                      size: 20,
                                                      color: met ? AppColors.success : Colors.grey.shade400,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        req,
                                                        style: TextStyle(fontSize: 13, color: met ? AppColors.success : Colors.grey.shade700),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Access at ${nextTier.name}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                                            const SizedBox(height: 8),
                                            ...nextTier.access.map((a) => Padding(
                                                  padding: const EdgeInsets.only(bottom: 6),
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Icon(Icons.star, size: 18, color: AppColors.warning),
                                                      const SizedBox(width: 8),
                                                      Expanded(child: Text(a, style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
                                                    ],
                                                  ),
                                                )),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                        // All tiers
                        Text(
                          'All tiers',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 10),
                        ..._tiers.map((t) {
                          final isCurrent = t.tier == currentTierNum;
                          final isLocked = t.tier > currentTierNum;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Card(
                              elevation: 0,
                              color: isCurrent
                                  ? AppColors.blue600.withOpacity(0.08)
                                  : isLocked
                                      ? Colors.grey.shade100
                                      : AppColors.success.withOpacity(0.08),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isCurrent
                                      ? AppColors.blue600
                                      : isLocked
                                          ? Colors.grey.shade300
                                          : AppColors.success,
                                  width: isCurrent ? 2 : 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Tier ${t.tier} – ${t.name}',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: isCurrent ? AppColors.blue600 : (isLocked ? Colors.grey.shade600 : AppColors.success),
                                          ),
                                        ),
                                        if (isCurrent)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(color: AppColors.blue600, borderRadius: BorderRadius.circular(6)),
                                            child: const Text('CURRENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                                          )
                                        else if (isLocked)
                                          Icon(Icons.lock, size: 22, color: Colors.grey.shade400)
                                        else
                                          Icon(Icons.check_circle, size: 22, color: AppColors.success),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${t.serviceRangeLabel} · Base × ${t.payoutMultiplier}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Access: ${t.access.join('; ')}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                        // Assignment & principles
                        Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.map, size: 20, color: AppColors.blue600),
                                    const SizedBox(width: 8),
                                    Text('Assignment model', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Fixed site assignment (30–90 days or full season) and dispatch queue (tier 5 sees first, then 4, 3, 2, 1).',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Icon(Icons.info_outline, size: 20, color: Colors.amber.shade700),
                                    const SizedBox(width: 8),
                                    Text('Decline policy', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Limited declines per shift; each affects Reliability Score and tier. Excessive declines can trigger dispatch restriction or tier downgrade.',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Icon(Icons.shield, size: 20, color: Colors.grey.shade600),
                                    const SizedBox(width: 8),
                                    Text('System principles', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Stability, long-term site ownership, tier-based merit, and reliability over price competition.',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatChip({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.blue600),
                const SizedBox(width: 6),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
