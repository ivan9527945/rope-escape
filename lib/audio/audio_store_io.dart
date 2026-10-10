import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Writes the rendered WAVs to the temp directory and plays them as files.
Future<Map<String, Source>> storeAudio(Map<String, Uint8List> rendered) async {
  final dir = Directory('${(await getTemporaryDirectory()).path}/rope-audio');
  await dir.create(recursive: true);
  final out = <String, Source>{};
  for (final e in rendered.entries) {
    final f = File('${dir.path}/${e.key}.wav');
    await f.writeAsBytes(e.value, flush: true);
    out[e.key] = DeviceFileSource(f.path);
  }
  return out;
}
