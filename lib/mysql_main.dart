import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'business/business_store.dart';
import 'screens/15_business_dashboard/business_dashboard_screen.dart';

typedef J = Map<String,dynamic>;
String randomId(int n) {final r=Random.secure();return List.generate(n,(_)=>r.nextInt(256).toRadixString(16).padLeft(2,'0')).join();}
int numId(dynamic v)=>int.tryParse('$v')??0;
int minor(dynamic v)=>((double.tryParse('$v')??0)*100).round();
String taka(int n)=>'৳${(n/100).toStringAsFixed(2)}';
const base=String.fromEnvironment('DIMLA_API',defaultValue:'http://10.0.2.2/smart_dimla_admin/');
Uri apiUri(String file,Map<String,String> params)=>Uri.parse(base).resolve(file).replace(queryParameters:params);
void main(){WidgetsFlutterBinding.ensureInitialized();runApp(GetMaterialApp(title:'Smart Dimla',debugShowCheckedModeBanner:false,theme:ThemeData(colorSchemeSeed:const Color(0xff176a53)),home:const Portal()));}
class Portal extends StatefulWidget{const Portal({super.key});@override State<Portal> createState()=>_Portal();}
class _Portal extends State<Portal> with WidgetsBindingObserver{
  final prefs=SharedPreferencesAsync(),client=HttpClient()..connectionTimeout=const Duration(seconds:8);
  String token='',error='',message=''; int tab=0,area=0,menu=0,cat=0,limit=50,epoch=0;
  bool loading=false,posting=false,front=true,more=false;
  J settings={}; List<J> shelves=[],shelfItems=[]; int shelf=0; bool opted=false;
  List<J> menus=[],areas=[],entries=[],items=[],zones=[],categories=[],orders=[];
  Map<String,dynamic> cart={};J? pending;
  final name=TextEditingController(),phone=TextEditingController(),address=TextEditingController();
  Timer? timer; final age=Stopwatch();String session='';int recorded=0;
  Future<void> usageChain=Future.value();
  List<J> list(dynamic v)=>(v as List).cast<J>();
  Future<J> req(String file,String action,{Map<String,String> args=const{},J? body})async{
    final u=apiUri(file,{'a':action,...args});
    if(const bool.fromEnvironment('dart.vm.product') && u.scheme!='https')throw StateError('Release API-তে HTTPS প্রয়োজন।');
    final r=await client.openUrl(body==null?'GET':'POST',u).timeout(const Duration(seconds:10));
    if(file=='mobile.php')r.headers.set('X-Device-Token',token);
    if(body!=null){r.headers.contentType=ContentType.json;r.write(jsonEncode(body));}
    r.followRedirects=false;final res=await r.close().timeout(const Duration(seconds:12));
    final text=await utf8.decoder.bind(res).join().timeout(const Duration(seconds:12));
    final obj=jsonDecode(text) as J;if(res.statusCode==400||res.statusCode==409)throw ApiDenied((obj['error']??'ফর্মটি দেখুন').toString());if(res.statusCode!=200)throw Exception(obj['error']??'HTTP ${res.statusCode}');return obj;
  }
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);boot();}
  Future<void> boot()async{try{
    opted=await prefs.getBool('sd.usageAllowed')??false;
    token=await prefs.getString('sd.token')??randomId(32);await prefs.setString('sd.token',token);
    cart=jsonDecode(await prefs.getString('sd.cart')??'{}') as J;
    pending=jsonDecode(await prefs.getString('sd.pending')??'null') as J?;
    if(!mounted)return;
    front=WidgetsBinding.instance.lifecycleState==AppLifecycleState.resumed;
    if(front)startClock();refresh();
    timer=Timer.periodic(const Duration(seconds:10),(_){if(front){record();refresh();}});
  }catch(e){if(mounted)setState(()=>error='$e');}}
  void startClock(){if(!opted||age.isRunning)return;session=randomId(16);recorded=0;age.reset();age.start();}
  void record(){if(!opted||session.isEmpty)return;final now=DateTime.now().toUtc().add(const Duration(hours:6));
  final end=age.elapsed.inSeconds,delta=end-recorded;recorded=end;
  final sid=session;final day=now.toIso8601String().substring(0,10);
  final midnight=DateTime.utc(now.year,now.month,now.day);
  final today=min(delta,now.difference(midnight).inSeconds);
  final yesterday=midnight.subtract(const Duration(days:1)).toIso8601String().substring(0,10);
  usageChain=usageChain.then((_)async{
    final queue=jsonDecode(await prefs.getString('sd.times')??'{}') as J;
    void add(String date,int seconds){final k='$date/$sid';queue[k]=numId(queue[k])+seconds;}
    if(delta>today)add(yesterday,delta-today);add(day,today);
    queue.removeWhere((k,v)=>now.difference(DateTime.parse('${k.split('/').first}T00:00:00Z')).inDays>30);
    await prefs.setString('sd.times',jsonEncode(queue));
  }).catchError((Object _){});flushTimes();}
  bool sending=false;
  Future<void> flushTimes()async{if(sending)return;sending=true;try{
    await usageChain;
    final q=jsonDecode(await prefs.getString('sd.times')??'{}') as J;
    for(final e in q.entries){final bits=e.key.split('/');
    // Server accepts cumulative totals; keep today's totals locally for future increments.
    if(!opted)return;if(lastSent[e.key]==e.value)continue;
    await req('mobile.php','usage',body:{'day':bits[0],'session':bits[1],'seconds':e.value});
    lastSent[e.key]=numId(e.value);
    }
  }catch(_){}finally{sending=false;}}
  final lastSent=<String,int>{};
  @override void didChangeAppLifecycleState(AppLifecycleState s){
    front=s==AppLifecycleState.resumed;if(front){if(token.isNotEmpty){startClock();refresh();}}
    else{if(age.isRunning){age.stop();record();}if(s!=AppLifecycleState.inactive&&Get.isRegistered<BusinessStore>()){final b=Get.find<BusinessStore>();if(!b.external)b.lock();}}
  }
  Future<void> refresh({bool force=false})async{
    if(!mounted||token.isEmpty||tab==2||(!force&&loading))return;
    final version=++epoch,t=tab,m=menu,z=area;setState(()=>loading=true);
    try{
      final directory=await req('api.php','catalog');final ns=list(directory['menus']),az=list(directory['areas']);
      J? shop;List<J> ls=[],os=[];bool next=false;
      if(t==0&&m!=0&&ns.any((n)=>numId(n['id'])==m&&n['kind']=='list')){
        do{final r=await req('api.php','list',args:{'menu':'$m','area':'$z','after':ls.isEmpty?'0':'${ls.last['id']}'});
        final chunk=list(r['items']);ls.addAll(chunk);next=r['more']==true&&chunk.isNotEmpty;
        }while(next&&ls.length<limit&&version==epoch);
      }else if(t==1||t==4){shop=await req('mobile.php','store',args:{'area':'$z'});}
      else if(t==3){os=list((await req('mobile.php','orders'))['items']);}
      if(!mounted||version!=epoch)return;
      setState((){error='';menus=ns;areas=az;entries=ls;more=next;orders=os;
      if(shop!=null){settings=shop['settings'] as J;shelves=list(shop['shelves']);shelfItems=list(shop['shelfItems']);if(!shelves.any((e)=>numId(e['id'])==shelf))shelf=0;items=list(shop['items']);zones=list(shop['zones']);categories=list(shop['categories']);}
      if(m!=0&&!ns.any((n)=>numId(n['id'])==m))menu=0;
      if(!az.any((a)=>numId(a['id'])==area))area=0;
      if(!categories.any((c)=>numId(c['id'])==cat))cat=0;});
    }catch(e){if(mounted&&version==epoch)setState(()=>error='$e');}
    finally{if(mounted&&version==epoch)setState(()=>loading=false);}
  }
  void go(int t){setState((){epoch++;tab=t;loading=false;error='';entries=[];more=false;message='';});refresh(force:true);}
  Future<void> change(J p,int d)async{
    if(posting||pending!=null)return;final k='${p['pack']}',qty=numId(cart[k]?['qty'])+d;
    if(qty>min(99,numId(p['stock']))&&d>0)return;
    setState((){if(qty<=0){cart.remove(k);}else{cart[k]={'qty':qty,'priceMinor':minor(p['price']),'name':p['name'],'label':p['label']};}});
    await prefs.setString('sd.cart',jsonEncode(cart));
  }
  Future<void> place()async{
    if(posting)return;setState(()=>posting=true);
    try{if(pending==null){
      final zone=zones.where((z)=>numId(z['id'])==area).firstOrNull;
      if(zone==null||cart.isEmpty||name.text.trim().isEmpty||address.text.trim().isEmpty||!RegExp(r'^01[3-9][0-9]{8}$').hasMatch(phone.text.trim()))throw Exception('ইউনিয়ন, নাম, ফোন, ঠিকানা ও কার্ট দেখুন।');
      pending={'key':randomId(16),'name':name.text.trim(),'phone':phone.text.trim(),'address':address.text.trim(),'area':area,'feeMinor':minor(zone['fee']),'cart':jsonDecode(jsonEncode(cart))};
    }await prefs.setString('sd.pending',jsonEncode(pending));
    final result=await req('mobile.php','place',body:pending);
    await prefs.setString('sd.cart','{}');await prefs.remove('sd.pending');cart={};pending=null;
    if(mounted){go(3);setState(()=>message='অর্ডার #${result['id']} জমা হয়েছে।');}
    }catch(e){if(e is ApiDenied){pending=null;await prefs.remove('sd.pending');}if(mounted)setState(()=>message='$e');}
    finally{if(mounted)setState(()=>posting=false);}
  }
  Widget select(String title,int value,List<J> options,void Function(int) changed){
    return DropdownButtonFormField<int>(key:ValueKey('$title/$value'),initialValue:options.any((e)=>numId(e['id'])==value)?value:0,
        decoration:InputDecoration(labelText:title),items:[const DropdownMenuItem(value:0,child:Text('সব')),
          for(final o in options)DropdownMenuItem(value:numId(o['id']),child:Text('${o['name']}'))],onChanged:(v){if(v!=null)changed(v);});
  }
  Future<void> suggest(J m)async{
    if(area==0){setState(()=>message='আগে আপনার ইউনিয়ন নির্বাচন করুন।');return;}
    final nc=TextEditingController(),pc=TextEditingController();bool consent=false;
    final extras={for(final f in m['fields'] as List) f['key'] as String:TextEditingController()};
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,update)=>AlertDialog(
        title:Text('${m['title']} · তথ্য প্রস্তাব'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:nc,decoration:const InputDecoration(labelText:'নাম')),TextField(controller:pc,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'প্রকাশের ফোন')),
      for(final f in m['fields']) TextField(controller:extras[f['key']],decoration:InputDecoration(labelText:'${f['label']}',helperText:(f['options'] as List).join(' / '))),
      CheckboxListTile(value:consent,title:const Text('নাম ও ফোন প্রকাশে সম্মতি আছে'),onChanged:(v)=>update(()=>consent=v==true))])),
        actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('বন্ধ')),FilledButton(onPressed:consent?()=>Navigator.pop(c,true):null,child:const Text('জমা দিন'))])));
    if(ok==true){try{await req('api.php','submit',body:{'menu':numId(m['id']),'areas':[area],'name':nc.text.trim(),'phone':pc.text.trim(),'consent':true,'extra':{for(final f in extras.entries)f.key:f.value.text.trim()}});if(mounted)setState(()=>message='পর্যালোচনার জন্য জমা হয়েছে।');}catch(e){if(mounted)setState(()=>message='$e');}}
  }
  Widget pic(String url)=>SizedBox(width:44,height:44,child:Image.network(url,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.image_outlined)));
  @override Widget build(BuildContext context){
    final current=menus.where((m)=>numId(m['id'])==menu).firstOrNull;
    final zone=zones.where((z)=>numId(z['id'])==area).firstOrNull;
    final sum=cart.values.fold<int>(0,(v,c)=>v+numId(c['qty'])*numId(c['priceMinor']));
    return Scaffold(appBar:AppBar(title:const Text('Smart Dimla'),actions:[IconButton(tooltip:'ব্যবহারের তথ্য শেয়ার',icon:Icon(opted?Icons.insights:Icons.insights_outlined),onPressed:()async{
      final choice=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('ব্যবহারের সময় শেয়ার'),content:const Text('চালু করলে একটি এলোমেলো ইনস্টলেশন কোড, সেশন, তারিখ ও অ্যাপ সামনে থাকার সময় Smart Dimla প্যানেলে যাবে। বন্ধ রেখেও সব সেবা ব্যবহার করা যায়।'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('বন্ধ রাখুন')),TextButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('চালু করুন'))]));
      if(!mounted||choice==null)return;
      if(!choice){age.stop();session='';}setState(()=>opted=choice);await prefs.setBool('sd.usageAllowed',choice);
      if(choice&&front)startClock();
    }),IconButton(onPressed:()=>refresh(force:true),icon:const Icon(Icons.refresh)),IconButton(onPressed:()=>go(4),icon:Badge(label:Text('${cart.length}'),child:const Icon(Icons.shopping_cart_outlined)))]),
        body:tab==2?const BusinessDashboardScreen():ListView(padding:const EdgeInsets.all(16),children:[
          if(loading)const LinearProgressIndicator(),if(error.isNotEmpty)Text('লোড হয়নি: $error'),if(message.isNotEmpty)Text(message),
          if(tab!=3)select('ইউনিয়ন',area,areas,(v){setState((){area=v;entries=[];items=[];limit=50;});refresh(force:true);}),
          if(tab==0)...[
            if(current!=null&&current['kind']=='list'&&numId(current['accept'])==1)TextButton(onPressed:()=>suggest(current),child:const Text('＋ তথ্য জমা দিন')),
            if(current!=null)TextButton(onPressed:(){setState((){menu=numId(current['parent']);limit=50;entries=[];});refresh(force:true);},child:Text('← ${current['title']}')),
            for(final m in menus.where((m)=>numId(m['parent'])==menu))Card(child:ListTile(leading:numId(m['hasIcon'])==1?pic(apiUri('api.php',{'a':'icon','id':'${m['id']}','v':'${m['rev']}'}).toString()):const Icon(Icons.folder_open),title:Text('${m['title']}'),trailing:const Icon(Icons.chevron_right),onTap:(){setState((){menu=numId(m['id']);limit=50;entries=[];});refresh(force:true);})),
            for(final e in entries)Card(child:ListTile(leading:numId(e['hasPhoto'])==1?pic(apiUri('api.php',{'a':'photo','id':'${e['id']}','v':'${e['rev']}'}).toString()):null,title:Text('${e['name']}'),subtitle:Text([e['phone'],for(final f in (e['profileFields']??[])) '${f['label']}: ${f['value']}',for(final f in (current?['fields']??[])) if((e['extra']??{})[f['key']]!=null) '${f['label']}: ${e['extra'][f['key']]}'].join('\n')),trailing:IconButton(icon:const Icon(Icons.call),onPressed:()=>launchUrl(Uri(scheme:'tel',path:'${e['phone']}'))))),
            if(more)TextButton(onPressed:(){limit+=50;refresh(force:true);},child:const Text('আরও দেখুন')),
            if(!loading&&error.isEmpty&&entries.isEmpty&&!menus.any((m)=>numId(m['parent'])==menu))const Text('এখানে প্রকাশিত তথ্য নেই।')],
          if(tab==1)...[if(shelves.isNotEmpty)Wrap(spacing:8,children:[ChoiceChip(label:const Text('সব তাক'),selected:shelf==0,onSelected:(_)=>setState(()=>shelf=0)),for(final h in shelves)ChoiceChip(label:Text('${h['title']}'),selected:shelf==numId(h['id']),onSelected:(_)=>setState(()=>shelf=numId(h['id']))) ]),select('ক্যাটাগরি',cat,categories,(v)=>setState(()=>cat=v)),
            for(final c in categories.where((e)=>cat==0||numId(e['id'])==cat))
              if(items.any((p)=>numId(p['category_id'])==numId(c['id'])&&(shelf==0||shelfItems.any((x)=>numId(x['shelf_id'])==shelf&&numId(x['product_id'])==numId(p['product'])))))...[
                Padding(padding:const EdgeInsets.only(top:16),child:Text('${c['name']}',style:Theme.of(context).textTheme.titleLarge)),
                for(final p in items.where((p)=>numId(p['category_id'])==numId(c['id'])&&(shelf==0||shelfItems.any((x)=>numId(x['shelf_id'])==shelf&&numId(x['product_id'])==numId(p['product'])))))Card(child:ListTile(leading:'${p['photo']??''}'.isEmpty?null:pic('${p['photo']}'),title:Text('${p['name']} · ${p['label']}'),subtitle:Text([if(p['regular_price']!=null)'নিয়মিত ৳${p['regular_price']}','৳${p['price']} • স্টক ${p['stock']}'].join(' · ')),trailing:IconButton(icon:const Icon(Icons.add_shopping_cart),onPressed:numId(p['stock'])>0?()=>change(p,1):null)))],
            if(items.isEmpty&&!loading)const Text('প্রকাশিত পণ্য নেই।')],
          if(tab==3)...[const Text('আমার অর্ডার'),if(orders.isEmpty&&!loading)const Text('কোনো অর্ডার নেই।'),for(final o in orders)ListTile(onTap:()async{try{final d=await req('mobile.php','detail',args:{'id':'${o['id']}'});if(!mounted)return;await showDialog<void>(context:this.context,builder:(ctx)=>AlertDialog(title:Text('অর্ডার #${o['id']}'),content:SingleChildScrollView(child:Text([for(final l in list(d['lines'])) '${l['title']} × ${l['qty']} • ৳${l['price']}', 'ডেলিভারি ৳${d['order']['delivery']}','সর্বমোট ৳${d['order']['total']}','${d['order']['area_name']} · ${d['order']['address']}'].join('\n'))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('বন্ধ'))]));}catch(e){if(mounted)setState(()=>error='$e');}},title:Text('অর্ডার #${o['id']} · ৳${o['total']}'),subtitle:Text('${o['created_at']} • ${o['status']}'))],
          if(tab==4)...[for(final e in cart.entries)ListTile(title:Text('${e.value['name']} · ${e.value['label']}'),subtitle:Text('${e.value['qty']} × ${taka(numId(e.value['priceMinor']))}'),trailing:IconButton(icon:const Icon(Icons.remove_circle_outline),onPressed:()async{if(posting||pending!=null)return;setState(()=>cart.remove(e.key));await prefs.setString('sd.cart',jsonEncode(cart));})),
            Text('পণ্য: ${taka(sum)} • ডেলিভারি: ${zone==null?"ইউনিয়ন বাছুন":taka(minor(zone['fee']))}'),
            Text('${settings['returns_text']??''}'),Text('স্টোর যোগাযোগ: ${settings['phone']??''}'),
            if(zone!=null)Text('সর্বমোট: ${taka(sum+minor(zone['fee']))}'),
            for(final pair in [(name,'নাম'),(phone,'মোবাইল'),(address,'পূর্ণ ঠিকানা')])TextField(controller:pair.$1,decoration:InputDecoration(labelText:pair.$2)),
            FilledButton(onPressed:posting||(cart.isEmpty&&pending==null)?null:place,child:Text(pending!=null?'একই অর্ডার আবার যাচাই করুন':'ক্যাশ অন ডেলিভারি · নিশ্চিত করুন'))]
        ]),bottomNavigationBar:NavigationBar(selectedIndex:tab==4?1:tab,onDestinationSelected:go,destinations:const [
          NavigationDestination(icon:Icon(Icons.home_outlined),label:'সেবা'),NavigationDestination(icon:Icon(Icons.storefront),label:'শপিং'),NavigationDestination(icon:Icon(Icons.book_outlined),label:'খাতা'),NavigationDestination(icon:Icon(Icons.receipt_long),label:'অর্ডার')]));
  }
  @override void dispose(){timer?.cancel();WidgetsBinding.instance.removeObserver(this);client.close(force:true);name.dispose();phone.dispose();address.dispose();super.dispose();}
}
class ApiDenied implements Exception{final String message;ApiDenied(this.message);@override String toString()=>message;}