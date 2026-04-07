import 'dart:async';
import 'package:flutter/material.dart';

import '../auth_storage.dart';
import '../services/api_service.dart';
import 'feed.dart';
import 'login.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.api});
  final Api api;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _isAuthed = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      //  SINGLE source of truth: AuthStorage
    final token = await AuthStorage.getAccessToken();
      if (!mounted) return;

      //  Step 1: decide screen immediately (fast startup)
      final hasToken = token != null && token.trim().isNotEmpty;
      setState(() {
        _isAuthed = hasToken;
        _loading = false;
      });

      //  Step 2 (optional): validate token quickly (non-blocking UX)
      if (hasToken) {
        final res = await widget.api
            .getPosts() //  Api reads token from AuthStorage in _headers()
            .timeout(const Duration(seconds: 5));

        // If unauthorized -> clear session and force login
        if (!res.ok && (res.message ?? '').toLowerCase() == 'unauthorized') {
          await AuthStorage.deleteAccessToken(); // clears token + userId
          if (!mounted) return;
          setState(() => _isAuthed = false);
        }
      }
    } on TimeoutException {
      //  Don't block startup on slow network
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      //  Any other error: don't block app
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _isAuthed
        ? FeedScreen(api: widget.api)
        : LoginScreen(api: widget.api);
  }
}