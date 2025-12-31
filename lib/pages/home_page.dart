import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/streak_service.dart';
import '../widgets/streak_bar.dart';
import 'new_session_page.dart';
import 'profile_overlay.dart';

const bool kForceStreakBarEveryLaunch = true; // TESTING ONLY

// Show debug button only in debug/profile builds (not release/TestFlight).
bool get _kShowMicDebugButton => kDebugMode || kProfileMode;

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _pageController = PageController();
  List<_AffirmationItem> _affirmations = [];
  final Map<int, GlobalKey> _boundaryKeys = {};
  final Set<String> _favoriteIds = {};
  int _pageIndex = 0;
  bool _loading = true;
  bool _showStreakBar = false;
  bool _streakBarVisible = false;
  StreakInfo? _streak;
  bool _loadingStreak = false;

  @override
  void initState() {
    super.initState();
    _loadAffirmations();
    _checkDailyStreakBar();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadAffirmations() async {
    try {
      final rows = await Supabase.instance.client
          .rpc('random_affirmations', params: {'p_limit': 20});

      final list = (rows as List? ?? const [])
          .map((e) => _AffirmationItem.fromRow(e as Map))
          .where((item) => item.text.isNotEmpty)
          .toList();

      setState(() {
        _affirmations = list.isEmpty ? _fallbackAffirmations : list;
        _boundaryKeys
          ..clear()
          ..addEntries(List.generate(
            _affirmations.length,
            (i) => MapEntry(i, GlobalKey()),
          ));
        _loading = false;
      });
      await _loadFavorites();
    } catch (_) {
      setState(() {
        _affirmations = _fallbackAffirmations;
        _boundaryKeys
          ..clear()
          ..addEntries(List.generate(
            _affirmations.length,
            (i) => MapEntry(i, GlobalKey()),
          ));
        _loading = false;
      });
    }
  }

  List<_AffirmationItem> get _fallbackAffirmations => const [
        _AffirmationItem(id: 'fallback-1', text: 'I refuse to give up.'),
        _AffirmationItem(id: 'fallback-2', text: 'I am grounded and clear.'),
        _AffirmationItem(id: 'fallback-3', text: 'I can do hard things.'),
        _AffirmationItem(id: 'fallback-4', text: 'I trust myself today.'),
        _AffirmationItem(id: 'fallback-5', text: 'I finish what I start.'),
      ];

  List<String> _sessionAffirmations() {
    if (_affirmations.isEmpty) {
      return const [
        'I am present.',
        'I am capable.',
        'I finish what I start.',
      ];
    }
    if (_affirmations.length <= 3) {
      return _affirmations.map((a) => a.text).toList();
    }
    final first = _pageIndex % _affirmations.length;
    final second = (first + 1) % _affirmations.length;
    final third = (first + 2) % _affirmations.length;
    return [
      _affirmations[first].text,
      _affirmations[second].text,
      _affirmations[third].text,
    ];
  }

  Future<void> _loadFavorites() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || _affirmations.isEmpty) return;
    final ids = _affirmations.map((a) => a.id).toList();
    if (ids.isEmpty) return;
    try {
      final rows = await Supabase.instance.client
          .from('favorite_affirmations')
          .select('affirmation_id')
          .eq('user_id', uid)
          .inFilter('affirmation_id', ids);
      final favorites = (rows as List? ?? const [])
          .map((e) => (e as Map)['affirmation_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      setState(() {
        _favoriteIds
          ..clear()
          ..addAll(favorites);
      });
    } catch (_) {}
  }

  Future<void> _toggleFavorite(_AffirmationItem item) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    if (item.id.startsWith('fallback-')) return;
    if (_favoriteIds.contains(item.id)) return;
    setState(() => _favoriteIds.add(item.id));
    try {
      await Supabase.instance.client.from('favorite_affirmations').upsert(
        {
          'user_id': uid,
          'affirmation_id': item.id,
        },
        onConflict: 'user_id,affirmation_id',
      );
    } catch (_) {
      setState(() => _favoriteIds.remove(item.id));
    }
  }

  Future<void> _shareCurrentAffirmation() async {
    if (_affirmations.isEmpty) return;
    final idx = _pageIndex % _affirmations.length;
    final key = _boundaryKeys[idx];
    final context = key?.currentContext;
    if (context == null) return;
    final boundary = context.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;

    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/affirmation_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes.buffer.asUint8List());
    await Share.shareXFiles(
      [XFile(file.path)],
      text: _affirmations[idx].text,
    );
  }

  Future<void> _checkDailyStreakBar() async {
    if (kForceStreakBarEveryLaunch) {
      if (!mounted) return;
      setState(() {
        _showStreakBar = true;
        _streakBarVisible = true;
      });
      _loadStreaks();
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _streakBarVisible = false);
        Future.delayed(const Duration(milliseconds: 350), () {
          if (!mounted) return;
          setState(() => _showStreakBar = false);
        });
      });
      return;
    }

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _formatDateKey(DateTime.now());
    final lastKey = prefs.getString('last_login_date_$uid');
    if (lastKey != todayKey) {
      await prefs.setString('last_login_date_$uid', todayKey);
      if (!mounted) return;
      setState(() {
        _showStreakBar = true;
        _streakBarVisible = true;
      });
      _loadStreaks();
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _streakBarVisible = false);
        Future.delayed(const Duration(milliseconds: 350), () {
          if (!mounted) return;
          setState(() => _showStreakBar = false);
        });
      });
    } else {
      if (!mounted) return;
      setState(() {
        _showStreakBar = false;
        _streakBarVisible = false;
      });
    }
  }

  Future<void> _loadStreaks() async {
    if (_loadingStreak) return;
    setState(() => _loadingStreak = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final s = await computeStreaks(Supabase.instance.client, uid);
      if (!mounted) return;
      setState(() {
        _streak = s;
        _loadingStreak = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingStreak = false);
    }
  }

  void _openProfileOverlay() {
    _loadStreaks();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Profile',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) {
        return ProfileOverlay(
          streakDays: _streak?.currentStreakDays ?? 0,
          loadingStreak: _loadingStreak,
        );
      },
      transitionBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  Future<void> _startDebugSession() async {
    // A short phrase that should be very easy for STT.
    const seed = ['hello mirroracle'];
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NewSessionPage(initialAffirmations: seed),
      ),
    );
    if (!mounted) return;
    _loadAffirmations();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFFEDE1D8),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.6),
                  radius: 1.2,
                  colors: [
                    const Color(0xFFF4ECE4),
                    const Color(0xFFE5D6CB),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _roundIcon(
                        icon: Icons.person_outline_rounded,
                        onTap: _openProfileOverlay,
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (_showStreakBar)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOut,
                      offset: _streakBarVisible
                          ? Offset.zero
                          : const Offset(0, -0.4),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        opacity: _streakBarVisible ? 1 : 0,
                        child: StreakBar(
                          streakDays: _streak?.currentStreakDays ?? 0,
                          loading: _loadingStreak,
                        ),
                      ),
                    ),
                  ),
                if (_showStreakBar) const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2F2624),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.auto_awesome, color: Colors.white70, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Daily affirmations',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : PageView.builder(
                          controller: _pageController,
                          scrollDirection: Axis.vertical,
                          onPageChanged: (idx) {
                            setState(() => _pageIndex = idx);
                          },
                          itemCount: _affirmations.length,
                          itemBuilder: (context, index) {
                            return AnimatedBuilder(
                              animation: _pageController,
                              builder: (context, child) {
                                double t = 0;
                                if (_pageController.hasClients &&
                                    _pageController
                                        .position.hasContentDimensions) {
                                  final page = _pageController.page ?? 0.0;
                                  t = (1 - (page - index).abs())
                                      .clamp(0.0, 1.0);
                                } else if (index == 0) {
                                  t = 1;
                                }
                                final scale = 0.92 + (0.08 * t);
                                final opacity = 0.35 + (0.65 * t);
                                return Center(
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 250),
                                    opacity: opacity,
                                    child: Transform.scale(
                                      scale: scale,
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: size.width * 0.12,
                                        ),
                                        child: RepaintBoundary(
                                          key: _boundaryKeys[index],
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 18,
                                              vertical: 16,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF6EEE7),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Color(0x1A000000),
                                                  blurRadius: 18,
                                                  offset: Offset(0, 8),
                                                ),
                                              ],
                                              border: Border.all(
                                                color: const Color(0xFFE5D6CB),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              _affirmations[index].text,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 30,
                                                height: 1.3,
                                                fontFamily: 'serif',
                                                color: Color(0xFF4B3C36),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.ios_share_rounded),
                        color: const Color(0xFF5C4B42),
                        onPressed: _affirmations.isEmpty
                            ? null
                            : _shareCurrentAffirmation,
                        tooltip: 'Share',
                      ),
                      const SizedBox(width: 16),
                      Builder(
                        builder: (context) {
                          final item = _affirmations.isEmpty
                              ? null
                              : _affirmations[_pageIndex % _affirmations.length];
                          return IconButton(
                            icon: Icon(
                              item != null && _favoriteIds.contains(item.id)
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                            ),
                            color: const Color(0xFFE07A6B),
                            onPressed:
                                item == null ? null : () => _toggleFavorite(item),
                            tooltip: 'Favorite',
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // TEMP DEBUG BUTTON (remove later)
                if (_kShowMicDebugButton)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: OutlinedButton.icon(
                      onPressed: _startDebugSession,
                      icon: const Icon(Icons.mic_rounded),
                      label: const Text('Mic Debug'),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF7F1EB),
                        foregroundColor: const Color(0xFF2F2624),
                        elevation: 6,
                        shadowColor: Colors.black26,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                      ),
                      onPressed: _affirmations.isEmpty
                          ? null
                          : () async {
                              final seed = _sessionAffirmations();
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => NewSessionPage(
                                    initialAffirmations: seed,
                                  ),
                                ),
                              );
                              if (!mounted) return;
                              _loadAffirmations();
                            },
                      icon: const Icon(Icons.self_improvement_outlined),
                      label: const Text(
                        'Practice',
                        style: TextStyle(fontWeight: FontWeight.w600),
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

  Widget _roundIcon({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F1EB),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, color: const Color(0xFF2F2624)),
        ),
      ),
    );
  }

  String _formatDateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _AffirmationItem {
  final String id;
  final String text;
  const _AffirmationItem({required this.id, required this.text});

  factory _AffirmationItem.fromRow(Map row) {
    return _AffirmationItem(
      id: row['id']?.toString() ?? '',
      text: row['text']?.toString().trim() ?? '',
    );
  }
}