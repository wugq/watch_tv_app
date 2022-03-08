import 'package:crypto/crypto.dart';
import 'dart:convert';

class CheckSum {
  static String sha1StringOf(String text) {
    var bytes = utf8.encode(text);
    var digest = sha1.convert(bytes);
    return digest.toString();
  }
}
