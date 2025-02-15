import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:digital_signage/data/app_exception.dart';
import 'package:digital_signage/data/network/base_api_service.dart';

class NetworkApiService extends BaseApiService {
  @override
  Future<dynamic> getApiResponse(String url) async {
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(Duration(seconds: 30));
      return _processResponse(response);
    } on SocketException {
      throw FetalException("No Internet Connection");
    } on TimeoutException {
      throw FetalException("Request Timed Out");
    }
  }

  @override
  Future<dynamic> postApiResponse(
      String url, dynamic data, String? authToken) async {
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers:  authToken != null
                ? {
                    HttpHeaders.contentTypeHeader: 'application/json',
                    HttpHeaders.authorizationHeader: "Bearer $authToken"
                  }
                : {HttpHeaders.contentTypeHeader: 'application/json'},
            body: jsonEncode(data),
          )
          .timeout(Duration(seconds: 30));
      return _processResponse(response);
    } on SocketException {
      throw FetalException("No Internet Connection");
    } on TimeoutException {
      throw FetalException("Request Timed Out");
    }
  }

  @override
  Future<dynamic> patchApiResponse(
      String url, dynamic data, String? authToken) async {
    try {
      final response = await http
          .patch(
            Uri.parse(url),
            headers: authToken != null
                ? {
                    HttpHeaders.contentTypeHeader: 'application/json',
                    HttpHeaders.authorizationHeader: "Bearer $authToken"
                  }
                : {HttpHeaders.contentTypeHeader: 'application/json'},
           body: jsonEncode(data),
          )
          .timeout(Duration(seconds: 30));
      return _processResponse(response);
    } on SocketException {
      throw FetalException("No Internet Connection");
    } on TimeoutException {
      throw FetalException("Request Timed Out");
    }
  }

  @override
  Future<dynamic> deleteApiResponse(String url, String? authToken) async {
    try {
      final response = await http
          .delete(
            Uri.parse(url),
            headers: authToken != null
                ? {
                    HttpHeaders.contentTypeHeader: 'application/json',
                    HttpHeaders.authorizationHeader: "Bearer $authToken"
                  }
                : {HttpHeaders.contentTypeHeader: 'application/json'},
          )
          .timeout(Duration(seconds: 30));
      return _processResponse(response);
    } on SocketException {
      throw FetalException("No Internet Connection");
    } on TimeoutException {
      throw FetalException("Request Timed Out");
    }
  }

  dynamic _processResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
      case 201:
        return jsonDecode(response.body);
      case 400:
        throw BadRequestException("Invalid Request");
      case 401:
       throw BadRequestException("Invalid Url");
      case 403:
        throw UnAuthException("Unauthorized");
      default:
        throw FetalException("Error: ${response.statusCode}");
    }
  }
}
