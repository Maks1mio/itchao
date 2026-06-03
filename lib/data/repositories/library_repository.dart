import '../itch_api_client.dart';
import '../models.dart';

class LibraryRepository {
  const LibraryRepository(this._client);

  final ItchApiClient _client;

  Future<List<LibraryGame>> fetchLibrary(String apiKey) {
    return _client.fetchLibrary(apiKey: apiKey);
  }
}
