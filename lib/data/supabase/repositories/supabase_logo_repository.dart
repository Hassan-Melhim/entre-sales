import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_config.dart';
import '../../../domain/models/store_logos.dart';
import '../../../domain/repositories/logo_repository.dart';

/// Reads the logos from the "Logos & Icons" storage bucket
/// (signed-in users may read it: see migration 20261106120000).
class SupabaseLogoRepository implements LogoRepository {
  final SupabaseClient _db;
  SupabaseLogoRepository(this._db);

  @override
  Future<StoreLogos> logos() async {
    final files = await Future.wait([LogoFiles.corner, LogoFiles.footer, LogoFiles.kisses].map(_load));
    return StoreLogos(corner: files[0], footer: files[1], kisses: files[2]);
  }

  Future<LogoImage?> _load(String path) async {
    try {
      final Uint8List bytes = await _db.storage.from(LogoFiles.bucket).download(path);
      if (bytes.isEmpty) return null;
      return LogoImage(bytes, isSvg: path.toLowerCase().endsWith('.svg') || _looksLikeSvg(bytes));
    } catch (_) {
      return null; // missing file or no access: the PDF is made without it
    }
  }

  static bool _looksLikeSvg(Uint8List b) {
    final head = String.fromCharCodes(b.take(200)).trimLeft().toLowerCase();
    return head.startsWith('<svg') || (head.startsWith('<?xml') && head.contains('<svg'));
  }
}
