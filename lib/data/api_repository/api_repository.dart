import 'package:digital_signage/data/network/base_api_service.dart';
import 'package:digital_signage/data/network/network_api_service.dart';
import 'package:digital_signage/utils/constants.dart';


class ApiRepository {
   final BaseApiService _apiService = NetworkApiService();

  Future<dynamic> fetchData(String url) async {
    try {
      return await _apiService.getApiResponse(url);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> postData(String url, dynamic data, String? authToken) async {
    try {
     
      return await _apiService.postApiResponse(baseurl+url, data, authToken);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> patchData(String url, String data, String authToken) async {
    try {
      return await _apiService.patchApiResponse(url, data, authToken);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> deleteData(String url, String authToken) async {
    try {
      return await _apiService.deleteApiResponse(url, authToken);
    } catch (e) {
      rethrow;
    }
  }
}
