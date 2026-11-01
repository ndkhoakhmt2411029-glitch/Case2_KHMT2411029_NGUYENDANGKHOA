import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
  }

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _uri(String path) => Uri.parse('${AppConstants.baseUrl}$path');

  Future<Map<String, dynamic>> get(String path, {bool auth = true}) =>
      _send(() async => http.get(_uri(path), headers: await _headers(auth: auth)));

  Future<Map<String, dynamic>> post(String path,
          {Map<String, dynamic>? body, bool auth = true}) =>
      _send(() async => http.post(_uri(path),
          headers: await _headers(auth: auth), body: jsonEncode(body ?? {})));

  Future<Map<String, dynamic>> put(String path,
          {Map<String, dynamic>? body, bool auth = true}) =>
      _send(() async => http.put(_uri(path),
          headers: await _headers(auth: auth), body: jsonEncode(body ?? {})));

  Future<Map<String, dynamic>> _send(
      Future<http.Response> Function() request) async {
    try {
      final res = await request().timeout(AppConstants.requestTimeout);
      Map<String, dynamic> data = {};
      if (res.body.isNotEmpty) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is Map<String, dynamic>) data = decoded;
      }
      if (res.statusCode >= 200 && res.statusCode < 300) return data;
      throw ApiException(
        (data['message'] ?? 'Đã xảy ra lỗi (${res.statusCode})').toString(),
        statusCode: res.statusCode,
      );
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Hết thời gian chờ, vui lòng thử lại');
    } on SocketException {
      throw ApiException('Không thể kết nối đến máy chủ');
    } on FormatException {
      throw ApiException('Dữ liệu phản hồi không hợp lệ');
    } catch (_) {
      throw ApiException('Đã xảy ra lỗi không xác định');
    }
  }
}
