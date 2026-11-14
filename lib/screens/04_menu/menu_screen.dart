// Smart Dimla: MySQL directory
import 'dart:async';
import 'package:flutter/material.dart' hide MenuController;
import '../../core/network/service_api.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/community_service.dart';
import '../02_home/sheets/home_sheets.dart';
import '../03_notifications/notifications_screen.dart';
import '../07_service_details/service_details_screen.dart';
import '../08_saved_items/saved_items_screen.dart';
import '../21_settings/settings_screen.dart';
import '../22_help_policies/help_policies_screen.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'menu_controller.dart';

typedef _Map = Map<String,dynamic>;
const _all='সব এলাকা', _wide='পুরো ডিমলা';
List<String> _strings(dynamic v)=> v is List ? v.whereType<String>().toList() : [];
List<_Map> _fields(_Map m)=> (m['fields'] as List? ?? []).whereType<Map>().map((v)=>Map<String,dynamic>.from(v)).toList();
void _message(BuildContext c,String s)=>ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text(s)));


int _num(dynamic x) => int.tryParse('$x') ?? 0;
bool _flag(dynamic x) => x == true || _num(x) == 1;
class _Catalog {
  _Catalog(ServiceCatalog c) {
    for (final a in c.areas) { areas[_num(a['id'])] = a['name'] as String; }
    for (final m in c.menus) {
      nodes["${m['id']}"] = {...m,
        'parent': _num(m['parent']) == 0 ? '' : "${m['parent']}",
        'order': _num(m['position']), 'icon': _num(m['rev']),
        'hasIcon': _flag(m['hasIcon']), 'home': _flag(m['home']), 'accept': _flag(m['accept'])};
    }
  }
  final areas = <int,String>{};
  final nodes = <String,_Map>{};
}
Stream<T> _feed<T>(State state, Future<T> Function() read) async* {
  while (state.mounted) {
    yield await read();
    do {
      await Future<void>.delayed(const Duration(seconds:30));
      if (!state.mounted) return;
    } while (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        !TickerMode.of(state.context) || ModalRoute.of(state.context)?.isCurrent == false);
  }
}
Future<_Catalog> _catalog() async => _Catalog(await ServiceApi.catalog());
Widget _retry(VoidCallback run) => Center(child: TextButton.icon(onPressed:run,
    icon:const Icon(Icons.refresh),label:const Text('লোড হয়নি · আবার চেষ্টা করুন')));

class MenuScreen extends ServiceMenuScreen { const MenuScreen({super.key}); }

