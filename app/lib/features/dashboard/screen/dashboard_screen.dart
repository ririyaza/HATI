import 'package:flutter/material.dart';

import '../widgets/dashboard_tour_overlay.dart';
import '../widgets/draggable_help_button.dart';
import 'home_screen.dart';
import 'modules_screen.dart';
import 'profile_screen.dart';
import 'progress_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

// Profile is the tab where the floating help button is normally hidden —
// that screen already offers a "Help & Support" settings tile — except
// while the dashboard tour is running, since its final step spotlights
// this same button while parked on the Profile tab.
const _profileTabIndex = 3;

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _tourActive = false;
  final _tourKeys = DashboardTourKeys();

  // Hati stays quiet on the Home tab until we know whether this is a
  // first-time user still mid-tutorial (dashboard coach-mark tour): if so,
  // it waits for that tour to finish before greeting them; otherwise
  // (returning user, tour already completed before this session) it's
  // cleared to start right away.
  bool _hatiReady = false;
  bool _hatiShowWelcome = false;

  List<Widget> get _screens => [
    HomeScreen(
      chatKey: _tourKeys.homeChatKey,
      hatiReady: _hatiReady,
      hatiShowWelcome: _hatiShowWelcome,
    ),
    ModulesScreen(gridKey: _tourKeys.modulesGridKey),
    ProgressScreen(weeklyKey: _tourKeys.progressWeeklyKey),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final started = await DashboardTourOverlay.maybeShow(
        context: context,
        keys: _tourKeys,
        onNavigate: _onItemTapped,
        onDismiss: () {
          if (!mounted) return;
          // Only reachable if the tour actually ran, so this was a
          // first-time user finishing it just now — welcome them.
          setState(() {
            _tourActive = false;
            _hatiReady = true;
            _hatiShowWelcome = true;
          });
        },
      );
      if (!mounted) return;
      if (started) {
        setState(() => _tourActive = true);
      } else {
        // Tour was already completed before this session — safe for Hati
        // to start talking right away.
        setState(() => _hatiReady = true);
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _replayTour() {
    setState(() => _tourActive = true);
    DashboardTourOverlay.show(
      context: context,
      keys: _tourKeys,
      onNavigate: _onItemTapped,
      onDismiss: () {
        if (mounted) setState(() => _tourActive = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
          if (_selectedIndex != _profileTabIndex || _tourActive)
            Positioned.fill(
              child: DraggableHelpButton(
                buttonKey: _tourKeys.helpButtonKey,
                onReplayTour: _replayTour,
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: BottomNavigationBar(
          key: _tourKeys.navBarKey,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF007AFF),
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.extension),
              label: 'Modules',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.trending_up),
              label: 'Progress',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
