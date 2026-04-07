import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/comment.dart';
import '../services/api_service.dart';
import '../widgets/comment_widgets.dart';
import '../core/app_theme.dart';

class CommentsScreen extends StatefulWidget {
  const CommentsScreen({
    super.key,
    required this.api,
    required this.postId,
    required this.postContent,
    required this.postAuthorEmail,
    required this.postCreatedAt,
    required this.onCommentCountUpdated,
  });

  final Api api;
  final int postId;
  final String postContent;
  final String postAuthorEmail;
  final String postCreatedAt;
  final void Function(int newCount) onCommentCountUpdated;

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _c = TextEditingController();
  final _scroll = ScrollController();

  // State
  List<Comment> _comments = [];
  bool _loading = true;
  bool _posting = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  
  // Pagination Config
  int _currentOffset = 0;
  final int _limit = 20; 

  @override
  void initState() {
    super.initState();
    //  This listener ensures the button activates the millisecond you type
    _c.addListener(() => setState(() {})); 
    _scroll.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore &&
        !_loading) {
      _loadMore();
    }
  }

  String _initial(String email) => email.isNotEmpty ? email[0].toUpperCase() : '?';

  // ---------------------------------------------------------
  // REFINED PAGINATION LOGIC
  // ---------------------------------------------------------
  Future<void> _loadInitial() async {
    setState(() { _loading = true; _currentOffset = 0; });
    final res = await widget.api.getComments(widget.postId); 
    
    if (mounted) {
      final List<Comment> fetched = (res.data ?? []).reversed.toList();
      setState(() {
        _comments = fetched;
        _loading = false;
        _hasMore = fetched.length >= _limit;
        _currentOffset = fetched.length;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    // In a real API, call: widget.api.getComments(widget.postId, offset: _currentOffset, limit: _limit);
    await Future.delayed(const Duration(milliseconds: 800)); 
    
    if (mounted) {
      setState(() {
        _loadingMore = false;
        _hasMore = false; // Mocking end of list
      });
    }
  }

  Future<void> _add() async {
    final text = _c.text.trim();
    if (_posting || text.isEmpty) return;
    
    setState(() => _posting = true);
    final res = await widget.api.addComment(widget.postId, text);

    if (mounted) {
      if (res.ok) {
        _c.clear();
        FocusScope.of(context).unfocus();
        HapticFeedback.mediumImpact();
        widget.onCommentCountUpdated(res.data!);
        _loadInitial(); 
      }
      setState(() => _posting = false);
    }
  }

  // ---------------------------------------------------------
  // UI BUILD (Linked & Curative)
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Discussion', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // 1. Linked Post Header
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    child: PostHeaderContext(
                      content: widget.postContent,
                      authorEmail: widget.postAuthorEmail,
                      createdAt: widget.postCreatedAt,
                      getInitial: _initial,
                    ),
                  ),
                ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                // 2. Paginated Comments
                _buildSliverList(),

                // 3. Load More Indicator
                if (_loadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  ),
              ],
            ),
          ),
          
          // 4. Smart Composer
          _buildComposer(isKeyboardOpen),
        ],
      ),
    );
  }

  Widget _buildSliverList() {
    if (_loading) {
      return const SliverFillRemaining(child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (_comments.isEmpty) {
      return const SliverFillRemaining(child: Center(child: Text('No comments yet.', style: TextStyle(color: AppColors.textMuted))));
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CommentTile(comment: _comments[i], getInitial: _initial),
          ),
          childCount: _comments.length,
        ),
      ),
    );
  }

  Widget _buildComposer(bool isKeyboardOpen) {
    // Check if button should be active
    final bool hasText = _c.text.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(
        12, 8, 12, 
        isKeyboardOpen ? 8 : MediaQuery.of(context).padding.bottom + 12
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black.withOpacity(0.05))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: BoxConstraints(maxHeight: isKeyboardOpen ? 90 : 160),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9), 
                borderRadius: BorderRadius.circular(22)
              ),
              child: TextField(
                controller: _c,
                maxLines: isKeyboardOpen ? 3 : 6,
                minLines: 1,
                style: const TextStyle(fontSize: 15, height: 1.3),
                decoration: const InputDecoration(
                  hintText: 'Write a comment...',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildSendButton(hasText),
        ],
      ),
    );
  }

  Widget _buildSendButton(bool active) {
    if (_posting) {
      return const SizedBox(
        width: 44, height: 44,
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: IconButton.filled(
        onPressed: active ? _add : null,
        icon: const Icon(Icons.arrow_upward_rounded, size: 22),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.accent,
          disabledBackgroundColor: Colors.grey.shade200,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}