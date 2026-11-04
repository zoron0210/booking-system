import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/core/app_session.dart';

import '../../../core/app_text.dart';

class FirstLaunchOnboardingGate extends StatefulWidget {
  const FirstLaunchOnboardingGate({
    super.key,
    required this.child,
    required this.session,
  });

  static const completionKey = 'spotgo_first_launch_onboarding_complete';

  final Widget child;
  final AppSession? session;

  @override
  State<FirstLaunchOnboardingGate> createState() =>
      _FirstLaunchOnboardingGateState();
}

class _FirstLaunchOnboardingGateState extends State<FirstLaunchOnboardingGate> {
  late Future<bool> _completion;

  @override
  void initState() {
    super.initState();
    _completion = _loadCompletion();
  }

  Future<bool> _loadCompletion() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(FirstLaunchOnboardingGate.completionKey) == true) {
      return true;
    }

    final session = widget.session;
    final hasUsedApp =
        session?.isAuthenticated == true || session?.lastBookingType != null;
    if (!hasUsedApp) return false;

    final saved = await preferences.setBool(
      FirstLaunchOnboardingGate.completionKey,
      true,
    );
    if (!saved) {
      throw StateError('The onboarding preference could not be saved.');
    }
    return true;
  }

  Future<void> _completeOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setBool(
      FirstLaunchOnboardingGate.completionKey,
      true,
    );
    if (!saved) {
      throw StateError('The onboarding preference could not be saved.');
    }
    if (mounted) {
      setState(() {
        _completion = Future<bool>.value(true);
      });
    }
  }

  void _retry() {
    setState(() => _completion = _loadCompletion());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _completion,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _OnboardingGateError(error: snapshot.error!, onRetry: _retry);
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const _OnboardingGateLoading();
      }
      if (snapshot.data == true) return widget.child;
      return FirstLaunchOnboardingPage(onComplete: _completeOnboarding);
    },
  );
}

class _OnboardingGateLoading extends StatelessWidget {
  const _OnboardingGateLoading();

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Color(0xFFF5F3FF),
    body: Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
  );
}

class _OnboardingGateError extends StatelessWidget {
  const _OnboardingGateError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F3FF),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFF7C3AED),
              size: 40,
            ),
            const SizedBox(height: 12),
            const AppText(
              'SpotGo could not load onboarding',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              localize: true,
            ),
            const SizedBox(height: 8),
            AppText('$error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    ),
  );
}

class FirstLaunchOnboardingPage extends StatefulWidget {
  const FirstLaunchOnboardingPage({super.key, required this.onComplete});

  final Future<void> Function() onComplete;

  @override
  State<FirstLaunchOnboardingPage> createState() =>
      _FirstLaunchOnboardingPageState();
}

class _FirstLaunchOnboardingPageState extends State<FirstLaunchOnboardingPage> {
  static const _slides = [
    _OnboardingSlide(
      category: 'Sports & Courts',
      title: 'Find Your Perfect Court, Anytime, Anywhere',
      description: 'Discover badminton, padel, and basketball courts nearby with seamless instant booking.',
      image: 'https://images.unsplash.com/photo-1546519638-68e109498ffc?auto=format&fit=crop&w=1200&q=85',
      fallbackAsset: 'assets/overview/sports.png',
      icon: Icons.sports_tennis_rounded,
      action: 'Get Started',
    ),
    _OnboardingSlide(
      category: 'Event Spaces',
      title: 'Book Your Dream Space in Just a Tap',
      description: 'Use powerful filters, interactive maps, and curated venue suggestions for your special day.',
      image: 'https://images.unsplash.com/photo-1519671482749-fd09be7ccebf?auto=format&fit=crop&w=1200&q=85',
      fallbackAsset: 'assets/overview/events.png',
      icon: Icons.celebration_rounded,
      action: 'Continue',
    ),
    _OnboardingSlide(
      category: 'Fitness & Wellness',
      title: 'Move, Reset & Elevate Your Fitness',
      description: 'Access Pilates studios, gym day passes, and instructor-led group sessions effortlessly.',
      image: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&w=1200&q=85',
      fallbackAsset: 'assets/overview/fitness.png',
      icon: Icons.bolt_rounded,
      action: 'Explore Sessions',
    ),
    _OnboardingSlide(
      category: 'SpotGo Guarantee',
      title: 'Relax and Enjoy Your Reservation',
      description: 'Plan your sports, events, and fitness sessions stress-free with trusted hosts and clear policies.',
      image: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=85',
      fallbackAsset: 'assets/overview/events.png',
      icon: Icons.verified_user_rounded,
      action: 'Register Account',
    ),
  ];

