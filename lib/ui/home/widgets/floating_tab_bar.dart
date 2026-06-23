import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FloatingTabBar extends StatelessWidget {
  final VoidCallback onResourceMappingTap;
  final VoidCallback onPlanningTap;
  final bool hasPlan;

  const FloatingTabBar({
    super.key,
    required this.onResourceMappingTap,
    required this.onPlanningTap,
    this.hasPlan = false,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 24,
      right: 24,
      bottom: bottomPadding + 24,
      child: Row(
        children: [
          Expanded(
            child: _FloatingPill(
              label: 'Resource Mapping',
              icon: Icons.place_outlined,
              enabled: hasPlan,
              onTap: () {
                HapticFeedback.lightImpact();
                onResourceMappingTap();
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _FloatingPill(
              label: 'Planning',
              icon: Icons.bar_chart_outlined,
              onTap: () {
                HapticFeedback.lightImpact();
                onPlanningTap();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _FloatingPill({
    required this.label,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: enabled
                    ? [
                        Colors.black.withValues(alpha: 0.92),
                        Colors.black.withValues(alpha: 0.65),
                      ]
                    : [
                        Colors.black.withValues(alpha: 0.40),
                        Colors.black.withValues(alpha: 0.28),
                      ],
              ),
              borderRadius: BorderRadius.circular(50),
              border: enabled
                  ? null
                  : Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 0.5,
                    ),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: enabled ? Colors.white : Colors.white38, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: enabled ? Colors.white : Colors.white38,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
