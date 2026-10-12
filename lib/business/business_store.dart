import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart' as sql;

import 'book.dart';
export 'book.dart';

const backupAad = 'HelloDimla/business-backup/v1';

Future<SecretKey> passwordKey(
    String password,
    List<int> salt,
    ) => Pbkdf2(
  macAlgorithm: Hmac.sha256(),
  iterations: 210000,
  bits: 256,
).deriveKey(
  secretKey: SecretKey(utf8.encode(password)),
  nonce: salt,
);

Future<Uint8List> encryptBook(
    BookRow data,
    String password,
    ) async {
  need(
    password.length >= 8 && password.length <= 128,
    'Password ৮–১২৮ অক্ষরের দিন',
  );

  final salt = List<int>.generate(
    16,
        (_) => Random.secure().nextInt(256),
  );

  final box = await AesGcm.with256bits().encrypt(
    utf8.encode(jsonEncode(data)),
    secretKey: await passwordKey(password, salt),
    aad: utf8.encode(backupAad),
  );

  return Uint8List.fromList(utf8.encode(jsonEncode({
    'format': backupAad,
    'salt': base64Encode(salt),
    'nonce': base64Encode(box.nonce),
    'mac': base64Encode(box.mac.bytes),
    'cipher': base64Encode(box.cipherText),
  })));
}

Future<BookRow> decryptBook(
    Uint8List bytes,
    String password,
    ) async {
  need(
    bytes.length <= 20000000 && password.length <= 128,
    'Backup অনেক বড় বা password ভুল',
  );

  final envelope = Map<String, dynamic>.from(
    jsonDecode(utf8.decode(bytes)) as Map,
  );

  need(envelope['format'] == backupAad, 'এটি Hello Dimla backup নয়');

  final salt = base64Decode(envelope['salt']);
  final nonce = base64Decode(envelope['nonce']);
  final mac = base64Decode(envelope['mac']);
  final encrypted = base64Decode(envelope['cipher']);

  need(
    salt.length == 16 && nonce.length == 12 && mac.length == 16,
    'Backup format ভুল',
  );

  final plain = await AesGcm.with256bits().decrypt(
    SecretBox(encrypted, nonce: nonce, mac: Mac(mac)),
    secretKey: await passwordKey(password, salt),
    aad: utf8.encode(backupAad),
  );

  final data = Map<String, dynamic>.from(
    jsonDecode(utf8.decode(plain)) as Map,
  );

  Book(data).validate();
  return data;
}

class BusinessStore extends GetxService {
  static BusinessStore get instance =>
      Get.isRegistered<BusinessStore>()
          ? Get.find<BusinessStore>()
          : Get.put(BusinessStore(), permanent: true);

  final state = Book.empty().obs;
  final ready = false.obs;
  final busy = false.obs;
  final locked = false.obs;
  final error = ''.obs;

  sql.Database? _db;
  Future<void>? _opening;

  bool external = false;

  Book get book => state.value;

  Future<void> init() => _opening ??= _load();

  Future<void> _load() async {
    try {
      final directory = await sql.getDatabasesPath();

      _db = await sql.openDatabase(
        '$directory/hello_dimla_business_v1.db',
        version: 1,
        onConfigure: (database) async {
          await database.execute('PRAGMA synchronous = FULL');
        },
        onCreate: (database, version) => database.execute(
          'CREATE TABLE ledger (id INTEGER PRIMARY KEY, body TEXT NOT NULL)',
        ),
      );

      final rows = await _db!.query(
        'ledger',
        where: 'id = ?',
        whereArgs: [1],
      );

      if (rows.isNotEmpty) {
        final loaded = Book(
          Map<String, dynamic>.from(
            jsonDecode(rows.single['body'] as String) as Map,
          ),
        );

        loaded.validate();
        state.value = loaded;
      }

      locked.value = book.settings?['pin'] != null;
      error.value = '';
      ready.value = true;
    } catch (_) {
      error.value =
      'খাতা খোলা যায়নি। Data মুছবেন না; পুনরায় চেষ্টা করুন।';
      _opening = null;
    }
  }

  void guard() {
    need(ready.value && !locked.value, 'আগে খাতা unlock করুন');
    need(!busy.value, 'আগের কাজ শেষ হতে দিন');
  }

  Future<void> _write(Book next) async {
    final body = jsonEncode(next.data);

    await _db!.transaction((tx) {
      return tx.insert(
        'ledger',
        {'id': 1, 'body': body},
        conflictAlgorithm: sql.ConflictAlgorithm.replace,
      );
    });

    state.value = next;
  }

  Future<void> change(void Function(Book) action) async {
    guard();
    busy.value = true;

    try {
      final next = book.clone();
      action(next);
      await _write(next);
    } finally {
      busy.value = false;
    }
  }

  Future<void> restore(BookRow data) async {
    guard();
    busy.value = true;

    try {
      final next = Book(copyRow(data));
      next.validate();

      await _write(next);
      locked.value = next.settings?['pin'] != null;
    } finally {
      busy.value = false;
    }
  }

  void lock() {
    if (book.settings?['pin'] != null) {
      locked.value = true;
    }
  }

  Future<void> setPin(String pin) async {
    guard();
    need(book.settings != null, 'আগে ব্যবসা তৈরি করুন');
    need(RegExp(r'^\d{6}$').hasMatch(pin), '৬ সংখ্যার PIN দিন');

    busy.value = true;

    try {
      final salt = List<int>.generate(
        16,
            (_) => Random.secure().nextInt(256),
      );

      final hash = await Isolate.run(
            () async => (await passwordKey(pin, salt)).extractBytes(),
      );

      final next = book.clone();

      next.settings!['pin'] = {
        'salt': base64Encode(salt),
        'hash': base64Encode(hash),
      };

      next.settings!['attempts'] = 0;
      next.settings!['lockUntil'] = 0;

      await _write(next);
    } finally {
      busy.value = false;
    }
  }

