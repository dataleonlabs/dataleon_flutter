import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<Uint8List?> readCachedFont(String cacheKey) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/dataleon_font_$cacheKey');
    if (await file.exists()) return await file.readAsBytes();
  } catch (_) {}
  return null;
}

Future<void> writeCachedFont(String cacheKey, Uint8List bytes) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/dataleon_font_$cacheKey');
    await file.writeAsBytes(bytes);
  } catch (_) {}
}
