import 'package:flutter/material.dart';
import '../models/comment.dart';
import '../core/app_theme.dart';

class CommentTile extends StatelessWidget {
  final Comment comment;
  final String Function(String) getInitial;

  const CommentTile({super.key, required this.comment, required this.getInitial});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Elevated CircleAvatar for a more polished look
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Text(
                getInitial(comment.authorEmail), 
                style: const TextStyle(
                  color: AppColors.accent, 
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row for metadata
                Row(
                  children: [
                    Text(
                      comment.authorEmail.split('@')[0],
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "• ${comment.createdAt}",
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Comment content with better line height
                Text(
                  comment.content,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMain,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PostHeaderContext extends StatelessWidget {
  final String content, authorEmail, createdAt;
  final String Function(String) getInitial;

  const PostHeaderContext({
    super.key, required this.content, required this.authorEmail, 
    required this.createdAt, required this.getInitial
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  getInitial(authorEmail), 
                  style: const TextStyle(
                    color: AppColors.primary, 
                    fontSize: 10, 
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                authorEmail.split('@')[0],
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: AppColors.textMain,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  createdAt,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textMain,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class CommentComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool isPosting;
  final VoidCallback onSend;
  final ValueChanged<String> onChanged;

  const CommentComposer({
    super.key, required this.controller, required this.isPosting, 
    required this.onSend, required this.onChanged
  });

  @override
  Widget build(BuildContext context) {
    // Determine if we should enable the send button
    final bool canSend = controller.text.trim().isNotEmpty && !isPosting;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end, // Aligns button with bottom of text
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9), // Slate 100
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  minLines: 1,
                  maxLines: 5,
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Share your thoughts...',
                    hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Maintain your 48px fixed width logic to prevent overflow
            SizedBox(
              width: 48,
              height: 48,
              child: isPosting
                  ? const Center(
                      child: SizedBox(
                        width: 20, 
                        height: 20, 
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                      ),
                    )
                  : IconButton.filled(
                      onPressed: canSend ? onSend : null,
                      icon: const Icon(Icons.arrow_upward_rounded, size: 22),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        disabledBackgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}