  Future<void> removePin() => change((next) {
    next.settings!['pin'] = null;
  });

  Future<void> unlock(String pin) async {
    need(ready.value && !busy.value, 'অপেক্ষা করুন');

    final savedPin = book.settings?['pin'];

    if (savedPin == null) {
      locked.value = false;
      return;
    }

    need(
      DateTime.now().millisecondsSinceEpoch >=
          book.settings!['lockUntil'],
      'কিছুক্ষণ পরে চেষ্টা করুন',
    );

    busy.value = true;

    try {
      final salt = base64Decode(savedPin['salt']);

      final result = await Isolate.run(
            () async => (await passwordKey(pin, salt)).extractBytes(),
      );

      final expected = base64Decode(savedPin['hash']);

      var mismatch = result.length ^ expected.length;

      for (var i = 0; i < min(result.length, expected.length); i++) {
        mismatch |= result[i] ^ expected[i];
      }

      final next = book.clone();

      if (mismatch != 0) {
        final attempts = (next.settings!['attempts'] as int) + 1;

        next.settings!['attempts'] = attempts;
        next.settings!['lockUntil'] = attempts >= 5
            ? DateTime.now().millisecondsSinceEpoch + 60000
            : 0;

        await _write(next);

        throw const FormatException(
          'PIN সঠিক নয়; ৫ বার ভুল হলে ১ মিনিট অপেক্ষা',
        );
      }

      next.settings!['attempts'] = 0;
      next.settings!['lockUntil'] = 0;

      await _write(next);
      locked.value = false;
    } finally {
      busy.value = false;
    }
  }

  Future<Uint8List> backup(String password) async {
    guard();

    final snapshot = copyRow(book.data);
    return Isolate.run(() => encryptBook(snapshot, password));
  }

  Future<BookRow?> readBackup(String password) async {
    guard();
    external = true;

    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
      );

      if (picked == null) return null;

      need(
        picked.files.single.size <= 20000000,
        'Backup ২০ MB-এর বেশি নয়',
      );

      final path = picked.files.single.path;
      need(path != null, 'File খোলা যায়নি');

      final bytes = await File(path!).readAsBytes();

      return await Isolate.run(
            () => decryptBook(bytes, password),
      );
    } on SecretBoxAuthenticationError {
      throw const FormatException(
        'Password ভুল অথবা backup ক্ষতিগ্রস্ত',
      );
    } finally {
      external = false;
    }
  }

  Future<bool> saveBytes(
      String name,
      Uint8List bytes,
      ) async {
    guard();
    external = true;

    try {
      final path = await FilePicker.saveFile(
        dialogTitle: 'ফাইল সংরক্ষণ করুন',
        fileName: name,
        type: FileType.any,
        bytes: bytes,
      );

      return path != null;
    } finally {
      external = false;
    }
  }

  String csv(List<List<String>> rows) {
    final content = rows.map((row) {
      return row.map((value) {
        final safe = RegExp(r'^[=+@\-\t\r]').hasMatch(value)
            ? "'$value"
            : value;

        return '"${safe.replaceAll('"', '""')}"';
      }).join(',');
    }).join('\r\n');

    return '\uFEFF$content';
  }

  Future<Uint8List> pdfBytes(
      String title,
      List<List<String>> rows,
      ) async {
    need(rows.length <= 3000, 'বড় report-এর জন্য CSV ব্যবহার করুন');

    final document = pw.Document();

    // Flutter renders Bengali; the PDF contains those rendered pages.
    for (var start = 0; start < max(1, rows.length); start += 15) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 1240, 1754),
        Paint()..color = Colors.white,
      );

      var y = 55.0;

      void paint(
          String text,
          double size, {
            bool bold = false,
          }) {
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: Colors.black,
              fontSize: size,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 3,
          ellipsis: '…',
        )..layout(maxWidth: 1130);

        painter.paint(canvas, Offset(55, y));
        y += painter.height + 16;
        painter.dispose();
      }

      paint(
        '${book.settings?['name'] ?? 'Hello Dimla'} • $title',
        32,
        bold: true,
      );

      paint(
        'পৃষ্ঠা ${bn('${start ~/ 15 + 1}')} • ${bn(today())}',
        22,
      );

      for (final row in rows.skip(start).take(15)) {
        paint(row.join(' | '), 23);
      }

      final picture = recorder.endRecording();
      final image = await picture.toImage(1240, 1754);
      final bytes = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      image.dispose();
      picture.dispose();

      final png = pw.MemoryImage(bytes!.buffer.asUint8List());

      document.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(png, fit: pw.BoxFit.contain),
      ));
    }

    return document.save();
  }

  Future<void> shareBytes(
      BuildContext context,
      String name,
      Uint8List bytes,
      ) async {
    guard();

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$name');

    await file.writeAsBytes(bytes, flush: true);

    if (!context.mounted) return;

    final box = context.findRenderObject() as RenderBox?;

    external = true;

    try {
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ));
    } finally {
      external = false;
    }
  }

  Future<void> settingsEraseLedger() async {
    guard();
    busy.value = true;

    try {
      final path = _db!.path;

      await _db!.close();

      _db = null;
      _opening = null;
      ready.value = false;

      await sql.deleteDatabase(path);

      state.value = Book.empty();
      locked.value = false;

      await init();

      if (!ready.value) {
        throw StateError('খাতা আবার খুলতে app restart করুন।');
      }
    } finally {
      busy.value = false;
    }
  }
}