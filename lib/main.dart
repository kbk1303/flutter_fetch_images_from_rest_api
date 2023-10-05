import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fetch_images_from_rest_api/services/foreground_notification/foreground_notification_service.dart';
import 'package:flutter_fetch_images_from_rest_api/services/locator/get_it_locator.dart';
import 'package:flutter_fetch_images_from_rest_api/services/http/http_client_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

/*
Future<void> initForegroundNotifications() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description:
        'This channel is used for important notifications.', // description
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}
*/

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await setupServiceLocator();
  FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
  //await initForegroundNotifications();
  runApp(const MyApp());
}

@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  debugPrint("Handling in Background: ${message.messageId}");
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Billedvalg',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const ImagePickerPage(),
    );
  }
}

class ImagePickerPage extends StatefulWidget {
  const ImagePickerPage({super.key});

  @override
  State<ImagePickerPage> createState() => _ImagePickerPageState();
}

class _ImagePickerPageState extends State<ImagePickerPage> {
  final List<Image> _selectedImages = [];
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  final String accessTokenKey = "Access_Token";
  final String refreshTokenKey = 'Refresh_Token';
  bool _isLoading = false;
  //late final String deviceToken;
  final ForegroundNotificationService _foregroundNotificationService =
      ForegroundNotificationService();
  //final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  @override
  void initState() {
    super.initState();

    _foregroundNotificationService.requestNotificationPermission();
    _foregroundNotificationService.firebaseInit();
    _foregroundNotificationService.isTokenRefresh();
    _foregroundNotificationService.getDeviceToken().then((String? token) {
      assert(token != null);
      if (kDebugMode) {
        print("FirebaseMessaging Token: $token");
      }
    });
    /* 
    _firebaseMessaging.getToken().then((String? token) {
      assert(token != null);
      if (kDebugMode) {
        print("FirebaseMessaging Token: $token");
      }
      deviceToken = token!;
    });

    _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.instance.subscribeToTopic("images_completed");
    //FirebaseMessaging.instance.subscribeToTopic("topic2");
    //FirebaseMessaging.instance.subscribeToTopic("topic3");

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("Message received: ${message.notification?.body}");
      // Gør noget baseret på den modtagne meddelelse
    });
    */
  }

  Future<List<Image>> _fetchImages() async {
    return await _apiFetchImages();
  }

  Future<void> _apiEnsureValidToken() async {
    try {
      var httpService =
          await getIt.getAsync<HttpClientService>(instanceName: 'secure');
      String? accessToken = await storage.read(key: accessTokenKey);
      final request = await httpService.httpClient
          .postUrl(Uri.parse('https://10.0.2.2:9443/validate-token'));
      request.headers.add('Authorization', 'Bearer $accessToken');
      HttpClientResponse response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        //login to get new tokens
        Map<String, String> body = {
          'username': 'krik@zbc.dk',
          'password': 'Teacher55@Prog',
        };
        final request = await httpService.httpClient
            .postUrl(Uri.parse('https://10.0.2.2:9443/login'));
        request.headers.set('content-type', 'application/json');
        request.add(utf8.encode(json.encode(body)));
        HttpClientResponse response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          throw ('an error occured: ${response.statusCode}');
        }
        String reply = await response.transform(utf8.decoder).join();
        var data = json.decode(reply);
        storage.delete(key: accessTokenKey);
        storage.delete(key: refreshTokenKey);
        storage.write(key: accessTokenKey, value: data['accessToken']);
        storage.write(key: refreshTokenKey, value: data['refreshToken']);
      }
    } catch (ex) {
      debugPrint('exception $ex');
      rethrow;
    }
  }

  Future<List<Image>> _apiFetchImages() async {
    await _apiEnsureValidToken();
    var httpService =
        await getIt.getAsync<HttpClientService>(instanceName: 'secure');
    String? accessToken = await storage.read(key: accessTokenKey);
    final request = await httpService.httpClient
        .getUrl(Uri.parse('https://10.0.2.2:9443/images'));
    request.headers.add('Authorization', 'Bearer $accessToken');
    HttpClientResponse response = await request.close();
    throwIf(response.statusCode != HttpStatus.ok, 'An error occured');
    String reply = await response.transform(utf8.decoder).join();
    try {
      var data = json.decode(reply);
      return data['images']
          .map<Image>((imgData) => Image.memory(base64Decode(imgData['image'])))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  void _showImageDialog(BuildContext context, List<Image> fetchedImages) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: fetchedImages.map((image) {
              return ListTile(
                leading: image,
                title: const Text('Klik for at vælge'),
                onTap: () {
                  setState(() {
                    _selectedImages.add(image);
                  });
                  Navigator.of(dialogContext).pop();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _fetchAndShowImages(BuildContext context) {
    setState(() {
      _isLoading = true;
    });

    final completer = Completer<List<Image>>();

    _fetchImages().then((images) {
      completer.complete(images);
    }).catchError((error) {
      completer.completeError(error);
    }).whenComplete(() {
      setState(() {
        _isLoading = false;
      });
    });

    completer.future.then((images) {
      _showImageDialog(context, images);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vælg Billeder'),
      ),
      body: Column(
        children: <Widget>[
          ElevatedButton(
            onPressed: () {
              _fetchAndShowImages(context);
            },
            child: const Text('Vis Billeder'),
          ),
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : Expanded(
                  child: ListView.builder(
                    itemCount: _selectedImages.length,
                    itemBuilder: (ctx, index) {
                      return InkWell(
                        onTap: () {
                          // Kode, der skal udføres ved klik
                          debugPrint("Billede ${index + 1} klikket");
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: SizedBox(
                            height: 100, // Højden af din thumbnail
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 16 /
                                    9, // Aspect ratio af din thumbnail, juster som nødvendigt
                                child: _selectedImages[index],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }
}
