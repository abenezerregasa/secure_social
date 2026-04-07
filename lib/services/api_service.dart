import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:tfa_social/models/comment.dart';

import '../auth_storage.dart';
import '../models/post.dart';

class ApiResult<T> {
  final bool ok;
  final T? data;
  final String? message;

  ApiResult.success(this.data)
      : ok = true,
        message = null;

  ApiResult.fail(this.message)
      : ok = false,
        data = null;
}

class Api {
  Api({
    required this.baseUrl,
    http.Client? client,
    Duration? timeout,
  })  : _client = client ?? http.Client(),
        _timeout = timeout ?? const Duration(seconds: 20);

  final String baseUrl;
  final http.Client _client;
  final Duration _timeout;

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> _jsonHeaders() => {
        'Content-Type': 'application/json',
      };

  Future<Map<String, String>> _authHeaders() async {
  final token = await AuthStorage.getAccessToken();
    if (token == null || token.trim().isEmpty) {
      return _jsonHeaders(); // caller will handle unauthorized
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  void dispose() {
    _client.close();
  }

  // ----------------------------
  // Core request wrapper
  // ----------------------------
  Future<http.Response> _get(String path, {Map<String, String>? headers}) async {
    try {
      final res = await _client.get(_u(path), headers: headers).timeout(_timeout);
      return res;
    } on TimeoutException {
      throw TimeoutException('timeout');
    }
  }

  Future<http.Response> _post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      final res = await _client
          .post(_u(path), headers: headers, body: body)
          .timeout(_timeout);
      return res;
    } on TimeoutException {
      throw TimeoutException('timeout');
    }
  }

  Future<http.Response> _delete(String path, {Map<String, String>? headers}) async {
    try {
      final res = await _client.delete(_u(path), headers: headers).timeout(_timeout);
      return res;
    } on TimeoutException {
      throw TimeoutException('timeout');
    }
  }

  ApiResult<T> _handleError<T>(Object e, String prefix) {
    if (e is TimeoutException) {
      return ApiResult.fail('$prefix timeout. Please try again.');
    }
    if (e is SocketException) {
      return ApiResult.fail('$prefix network error. Check Wi-Fi / server IP.');
    }
    return ApiResult.fail('$prefix error: $e');
  }

  // ----------------------------
  // Health
  // ----------------------------
  Future<ApiResult<void>> health() async {
    try {
      final res = await _get('/health');
      if (res.statusCode == 200) return ApiResult.success(null);
      return ApiResult.fail('Health failed (${res.statusCode}).');
    } catch (e) {
      return _handleError(e, 'Health');
    }
  }