class ServiceMenuScreen extends StatefulWidget {
  const ServiceMenuScreen({super.key,this.menuId=''});
  final String menuId;
  @override State<ServiceMenuScreen> createState()=>_MenuState();
}
class _MenuState extends State<ServiceMenuScreen>{
  final community=Get.find<CommunityService>();
  late var stream=_feed(this,_catalog);
  String search='';
  @override Widget build(BuildContext context)=>StreamBuilder<_Catalog>(stream:stream,builder:(context,s){
    if(s.hasError)return Scaffold(appBar:AppBar(),body:_retry(()=>setState(()=>stream=_feed(this,_catalog))));
    if(!s.hasData)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    final nodes=s.data!.nodes, areas=s.data!.areas;
    final id=widget.menuId,root=id.isEmpty;
    final n=root?<String,dynamic>{'kind':'group','title':'সেবা মেনু'}:nodes[id];
    if(n==null)return Scaffold(appBar:AppBar(),body:const Center(child:Text('এই মেনু এখন পাওয়া যাচ্ছে না।')));
    final children=nodes.entries.where((e)=>e.value['parent']==id && e.value['title'].toString().toLowerCase().contains(search.toLowerCase())).toList()
      ..sort((a,b){final r=(a.value['order'] as int).compareTo(b.value['order'] as int);return r!=0?r:a.value['title'].toString().compareTo(b.value['title'].toString());});
    return Scaffold(appBar:AppBar(title:Text(n['title']),actions:[if(root)PopupMenuButton<String>(tooltip:'আরও অপশন',onSelected:(v){
      switch(v){case 'সেভ করা':Get.to(()=>const SavedItemsScreen());break;case 'সেটিংস':Get.to(()=>const SettingsScreen());break;case 'সাহায্য':Get.to(()=>const HelpPoliciesScreen());break;default:Get.to(()=>const NotificationsScreen());}
    },itemBuilder:(_)=>[for(final label in ['সেভ করা','সেটিংস','সাহায্য','নোটিফিকেশন'])PopupMenuItem(value:label,child:Text(label))])]),
        body:SafeArea(child:Column(children:[
          ListTile(leading:const Icon(Icons.place_outlined),title:Obx(()=>Text('এলাকা: ${community.selectedArea.value}')),trailing:const Icon(Icons.expand_more),onTap:()=>Get.bottomSheet(AreaSelectionSheet(directoryAreas:areas.values.toList()),isScrollControlled:true)),
          if(n['kind']=='group')...[
            Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:TextField(decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'এই মেনুতে খুঁজুন'),onChanged:(v)=>setState(()=>search=v))),
            Expanded(child:children.isEmpty?const Center(child:Text('কোনো মেনু পাওয়া যায়নি।')):ListView.builder(itemCount:children.length,itemBuilder:(_,i){
              final e=children[i];return ListTile(leading:_MenuIcon(key:ValueKey('${e.key}:${e.value['icon']}'),id:e.key,version:e.value['icon'] as int,hasIcon:e.value['hasIcon']==true),
                  title:Text(e.value['title']),trailing:const Icon(Icons.chevron_right),onTap:()=>Get.to(()=>ServiceMenuScreen(menuId:e.key),preventDuplicates:false));}))]
          else Expanded(child:Obx((){
            final name=community.selectedArea.value;
            final ids=areas.keys.where((k)=>areas[k]==name);
            if(name!=_all && ids.isEmpty)return const Center(child:Text('উপরে তালিকাভুক্ত একটি ইউনিয়ন নির্বাচন করুন।'));
            final zone=name==_all?0:ids.first;
            return _Listings(key:ValueKey('$id/$zone'),id:id,node:n,zone:zone,areas:areas);
          }))
        ])));
  });
}

class _MenuIcon extends StatelessWidget {
  const _MenuIcon({super.key,required this.id,required this.version,required this.hasIcon});
  final String id; final int version; final bool hasIcon;
  @override Widget build(BuildContext c){
    const fallback=Icon(Icons.grid_view_rounded,color:Color(0xff245ede));
    return hasIcon?Image.network(ServiceApi.menuIcon(int.parse(id),revision:version).toString(),
        width:42,height:42,errorBuilder:(_,__,___)=>fallback):fallback;
  }
}
class _Listings extends StatefulWidget{
  const _Listings({super.key,required this.id,required this.node,required this.zone,required this.areas});
  final int zone; final Map<int,String> areas;
  final String id; final _Map node;
  @override State<_Listings> createState()=>_ListingsState();
}
class _ListingsState extends State<_Listings>{
  final filters=<String,String>{};
  late var stream=_feed(this,read);
  Future<List<_Map>> read()async{
    final mid=int.parse(widget.id), zone=widget.zone;
    final rows=<int,_Map>{};
    int? cursor=0;
    while(mounted && cursor!=null){
      final p=await ServiceApi.entries(menuId:mid,areaId:zone,after:cursor);
      for(final r in p.items){rows[_num(r['id'])]=r;}
      cursor=p.nextAfter;
    }
    return rows.values.toList();
  }
  @override Widget build(BuildContext c){final fields=_fields(widget.node);
  return Column(children:[
    if(fields.any((f)=>_strings(f['options']).isNotEmpty))SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
      for(final f in fields.where((f)=>_strings(f['options']).isNotEmpty))Padding(padding:const EdgeInsets.symmetric(horizontal:8),child:DropdownButton<String>(
          value:_strings(f['options']).contains(filters[f['key']])?filters[f['key']]:'',
          items:[DropdownMenuItem(value:'',child:Text('${f['label']}: সব')),for(final v in _strings(f['options']))DropdownMenuItem(value:v,child:Text(v))],
          onChanged:(v)=>setState(()=>filters[f['key']]=v??'')))])),
    if(widget.node['accept']==true)TextButton.icon(icon:const Icon(Icons.add),label:const Text('তথ্য যোগ করুন'),onPressed:()=>showDialog(context:c,barrierDismissible:false,builder:(_)=>_Submit(id:widget.id,node:widget.node,areas:widget.areas,zone:widget.zone))),
    Expanded(child:StreamBuilder<List<_Map>>(stream:stream,builder:(_,s){
      if(s.hasError)return _retry(()=>setState(()=>stream=_feed(this,read)));
      if(!s.hasData)return const Center(child:CircularProgressIndicator());
      List<int> ids(_Map r)=>(r['areas'] as List? ?? []).map(_num).toList();
      List<String> labels(_Map r)=>[if(_flag(r['wide'])) _wide,
        for(final id in ids(r)) if(widget.areas.containsKey(id)) widget.areas[id]!];
      int rank(_Map r)=>widget.zone==0 || ids(r).contains(widget.zone)?0:1;
      final docs=s.data!.where((r)=>fields.every((f){
        final v=filters[f['key']];
        return v==null || !_strings(f['options']).contains(v) || r['extra']?[f['key']]==v;
      })).toList()..sort((a,b){final n=rank(a).compareTo(rank(b));
      return n!=0?n:a['name'].toString().compareTo(b['name'].toString());});
      if(docs.isEmpty)return const Center(child:Text('এই নির্বাচনে এখনো কোনো তথ্য নেই।'));
      return ListView.builder(itemCount:docs.length,itemBuilder:(_,i){final v=docs[i],phone=(v['phone']??'').toString();
      return ListTile(title:Text(v['name']??''),subtitle:Text([labels(v).join(' · '),for(final f in fields)if(v['extra']?[f['key']]!=null)'${f['label']}: ${v['extra'][f['key']]}'].where((s)=>s.isNotEmpty).join('\n')),
          onTap:()=>Get.to(()=>ServiceDetailsScreen(serviceId:"mysql:${v['id']}"),arguments:{'source':'mysql','entry':v,'menu':widget.node,'areaNames':widget.areas}),trailing:phone.isEmpty?null:IconButton(tooltip:'কল করুন',icon:const Icon(Icons.phone_outlined),onPressed:()async{try{if(!await launchUrl(Uri(scheme:'tel',path:phone)))throw StateError('dialer');}catch(_){if(c.mounted)_message(c,'ডায়ালার খোলা যায়নি।');}}));});}))
  ]);}
}

