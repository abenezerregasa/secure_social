import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../core/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.api});
  final Api api;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // ---------------------------------------------------------
  // STATE & CONTROLLERS (Logic Integrity Maintained)
  // ---------------------------------------------------------
  final _emailC = TextEditingController();
  final _passC = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _success;

  String? _stage;
  Timer? _softTimer;
  bool _softTimedOut = false;

  // ---------------------------------------------------------
  // TIMEOUT & UI LOGIC (Preserved)
  // ---------------------------------------------------------
  void _startSoft(String stage) {
    _softTimer?.cancel();
    _softTimedOut = false;

    setState(() {
      _loading = true;
      _stage = stage;
      _error = null;
      _success = null;
    });

    _softTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      if (_loading) {
        setState(() {
          _softTimedOut = true;
          _loading = false; 
          _stage = null;
          _error = 'Creation is taking longer than expected. Please check your connection.';
        });
      }
    });
  }

  void _stopSoft() {
    _softTimer?.cancel();
    _softTimer = null;
    _softTimedOut = false;
  }

  void _clearMessages() {
    if (_error != null || _success != null || _softTimedOut) {
      setState(() {
        _error = null;
        _success = null;
        _softTimedOut = false;
      });
    }
  }

  // ---------------------------------------------------------
  // REGISTRATION LOGIC (Preserved)
  // ---------------------------------------------------------
  Future<void> _doRegister() async {
    if (_loading) return;

    FocusScope.of(context).unfocus();
    final email = _emailC.text.trim();
    final pass = _passC.text;

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    if (pass.length < 8) {
      setState(() => _error = 'For security, passwords must be at least 8 characters.');
      return;
    }

    try {
      _startSoft('Creating your account...');

      final res = await widget.api.register(email, pass);
      if (!mounted) return;

      if (!res.ok) {
        _stopSoft();
        setState(() {
          _loading = false;
          _stage = null;
          _error = res.message ?? 'Registration failed.';
        });
        return;
      }

      _stopSoft();
      HapticFeedback.successNotification();
      
      setState(() {
        _loading = false;
        _stage = null;
        _success = 'Account created successfully! You can now log in.';
      });

    } catch (e) {
      if (!mounted) return;
      _stopSoft();
      setState(() {
        _loading = false;
        _stage = null;
        _error = 'System error: $e';
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

  // ---------------------------------------------------------
  // REFINED UI BUILD
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textMain, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.person_add_rounded, size: 64, color: AppColors.primary),
                  const SizedBox(height: 16),
                  const Text(
                    'Join TFA Social',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30, 
                      fontWeight: FontWeight.w900, 
                      letterSpacing: -1.0,
                      color: AppColors.primary
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create an account to join the conversation.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                  ),
                  const SizedBox(height: 40),

                  _buildLabel('Email Address'),
                  TextField(
                    controller: _emailC,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => _clearMessages(),
                    decoration: _inputDecoration('Enter your email', Icons.alternate_email_rounded),
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Password'),
                  TextField(
                    controller: _passC,
                    obscureText: _obscure,
                    onChanged: (_) => _clearMessages(),
                    decoration: _inputDecoration('Min. 8 characters', Icons.lock_outline_rounded).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 20),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Message area (Stage, Success, or Error)
                  if (_stage != null && _loading)
                    _StatusMessage(message: _stage!, color: AppColors.primary, icon: Icons.sync),

                  if (_success != null)
                    _StatusMessage(message: _success!, color: Colors.green.shade700, icon: Icons.check_circle_outline),

                  if (_error != null)
                    _StatusMessage(message: _error!, color: AppColors.error, icon: Icons.error_outline),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _loading ? null : _doRegister,
                      child: _loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                          : Text(
                              _softTimedOut ? 'Retry Registration' : 'Create Account',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  
                  TextButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                        children: [
                          TextSpan(text: "Already have an account? "),
                          TextSpan(
                            text: "Log In", 
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
  final IconData icon;
  const _StatusMessage({required this.message, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}