  // ----------------------------
  // Auth
  // ----------------------------
  Future<ApiResult<void>> register(String email, String password) async {
    try {
      final res = await _post(
        '/auth/register',
        headers: _jsonHeaders(),
        body: jsonEncode({'email': email, 'password': password}),
      );

      final obj = _safeJson(res.body);

      if (res.statusCode == 201 && (obj['ok'] == true)) {
        return ApiResult.success(null);
      }
      return ApiResult.fail((obj['message'] ?? 'Register failed.').toString());
    } catch (e) {
      return _handleError(e, 'Register');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> login(String email, String password) async {
    try {
      final res = await _post(
        '/auth/login',
        headers: _jsonHeaders(),
        body: jsonEncode({'email': email, 'password': password}),
      );

      final obj = _safeJson(res.body);

      if (res.statusCode == 200 && obj['ok'] == true) {
        return ApiResult.success({
          'challenge_id': obj['challenge_id'],
          'otp_debug': obj['otp_debug'],
        });
      }
      return ApiResult.fail((obj['message'] ?? 'Login failed.').toString());
    } catch (e) {
      return _handleError(e, 'Login');
    }
  }

  Future<ApiResult<String>> verifyOtp(int challengeId, String otp) async {
    try {
      final res = await _post(
        '/auth/verify-otp',
        headers: _jsonHeaders(),
        body: jsonEncode({'challenge_id': challengeId, 'otp': otp}),
      );

      final obj = _safeJson(res.body);

      if (res.statusCode == 200 && obj['ok'] == true) {
        return ApiResult.success((obj['otp_token'] ?? '').toString());
      }
      return ApiResult.fail((obj['message'] ?? 'OTP failed.').toString());
    } catch (e) {
      return _handleError(e, 'Verify OTP');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> resendOtp(int challengeId) async {
    try {
      final res = await _post(
        '/auth/resend-otp',
        headers: _jsonHeaders(),
        body: jsonEncode({'challenge_id': challengeId}),
      );

      final obj = _safeJson(res.body);

      if (res.statusCode == 200 && obj['ok'] == true) {
        return ApiResult.success({
          'challenge_id': obj['challenge_id'],
          'otp_debug': obj['otp_debug'],
        });
      }
      return ApiResult.fail((obj['message'] ?? 'Resend failed.').toString());
    } catch (e) {
      return _handleError(e, 'Resend OTP');
    }
  }

  Future<ApiResult<String>> complete(String otpToken) async {
    try {
      final res = await _post(
        '/auth/complete',
        headers: _jsonHeaders(),
        body: jsonEncode({'otp_token': otpToken}),
      );

      final obj = _safeJson(res.body);

      if ((res.statusCode == 200 || res.statusCode == 201) && obj['ok'] == true) {
        return ApiResult.success((obj['access_token'] ?? '').toString());
      }
      return ApiResult.fail((obj['message'] ?? 'Complete failed.').toString());
    } catch (e) {
      return _handleError(e, 'Complete');
    }
  }

  // ----------------------------
  // Posts (TOKEN IS READ INTERNALLY)
  // ----------------------------
  Future<ApiResult<List<Post>>> getPosts() async {
    try {
      final headers = await _authHeaders();
      if (!headers.containsKey('Authorization')) return ApiResult.fail('unauthorized');

      final res = await _get('/posts', headers: headers);

      if (res.statusCode == 401 || res.statusCode == 403) {
        return ApiResult.fail('unauthorized');
      }

      final obj = _safeJson(res.body);

      if ((res.statusCode == 200 || res.statusCode == 201) && obj['ok'] == true) {
        final list = (obj['posts'] as List? ?? [])
            .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        return ApiResult.success(list);
      }
      return ApiResult.fail((obj['message'] ?? 'Get posts failed.').toString());
    } catch (e) {
      return _handleError(e, 'Get posts');
    }
  }

  Future<ApiResult<int>> createPost(String content) async {
    try {
      final headers = await _authHeaders();
      if (!headers.containsKey('Authorization')) return ApiResult.fail('unauthorized');

      final res = await _post(
        '/posts',
        headers: headers,
        body: jsonEncode({'content': content}),
      );

      if (res.statusCode == 401 || res.statusCode == 403) {
        return ApiResult.fail('unauthorized');
      }

      final obj = _safeJson(res.body);

      if ((res.statusCode == 200 || res.statusCode == 201) && obj['ok'] == true) {
        return ApiResult.success((obj['post_id'] as num).toInt());
      }

      return ApiResult.fail((obj['message'] ?? 'Create post failed.').toString());
    } catch (e) {
      return _handleError(e, 'Create post');
    }
  }

  Future<ApiResult<void>> deletePost(int postId) async {
    try {
      final headers = await _authHeaders();
      if (!headers.containsKey('Authorization')) return ApiResult.fail('unauthorized');

      final res = await _delete('/posts/$postId', headers: headers);

      if (res.statusCode == 401 || res.statusCode == 403) {
        return ApiResult.fail('unauthorized');
      }

      final obj = _safeJson(res.body);

      if (res.statusCode == 200 && obj['ok'] == true) {
        return ApiResult.success(null);
      }
      return ApiResult.fail((obj['message'] ?? 'Delete failed.').toString());
    } catch (e) {
      return _handleError(e, 'Delete post');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> likePost(int postId) async {
    try {
      final headers = await _authHeaders();
      if (!headers.containsKey('Authorization')) return ApiResult.fail('unauthorized');

      final res = await _post('/posts/$postId/like', headers: headers);

      if (res.statusCode == 401 || res.statusCode == 403) {
        return ApiResult.fail('unauthorized');
      }

      final obj = _safeJson(res.body);

      if (res.statusCode == 200 && obj['ok'] == true) {
        return ApiResult.success({
          'like_count': obj['like_count'],
          'liked_by_me': obj['liked_by_me'],
        });
      }
      return ApiResult.fail((obj['message'] ?? 'Like failed.').toString());
    } catch (e) {
      return _handleError(e, 'Like');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> unlikePost(int postId) async {
    try {
      final headers = await _authHeaders();
      if (!headers.containsKey('Authorization')) return ApiResult.fail('unauthorized');

      final res = await _delete('/posts/$postId/like', headers: headers);

      if (res.statusCode == 401 || res.statusCode == 403) {
        return ApiResult.fail('unauthorized');
      }

      final obj = _safeJson(res.body);

      if (res.statusCode == 200 && obj['ok'] == true) {
        return ApiResult.success({
          'like_count': obj['like_count'],
          'liked_by_me': obj['liked_by_me'],
        });
      }
      return ApiResult.fail((obj['message'] ?? 'Unlike failed.').toString());
    } catch (e) {
      return _handleError(e, 'Unlike');
    }
  }

  Future<ApiResult<List<Comment>>> getComments(int postId) async {
    try {
      final headers = await _authHeaders();
      if (!headers.containsKey('Authorization')) return ApiResult.fail('unauthorized');

      final res = await _get('/posts/$postId/comments', headers: headers);

      if (res.statusCode == 401 || res.statusCode == 403) {
        return ApiResult.fail('unauthorized');
      }

      final obj = _safeJson(res.body);

      if (res.statusCode == 200 && obj['ok'] == true) {
        final list = (obj['comments'] as List? ?? [])
            .map((e) => Comment.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        return ApiResult.success(list);
      }

      return ApiResult.fail((obj['message'] ?? 'Get comments failed.').toString());
    } catch (e) {
      return _handleError(e, 'Get comments');
    }
  }

  Future<ApiResult<int>> addComment(int postId, String content) async {
    try {
      final headers = await _authHeaders();
      if (!headers.containsKey('Authorization')) return ApiResult.fail('unauthorized');

      final res = await _post(
        '/posts/$postId/comments',
        headers: headers,
        body: jsonEncode({'content': content}),
      );

      if (res.statusCode == 401 || res.statusCode == 403) {
        return ApiResult.fail('unauthorized');
      }

      final obj = _safeJson(res.body);

      if ((res.statusCode == 200 || res.statusCode == 201) && obj['ok'] == true) {
        return ApiResult.success((obj['comment_count'] as num).toInt());
      }

      return ApiResult.fail((obj['message'] ?? 'Add comment failed.').toString());
    } catch (e) {
      return _handleError(e, 'Add comment');
    }
  }

  // ----------------------------
  // Helpers
  // ----------------------------
  Map<String, dynamic> _safeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'ok': false, 'message': 'Invalid server response (not a JSON object).'};
    } catch (_) {
      final snippet = body.length > 200 ? body.substring(0, 200) : body;
      return {'ok': false, 'message': 'Non-JSON response: $snippet'};
    }
  }
}