import 'package:flutter/material.dart';
import '../engine/chart_controller.dart';

/// Floating glassmorphic control bar for Bar Replay & Strategy Simulation.
class ReplayControlBar extends StatelessWidget {
  final TradingChartController controller;

  const ReplayControlBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.isReplayMode) return const SizedBox.shrink();

        final isDark = controller.isDarkTheme;
        final totalBars = controller.allCandlesCount;
        final currentBar = (controller.replayIndex ?? 0) + 1;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E222D).withValues(alpha: 0.95)
                : const Color(0xFFFFFFFF).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFFF9800).withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Replay Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.history, size: 12, color: Color(0xFFFF9800)),
                    SizedBox(width: 4),
                    Text(
                      'REPLAY',
                      style: TextStyle(
                        color: Color(0xFFFF9800),
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Bar counter
              Text(
                '$currentBar / $totalBars',
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF131722),
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 16, color: Colors.white24),
              const SizedBox(width: 6),

              // Step Backward
              IconButton(
                key: const Key('replay_step_back'),
                icon: const Icon(Icons.skip_previous, size: 18),
                tooltip: 'Step Backward (1 bar)',
                color: isDark ? Colors.white : Colors.black87,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: controller.stepReplayBackward,
              ),

              // Play / Pause
              IconButton(
                key: const Key('replay_play_pause'),
                icon: Icon(
                  controller.isReplaying ? Icons.pause : Icons.play_arrow,
                  size: 20,
                  color: const Color(0xFF2962FF),
                ),
                tooltip: controller.isReplaying ? 'Pause' : 'Play',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
                onPressed: controller.toggleReplayPlay,
              ),

              // Step Forward
              IconButton(
                key: const Key('replay_step_forward'),
                icon: const Icon(Icons.skip_next, size: 18),
                tooltip: 'Step Forward (1 bar)',
                color: isDark ? Colors.white : Colors.black87,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: controller.stepReplayForward,
              ),

              const SizedBox(width: 6),
              Container(width: 1, height: 16, color: Colors.white24),
              const SizedBox(width: 8),

              // Speed selector
              GestureDetector(
                key: const Key('replay_speed_button'),
                onTap: () {
                  final current = controller.replaySpeed;
                  final nextSpeed = current == 1.0
                      ? 2.0
                      : current == 2.0
                          ? 3.0
                          : current == 3.0
                              ? 5.0
                              : 1.0;
                  controller.setReplaySpeed(nextSpeed);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2E39) : const Color(0xFFECEFF1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${controller.replaySpeed.toStringAsFixed(0)}x',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2962FF),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Exit button
              IconButton(
                key: const Key('replay_exit_button'),
                icon: const Icon(Icons.close, size: 16),
                tooltip: 'Exit Replay',
                color: const Color(0xFFFF5252),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 28),
                onPressed: controller.exitReplay,
              ),
            ],
          ),
        );
      },
    );
  }
}
