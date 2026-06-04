import 'dart:convert';

import 'package:http/http.dart' as http;

/// Декодирует тело HTTP-ответа как UTF-8 (itch.io отдаёт emoji в UTF-8).
String decodeHttpResponseBody(http.Response response) {
  final contentType = response.headers['content-type']?.toLowerCase() ?? '';
  if (contentType.contains('charset=') &&
      !contentType.contains('charset=utf-8') &&
      !contentType.contains('charset=utf8')) {
    return response.body;
  }
  return utf8.decode(response.bodyBytes, allowMalformed: true);
}
