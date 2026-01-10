import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  bool _loading = true;
  String? _error;
  List<_FavoriteThemeGroup> _groups = const [];
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      setState(() {
        _loading = false;
        _error = 'Please sign in to view favorites.';
      });
      return;
    }

    try {
      final client = Supabase.instance.client;

      final favRows = await client
          .from('favorite_affirmations')
          .select('affirmations(id,text,theme_id,themes(name))')
          .eq('user_id', uid);

      final themeRows = await client
          .from('user_theme_preferences')
          .select('themes(id,name)')
          .eq('user_id', uid);

      final byTheme = <String, List<String>>{};

      for (final row in (favRows as List? ?? const [])) {
        if (row is! Map) continue;
        final aff =
            row['affirmations'] as Map? ?? row['affirmation'] as Map?;
        if (aff == null) continue;
        final text = aff['text']?.toString().trim() ?? '';
        if (text.isEmpty) continue;

        final themeMap = aff['themes'] as Map?;
        final themeName =
            themeMap?['name']?.toString().trim().isNotEmpty == true
                ? themeMap!['name'].toString()
                : 'Other';

        byTheme.putIfAbsent(themeName, () => []).add(text);
      }

      for (final row in (themeRows as List? ?? const [])) {
        if (row is! Map) continue;
        final theme = row['themes'] as Map?;
        final name = theme?['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        byTheme.putIfAbsent(name, () => []);
      }

      final groups = byTheme.entries
          .map((e) => _FavoriteThemeGroup(name: e.key, affirmations: e.value))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        _groups = groups;
        _loading = false;
        _error = null;
        _selectedFilter = 'All';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not load favorites.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = [
      'All',
      ..._groups.map((g) => g.name),
    ];
    final visibleGroups = _selectedFilter == 'All'
        ? _groups
        : _groups.where((g) => g.name == _selectedFilter).toList();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFD9D0EC),
              Color(0xFFEFEAF7),
              Color(0xFFF7F5FB),
            ],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _EmptyState(message: _error!)
                  : CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Favorites',
                                  style: GoogleFonts.manrope(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1F1B2E),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: filters.map((label) {
                                      final selected = label == _selectedFilter;
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(right: 10),
                                        child: ChoiceChip(
                                          label: Text(
                                            label,
                                            style: GoogleFonts.manrope(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: selected
                                                  ? const Color(0xFF2B2340)
                                                  : const Color(0xFF5A4F75),
                                            ),
                                          ),
                                          selected: selected,
                                          onSelected: (_) {
                                            setState(
                                              () => _selectedFilter = label,
                                            );
                                          },
                                          selectedColor:
                                              const Color(0xFFF5F1FA),
                                          backgroundColor:
                                              const Color(0xFFE4DDF1),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            side: BorderSide(
                                              color: selected
                                                  ? const Color(0xFFB5A4D4)
                                                  : const Color(0xFFC9BEDF),
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (visibleGroups.isEmpty)
                          const SliverToBoxAdapter(
                            child: _EmptyState(
                              message: 'No favorites yet.',
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final group = visibleGroups[index];
                                  return _FavoriteCard(group: group);
                                },
                                childCount: visibleGroups.length,
                              ),
                            ),
                          ),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _FavoriteThemeGroup {
  final String name;
  final List<String> affirmations;

  const _FavoriteThemeGroup({
    required this.name,
    required this.affirmations,
  });
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({required this.group});

  final _FavoriteThemeGroup group;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EDF7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFC6BEDB), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A352A4A),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            group.name,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF5B516E),
            ),
          ),
          const SizedBox(height: 12),
          if (group.affirmations.isEmpty)
            Text(
              'No affirmations saved yet.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6F657E),
              ),
            )
          else
            ...group.affirmations.map(
              (text) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E1A2C),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF5A4F75),
        ),
      ),
    );
  }
}
