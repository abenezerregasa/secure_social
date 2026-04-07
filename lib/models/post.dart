class Post {
  final int id;
  final int userId; //  owner id (from backend user_id)
  final String content;
  final String authorEmail;
  final String createdAt;

  int likeCount;
  bool likedByMe;
  int commentCount;

  Post({
    required this.id,
    required this.userId,
    required this.content,
    required this.authorEmail,
    required this.createdAt,
    this.likeCount = 0,
    this.likedByMe = false,
    this.commentCount = 0,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(), //  map user_id -> userId
      content: (json['content'] ?? '').toString(),
      authorEmail: (json['author_email'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      likeCount: (json['like_count'] is num) ? (json['like_count'] as num).toInt() : 0,
      likedByMe: json['liked_by_me'] == true,
      commentCount: (json['comment_count'] is num) ? (json['comment_count'] as num).toInt() : 0,
    );
  }
}