class _Submit extends StatefulWidget{
  const _Submit({required this.id,required this.node,required this.areas,required this.zone});final Map<int,String> areas;final int zone;final String id;final _Map node;
  @override State<_Submit> createState()=>_SubmitState();
}
class _SubmitState extends State<_Submit>{
  final values=<String,String>{};
  String name='',phone='',area='',error='';bool consent=false,busy=false;
  @override void initState(){super.initState();area=widget.areas[widget.zone]??'';}
  Future<void> submit()async{
    if(busy)return;
    final p=phone.trim().replaceAllMapped(RegExp('[০-৯]'),(m)=>'০১২৩৪৫৬৭৮৯'.indexOf(m[0]!).toString()).replaceAll(RegExp(r'[\s()-]'),'');
    if(name.trim().length<2||!RegExp(r'^\+?[0-9]{3,15}$').hasMatch(p)||area.isEmpty||!consent){setState(()=>error='নাম, ফোন, ইউনিয়ন ও প্রকাশের সম্মতি দিন।');return;}
    setState((){busy=true;error='';});try{
      final zone=widget.areas.entries.firstWhere((a)=>a.value==area).key;
      await ServiceApi.submit(menuId:int.parse(widget.id),name:name.trim(),phone:p,areaIds:[zone],
          consent:consent,extra:{for(final e in values.entries)if(e.value.trim().isNotEmpty)e.key:e.value.trim()});
      if(mounted){_message(context,'তথ্য জমা হয়েছে। অনুমোদনের পর তালিকায় আসবে।');Navigator.pop(context);}
    }catch(e){if(mounted)setState(()=>error=e.toString());}finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext c)=>PopScope(canPop:!busy,child:AlertDialog(title:Text('${widget.node['title']} · তথ্য যোগ'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    TextField(maxLength:100,decoration:const InputDecoration(labelText:'নাম'),onChanged:(v)=>name=v),
    TextField(keyboardType:TextInputType.phone,maxLength:30,decoration:const InputDecoration(labelText:'প্রকাশের ফোন'),onChanged:(v)=>phone=v),
    Builder(builder:(_){final a=widget.areas.values.toSet();return DropdownButton<String>(isExpanded:true,hint:const Text('সেবার ইউনিয়ন'),value:a.contains(area)?area:null,items:[for(final x in a)DropdownMenuItem(value:x,child:Text(x))],onChanged:(v)=>setState(()=>area=v??''));}),
    for(final f in _fields(widget.node))if(_strings(f['options']).isEmpty)TextField(maxLength:120,decoration:InputDecoration(labelText:f['label']),onChanged:(v)=>values[f['key']]=v)
    else DropdownButton<String>(isExpanded:true,hint:Text(f['label']),value:values[f['key']],items:[for(final v in _strings(f['options']))DropdownMenuItem(value:v,child:Text(v))],onChanged:(v)=>setState(()=>values[f['key']]=v??'')),
    CheckboxListTile(contentPadding:EdgeInsets.zero,title:const Text('নাম, নম্বর ও দেওয়া তথ্য প্রকাশে সংশ্লিষ্ট ব্যক্তির সম্মতি আছে'),value:consent,onChanged:(v)=>setState(()=>consent=v??false)),
    if(error.isNotEmpty)Text(error)
  ])),actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(c),child:const Text('ফিরুন')),FilledButton(onPressed:busy?null:submit,child:Text(busy?'জমা হচ্ছে…':'জমা দিন'))]));
}

