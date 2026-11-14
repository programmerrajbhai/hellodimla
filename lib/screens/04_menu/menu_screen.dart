import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/network/service_api.dart';
import '../../services/community_service.dart';
import '../02_home/sheets/home_sheets.dart';
import '../03_notifications/notifications_screen.dart';
import '../08_saved_items/saved_items_screen.dart';
import '../21_settings/settings_screen.dart';
import '../22_help_policies/help_policies_screen.dart';
import 'service_list_panel.dart';

typedef _Json = Map<String, dynamic>;

const _blue = Color(0xFF1959E8);
const _navy = Color(0xFF162644);
const _muted = Color(0xFF596A80);
const _border = Color(0xFFDDE5F1);
const _bg = Color(0xFFF5F8FD);
const _allAreas = 'সব এলাকা';

const _accents = [
  Color(0xFF1959E8),
  Color(0xFFBE3455),
  Color(0xFF087F75),
  Color(0xFF7354B5),
];

int _int(dynamic value) => int.tryParse('$value') ?? 0;
bool _yes(dynamic value) => value == true || _int(value) == 1;
String _text(dynamic value) => value?.toString().trim() ?? '';

RoundedRectangleBorder _shape() => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(16),
  side: const BorderSide(color: _border),
);

void _openMenu(_Json menu) {
  Get.to(
        () => ServiceMenuScreen(menuId: '${menu['id']}'),
    preventDuplicates: false,
  );
}

class _Directory {
  const _Directory(this.areas, this.menus);

  final Map<int, String> areas;
  final Map<String, _Json> menus;

  static Future<_Directory> load() async {
    final catalog = await ServiceApi.catalog();
    final areas = <int, String>{};
    final menus = <String, _Json>{};

    for (final row in catalog.areas) {
      final id = _int(row['id']);
      final name = _text(row['name']);
      if (id > 0 && name.isNotEmpty) areas[id] = name;
    }

    for (final row in catalog.menus) {
      final id = _int(row['id']);
      if (id <= 0) continue;

      final parent = _int(row['parent']);
      menus['$id'] = {
        ...row,
        'id': id,
        'parent': parent > 0 ? '$parent' : '',
        'title': _text(row['title']),
        'position': _int(row['position']),
        'rev': _int(row['rev']),
        'hasIcon': _yes(row['hasIcon']),
        'home': _yes(row['home']),
        'accept': _yes(row['accept']),
      };
    }

    return _Directory(areas, menus);
  }

  List<_Json> sorted(Iterable<_Json> rows) {
    return rows.toList()
      ..sort((a, b) {
        final order = _int(a['position']).compareTo(_int(b['position']));
        if (order != 0) return order;

        final title = _text(a['title']).compareTo(_text(b['title']));
        if (title != 0) return title;

        return _int(a['id']).compareTo(_int(b['id']));
      });
  }

  int? zoneFor(String name) {
    if (name == _allAreas) return 0;
    for (final area in areas.entries) {
      if (area.value == name) return area.key;
    }
    return null;
  }
}

class _CatalogView extends StatefulWidget {
  const _CatalogView({required this.builder, this.compact = false});

  final Widget Function(_Directory, Future<void> Function()) builder;
  final bool compact;

  @override
  State<_CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends State<_CatalogView> {
  _Directory? _data;
  bool _failed = false;
  Future<void>? _pending;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());

    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
          !TickerMode.of(context) ||
          ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      unawaited(_refresh());
    });
  }

  Future<void> _refresh() {
    return _pending ??= _load().whenComplete(() {
      _pending = null;
    });
  }

  Future<void> _load() async {
    try {
      final data = await _Directory.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data != null) return widget.builder(data, _refresh);

    final Widget status;
    if (_failed) {
      status = TextButton.icon(
        onPressed: _refresh,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('মেনু লোড হয়নি · আবার চেষ্টা করুন'),
      );
    } else {
      status = widget.compact
          ? const LinearProgressIndicator(minHeight: 2)
          : const CircularProgressIndicator();
    }

    if (widget.compact) return status;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(title: const Text('সেবা মেনু')),
      body: Center(child: status),
    );
  }
}

