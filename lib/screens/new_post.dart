import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../core/app_theme.dart';

class NewPostScreen extends StatefulWidget {
  const NewPostScreen({super.key, required this.api});

  final Api api;

  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> {
  // ---------------------------------------------------------
  // STATE & LOGIC (Preserving your exact logic flow)
  // ---------------------------------------------------------
  final _contentC = TextEditingController();

  bool _submitting = false;
  bool _softTimedOut = false;
  String? _error;

  Timer? _softTimer;
  int _reqId = 0;

  String get _trimmed => _contentC.text.trim();

  bool get _canSubmit {
    if (_submitting) return false;
    return _trimmed.isNotEmpty && _trimmed.length <= 50000;
  }

  void _startSoftTimeout(int myReqId) {
    _softTimer?.cancel();
    _softTimedOut = false;
    _softTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (_submitting && myReqId == _reqId) {
        setState(() {
          _softTimedOut = true;
          _submitting = false;
          _error = _error ?? 'Taking longer than usual…';
        });
      }
    });
  }

  void _stopSoftTimeout() {
    _softTimer?.cancel();
    _softTimer = null;
    _softTimedOut = false;
  }

  Future<void> _submit() async {
    if (_submitting) return;

    FocusScope.of(context).unfocus();
    final content = _trimmed;

    if (content.isEmpty) {
      setState(() => _error = 'Post content cannot be empty.');
      return;
    }

    _reqId++;
    final myReqId = _reqId;

    setState(() {
      _submitting = true;
      _softTimedOut = false;
      _error = null;
    });

    _startSoftTimeout(myReqId);

    try {
      final res = await widget.api.createPost(content);

      if (!mounted || myReqId != _reqId) return;

      _stopSoftTimeout();

      if (!res.ok) {
        if (res.message == 'unauthorized') {
          setState(() {
            _submitting = false;
            _error = 'Session expired. Please login again.';
          });
          return;
        }

        setState(() {
          _submitting = false;
          _error = res.message ?? 'Create failed';
        });
        return;
      }

      HapticFeedback.successNotification(); // Serious UI polish
      setState(() => _submitting = false);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted || myReqId != _reqId) return;
      _stopSoftTimeout();
      setState(() {
        _submitting = false;
        _error = 'Create error: $e';
      });
    }
  }

  @override
  void dispose() {
    _softTimer?.cancel();
    _contentC.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------
  // REFINED UI BUILD
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final len = _trimmed.length;

    return Scaffold(
      backgroundColor: Colors.white, // Pure white for creation "canvas"
      appBar: AppBar(
        title: const Text(
          'New Post',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.primary,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, size: 26),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                disabledBackgroundColor: AppColors.accent.withOpacity(0.3),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: _canSubmit ? _submit : null,
              child: _submitting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Post', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_submitting) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _contentC,
                    maxLines: null, // Dynamic height is more professional
                    minLines: 5,
                    maxLength: 50000,
                    style: const TextStyle(fontSize: 18, height: 1.5, color: AppColors.textMain),
                    decoration: const InputDecoration(
                      hintText: "What's happening?",
                      hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 18),
                      border: InputBorder.none,
                      counterText: "", // Moving counter to a custom widget for "integrity"
                    ),
                    onChanged: (_) {
                      setState(() {
                        _error = null;
                        if (_softTimedOut) _softTimedOut = false;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_error != null) _buildErrorCard(),
                  if (_softTimedOut) _buildTimeoutActions(),
                ],
              ),
            ),
          ),
          _buildBottomToolbar(len),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildBottomToolbar(int len) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Icon(Icons.image_outlined, color: AppColors.accent.withOpacity(0.5)),
          const SizedBox(width: 20),
          Icon(Icons.alternate_email_rounded, color: AppColors.accent.withOpacity(0.5)),
          const Spacer(),
          Text(
            '$len / 50000',
            style: TextStyle(
              color: len > 45000 ? AppColors.error : AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeoutActions() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('Connection is slow...', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _softTimedOut = false),
                  child: const Text('Cancel'),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: _submit,
                  child: const Text('Retry Now', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}