import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for HapticFeedback

import '../auth_storage.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../core/app_theme.dart';
import '../widgets/post_card.dart';
import '../widgets/feed_state_widgets.dart';
import '../widgets/main_drawer.dart';
import 'login.dart';
import 'new_post.dart';
import 'comments_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, required this.api});
  final Api api;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  // ---------------------------
  // STATE VARIABLES (UNCHANGED)
  // ---------------------------
  int? _myUserId;
  bool _loading = true;
  String? _error;
  List<Post> _posts = [];
  final Set<int> _likeBusy = {};
  static const int _pageSize = 10;
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  // ---------------------------
  // LOGIC HELPERS (UNCHANGED)
  // ---------------------------
  int? _extractUserIdFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final obj = jsonDecode(decoded);
      final sub = obj['sub'];
      if (sub == null) return null;
      if (sub is num) return sub.toInt();
      return int.tryParse(sub.toString());
    } catch (_) {
      return null;
    }
  }

  List<Post> get _visiblePosts {
    final count = _visibleCount.clamp(0, _posts.length);
    return _posts.take(count).toList();
  }

  bool get _hasMore => _visibleCount < _posts.length;

  void _loadMore() {
    HapticFeedback.mediumImpact(); // Serious UI feedback
    setState(() => _visibleCount += _pageSize);
  }

  // ---------------------------
  // AUTH & BOOTSTRAP (UNCHANGED)
  // ---------------------------
  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final token = await AuthStorage.getAccessToken();
    if (!mounted) return;

    if (token == null || token.isEmpty) {
      setState(() {
        _myUserId = null;
        _loading = false;
        _error = 'No access token found. Please login again.';
      });
      return;
    }

    setState(() {
      _myUserId = _extractUserIdFromJwt(token);
    });

    await _loadPosts(showSpinner: true);
  }

  Future<void> _forceLogout() async {
    await AuthStorage.deleteAccessToken();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen(api: widget.api)),
      (_) => false,
    );
  }

  // ---------------------------
  // API ACTIONS (UNCHANGED)
  // ---------------------------
  Future<void> _loadPosts({bool showSpinner = false}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final res = await widget.api.getPosts();

    if (!mounted) return;

    if (!res.ok && res.message == 'unauthorized') {
      await _forceLogout();
      return;
    }

    if (!res.ok || res.data == null) {
      setState(() {
        _loading = false;
        _error = res.message ?? 'Failed to load posts.';
      });
      return;
    }

    setState(() {
      _posts = res.data!;
      _visibleCount = _pageSize;
      _loading = false;
      _error = null;
    });
  }

  Future<void> _goNewPost() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NewPostScreen(api: widget.api),
      ),
    );

    if (created == true) {
      await _loadPosts(showSpinner: true);
    }
  }

  Future<void> _deletePostConfirmed(Post p) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Post', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('This action cannot be undone. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (yes != true) return;

    final res = await widget.api.deletePost(p.id);
    if (!mounted) return;

    if (!res.ok && res.message == 'unauthorized') {
      await _forceLogout();
      return;
    }

    if (!res.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message ?? 'Delete failed.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _posts.removeWhere((x) => x.id == p.id));
  }

  Future<void> _toggleLike(Post p) async {
    if (_likeBusy.contains(p.id)) return;

    HapticFeedback.lightImpact(); // Professional tactile feel
    _likeBusy.add(p.id);
    if (mounted) setState(() {});

    final oldLiked = p.likedByMe;
    final oldCount = p.likeCount;

    setState(() {
      p.likedByMe = !oldLiked;
      p.likeCount = p.likeCount + (p.likedByMe ? 1 : -1);
    });

    final res = p.likedByMe
        ? await widget.api.likePost(p.id)
        : await widget.api.unlikePost(p.id);

    if (!mounted) return;

    _likeBusy.remove(p.id);

    if (!res.ok && res.message == 'unauthorized') {
      await _forceLogout();
      return;
    }

    if (!res.ok || res.data == null) {
      setState(() {
        p.likedByMe = oldLiked;
        p.likeCount = oldCount;
      });
      return;
    }

    setState(() {
      p.likeCount = (res.data!['like_count'] as num).toInt();
      p.likedByMe = res.data!['liked_by_me'] == true;
    });
  }

  Future<void> _openComments(Post p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommentsScreen(
          api: widget.api,
          postId: p.id,
          postContent: p.content,
          postAuthorEmail: p.authorEmail,
          postCreatedAt: p.createdAt,
          onCommentCountUpdated: (newCount) {
            setState(() => p.commentCount = newCount);
          },
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _forceLogout();
    }
  }

  // ---------------------------
  // BUILD METHODS (MODERN UI)
  // ---------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100 - Very professional background
      appBar: AppBar(
        title: const Text(
          'Home Feed',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
            color: AppColors.primary,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.primary),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _loadPosts(showSpinner: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.black.withOpacity(0.05), height: 1),
        ),
      ),

      drawer: MainDrawer(
        userEmail: _posts.isNotEmpty ? _posts.first.authorEmail : "My Account",
        onLogout: () {
          Navigator.pop(context);
          _logout();
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: _loading ? null : _goNewPost,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("New Post", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),

      body: _loading
          ? _buildSkeletonLoader()
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => _loadPosts(showSpinner: false),
              child: (_error != null)
                  ? _buildErrorUI()
                  : (_posts.isEmpty)
                      ? _buildEmptyUI()
                      : _buildListUI(),
            ),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (_, __) => Container(
        height: 180,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildErrorUI() {
    return ListView(
      children: [
        const SizedBox(height: 120),
        FeedErrorState(
          message: _error!,
          onRetry: () => _loadPosts(showSpinner: true),
        ),
      ],
    );
  }

  Widget _buildEmptyUI() {
    return ListView(
      children: [
        const SizedBox(height: 120),
        FeedEmptyState(onCreatePost: _goNewPost),
      ],
    );
  }

  Widget _buildListUI() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _visiblePosts.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, i) {
        if (_hasMore && i == _visiblePosts.length) {
          return _buildLoadMoreButton();
        }

        final p = _visiblePosts[i];
        return PostCard(
          post: p,
          isMine: (_myUserId != null && p.userId == _myUserId),
          isLikeBusy: _likeBusy.contains(p.id),
          isLoading: _loading,
          onLike: () => _toggleLike(p),
          onDelete: () => _deletePostConfirmed(p),
          onOpenComments: () => _openComments(p),
        );
      },
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: _loadMore,
          icon: const Icon(Icons.expand_more_rounded),
          label: Text('Load More (${_posts.length - _visibleCount} remaining)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textMuted,
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),
    );
  }
}