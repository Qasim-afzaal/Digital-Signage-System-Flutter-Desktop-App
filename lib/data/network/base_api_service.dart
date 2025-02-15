abstract class BaseApiService {
  Future<dynamic> getApiResponse(String url);
  Future<dynamic> postApiResponse(String url, dynamic data, String? authToken);
  Future<dynamic> patchApiResponse(String url, dynamic data, String? authToken);
  Future<dynamic> deleteApiResponse(String url, String authToken);
}
