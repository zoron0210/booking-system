part of 'app_root.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  Future<void> _openBookings(BuildContext context) async {
    final session = await AppSessionService.instance.load();
    if (!context.mounted) return;
    if (session.role == 'merchant' &&
        session.isAuthenticated &&
        session.apiToken?.isNotEmpty == true) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              MerchantDashboardPage(onLogout: logoutToBookingPicker),
        ),
      );
      return;
    }
    final lastBookingPage = bookingTypeDashboard(
      session.lastBookingType,
      onLogout: logoutToBookingPicker,
    );
    if (lastBookingPage != null) {
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => lastBookingPage));
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReserveDashboardPage(
          initialSelection: session.lastBookingType,
          onLogout: logoutToBookingPicker,
        ),
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: AppText(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _navy,
        ),
      );
  }

  Future<void> _refreshOverview() {
    setState(() {});
    return Future<void>.value();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator.adaptive(
          onRefresh: _refreshOverview,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AppResponsive.contentMaxWidthFor(
                  MediaQuery.sizeOf(context).width,
                ),
              ),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _Header(
                      onLogin: () async {
                        await openCustomerLogin(context);
                      },
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _Hero(onExplore: () => _openBookings(context)),
                  ),
                  SliverToBoxAdapter(
                    child: _OverviewCategories(
                      onExplore: () => _openBookings(context),
                    ),
                  ),
                  SliverToBoxAdapter(child: _HowItWorks()),
                  SliverToBoxAdapter(child: _Features()),
                  SliverToBoxAdapter(child: _OverviewTrustSection()),
                  SliverToBoxAdapter(
                    child: _BottomCallout(
                      onTap: () =>
                          _showMessage(context, 'Welcome to TinkerPro Sports!'),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 6)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Expanded(
            key: const ValueKey('overview-brand'),
            child: Row(
              children: [
                Image.asset(
                  'assets/tinker_logo.png',
                  width: 52,
                  height: 44,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: AppText.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Tinker',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.5,
                          ),
                        ),
                        TextSpan(
                          text: 'Pro',
                          style: TextStyle(
                            color: _orange,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.5,
                          ),
                        ),
                      ],
                    ),
                    localize: true,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            key: const ValueKey('overview-login'),
            onPressed: onLogin,
            icon: const Icon(Icons.login_rounded, size: 16),
            label: const AppText('Log in', localize: true),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
