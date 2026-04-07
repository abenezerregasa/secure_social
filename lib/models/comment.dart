class Comment {
  final int id;
  final int postId;
  final int userId;
  final String authorEmail;
  final String content;
  final String createdAt;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.authorEmail,
    required this.content,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: (json['id'] as num).toInt(),
      postId: (json['post_id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      authorEmail: (json['author_email'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}