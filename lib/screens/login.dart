import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../core/app_theme.dart';
import '../screens/otp.dart';
import 'register.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api});
  final Api api;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ---------------------------------------------------------
  // STATE & CONTROLLERS (Logic Integrity Maintained)
  // ---------------------------------------------------------
  final _emailC = TextEditingController();
  final _passC = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  String? _stage;
  Timer? _softTimer;
  bool _softTimedOut = false;

  // ---------------------------------------------------------
  // TIMEOUT LOGIC (Preserved)
  // ---------------------------------------------------------
  void _startSoft(String stage) {
    _softTimer?.cancel();
    _softTimedOut = false;

    setState(() {
      _loading = true;
      _stage = stage;
      _error = null;
    });

    _softTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      if (_loading) {
        setState(() {
          _softTimedOut = true;
          _loading = false; //  release UI
          _stage = null;
          _error = 'Still working… If it feels stuck, tap Retry.';
        });
      }
    });
  }

  void _stopSoft() {
    _softTimer?.cancel();
    _softTimer = null;
    _softTimedOut = false;
  }

  // ---------------------------------------------------------
  // AUTH LOGIC (Preserved)
  // ---------------------------------------------------------
  Future<void> _doLogin() async {
    if (_loading) return;

    FocusScope.of(context).unfocus();
    final email = _emailC.text.trim();
    final password = _passC.text;

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'Please enter your password.');
      return;
    }

    try {
      _startSoft('Authenticating...');

      final res = await widget.api.login(email, password);
      if (!mounted) return;

      if (!res.ok || res.data == null) {
        _stopSoft();
        setState(() {
          _loading = false;
          _stage = null;
          _error = res.message ?? 'Login failed. Please check your credentials.';
        });
        return;
      }

      final challengeId = res.data!['challenge_id'];
      final otpDebug = (res.data!['otp_debug'] ?? '').toString();

      _stopSoft();
      HapticFeedback.mediumImpact();

      if (!mounted) return;

      setState(() {
        _loading = false;
        _stage = null;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            api: widget.api,
            challengeId: (challengeId as num).toInt(),
            otpDebug: otpDebug,
            userEmail: email,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _stopSoft();
      setState(() {
        _loading = false;
        _stage = null;
        _error = 'A connection error occurred. $e';
      });
    } finally {
      if (!mounted) return;
      if (!_softTimedOut) {
        setState(() {
          _loading = false;
          _stage = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _softTimer?.cancel();
    _emailC.dispose();
    _passC.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------
  // REFINED UI BUILD
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo/Branding
                  const Icon(Icons.shield_rounded, size: 72, color: AppColors.primary),
                  const SizedBox(height: 16),
                  const Text(
                    'TFA Social',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32, 
                      fontWeight: FontWeight.w900, 
                      letterSpacing: -1.0,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Secure OTP & Biometric Access',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                  ),
                  const SizedBox(height: 48),

                  // Email Field
                  _buildLabel('Email Address'),
                  TextField(
                    controller: _emailC,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => _clearErrors(),
                    decoration: _inputDecoration('Enter your email', Icons.alternate_email_rounded),
                  ),
                  const SizedBox(height: 20),

                  // Password Field
                  _buildLabel('Password'),
                  TextField(
                    controller: _passC,
                    obscureText: _obscure,
                    onChanged: (_) => _clearErrors(),
                    decoration: _inputDecoration('Enter your password', Icons.lock_outline_rounded).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 20),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),

                  // Status/Error Messages
                  if (_stage != null && _loading)
                    _StatusMessage(message: _stage!, color: AppColors.primary),

                  if (_error != null)
                    _StatusMessage(message: _error!, color: AppColors.error),

                  const SizedBox(height: 24),

                  // Action Button
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: _loading ? null : _doLogin,
                      child: _loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                          : Text(
                              _softTimedOut ? 'Retry Login' : 'Continue',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?", style: TextStyle(color: AppColors.textMuted)),
                      TextButton(
                        onPressed: _loading ? null : () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen(api: widget.api)));
                        },
                        child: const Text('Create Account', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _clearErrors() {
    if (_error != null || _softTimedOut) {
      setState(() {
        _error = null;
        _softTimedOut = false;
      });
    }
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textMain)),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final String message;
  final Color color;
  const _StatusMessage({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}