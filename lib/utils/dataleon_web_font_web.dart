import 'dart:convert';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<void> registerWebFont(String family, Uint8List bytes, int weight) async {
  try {
    final b64 = base64Encode(bytes);
    final css = "@font-face {"
        " font-family: '$family';"
        " src: url('data:font/truetype;base64,$b64') format('truetype');"
        " font-weight: $weight;"
        " }";
    final style = web.HTMLStyleElement();
    style.textContent = css;
    web.document.head?.append(style);
  } catch (_) {}
}
