import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Hands the finished file to the person: the system share sheet on a phone (save to Files, send to Telegram,
/// e-mail it to yourself), a download in a browser. Returns false when they closed the sheet without choosing.
/// A provider so tests can swap the platform call for a recording fake.
typedef BackupSharer = Future<bool> Function(Uint8List bytes, String fileName);

const xlsxMimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

final backupSharerProvider = Provider<BackupSharer>((ref) {
  return (bytes, fileName) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: xlsxMimeType, name: fileName)],
        fileNameOverrides: [fileName],
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  };
});