/// Home uses the same published MySQL menu IDs as Screen 04.
class DirectoryHomeLinks extends StatefulWidget {
  const DirectoryHomeLinks({super.key,required this.legacy,required this.onAll});
  final WidgetBuilder legacy;
  final VoidCallback onAll;
  @override State<DirectoryHomeLinks> createState()=>_HomeLinks();
}
class _HomeLinks extends State<DirectoryHomeLinks>{
  late var feed=_feed(this,_catalog);
  @override Widget build(BuildContext c)=>StreamBuilder<_Catalog>(stream:feed,builder:(c,s){
    if(s.hasError)return _retry(()=>setState(()=>feed=_feed(this,_catalog)));
    if(!s.hasData)return const LinearProgressIndicator(minHeight:2);
    final tree=s.data!.nodes;
    final all=tree.entries.toList()..sort((a,b){final k=(a.value['order'] as int).compareTo(b.value['order'] as int);return k==0?a.key.compareTo(b.key):k;});
    final pinned=all.where((e)=>e.value['home']==true);
    final items=(pinned.isEmpty?all.where((e)=>e.value['parent']==''):pinned).take(8);
    return Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const Expanded(child:Text('দ্রুত সেবা',style:TextStyle(fontWeight:FontWeight.bold,fontSize:18))),TextButton(onPressed:widget.onAll,child:const Text('সব মেনু'))]),
      Wrap(spacing:8,runSpacing:8,children:[for(final e in items)ActionChip(avatar:_MenuIcon(key:ValueKey('${e.key}-${e.value['icon']}'),id:e.key,version:e.value['icon'] as int,hasIcon:e.value['hasIcon']==true),label:Text(e.value['title']),onPressed:()=>Get.to(()=>ServiceMenuScreen(menuId:e.key),preventDuplicates:false))])
    ])));
  });
}

class _LegacyMenuScreen extends StatelessWidget {
  const _LegacyMenuScreen({super.key});

  // --- Modern Color Palette ---
  static const blue = Color(0xFF1959E8);
  static const blueDark = Color(0xFF0F2D6B);
  static const navy = Color(0xFF0F1E36);
  static const muted = Color(0xFF64748B);
  static const bg = Color(0xFFF4F7FB);
  static const border = Color(0xFFE2E8F0);

  static const accents = [
    Color(0xFF1959E8), // Royal Blue
    Color(0xFF0D9488), // Teal
    Color(0xFFD97706), // Amber
    Color(0xFF7C3AED), // Violet
    Color(0xFFE11D48), // Rose
    Color(0xFF0284C7), // Sky Blue
    Color(0xFFEA580C), // Orange
    Color(0xFF4F46E5), // Indigo
  ];

