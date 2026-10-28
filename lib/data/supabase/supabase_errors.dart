import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/exceptions.dart';

/// Runs a Supabase call and turns its errors into the app's own exceptions.
Future<T> guard<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on PostgrestException catch (e) {
    throw translate(e);
  } on AuthException catch (_) {
    throw NotSignedInException();
  }
}

Object translate(PostgrestException e) {
  switch (e.code) {
    // Not enough stock (raised by the checkout function).
    case 'ES001':
      return InsufficientStockException(_problems(e.details));
    // Not signed in, or the session expired.
    case '42501':
    case 'PGRST301':
    case 'PGRST302':
      return NotSignedInException();
    // Unique name already used.
    case '23505':
      return DataException('That name is already used.');
    // Still used by products or sales.
    case '23503':
      return DataException('It is still used elsewhere (products or sales), so it cannot be deleted.');
    default:
      return DataException(e.message);
  }
}

List<String> _problems(Object? details) {
  try {
    return (jsonDecode('$details') as List).map((e) => '$e').toList();
  } catch (_) {
    return ['$details'];
  }
}
