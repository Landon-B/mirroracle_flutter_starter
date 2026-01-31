// lib/pages/home_page.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../services/streak_service.dart';
import '../widgets/home/home_widgets.dart';
import 'mic_debug_page.dart';
import 'new_session_page.dart';
import 'profile_overlay.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _pageController = PageController();
  List<AffirmationItem> _affirmations = [];
  final Map<int, GlobalKey> _boundaryKeys = {};
  final Set<String> _favoriteIds = {};
  int _pageIndex = 0;
  bool _loading = true;

  // Streak bar state
  bool _showStreakBar = false;
  bool _streakBarVisible = false;
  StreakInfo? _streak;
  bool _loadingStreak = false;

  // Name overlay state
  bool _showNameOverlay = false;
  bool _savingName = false;
  String? _nameError;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAffirmations();
    _checkDailyStreakBar();
    _checkMissingName();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Name Overlay Logic
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _checkMissingName() async {
    final user = Supabase.instance.client.auth.currentUser;
    final firstName = user?.userMetadata?['first_name']?.toString().trim();
    if (firstName == null || firstName.isEmpty) {
      setState(() => _showNameOverlay = true);
    }
  }

  Future<void> _submitMissingName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Please enter your first name.');
      return;
    }
    setState(() {
      _savingName = true;
      _nameError = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'first_name': name}),
      );
      if (!mounted) return;
      setState(() => _showNameOverlay = false);
    } on AuthException catch (e) {
      setState(() => _nameError = e.message);
    } catch (e) {
      setState(() => _nameError = 'Unexpected error: $e');
    } finally {
      if (mounted) {
        setState(() => _savingName = false);
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Affirmations Logic
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _loadAffirmations() async {
    try {
      final rows = await Supabase.instance.client
          .rpc('random_affirmations', params: {'p_limit': 20});

      final list = (rows as List? ?? const [])
          .map((e) => AffirmationItem.fromRow(e as Map))
          .where((item) => item.text.isNotEmpty)
          .toList();

      final themeIds =
          list.map((item) => item.themeId).whereType<String>().toSet();
      final themeNames = <String, String>{};
      if (themeIds.isNotEmpty) {
        final rows = await Supabase.instance.client
            .from('themes')
            .select('id,name')
            .inFilter('id', themeIds.toList());
        for (final row in (rows as List? ?? const [])) {
          final id = (row as Map)['id']?.toString();
          final name = row['name']?.toString();
          if (id != null && name != null) {
            themeNames[id] = name;
          }
        }
      }

      final mapped = list
          .map(
            (item) => item.copyWith(
              themeName: item.themeId != null ? themeNames[item.themeId!] : null,
            ),
          )
          .toList();

      setState(() {
        _affirmations = mapped;
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
        _affirmations = [];
        _boundaryKeys.clear();
        _loading = false;
      });
    }
  }

  List<String> _sessionAffirmations() {
    if (_affirmations.isEmpty) return const [];
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

  Future<void> _toggleFavorite(AffirmationItem item) async {
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

  // ──────────────────────────────────────────────────────────────────────────
  // Streak Bar Logic
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _checkDailyStreakBar() async {
    if (kForceStreakBarEveryLaunch) {
      if (!mounted) return;
      setState(() {
        _showStreakBar = true;
        _streakBarVisible = true;
      });
      _loadStreaks();
      _scheduleStreakBarHide();
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
      _scheduleStreakBarHide();
    } else {
      if (!mounted) return;
      setState(() {
        _showStreakBar = false;
        _streakBarVisible = false;
      });
    }
  }

  void _scheduleStreakBarHide() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _streakBarVisible = false);
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        setState(() => _showStreakBar = false);
      });
    });
  }

  Future<void> _loadStreaks() async {
    if (_loadingStreak) return;
    setState(() => _loadingStreak = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) {
        if (!mounted) return;
        setState(() => _loadingStreak = false);
        return;
      }
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

  // ──────────────────────────────────────────────────────────────────────────
  // Profile Overlay
  // ──────────────────────────────────────────────────────────────────────────

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
          activeDates: _streak?.activeDates ?? const {},
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

  // ──────────────────────────────────────────────────────────────────────────
  // Navigation
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _navigateToSession() async {
    final seed = _sessionAffirmations();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewSessionPage(initialAffirmations: seed),
      ),
    );
    if (!mounted) return;
    _loadAffirmations();
  }

  void _navigateToMicDebug() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MicDebugPage()),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────────────────────

  String _formatDateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  AffirmationItem? get _currentAffirmation {
    if (_affirmations.isEmpty) return null;
    return _affirmations[_pageIndex % _affirmations.length];
  }

  bool get _isCurrentFavorited {
    final item = _currentAffirmation;
    return item != null && _favoriteIds.contains(item.id);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDE1D8),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                _buildHeader(),
                const SizedBox(height: 8),
                if (_showStreakBar) ...[
                  AnimatedStreakBar(
                    visible: _streakBarVisible,
                    activeDates: _streak?.activeDates ?? const {},
                    loading: _loadingStreak,
                  ),
                  const SizedBox(height: 16),
                ],
                const DailyAffirmationsChip(),
                const SizedBox(height: 24),
                Expanded(child: _buildAffirmationList()),
                _buildBottomActions(),
              ],
            ),
          ),
          if (_showNameOverlay)
            NameOverlay(
              controller: _nameController,
              errorMessage: _nameError,
              isSaving: _savingName,
              onSubmit: _submitMissingName,
            ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
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
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.person_outline_rounded,
            onTap: _openProfileOverlay,
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildAffirmationList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_affirmations.isEmpty) {
      return const Center(
        child: Text(
          'No affirmations available yet.',
          style: TextStyle(fontSize: 16, color: Color(0xFF6B5B52)),
        ),
      );
    }
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      onPageChanged: (idx) => setState(() => _pageIndex = idx),
      itemCount: _affirmations.length,
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: _pageController,
          builder: (context, child) {
            double t = 0;
            if (_pageController.hasClients &&
                _pageController.position.hasContentDimensions) {
              final page = _pageController.page ?? 0.0;
              t = (1 - (page - index).abs()).clamp(0.0, 1.0);
            } else if (index == 0) {
              t = 1;
            }
            final scale = 0.92 + (0.08 * t);
            final opacity = 0.35 + (0.65 * t);
            return AffirmationCard(
              item: _affirmations[index],
              opacity: opacity,
              scale: scale,
              repaintKey: _boundaryKeys[index],
            );
          },
        );
      },
    );
  }

  Widget _buildBottomActions() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AffirmationActions(
            enabled: _affirmations.isNotEmpty,
            isFavorited: _isCurrentFavorited,
            onShare: _shareCurrentAffirmation,
            onFavorite: () {
              final item = _currentAffirmation;
              if (item != null) _toggleFavorite(item);
            },
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: PracticeButton(
            enabled: _affirmations.isNotEmpty,
            onPressed: _navigateToSession,
            onLongPress: _navigateToMicDebug,
          ),
        ),
      ],
    );
  }
}
