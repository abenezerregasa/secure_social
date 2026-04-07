import 'package:flutter/material.dart';
import '../models/post.dart';
import '../widgets/expandable_text.dart';
import '../core/app_theme.dart'; // Ensure this is imported for AppColors

class PostCard extends StatelessWidget {
  final Post post;
  final bool isMine;
  final bool isLikeBusy;
  final bool isLoading;
  final VoidCallback onLike;
  final VoidCallback onDelete;
  final VoidCallback onOpenComments;

  const PostCard({
    super.key,
    required this.post,
    required this.isMine,
    required this.isLikeBusy,
    required this.isLoading,
    required this.onLike,
    required this.onDelete,
    required this.onOpenComments,
  });

  String _initial(String email) {
    final e = email.trim();
    return e.isEmpty ? '?' : e[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Replacing Card with a Container for total control over borders/shadows
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16), // Increased padding for "breathability"
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header Section ---
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.accent.withOpacity(0.1),
                  child: Text(
                    _initial(post.authorEmail),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorEmail.split('@')[0], // Cleaner display name
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textMain,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        post.createdAt, // Ideally format this to "2h ago"
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isMine)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'delete') onDelete();
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    icon: Icon(Icons.more_horiz, color: Colors.grey[400]),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // --- Content Section ---
            ExpandableText(
              post.content.isNotEmpty ? post.content : '(empty post)',
              trimLines: 4,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4, // Better line height for readability
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 16),

            // --- Action Section ---
            Row(
              children: [
                _buildActionButton(
                  icon: post.likedByMe ? Icons.favorite : Icons.favorite_border,
                  label: '${post.likeCount}',
                  color: post.likedByMe ? Colors.red : AppColors.textMuted,
                  isLoading: isLikeBusy,
                  onTap: (isLoading || isLikeBusy) ? null : onLike,
                ),
                const SizedBox(width: 16),
                _buildActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '${post.commentCount}',
                  color: AppColors.textMuted,
                  isLoading: false,
                  onTap: isLoading ? null : onOpenComments,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // A helper for consistent, professional action buttons
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isLoading,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                  )
                : Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}