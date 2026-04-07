import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../auth_storage.dart';
import '../services/biometric_service.dart';
import '../core/app_theme.dart';
import 'feed.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.api,
    required this.challengeId,
    required this.otpDebug,
    required this.userEmail,
  });

  final Api api;
  final int challengeId;
  final String otpDebug;
  final String userEmail;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  // ---------------------------------------------------------
  // STATE & LOGIC (Preserving your exact flow)
  // ---------------------------------------------------------
  final _otpC = TextEditingController();
  final _bio = BiometricService();

  bool _loading = false;
  String? _error;
  String? _stage;

  Timer? _softTimer;
  bool _softTimedOut = false;

  int _secondsLeft = 60;
  Timer? _timer;

  late int _challengeId;
  late String _otpDebug;
  int _opId = 0;

  static const bool bypassBiometric = false;

  @override
  void initState() {
    super.initState();
    _challengeId = widget.challengeId;
    _otpDebug = widget.otpDebug;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _softTimer?.cancel();
    _otpC.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String _maskEmail(String email) {
    final e = email.trim();
    final at = e.indexOf('@');
    if (at <= 1) return e;
    return '${e.substring(0, 2)}***${e.substring(at)}';
  }

  String _normalizeOtp(String raw) => raw.replaceAll(RegExp(r'[^0-9]'), '');

  void _startSoft(String stage) {
    _softTimer?.cancel();
    _softTimedOut = false;
    setState(() {
      _loading = true;
      _stage = stage;
      _error = null;
    });

    _softTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      if (_loading) {
        setState(() {
          _softTimedOut = true;
          _loading = false;
          _stage = null;
          _error = 'Still working… If it feels stuck, tap Retry.';
        });
      }
    });
  }

  void _stopSoft() => _softTimer?.cancel();

  // ---------------------------------------------------------
  // CORE AUTHENTICATION FLOW
  // ---------------------------------------------------------
  Future<void> _verify() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();

    final otp = _normalizeOtp(_otpC.text);
    if (otp.length < 4) {
      setState(() => _error = 'Please enter the verification code.');
      return;
    }

    final int op = ++_opId;

    try {
      _startSoft('Verifying OTP…');
      final otpRes = await widget.api.verifyOtp(_challengeId, otp);
      if (!mounted || op != _opId) return;

      if (!otpRes.ok || otpRes.data == null) {
        _stopSoft();
        setState(() { _loading = false; _error = otpRes.message ?? 'OTP failed.'; });
        return;
      }

      final otpToken = otpRes.data!;

      if (!bypassBiometric) {
        _startSoft('Authenticating Biometrics…');
        final canUse = await _bio.canUseBiometrics();
        if (!mounted || op != _opId) return;

        if (!canUse) {
          _stopSoft();
          setState(() { _loading = false; _error = 'Biometrics unavailable.'; });
          return;
        }

        final bioRes = await _bio.authenticate(reason: 'Verify your identity to continue');
        if (!mounted || op != _opId) return;

        if (!bioRes.ok) {
          _stopSoft();
          setState(() { _loading = false; _error = bioRes.error ?? 'Biometric failed.'; });
          return;
        }
      }

      _startSoft('Finalizing Secure Login…');
      final completeRes = await widget.api.complete(otpToken);
      if (!mounted || op != _opId) return;

      if (!completeRes.ok || completeRes.data == null) {
        _stopSoft();
        setState(() { _loading = false; _error = completeRes.message ?? 'Finalization failed.'; });
        return;
      }

      await AuthStorage.saveAccessToken(completeRes.data!);
      if (!mounted || op != _opId) return;

      _stopSoft();
      HapticFeedback.successNotification();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => FeedScreen(api: widget.api)),
        (_) => false,
      );
    } catch (e) {
      if (!mounted || op != _opId) return;
      _stopSoft();
      setState(() { _loading = false; _error = 'System Error: $e'; });
    } finally {
      if (mounted && op == _opId && !_softTimedOut) {
        setState(() { _loading = false; _stage = null; });
      }
    }
  }

  // ---------------------------------------------------------
  // REFINED UI BUILD
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final masked = _maskEmail(widget.userEmail);
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textMain),
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
                children: [
                  const Icon(Icons.mark_email_read_rounded, size: 72, color: AppColors.primary),
                  const SizedBox(height: 16),
                  const Text(
                    'Two-Step Verification',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28, 
                      fontWeight: FontWeight.w900, 
                      letterSpacing: -1.0,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 16, height: 1.4),
                      children: [
                        const TextSpan(text: "Enter the code sent to\n"),
                        TextSpan(
                          text: masked,
                          style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Input Field
                  _buildLabel('Verification Code'),
                  TextField(
                    controller: _otpC,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                    onChanged: (_) => setState(() => _error = null),
                    decoration: _inputDecoration('000000').copyWith(counterText: ""),
                  ),

                  // Status / Error Messages
                  if (_stage != null && _loading)
                    _StatusMessage(message: _stage!, color: AppColors.primary, icon: Icons.sync),

                  if (_error != null)
                    _StatusMessage(message: _error!, color: AppColors.error, icon: Icons.error_outline),

                  if (_otpDebug.isNotEmpty)
                    _StatusMessage(message: 'DEV OTP: $_otpDebug', color: Colors.blueGrey, icon: Icons.bug_report_outlined),

                  const SizedBox(height: 32),

                  // Main Verify Button
                  SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _loading ? null : _verify,
                      child: _loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                          : Text(_softTimedOut ? 'Retry Verification' : 'Verify & Continue', 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Resend Action
                  TextButton(
                    onPressed: (_loading || _secondsLeft > 0) ? null : _resend,
                    child: Text(
                      _secondsLeft > 0 ? 'Resend code in ${_secondsLeft}s' : 'Didn\'t receive a code? Resend OTP',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _secondsLeft > 0 ? AppColors.textMuted : AppColors.primary,
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

  // Reuse style helpers for consistency
  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textMain)),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
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

  // Internal Logic for resending (Preserving your flow)
  Future<void> _resend() async {
    if (_loading || _secondsLeft > 0) return;
    final int op = ++_opId;
    try {
      _startSoft('Resending OTP…');
      final res = await widget.api.resendOtp(_challengeId);
      if (!mounted || op != _opId) return;
      if (!res.ok) {
        _stopSoft();
        setState(() { _loading = false; _error = res.message ?? 'Resend failed.'; });
        return;
      }
      final dynamic raw = res.data!['challenge_id'];
      setState(() {
        _challengeId = (raw is num) ? raw.toInt() : int.tryParse(raw.toString()) ?? -1;
        _otpDebug = (res.data!['otp_debug'] ?? '').toString();
        _error = null; _loading = false;
      });
      _otpC.clear();
      _startTimer();
    } catch (e) {
      if (mounted && op == _opId) setState(() { _loading = false; _error = 'Resend error: $e'; });
    }
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
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
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