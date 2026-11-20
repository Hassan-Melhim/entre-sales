import 'dart:js_interop';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

import '../../../core/app_config.dart';
import '../../../domain/models/store_logos.dart';
import '../../../domain/repositories/logo_repository.dart';

/// Reads the logos from the "Logos & Icons" storage bucket: as a signed-in
/// user (allowed by migration 20261106120000), or else from the bucket's
/// public address if it is a public bucket.
class SupabaseLogoRepository implements LogoRepository {
  final SupabaseClient _db;
  SupabaseLogoRepository(this._db);

  @override
  Future<StoreLogos> logos() async {
    final problems = <String>[];
    final files = await Future.wait(
        [LogoFiles.corner, LogoFiles.footer, LogoFiles.kisses].map((path) => _load(path, problems)));
    return StoreLogos(corner: files[0], footer: files[1], kisses: files[2], problems: problems);
  }

  Future<LogoImage?> _load(String path, List<String> problems) async {
    final bucket = _db.storage.from(LogoFiles.bucket);
    Uint8List? bytes;
    Object? signedInError;
    try {
      bytes = await bucket.download(path);
    } catch (e) {
      signedInError = e;
      try {
        bytes = await _fetch(bucket.getPublicUrl(path));
      } catch (_) {
        // Report the signed-in error: it says more (not found / not allowed).
      }
    }
    if (bytes == null || bytes.isEmpty) {
      problems.add('$path: ${_explain(signedInError)}');
      return null;
    }
    return LogoImage(bytes, isSvg: path.toLowerCase().endsWith('.svg') || _looksLikeSvg(bytes));
  }

  static Future<Uint8List> _fetch(String url) async {
    final response = await web.window.fetch(url.toJS).toDart;
    if (!response.ok) throw StateError('HTTP ${response.status}');
    final buffer = await response.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }

  static String _explain(Object? e) {
    if (e is StorageException) {
      final code = e.statusCode ?? '';
      if (code == '404' || e.message.toLowerCase().contains('not found')) {
        return 'not found. Check the file and bucket names (bucket "${LogoFiles.bucket}").';
      }
      if (code == '400' || code == '403' || e.message.toLowerCase().contains('policy')) {
        return 'not allowed. Run supabase/migrations/20261106120000_import_and_logos.sql in the SQL Editor.';
      }
      return e.message;
    }
    return '$e';
  }

  static bool _looksLikeSvg(Uint8List b) {
    final head = String.fromCharCodes(b.take(200)).trimLeft().toLowerCase();
    return head.startsWith('<svg') || (head.startsWith('<?xml') && head.contains('<svg'));
  }
}
