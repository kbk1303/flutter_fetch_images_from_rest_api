import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum HttpClientType { secure, standard }

class HttpClientService {
  late final String ipAddress;
  late final int port;
  late final HttpClient _httpClient;
  late bool initialized = false;
  HttpClient get httpClient => _httpClient;

  HttpClientService();

  Future<void> initialiseHttpClient(HttpClientType httpClientType) async {
    try {
      switch (httpClientType) {
        case HttpClientType.secure:
          ByteData ca = await rootBundle.load('assets/rootCA.pem');
          ByteData cert =
              await rootBundle.load('assets/fluttertest-client+4-client.pem');
          ByteData key = await rootBundle
              .load('assets/fluttertest-client+4-client-key.pem');

          List<int> caBytes =
              ca.buffer.asUint8List(ca.offsetInBytes, ca.lengthInBytes);

          List<int> certBytes =
              cert.buffer.asUint8List(cert.offsetInBytes, cert.lengthInBytes);

          List<int> keyBytes =
              key.buffer.asUint8List(key.offsetInBytes, key.lengthInBytes);

          SecurityContext secContext = SecurityContext(withTrustedRoots: true)
            ..setTrustedCertificatesBytes(caBytes)
            ..useCertificateChainBytes(certBytes)
            ..usePrivateKeyBytes(keyBytes);

          _httpClient = HttpClient(context: secContext);
          /*
          ..badCertificateCallback =
                ((X509Certificate cert, String host, int port) {
              if (cert.issuer == cert.subject) {
                // Certifikatet er sandsynligvis self-signed
                return true;
              }
              return false;
            });
            */
          initialized = true;
          break;
        case HttpClientType.standard:
          _httpClient = HttpClient();

          break;
      }
    } catch (exp) {
      debugPrint("$exp");
    }
  }
}
