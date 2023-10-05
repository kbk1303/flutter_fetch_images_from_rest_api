import 'package:flutter_fetch_images_from_rest_api/services/http/http_client_service.dart';
import 'package:get_it/get_it.dart';

final GetIt getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Registrerer en sikker HttpClientService
  getIt.registerLazySingletonAsync<HttpClientService>(() async {
    final service = HttpClientService();
    if (!service.initialized) {
      await service.initialiseHttpClient(HttpClientType.secure);
    } // Forudsat at `initialise` er en asynkron metode
    return service;
  }, instanceName: 'secure');
  /*
  getIt.registerFactoryAsync<HttpClientService>(() async {
    final service = HttpClientService();
    await service.initialiseHttpClient(HttpClientType
        .secure); // Forudsat at `initialise` er en asynkron metode
    return service;
  }, instanceName: 'secure');
 */
  // Registrerer en standard HttpClientService
  getIt.registerFactoryAsync<HttpClientService>(() async {
    final service = HttpClientService();
    await service.initialiseHttpClient(HttpClientType
        .standard); // Forudsat at `initialise` er en asynkron metode
    return service;
  }, instanceName: 'default');

  return getIt.allReady();
}