  final _pageController = PageController();
  int _currentPage = 0;
  bool _finishing = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      await widget.onComplete();
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _finishing = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Could not save onboarding: $error')),
        );
    }
  }

  Future<void> _advance() async {
    if (_finishing) return;
    if (_currentPage == _slides.length - 1) {
      await _finish();
      return;
    }
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF5F3FF), Color(0xFFD8CEF8)],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth > 500
                ? 460.0
                : constraints.maxWidth;
            return Center(
              child: SizedBox(
                width: cardWidth,
                height: constraints.maxHeight,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth > 500 ? 12 : 10,
                    vertical: 8,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(34),
                    child: Material(
                      color: Colors.white,
                      child: PageView.builder(
                        key: const ValueKey('first-launch-onboarding-pages'),
                        controller: _pageController,
                        itemCount: _slides.length,
                        onPageChanged: (index) {
                          setState(() => _currentPage = index);
                        },
                        itemBuilder: (context, index) =>
                            _buildSlide(_slides[index], index),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  Widget _buildSlide(_OnboardingSlide slide, int index) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxHeight < 600;
      final imageFlex = compact ? 55 : 60;
      return Column(
        children: [
          Expanded(
            flex: imageFlex,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _OnboardingImage(slide: slide),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x33000000),
                        Colors.transparent,
                        Color(0xFFFDFBFF),
                      ],
                      stops: [0, .56, 1],
                    ),
                  ),
                ),
                Positioned(
                  top: 18,
                  left: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .88),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white70),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(slide.icon, size: 15, color: _purple),
                        const SizedBox(width: 6),
                        AppText(
                          slide.category,
                          style: const TextStyle(
                            color: Color(0xFF6D28D9),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: TextButton(
                    key: ValueKey('onboarding-skip-$index'),
                    onPressed: _finishing ? null : _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.black.withValues(alpha: .34),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      minimumSize: const Size(48, 40),
                      shape: const StadiumBorder(),
                    ),
                    child: const AppText(
                      'Skip',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      localize: true,
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  bottom: 12,
                  child: AppText(
                    '0${index + 1}  /  0${_slides.length}',
                    style: const TextStyle(
                      color: Color(0xFF6D28D9),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 100 - imageFlex,
            child: Padding(
              padding: EdgeInsets.fromLTRB(26, compact ? 0 : 4, 26, 22),
              child: Column(
                children: [
                  const Spacer(),
                  AppText(
                    slide.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF171421),
                      fontSize: compact ? 21 : 25,
                      height: 1.12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.55,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AppText(
                    slide.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF777382),
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (dotIndex) => AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: index == dotIndex ? 24 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: index == dotIndex
                              ? _purple
                              : const Color(0xFFE7E3EF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      key: const ValueKey('onboarding-continue'),
                      onPressed: _finishing ? null : _advance,
                      style: FilledButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: _purple.withValues(alpha: .35),
                        shape: const StadiumBorder(),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_finishing)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          else ...[
                            AppText(
                              slide.action,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .2,
                              ),
                            ),
                            const SizedBox(width: 9),
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _OnboardingImage extends StatelessWidget {
  const _OnboardingImage({required this.slide});

  final _OnboardingSlide slide;

  @override
  Widget build(BuildContext context) => Image.network(
    slide.image,
    fit: BoxFit.cover,
    alignment: Alignment.center,
    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
      if (wasSynchronouslyLoaded || frame != null) return child;
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(slide.fallbackAsset, fit: BoxFit.cover),
          const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    },
    errorBuilder: (context, error, stackTrace) =>
        Image.asset(slide.fallbackAsset, fit: BoxFit.cover),
  );
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.category,
    required this.title,
    required this.description,
    required this.image,
    required this.fallbackAsset,
    required this.icon,
    required this.action,
  });

  final String category;
  final String title;
  final String description;
  final String image;
  final String fallbackAsset;
  final IconData icon;
  final String action;
}

const _purple = Color(0xFF7C3AED);
