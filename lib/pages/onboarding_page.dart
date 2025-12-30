import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'new_session_page.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onFinished;
  const OnboardingPage({super.key, required this.onFinished});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _carouselIndex = 0;
  int _stage = 0;
  String? _selectedIntent;
  int _centerCount = 7;
  bool _centerReady = false;
  Timer? _centerTimer;

  final List<_IntentOption> _intents = const [
    _IntentOption(label: 'Calm Energy', icon: Icons.air_rounded),
    _IntentOption(label: 'Clarity & Focus', icon: Icons.center_focus_strong),
    _IntentOption(label: 'Confidence', icon: Icons.auto_awesome_outlined),
    _IntentOption(label: 'Forgiveness', icon: Icons.favorite_border_rounded),
    _IntentOption(label: 'Love', icon: Icons.favorite_rounded),
    _IntentOption(label: 'Motivation', icon: Icons.wb_sunny_outlined),
    _IntentOption(label: 'Resilience', icon: Icons.change_history_rounded),
    _IntentOption(label: 'Surprise Me', icon: Icons.auto_fix_high_rounded),
  ];

  int get _carouselCount => 4;

  @override
  void dispose() {
    _controller.dispose();
    _centerTimer?.cancel();
    super.dispose();
  }

  Future<void> _next() async {
    if (_stage == 0) {
      if (_carouselIndex < _carouselCount - 1) {
        await _controller.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      } else {
        setState(() => _stage = 1);
      }
      return;
    }

    if (_stage == 1) {
      if (_selectedIntent == null) return;
      setState(() {
        _stage = 2;
        _centerCount = 7;
        _centerReady = false;
      });
      _startCenterCountdown();
      return;
    }

    if (_stage == 2) {
      if (!_centerReady) return;
      widget.onFinished();
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NewSessionPage()),
      );
    }
  }

  void _startCenterCountdown() {
    _centerTimer?.cancel();
    _centerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _centerCount -= 1;
        if (_centerCount <= 0) {
          _centerCount = 0;
          _centerReady = true;
          timer.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final background = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFF1F6FB),
          const Color(0xFFE9EEF4),
        ],
      ),
    );

    return Scaffold(
      body: Container(
        decoration: background,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _stage == 0
                    ? PageView(
                        controller: _controller,
                        onPageChanged: (value) =>
                            setState(() => _carouselIndex = value),
                        children: [
                          _simpleSlide(
                            title: 'Friendly Reminder',
                            body:
                                'You are the miracle,\nand every day is your chance to remember.',
                          ),
                          _howItWorksSlide(),
                          _simpleSlide(
                            title: 'Welcome to Mirroracle',
                            body:
                                'Discover the power of mirror affirmations — the practice of speaking positive, intentional statements to yourself, while looking at yourself.',
                          ),
                          _simpleSlide(
                            title: 'Why You Benefit',
                            body:
                                'Mirror affirmations build confidence, quiet self-criticism, and help you feel grounded.\n\nBy pairing eye contact with intention, you shift the way you see yourself from within.',
                          ),
                        ],
                      )
                    : _stage == 1
                        ? _intentSlide()
                        : _centerSlide(),
              ),
              const SizedBox(height: 8),
              if (_stage == 0) _buildDots(),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: _stage == 2 && !_centerReady
                      ? const SizedBox.shrink()
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.black26,
                            disabledForegroundColor: Colors.white70,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: _stage == 1 && _selectedIntent == null
                              ? null
                              : _next,
                          child: Text(
                            _stage == 2 ? 'Begin the Journey' : 'Continue',
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_carouselCount, (i) {
        final isActive = i == _carouselIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          height: 8,
          width: isActive ? 16 : 8,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(isActive ? 0.9 : 0.35),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  Widget _simpleSlide({required String title, required String body}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSerifDisplay(
              fontSize: 30,
              height: 1.1,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            body,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 18,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _howItWorksSlide() {
    final steps = [
      'Choose what you want to strengthen.',
      'Take a deep breath.',
      'Repeat each affirmation three times.',
      'Feel your energy shift.',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'How It Works',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSerifDisplay(
              fontSize: 30,
              height: 1.1,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          ...steps.map(
            (s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                s,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  height: 1.4,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _intentSlide() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'What are you\ncalling in today?',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSerifDisplay(
              fontSize: 28,
              height: 1.1,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          ..._intents.map(
            (intent) {
              final isSelected = _selectedIntent == intent.label;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFF0D000)
                            : Colors.white24,
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 10,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () =>
                            setState(() => _selectedIntent = intent.label),
                        child: SizedBox(
                          height: 58,
                          child: Row(
                            children: [
                              const SizedBox(width: 18),
                              Icon(intent.icon,
                                  color: Colors.white, size: 22),
                              const SizedBox(width: 16),
                              Text(
                                intent.label,
                                style: GoogleFonts.manrope(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _centerSlide() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: SizedBox.expand(
        child: Column(
          children: [
            const Spacer(),
            Text(
              'Find Your Center',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 30,
                height: 1.1,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFF64D2D2), Color(0xFFB2794C)],
                  radius: 0.9,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66F2E58F),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: Color(0x332F7F8F),
                    blurRadius: 30,
                    spreadRadius: 8,
                  ),
                ],
                border: Border.all(color: Color(0xFFF2E58F), width: 3),
              ),
              alignment: Alignment.center,
              child: Text(
                '$_centerCount',
                style: GoogleFonts.manrope(
                  fontSize: 48,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_centerCount > 0) ...[
              Text(
                'Relax your shoulders.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Inhale slowly. Exhale gently.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Let yourself settle into this moment.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
            ] else
              Text(
                'Ready when you are.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const Spacer(),
            if (_centerCount > 0)
              TextButton(
                onPressed: () {
                  setState(() {
                    _centerCount = 0;
                    _centerReady = true;
                  });
                },
                child: Text(
                  'Skip Timer',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    decoration: TextDecoration.underline,
                    color: Colors.black54,
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _IntentOption {
  final String label;
  final IconData icon;
  const _IntentOption({required this.label, required this.icon});
}