  // --- Cached Base Font Styles for 120fps Smooth Scrolling ---
  static final Map<FontWeight, TextStyle> _baseFonts = {
    FontWeight.w400: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w400),
    FontWeight.w500: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w500),
    FontWeight.w600: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
    FontWeight.w700: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700),
  };

  static TextStyle text(
      double size, {
        Color color = navy,
        FontWeight weight = FontWeight.w500,
        double height = 1.38,
      }) {
    final base = _baseFonts[weight] ?? _baseFonts[FontWeight.w500]!;
    return base.copyWith(
      fontSize: size,
      color: color,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final contentWidth = screenWidth > 640 ? 640.0 : screenWidth;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
    final crossAxisCount = largeText ? 1 : (contentWidth >= 520 ? 3 : 2);

    return GetBuilder<MenuController>(
      init: MenuController(),
      builder: (c) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: bg,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: bg,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              titleSpacing: 18,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0x1A1959E8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.grid_view_rounded,
                      color: blue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'সব সেবা ও মেনু',
                    style: text(22, weight: FontWeight.w700),
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 18),
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(
                      side: BorderSide(color: border),
                    ),
                    child: IconButton(
                      tooltip: 'নোটিফিকেশন',
                      onPressed: c.openNotifications,
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: navy,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: CustomScrollView(
                  key: const PageStorageKey('dimla_menu_scroll'),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  cacheExtent: 600,
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    // --- Top Static Content ---
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const RepaintBoundary(
                              child: _DirectoryBanner(),
                            ),
                            const SizedBox(height: 16),
                            RepaintBoundary(
                              child: _SearchBox(controller: c),
                            ),
                            const SizedBox(height: 16),
                            RepaintBoundary(
                              child: _ShortcutsDock(controller: c),
                            ),
                            const SizedBox(height: 24),
                            _SectionHeader(controller: c),
                          ],
                        ),
                      ),
                    ),

                    // --- Reactive Sliver Grid / Empty State ---
                    Obx(() {
                      final items = c.filteredCategories;

                      if (items.isEmpty) {
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 36),
                          sliver: SliverToBoxAdapter(
                            child: _EmptyState(onReset: c.clearSearch),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 36),
                        sliver: SliverGrid.builder(
                          itemCount: items.length,
                          gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: 144,
                          ),
                          itemBuilder: (context, index) {
                            final category = items[index];
                            final accent = accents[index % accents.length];

                            return RepaintBoundary(
                              child: _CategoryCard(
                                category: category,
                                accent: accent,
                                onTap: () => c.openCategory(category),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- 1. Directory Top Banner (Const & Isolated) ---
class _DirectoryBanner extends StatelessWidget {
  const _DirectoryBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _LegacyMenuScreen.blueDark,
            _LegacyMenuScreen.blue,
            Color(0xFF088395),
          ],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -25,
            top: -25,
            child: SizedBox(
              width: 110,
              height: 110,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x14FFFFFF),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x29FFFFFF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'ডিমলা সার্ভিস ডিরেক্টরি',
                          style: _LegacyMenuScreen.text(
                            11,
                            color: Colors.white,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'প্রয়োজনীয় সব সেবা,\nএখন হাতের মুঠোয়।',
                        style: _LegacyMenuScreen.text(
                          21,
                          color: Colors.white,
                          weight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'যেকোনো ক্যাটাগরি বেছে নিয়ে বিস্তারিত তথ্য ও যোগাযোগ দেখুন।',
                        style: _LegacyMenuScreen.text(
                          12.5,
                          color: const Color(0xFFDCEBFF),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0x24FFFFFF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0x33FFFFFF),
                    ),
                  ),
                  child: const Icon(
                    Icons.apps_rounded,
                    color: Colors.white,
                    size: 34,
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

// --- 2. Smooth Search Box (Only Suffix Icon Rebuilds) ---
class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller});

  final MenuController controller;

  static final _defaultBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: const BorderSide(color: _LegacyMenuScreen.border),
  );

  static final _focusedBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: const BorderSide(color: _LegacyMenuScreen.blue, width: 1.5),
  );

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller.searchInput,
      onChanged: (value) => controller.query.value = value,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      cursorColor: _LegacyMenuScreen.blue,
      style: _LegacyMenuScreen.text(14.5, weight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: 'সেবার বিভাগ খুঁজুন (যেমন: ডাক্তার, অটো, দোকান)...',
        hintStyle: _LegacyMenuScreen.text(
          13.5,
          color: _LegacyMenuScreen.muted,
          weight: FontWeight.w400,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 12, right: 8),
          child: Icon(
            Icons.search_rounded,
            color: _LegacyMenuScreen.blue,
            size: 23,
          ),
        ),
        suffixIcon: Obx(() {
          if (controller.query.value.isEmpty) {
            return const SizedBox.shrink();
          }
          return IconButton(
            tooltip: 'Search মুছুন',
            onPressed: controller.clearSearch,
            icon: const Icon(
              Icons.close_rounded,
              color: _LegacyMenuScreen.muted,
              size: 20,
            ),
          );
        }),
        border: _defaultBorder,
        enabledBorder: _defaultBorder,
        focusedBorder: _focusedBorder,
      ),
    );
  }
}

