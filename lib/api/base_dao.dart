import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';

const Duration _kRequestTimeout = Duration(seconds: 30);

// API хандалтын үндсэн DAO
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final int? statusCode;

  ApiResponse({required this.success, this.data, this.message, this.statusCode});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json, {
    T Function(dynamic)? parse,
    int? statusCode,
  }) {
    return ApiResponse<T>(
      success: json['success'] == true,
      data: parse != null ? parse(json['data']) : json['data'],
      message: json['message']?.toString(),
      statusCode: statusCode,
    );
  }
}

enum HeaderType {
  jsonOnly, // Content-Type: application/json
  bearerToken, // Authorization: Bearer <token>
  xtoken, // X-Token: Constants.xToken
  bearerAndJson, // Bearer + JSON
  xtokenAndTenant, //X-Token + X-Tenant
  xtokenAndTenantAndxmedsoftToken, //X-Token + X-Tenant + X-Medsoft-Token
  custom, // For custom headers
}

class RequestConfig {
  final HeaderType headerType;
  final Map<String, String>? customHeaders;
  final bool excludeToken;

  const RequestConfig({
    this.headerType = HeaderType.jsonOnly,
    this.customHeaders,
    this.excludeToken = false,
  });
}

String statusMessage(int? statusCode) {
  switch (statusCode) {
    case 400:
      return 'Илгээсэн хүсэлт буруу байна.';
    case 401:
      return 'Баталгаажуулалт амжилтгүй боллоо. Дахин нэвтэрнэ үү.';
    case 403:
      return 'Та энэ үйлдлийг хийх эрхгүй байна.';
    case 404:
      return 'Хүссэн мэдээлэл олдсонгүй.';
    case 409:
      return 'Хүсэлтийг гүйцэтгэх боломжгүй байна.';
    case 422:
      return 'Оруулсан мэдээллээ шалгаад дахин оролдоно уу.';
    case 429:
      return 'Хэт олон оролдлого хийсэн байна. Дараа дахин оролдоно уу.';
    case 500:
      return 'Системийн алдаа гарлаа.';
    case 503:
      return 'Үйлчилгээ түр хугацаанд боломжгүй байна.';
    default:
      return 'Алдаа гарлаа. Дахин оролдоно уу.';
  }
}

abstract class BaseDAO {
  Future<ApiResponse<T>> post<T>(
    String url, {
    dynamic body,
    RequestConfig config = const RequestConfig(),
    T Function(dynamic)? parse,
  }) async {
    try {
      final headers = await _buildHeaders(config);
      final response = await http
          .post(Uri.parse(url), headers: headers, body: body != null ? jsonEncode(body) : null)
          .timeout(_kRequestTimeout);
      return _handleResponse<T>(response, parse: parse);
    } on SocketException {
      return ApiResponse<T>(success: false, message: 'Интернэт холболтоо шалгана уу.');
    } on TimeoutException {
      return ApiResponse<T>(success: false, message: 'Серверт холбогдоход хугацаа дууслаа.');
    } catch (e) {
      return ApiResponse<T>(success: false, message: e.toString());
    }
  }

  Future<ApiResponse<T>> get<T>(
    String url, {
    RequestConfig config = const RequestConfig(),
    T Function(dynamic)? parse,
  }) async {
    try {
      final headers = await _buildHeaders(config);
      final response = await http.get(Uri.parse(url), headers: headers).timeout(_kRequestTimeout);
      return _handleResponse<T>(response, parse: parse);
    } on SocketException {
      return ApiResponse<T>(success: false, message: 'Интернэт холболтоо шалгана уу.');
    } on TimeoutException {
      return ApiResponse<T>(success: false, message: 'Серверт холбогдоход хугацаа дууслаа.');
    } catch (e) {
      return ApiResponse<T>(success: false, message: e.toString());
    }
  }

  Future<Map<String, String>> _buildHeaders(RequestConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('X-Medsoft-Token') ?? '';
    final savedTenant = prefs.getString('X-Tenant') ?? '';

    Map<String, String> headers = {};

    switch (config.headerType) {
      case HeaderType.jsonOnly:
        headers['Content-Type'] = 'application/json';
        break;
      case HeaderType.bearerToken:
        if (!config.excludeToken && savedToken.isNotEmpty) {
          headers['Authorization'] = 'Bearer $savedToken';
        }
        break;
      case HeaderType.xtoken:
        headers['X-Token'] = Constants.xToken;
        break;
      case HeaderType.bearerAndJson:
        headers['Content-Type'] = 'application/json';
        if (!config.excludeToken && savedToken.isNotEmpty) {
          headers['Authorization'] = 'Bearer $savedToken';
        }
        break;
      case HeaderType.xtokenAndTenant:
        if (!config.excludeToken && savedToken.isNotEmpty) {
          headers['Authorization'] = 'Bearer $savedToken';
        }
        headers['Content-Type'] = 'application/json';
        headers['X-Token'] = Constants.xToken;
        if (savedTenant.isNotEmpty) {
          headers['X-Tenant'] = savedTenant;
        }
        break;
      case HeaderType.xtokenAndTenantAndxmedsoftToken:
        if (!config.excludeToken && savedToken.isNotEmpty) {
          headers['Authorization'] = 'Bearer $savedToken';
        }
        headers['Content-Type'] = 'application/json';
        headers['X-Token'] = Constants.xToken;
        if (savedTenant.isNotEmpty) {
          headers['X-Tenant'] = savedTenant;
        }
        if (savedToken.isNotEmpty) {
          headers['X-Medsoft-Token'] = savedToken;
        }
        break;
      case HeaderType.custom:
        break;
    }

    if (config.customHeaders != null) {
      headers.addAll(config.customHeaders!);
    }

    return headers;
  }

  ApiResponse<T> _handleResponse<T>(http.Response response, {T Function(dynamic)? parse}) {
    if (response.statusCode >= 400) {
      return ApiResponse<T>(
        success: false,
        message: statusMessage(response.statusCode),
        statusCode: response.statusCode,
      );
    }

    try {
      final jsonBody = jsonDecode(response.body);
      return ApiResponse.fromJson(jsonBody, parse: parse, statusCode: response.statusCode);
    } catch (e) {
      return ApiResponse<T>(
        success: false,
        message: 'Системийн алдаа гарлаа. Мэдээллийн ажилтанд хандаж алдааг шалгуулна уу.',
        statusCode: response.statusCode,
      );
    }
  }
}