class MenuScreen extends ServiceMenuScreen {
  const MenuScreen({super.key});
}

class ServiceMenuScreen extends StatefulWidget {
  const ServiceMenuScreen({super.key, this.menuId = ''});

  final String menuId;

  @override
  State<ServiceMenuScreen> createState() => _ServiceMenuScreenState();
}

class _ServiceMenuScreenState extends State<ServiceMenuScreen> {
  final _community = Get.find<CommunityService>();
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _search.clear();
    setState(() => _query = '');
  }

  void _openShortcut(String action) {
    switch (action) {
      case 'saved':
        Get.to(() => const SavedItemsScreen());
        break;
      case 'settings':
        Get.to(() => const SettingsScreen());
        break;
      case 'help':
        Get.to(() => const HelpPoliciesScreen());
        break;
      case 'notifications':
        Get.to(() => const NotificationsScreen());
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CatalogView(
      builder: (directory, refresh) {
        final id = widget.menuId;
        final root = id.isEmpty;
        final node = directory.menus[id];

        if (!root && node == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('সেবা মেনু')),
            body: Center(
              child: TextButton.icon(
                onPressed: refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('এই মেনুটি পাওয়া যাচ্ছে না · আবার দেখুন'),
              ),
            ),
          );
        }

        final group = root || node?['kind'] == 'group';
        final title = root ? 'সেবা মেনু' : _text(node?['title']);

        final children = directory.sorted(
          directory.menus.values.where(
                (m) =>
            m['parent'] == id &&
                _text(m['title']).toLowerCase().contains(_query),
          ),
        );

        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _bg,
            foregroundColor: _navy,
            elevation: 0,
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            actions: [
              if (root)
                PopupMenuButton<String>(
                  tooltip: 'আরও অপশন',
                  onSelected: _openShortcut,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'saved', child: Text('সেভ করা')),
                    PopupMenuItem(value: 'settings', child: Text('সেটিংস')),
                    PopupMenuItem(value: 'help', child: Text('সাহায্য')),
                    PopupMenuItem(
                      value: 'notifications',
                      child: Text('নোটিফিকেশন'),
                    ),
                  ],
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Material(
                    color: Colors.white,
                    shape: _shape(),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: const Icon(Icons.place_outlined, color: _blue),
                      title: Obx(
                            () => Text('এলাকা: ${_community.selectedArea.value}'),
                      ),
                      trailing: const Icon(Icons.expand_more_rounded),
                      onTap: () => Get.bottomSheet(
                        AreaSelectionSheet(
                          directoryAreas: directory.areas.values.toList(),
                        ),
                        isScrollControlled: true,
                      ),
                    ),
                  ),
                ),
                if (group) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      onChanged: (v) =>
                          setState(() => _query = v.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'এই মেনুতে সেবা খুঁজুন',
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                          tooltip: 'অনুসন্ধান মুছুন',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: _clearSearch,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: _border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: _blue, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _MenuGrid(
                      menuId: id,
                      items: children,
                      searching: _query.isNotEmpty,
                      onClear: _clearSearch,
                      onRefresh: refresh,
                    ),
                  ),
                ] else
                  Expanded(
                    child: Obx(() {
                      final zone =
                      directory.zoneFor(_community.selectedArea.value);
                      if (zone == null) {
                        return const Center(
                          child: Text('উপরে একটি ইউনিয়ন নির্বাচন করুন।'),
                        );
                      }
                      return ServiceListPanel(
                        key: ValueKey('$id/$zone'),
                        menu: node!,
                        zone: zone,
                        areas: directory.areas,
                      );
                    }),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MenuGrid extends StatelessWidget {
  const _MenuGrid({
    required this.menuId,
    required this.items,
    required this.searching,
    required this.onClear,
    required this.onRefresh,
  });

  final String menuId;
  final List<_Json> items;
  final bool searching;
  final VoidCallback onClear;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context);

    // বড় সিস্টেম ফন্টেও আইকন, দুই লাইনের নাম ও নিচের লেখা জায়গা পাবে।
    final cardHeight = 94 + scale.scale(15) * 2.9 + scale.scale(12) * 1.6;

    return RefreshIndicator(
      color: _blue,
      onRefresh: onRefresh,
      child: CustomScrollView(
        key: PageStorageKey('service-menu-grid-$menuId'),
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        searching
                            ? Icons.search_off_rounded
                            : Icons.folder_open_rounded,
                        color: _muted,
                        size: 36,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        searching
                            ? 'এই নামে কোনো সেবা পাওয়া যায়নি।'
                            : 'এই বিভাগে এখনো কোনো মেনু নেই।',
                        textAlign: TextAlign.center,
                      ),
                      if (searching)
                        TextButton(
                          onPressed: onClear,
                          child: const Text('সব বিভাগ দেখুন'),
                        ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: cardHeight,
                ),
                delegate: SliverChildBuilderDelegate(
                      (_, i) => _MenuCard(
                    key: ValueKey(items[i]['id']),
                    menu: items[i],
                  ),
                  childCount: items.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({super.key, required this.menu});

  final _Json menu;

  @override
  Widget build(BuildContext context) {
    final id = _int(menu['id']);
    // সার্চ করলেও একই মেনুর রঙ একই থাকবে।
    final accent = _accents[(id - 1) % _accents.length];
    final title = _text(menu['title']);
    final isGroup = menu['kind'] == 'group';

    return Material(
      color: Color.alphaBlend(
        accent.withValues(alpha: .045),
        Colors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: BorderSide(color: accent.withValues(alpha: .16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openMenu(menu),
        splashColor: accent.withValues(alpha: .10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _MenuIcon(menu: menu, size: 50, accent: accent),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, size: 19, color: accent),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.32,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isGroup ? 'বিভাগগুলো দেখুন' : 'সেবার তালিকা',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuIcon extends StatelessWidget {
  const _MenuIcon({
    required this.menu,
    required this.size,
    this.accent = _blue,
  });

  final _Json menu;
  final double size;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      menu['kind'] == 'group'
          ? Icons.folder_outlined
          : Icons.grid_view_rounded,
      size: size * .58,
      color: accent,
    );

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: accent.withValues(alpha: .13)),
      ),
      child: menu['hasIcon'] == true
          ? ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          ServiceApi.menuIcon(
            _int(menu['id']),
            revision: _int(menu['rev']),
          ).toString(),
          fit: BoxFit.contain,
          excludeFromSemantics: true,
          errorBuilder: (_, __, ___) => fallback,
        ),
      )
          : fallback,
    );
  }
}

// পুরোনো HomeScreen-এ DirectoryHomeLinks ব্যবহার থাকলেও কলটি কাজ করবে।
class DirectoryHomeLinks extends StatelessWidget {
  const DirectoryHomeLinks({
    super.key,
    required this.legacy,
    required this.onAll,
  });

  final WidgetBuilder legacy;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    return _CatalogView(
      compact: true,
      builder: (directory, _) {
        final all = directory.sorted(directory.menus.values);
        final pinned = all.where((m) => m['home'] == true).toList();
        final items = (pinned.isEmpty
            ? all.where((m) => m['parent'] == '')
            : pinned)
            .take(8);

        return Card(
          elevation: 0,
          color: Colors.white,
          shape: _shape(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Expanded(
                    child: Text(
                      'দ্রুত সেবা',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(onPressed: onAll, child: const Text('সব মেনু')),
                ]),
                if (items.isEmpty)
                  const Text('এখনো কোনো সেবা যোগ করা হয়নি।')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final menu in items)
                        OutlinedButton.icon(
                          onPressed: () => _openMenu(menu),
                          icon: _MenuIcon(menu: menu, size: 32),
                          label: Text(
                            _text(menu['title']),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _navy,
                            minimumSize: const Size(0, 50),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: const BorderSide(color: _border),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}