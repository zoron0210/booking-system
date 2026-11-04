part of 'app_root.dart';

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
