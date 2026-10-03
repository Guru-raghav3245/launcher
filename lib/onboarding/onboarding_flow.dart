import 'package:flutter/material.dart';

import '../services/onboarding_service.dart';
import 'steps/customize_step.dart';
import 'steps/welcome_step.dart';

/// First-run flow: Welcome -> Customize (mockup + pickers + set-as-launcher).
/// Forward-only stepping, no swipe navigation (this isn't the 5-panel
/// shell). The tutorial that used to follow is now Home's "Take a look
/// around" tours (Phase 10 task 8).
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
        _ => CustomizeStep(onNext: _finish),
      },
    );
  }
}