// --- 3. Lightweight Quick Utility Dock (No IntrinsicHeight) ---
class _ShortcutsDock extends StatelessWidget {
  const _ShortcutsDock({required this.controller});

  final MenuController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _LegacyMenuScreen.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ShortcutItem(
              title: 'সেভ করা',
              icon: Icons.bookmark_rounded,
              color: const Color(0xFF7C3AED),
              onTap: controller.openSaved,
            ),
          ),
          Container(width: 1, height: 42, color: _LegacyMenuScreen.border),
          Expanded(
            child: _ShortcutItem(
              title: 'সেটিংস',
              icon: Icons.tune_rounded,
              color: _LegacyMenuScreen.blue,
              onTap: controller.openSettings,
            ),
          ),
          Container(width: 1, height: 42, color: _LegacyMenuScreen.border),
          Expanded(
            child: _ShortcutItem(
              title: 'সাহায্য',
              icon: Icons.support_agent_rounded,
              color: const Color(0xFF0D9488),
              onTap: controller.openHelp,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutItem extends StatelessWidget {
  const _ShortcutItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 7),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _LegacyMenuScreen.text(12.5, weight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 4. Section Header ---
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.controller});

  final MenuController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSearching = controller.query.value.trim().isNotEmpty;
      final count = controller.filteredCategories.length;

      return Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: _LegacyMenuScreen.blue,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              isSearching ? 'খোঁজার ফলাফল' : 'সেবার বিভাগসমূহ',
              style: _LegacyMenuScreen.text(19, weight: FontWeight.w700),
            ),
          ),
          if (isSearching)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: controller.clearSearch,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    'রিসেট',
                    style: _LegacyMenuScreen.text(
                      12.5,
                      color: const Color(0xFFE11D48),
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0x1A1959E8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$countটি বিভাগ',
              style: _LegacyMenuScreen.text(
                12,
                color: _LegacyMenuScreen.blue,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    });
  }
}

// --- 5. High-Performance Bento Category Card ---
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.accent,
    required this.onTap,
  });

  final MenuCategory category;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: _LegacyMenuScreen.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: accent.withValues(alpha: 0.1),
        highlightColor: accent.withValues(alpha: 0.04),
        child: Stack(
          children: [
            // Subtle Watermark Icon
            Positioned(
              right: -12,
              bottom: -12,
              child: Icon(
                category.icon,
                size: 72,
                color: accent.withValues(alpha: 0.05),
              ),
            ),
            // Top Accent Line Indicator
            Positioned(
              top: 0,
              left: 20,
              right: 20,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          category.icon,
                          color: accent,
                          size: 24,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          shape: BoxShape.circle,
                          border: Border.all(color: _LegacyMenuScreen.border),
                        ),
                        child: Icon(
                          Icons.arrow_outward_rounded,
                          color: accent,
                          size: 15,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _LegacyMenuScreen.text(
                          15,
                          weight: FontWeight.w700,
                          height: 1.22,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'তালিকা দেখুন',
                        style: _LegacyMenuScreen.text(
                          11.5,
                          color: _LegacyMenuScreen.muted,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ],
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

// --- 6. Empty Search State ---
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _LegacyMenuScreen.border),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0x141959E8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 30,
              color: _LegacyMenuScreen.blue,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'কোনো বিভাগ পাওয়া যায়নি',
            style: _LegacyMenuScreen.text(18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'অন্য কোনো নাম লিখে খুঁজুন অথবা সবগুলো বিভাগ দেখুন।',
            textAlign: TextAlign.center,
            style: _LegacyMenuScreen.text(13.5, color: _LegacyMenuScreen.muted),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onReset,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0x1A1959E8),
              foregroundColor: _LegacyMenuScreen.blue,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              'সব বিভাগ দেখুন',
              style: _LegacyMenuScreen.text(
                13.5,
                color: _LegacyMenuScreen.blue,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}