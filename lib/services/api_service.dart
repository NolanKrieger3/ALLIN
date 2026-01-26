import 'dart:convert';
import 'package:http/http.dart' as http;

/// Base API service for making HTTP requests
class ApiService {
  final String baseUrl;
  final Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
  };

  ApiService({required this.baseUrl});

  /// Set authorization token for authenticated requests
  void setAuthToken(String token) {
    _defaultHeaders['Authorization'] = 'Bearer $token';
  }

  /// Remove authorization token
  void clearAuthToken() {
    _defaultHeaders.remove('Authorization');
  }

  /// GET request
  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParams);
    
    try {
      final response = await http.get(uri, headers: _defaultHeaders);
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  /// POST request
  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    
    try {
      final response = await http.post(
        uri,
        headers: _defaultHeaders,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  /// PUT request
  Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    
    try {
      final response = await http.put(
        uri,
        headers: _defaultHeaders,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  /// DELETE request
  Future<dynamic> delete(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    
    try {
      final response = await http.delete(uri, headers: _defaultHeaders);
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  /// Handle HTTP response
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw ApiException('Unauthorized', statusCode: 401);
    } else if (response.statusCode == 404) {
      throw ApiException('Not found', statusCode: 404);
    } else {
      throw ApiException(
        'Request failed with status: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }
}

/// Custom exception for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}
