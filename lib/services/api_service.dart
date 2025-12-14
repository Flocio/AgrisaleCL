/// API 服务基础类
/// 提供统一的 HTTP 请求、错误处理、重试机制

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_response.dart';
import '../models/api_error.dart';

class ApiService {
  // 单例模式
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// 服务器基础 URL（从环境变量或配置读取）
  String baseUrl = 'https://agrisalecl.drflo.org'; // 默认值，HTTPS 内网穿透地址（同时支持内网和外网）

  /// 请求超时时间（秒）
  /// 登录请求使用较短超时，避免用户等待过久
  static const int timeoutSeconds = 15;

  /// 最大重试次数
  static const int maxRetries = 3;

  /// 重试延迟（毫秒）
  static const int retryDelayMs = 1000;

  /// Token 存储键
  static const String _tokenKey = 'api_token';

  /// 获取当前 Token（公开方法，供其他服务使用）
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// 获取当前 Token（内部方法，保持向后兼容）
  Future<String?> _getToken() async => getToken();

  /// 保存 Token
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// 清除 Token
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// 设置服务器地址
  void setBaseUrl(String url) {
    baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// 设置 Token
  Future<void> setToken(String token) async {
    await _saveToken(token);
  }

  /// 构建请求头
  Future<Map<String, String>> _buildHeaders({
    Map<String, String>? additionalHeaders,
    bool includeAuth = true,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = await _getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    return headers;
  }

  /// 处理 HTTP 响应
  Future<ApiResponse<T>> _handleResponse<T>(
    http.Response response,
    T? Function(dynamic)? fromJsonT,
  ) async {
    // 解析响应体
    Map<String, dynamic>? json;
    try {
      if (response.body.isNotEmpty) {
        json = jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // 如果响应不是 JSON，创建错误响应
      throw ApiError.server(
        response.statusCode,
        '服务器返回了无效的响应格式',
      );
    }

    // 检查 HTTP 状态码
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // 成功响应
      return ApiResponse.fromJson(json ?? {}, fromJsonT);
    } else {
      // 错误响应
      throw ApiError.fromHttpResponse(response.statusCode, json);
    }
  }

  /// 执行 HTTP 请求（带重试）
  Future<http.Response> _executeRequest(
    Future<http.Response> Function() request,
  ) async {
    int attempts = 0;
    Exception? lastException;

    while (attempts < maxRetries) {
      try {
        print('API 请求尝试 ${attempts + 1}/$maxRetries'); // 调试日志
        
        final response = await request()
            .timeout(Duration(seconds: timeoutSeconds));

        print('API 响应状态码: ${response.statusCode}'); // 调试日志

        // 如果是 401 未授权，不重试
        if (response.statusCode == 401) {
          throw ApiError.unauthorized();
        }

        // 如果是 5xx 服务器错误，重试
        if (response.statusCode >= 500 && attempts < maxRetries - 1) {
          print('服务器错误，准备重试...'); // 调试日志
          await Future.delayed(Duration(milliseconds: retryDelayMs * (attempts + 1)));
          attempts++;
          continue;
        }

        return response;
      } on ApiError {
        rethrow;
      } on TimeoutException catch (e) {
        lastException = e;
        print('请求超时 (尝试 ${attempts + 1}/$maxRetries)'); // 调试日志
        if (attempts < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: retryDelayMs * (attempts + 1)));
          attempts++;
          continue;
        }
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        print('请求异常: $e (尝试 ${attempts + 1}/$maxRetries)'); // 调试日志
        
        // 如果是超时或网络错误，重试
        if (attempts < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: retryDelayMs * (attempts + 1)));
          attempts++;
          continue;
        }
      }
    }

    // 所有重试都失败
    if (lastException != null) {
      if (lastException.toString().contains('TimeoutException') || 
          lastException is TimeoutException) {
        print('所有重试失败：超时'); // 调试日志
        throw ApiError.timeout('连接超时，请检查网络连接和服务器地址');
      } else {
        print('所有重试失败：网络错误'); // 调试日志
        throw ApiError.network('无法连接到服务器，请检查：\n1. 是否与服务器在同一网络\n2. 服务器地址是否正确\n3. 防火墙是否阻止连接', lastException);
      }
    }

    throw ApiError.unknown('请求失败');
  }

  /// GET 请求
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, String>? queryParameters,
    T? Function(dynamic)? fromJsonT,
    bool includeAuth = true,
  }) async {
    try {
      // 构建 URL
      var uri = Uri.parse('$baseUrl$path');
      if (queryParameters != null && queryParameters.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParameters);
      }

      // 执行请求
      final response = await _executeRequest(() async {
        final headers = await _buildHeaders(includeAuth: includeAuth);
        return await http.get(uri, headers: headers);
      });

      return await _handleResponse<T>(response, fromJsonT);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('GET 请求失败', e);
    }
  }

  /// POST 请求
  Future<ApiResponse<T>> post<T>(
    String path, {
    Map<String, dynamic>? body,
    T? Function(dynamic)? fromJsonT,
    bool includeAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');

      // 执行请求
      final response = await _executeRequest(() async {
        final headers = await _buildHeaders(includeAuth: includeAuth);
        final bodyJson = body != null ? jsonEncode(body) : null;
        return await http.post(uri, headers: headers, body: bodyJson);
      });

      return await _handleResponse<T>(response, fromJsonT);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('POST 请求失败', e);
    }
  }

  /// PUT 请求
  Future<ApiResponse<T>> put<T>(
    String path, {
    Map<String, dynamic>? body,
    T? Function(dynamic)? fromJsonT,
    bool includeAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');

      // 执行请求
      final response = await _executeRequest(() async {
        final headers = await _buildHeaders(includeAuth: includeAuth);
        final bodyJson = body != null ? jsonEncode(body) : null;
        return await http.put(uri, headers: headers, body: bodyJson);
      });

      return await _handleResponse<T>(response, fromJsonT);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('PUT 请求失败', e);
    }
  }

  /// DELETE 请求
  Future<ApiResponse<T>> delete<T>(
    String path, {
    T? Function(dynamic)? fromJsonT,
    bool includeAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');

      // 执行请求
      final response = await _executeRequest(() async {
        final headers = await _buildHeaders(includeAuth: includeAuth);
        return await http.delete(uri, headers: headers);
      });

      return await _handleResponse<T>(response, fromJsonT);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('DELETE 请求失败', e);
    }
  }

  /// PATCH 请求
  Future<ApiResponse<T>> patch<T>(
    String path, {
    Map<String, dynamic>? body,
    T? Function(dynamic)? fromJsonT,
    bool includeAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');

      // 执行请求
      final response = await _executeRequest(() async {
        final headers = await _buildHeaders(includeAuth: includeAuth);
        final bodyJson = body != null ? jsonEncode(body) : null;
        return await http.patch(uri, headers: headers, body: bodyJson);
      });

      return await _handleResponse<T>(response, fromJsonT);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('PATCH 请求失败', e);
    }
  }
}

