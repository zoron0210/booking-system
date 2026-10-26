part of 'app_root.dart';

class _Hero extends StatelessWidget {
  const _Hero({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('overview-hero-card'),
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.explore_outlined,
                size: 16,
                color: AppColors.accentForeground,
              ),
              const SizedBox(width: 7),
              AppText(
                'A LITTLE INSPIRATION FOR TODAY',
                style: TextStyle(
                  color: AppColors.accentForeground,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
                localize: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppText(
            'Make today\nyours.',
            key: const ValueKey('overview-hero-title'),
            style: TextStyle(
              color: _ink,
              fontSize: 38,
              height: 1.02,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
            ),
            localize: true,
          ),
          const SizedBox(height: 10),
          AppText(
            'Find a court, a fitness session, or a space to celebrate something special.',
            style: TextStyle(color: _muted, fontSize: 15, height: 1.45),
            localize: true,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const ValueKey('overview-hero-explore'),
            onPressed: onExplore,
            icon: const Icon(Icons.arrow_forward_rounded, size: 19),
            label: const AppText('Find your next place', localize: true),
          ),
        ],
      ),
    );
  }
}

class _OverviewCategories extends StatelessWidget {
  const _OverviewCategories({required this.onExploreType});

  final ValueChanged<String> onExploreType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            'What sounds good?',
            style: TextStyle(
              color: _ink,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
            localize: true,
          ),
          const SizedBox(height: 5),
          AppText(
            'Pick a starting point. There’s no wrong answer.',
            style: TextStyle(color: _muted, fontSize: 14, height: 1.4),
            localize: true,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final categories = [
                (
                  'assets/overview/sports.png',
                  Icons.sports_tennis_rounded,
                  'Sports',
                  'GET ACTIVE',
                  'Find a court or field',
                  'Sports',
                ),
                (
                  'assets/overview/events.png',
                  Icons.celebration_rounded,
                  'Events',
                  'CELEBRATE',
                  'Find a place to gather',
                  'Event',
                ),
                (
                  'assets/overview/fitness.png',
                  Icons.fitness_center_rounded,
                  'Fitness & Wellness',
                  'MOVE & RESET',
                  'Explore fitness nearby',
                  'Fitness & Wellness',
                ),
              ];
              return Column(
                children: [
                  for (final category in categories)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _OverviewCategoryTile(
                        key: ValueKey('overview-category-${category.$3}'),
                        category: category,
                        width: constraints.maxWidth,
                        height: 196,
                        onTap: () => onExploreType(category.$6),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OverviewCategoryTile extends StatelessWidget {
  const _OverviewCategoryTile({
    super.key,
    required this.category,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final (String, IconData, String, String, String, String) category;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final compact = width < 200;
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(category.$1, fit: BoxFit.cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: .08),
                      Colors.black.withValues(alpha: .72),
                    ],
                    stops: const [0.15, 1],
                  ),
                ),
              ),
              Positioned(
                top: 13,
                left: 13,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentForeground,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(category.$2, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      AppText(
                        category.$4,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .6,
                        ),
                        localize: true,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 15,
                right: 13,
                bottom: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: AppText(
                        category.$5,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 16 : 20,
                          height: 1.12,
                          fontWeight: FontWeight.w900,
                        ),
                        localize: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: compact ? 17 : 19,
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.blue,
                      child: Icon(
                        Icons.arrow_outward_rounded,
                        size: compact ? 18 : 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SportsSelectionPage extends StatefulWidget {
  const SportsSelectionPage({super.key});

  @override
  State<SportsSelectionPage> createState() => _SportsSelectionPageState();
}

class _SportsSelectionPageState extends State<SportsSelectionPage> {
  String? _selectedBooking;
  bool _showEvents = false;

  static const _sports = [
    (
      'assets/court/basket-court.jpg',
      Icons.sports_basketball_rounded,
      'Basketball',
      'Indoor courts',
    ),
    (
      'assets/court/volley-court.jpg',
      Icons.sports_volleyball_rounded,
      'Volleyball',
      'Team courts',
    ),
    (
      'assets/court/badminton-court.jpg',
      Icons.sports_tennis_rounded,
      'Badminton',
      'Fast-paced play',
    ),
    (
      'assets/court/pickle-court.jpg',
      Icons.sports_tennis_rounded,
      'Pickleball',
      'Social court play',
    ),
  ];

  static const _events = [
    (
      'assets/court/basket-court.jpg',
      Icons.celebration_rounded,
      'Community events',
      'Local activities',
    ),
    (
      'assets/court/volley-court.jpg',
      Icons.groups_rounded,
      'Group experiences',
      'Gather and connect',
    ),
    (
      'assets/court/badminton-court.jpg',
      Icons.event_rounded,
      'Hosted events',
      'Book an event',
    ),
    (
      'assets/court/pickle-court.jpg',
      Icons.local_activity_rounded,
      'Special occasions',
      'Plan your day',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: _navy,
                    ),
                    const Spacer(),
                    AppText(
                      'STEP 1 OF 3',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                      localize: true,
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: _SelectionHero()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: AppText('Sports', localize: true),
                      icon: Icon(Icons.sports_score_rounded),
                    ),
                    ButtonSegment(
                      value: true,
                      label: AppText('Events', localize: true),
                      icon: Icon(Icons.event_rounded),
                    ),
                  ],
                  selected: {_showEvents},
                  onSelectionChanged: (selection) => setState(() {
                    _showEvents = selection.first;
                    _selectedBooking = null;
                  }),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
              sliver: SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: AppText(
                        _showEvents ? 'Choose an event' : 'Choose a sport',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    AppText(
                      '${(_showEvents ? _events : _sports).length} available',
                      style: TextStyle(color: _muted, fontSize: 12),
                      localize: true,
                    ),
                  ],
                ),
              ),
            ),
            SliverLayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.crossAxisExtent < AppResponsive.singleColumn ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.3;
                return SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppResponsive.pageInset(
                      constraints.crossAxisExtent,
                    ),
                  ),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final booking = (_showEvents ? _events : _sports)[index];
                      final selected = _selectedBooking == booking.$3;
                      return _SportCard(
                        imagePath: booking.$1,
                        icon: booking.$2,
                        title: booking.$3,
                        subtitle: booking.$4,
                        selected: selected,
                        onTap: () =>
                            setState(() => _selectedBooking = booking.$3),
                      );
                    }, childCount: (_showEvents ? _events : _sports).length),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: compact ? 1 : 2,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                      childAspectRatio: compact ? 1.15 : .96,
                    ),
                  ),
                );
              },
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                child: FilledButton(
                  onPressed: _selectedBooking == null
                      ? null
                      : () => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: AppText(
                              'Great choice! Let’s find $_selectedBooking listings.',
                              localize: true,
                            ),
                            backgroundColor: _navy,
                          ),
                        ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(55),
                    backgroundColor: _orange,
                    disabledBackgroundColor: const Color(0xFFE0E4EB),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: _muted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: AppText(
                    _selectedBooking == null
                        ? (_showEvents
                              ? 'Select an event to continue'
                              : 'Select a sport to continue')
                        : 'Find $_selectedBooking',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionHero extends StatefulWidget {
  @override
  State<_SelectionHero> createState() => _SelectionHeroState();
}

class _SelectionHeroState extends State<_SelectionHero> {
  static const _heroImages = [
    'assets/court/basket-court.jpg',
    'assets/court/volley-court.jpg',
    'assets/court/badminton-court.jpg',
    'assets/court/pickle-court.jpg',
  ];

  late final PageController _pageController;
  Timer? _carouselTimer;
  int _activePage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      _activePage = (_activePage + 1) % _heroImages.length;
      _pageController.animateToPage(
        _activePage,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final heroHeight = textScale > 1.2
        ? screenWidth < AppResponsive.narrowPhone
              ? 500.0
              : screenWidth < AppResponsive.compactPhone
              ? 440.0
              : 360.0
        : screenWidth < AppResponsive.narrowPhone
        ? 250.0
        : 224.0;
    return Container(
      height: heroHeight,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(28)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _heroImages.length,
            onPageChanged: (page) => setState(() => _activePage = page),
            itemBuilder: (context, index) =>
                Image.asset(_heroImages[index], fit: BoxFit.cover),
          ),
          DecoratedBox(
            decoration: BoxDecoration(gradient: AppGradients.navyHeroOverlay),
          ),
          Padding(
            padding: EdgeInsets.all(
              screenWidth < AppResponsive.narrowPhone ? 16 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const AppText(
                        'FOOTBALL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8,
                        ),
                        localize: true,
                      ),
                    ),
                    const AppText(
                      'COMING SOON',
                      style: TextStyle(
                        color: Color(0xE6FFFFFF),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                      localize: true,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AppText(
                  'Find your next game',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                  localize: true,
                ),
                SizedBox(height: 6),
                AppText(
                  'Choose a sport or event and we’ll take care of the rest.',
                  style: TextStyle(
                    color: Color(0xD9FFFFFF),
                    fontSize: 13,
                    height: 1.45,
                  ),
                  localize: true,
                ),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(
                    _heroImages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.only(right: 5),
                      width: index == _activePage ? 22 : 6,
                      height: 5,
                      decoration: BoxDecoration(
                        color: index == _activePage
                            ? _orange
                            : Colors.white.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SportCard extends StatelessWidget {
  const _SportCard({
    required this.imagePath,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String imagePath;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _orange : const Color(0xFFE6EAF1),
            width: selected ? 2 : 1,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              imagePath,
              fit: BoxFit.cover,
              color: Colors.black.withValues(alpha: .16),
              colorBlendMode: BlendMode.darken,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppGradients.navyImageOverlay,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .9),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(icon, color: _orange, size: 23),
                      ),
                      if (selected)
                        Icon(
                          Icons.check_circle_rounded,
                          color: _orange,
                          size: 23,
                        ),
                    ],
                  ),
                  const Spacer(),
                  AppText(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AppText(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xD9FFFFFF),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('overview-how-it-works'),
      margin: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            'HOW SPOTGO WORKS',
            style: TextStyle(
              color: AppColors.accentForeground,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
            localize: true,
          ),
          const SizedBox(height: 8),
          AppText(
            'Choose an activity, compare places, then follow the booking steps for the one you like.',
            style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
            localize: true,
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              _PlanStep(number: '01', title: 'Choose'),
              _PlanStepConnector(),
              _PlanStep(number: '02', title: 'Compare'),
              _PlanStepConnector(),
              _PlanStep(number: '03', title: 'Book'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanStep extends StatelessWidget {
  const _PlanStep({required this.number, required this.title});

  final String number;
  final String title;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          number,
          style: TextStyle(
            color: AppColors.accentForeground,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        AppText(
          title,
          style: TextStyle(
            color: _ink,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
          localize: true,
        ),
      ],
    ),
  );
}

class _PlanStepConnector extends StatelessWidget {
  const _PlanStepConnector();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 10, bottom: 17),
    child: Icon(Icons.arrow_forward_rounded, size: 15, color: _muted),
  );
}

class _BottomCallout extends StatelessWidget {
  const _BottomCallout({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('overview-bottom-callout'),
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.blue,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppText(
            'Your next plan starts here',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
            localize: true,
          ),
          const SizedBox(height: 7),
          AppText(
            'Browse courts, fitness sessions, and event spaces in one place.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .84),
              fontSize: 13,
              height: 1.4,
            ),
            localize: true,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('overview-bottom-explore'),
            onPressed: onTap,
            icon: const Icon(Icons.grid_view_rounded),
            label: const AppText('See every category', localize: true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.blue,
            ),
          ),
        ],
      ),
    );
  }
}
