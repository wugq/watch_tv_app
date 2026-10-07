import 'dart:convert';

import 'package:crypto/crypto.dart';

String sha1Of(String text) => sha1.convert(utf8.encode(text)).toString();
