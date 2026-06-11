import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/property.dart';

/// Color for risk score 0–100 (green < 30, yellow < 60, orange < 80, red >= 80).
Color riskScoreColor(int score) {
  if (score < 30) return AppColors.success;
  if (score < 60) return Colors.amber.shade700;
  if (score < 80) return Colors.orange.shade700;
  return Colors.red.shade700;
}

/// Color for salt effectiveness 0–100 (higher = better: green >= 60, amber 30–59, red < 30).
Color saltEffectivenessColor(int percent) {
  if (percent >= 60) return AppColors.success;
  if (percent >= 30) return Colors.amber.shade700;
  return Colors.red.shade700;
}

/// Compact one-line risk summary: Risk · 24h · 48h · 7d. For list items.
class PropertyRiskChips extends StatelessWidget {
  final Property property;

  const PropertyRiskChips({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    if (!property.hasRiskData) return const SizedBox.shrink();
    final parts = <Widget>[];
    void add(String label, int? value) {
      if (value == null) return;
      parts.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: riskScoreColor(value).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: riskScoreColor(value).withOpacity(0.5), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
              const SizedBox(width: 4),
              Text('$value', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: riskScoreColor(value))),
            ],
          ),
        ),
      );
    }

    add('Risk', property.riskScore);
    add('24h', property.highest24h);
    add('48h', property.highest48h);
    add('7d', property.highest7days);
    add('Zone', property.highestZoneRisk);
    if (property.saltEffectiveness != null) {
      parts.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: saltEffectivenessColor(property.saltEffectiveness!).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: saltEffectivenessColor(property.saltEffectiveness!).withOpacity(0.5), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Salt', style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
              const SizedBox(width: 4),
              Text('${property.saltEffectiveness}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: saltEffectivenessColor(property.saltEffectiveness!))),
            ],
          ),
        ),
      );
    }
    if (parts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: parts,
      ),
    );
  }
}

/// Small 2×2 grid for property detail: Peak 24h, 48h, 7-day, current risk.
class PropertyRiskAtAGlance extends StatelessWidget {
  final Property property;

  const PropertyRiskAtAGlance({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    if (!property.hasRiskData) return const SizedBox.shrink();
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, size: 18, color: AppColors.blue600),
                const SizedBox(width: 6),
                const Text('Risk at a glance', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _cell('Risk now', property.riskScore)),
                const SizedBox(width: 8),
                Expanded(child: _cell('Peak 24h', property.highest24h)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _cell('Peak 48h', property.highest48h)),
                const SizedBox(width: 8),
                Expanded(child: _cell('7-day high', property.highest7days)),
              ],
            ),
            if (property.highestZoneRisk != null || property.saltEffectiveness != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (property.highestZoneRisk != null) Expanded(child: _cell('Zone risk', property.highestZoneRisk)),
                  if (property.highestZoneRisk != null && property.saltEffectiveness != null) const SizedBox(width: 8),
                  if (property.saltEffectiveness != null)
                    Expanded(
                      child: _saltCell('Salt %', property.saltEffectiveness),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cell(String label, int? value) {
    final v = value ?? 0;
    final color = value != null ? riskScoreColor(v) : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          const SizedBox(height: 2),
          Text(
            value != null ? '$value' : '—',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _saltCell(String label, int? value) {
    final v = value ?? 0;
    final color = value != null ? saltEffectivenessColor(v) : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          const SizedBox(height: 2),
          Text(
            value != null ? '$value%' : '—',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
