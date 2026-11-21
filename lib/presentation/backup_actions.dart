import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dates.dart';
import '../data/export/export_file.dart';
import '../domain/repositories/settings_repository.dart';
import 'providers.dart';
import 'widgets/file_delivery.dart';

/// Downloads the backup file and records, for every device, when it was
/// made and by whom. Throws if the backup can't be made.
Future<void> downloadBackup(WidgetRef ref) async {
  final bytes = await ref.read(backupRepositoryProvider).exportBackup();
  await deliverExport(
      ExportFile('entre_sales_backup_${fileStamp(DateTime.now())}.json', Uint8List.fromList(bytes), ExportFile.json));
  final settings = ref.read(settingsRepositoryProvider);
  await settings.set(SharedSettingKeys.lastBackupAt, DateTime.now().toUtc().toIso8601String());
  await settings.set(SharedSettingKeys.lastBackupBy, ref.read(currentUserProvider).valueOrNull?.email);
  ref.invalidate(backupStatusProvider);
}
