import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;

import '../../notifications/first_login_notifications.dart';
import '../../postAssessment/data/reassessment_notification_service.dart';
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
    // Re-sync (not request) the reminder against Firestore's current
    // enabled/due state on every dashboard load — catches cases the
    // reassessment flow's own sync call can't: a fresh reinstall, or the
    // scheduled reminder having already fired and needing to roll forward.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      ReassessmentNotificationService.sync(uid).catchError((_) {});
      // First time this account ever reaches the dashboard: ask for the OS
      // notification permission up front and, if granted, turn on every
      // on-device reminder (daily nudge + the reassessment one above). No-
      // ops on every later login.
      FirstLoginNotifications.requestOnce(uid).catchError((_) {});
    }
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

  Future<bool> _confirmExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit HATI?'),
        content: const Text('Are you sure you want to close the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // This is the dashboard shell sitting at the root of the nav stack
      // (login reaches it via pushReplacement, so there's nothing behind
      // it) — without this, the system back button had no PopScope/
      // WillPopScope anywhere in the app to intercept it and just exited
      // immediately on any tab, and on non-Home tabs there was no way to
      // "back" to Home first.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          return;
        }
        if (await _confirmExit()) {
          if (mounted) SystemNavigator.pop();
        }
      },
      child: Scaffold(
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
      ),
    );
  }
}
