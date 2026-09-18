import 'package:flutter/material.dart';

import '../services/onboarding_service.dart';
import 'steps/customize_step.dart';
import 'steps/tutorial_step.dart';
import 'steps/welcome_step.dart';

/// First-run flow: Welcome -> Customize (mockup + pickers + set-as-launcher)
/// -> Tutorial. Forward-only stepping, no swipe navigation (this isn't the
/// 5-panel shell).
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _service = const OnboardingService();
  int _step = 0;

  void _next() => setState(() => _step += 1);

  Future<void> _finish() async {
    await _service.markComplete();
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: switch (_step) {
        0 => WelcomeStep(onNext: _next),
        1 => CustomizeStep(onNext: _next),
        _ => TutorialStep(onFinish: _finish),
      },
    );
  }
}
