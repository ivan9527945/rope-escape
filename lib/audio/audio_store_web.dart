import 'dart:js_interop';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Wraps the rendered WAVs in blob URLs; nothing touches the file system.
Future<Map<String, Source>> storeAudio(Map<String, Uint8List> rendered) async {
  final out = <String, Source>{};
  for (final e in rendered.entries) {
    final blob = web.Blob(
      [e.value.toJS].toJS,
      web.BlobPropertyBag(type: 'audio/wav'),
    );
    out[e.key] = UrlSource(
      web.URL.createObjectURL(blob),
      mimeType: 'audio/wav',
    );
  }
  return out;
}
