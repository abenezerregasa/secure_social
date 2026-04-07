import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class FeedEmptyState extends StatelessWidget {
  final VoidCallback onCreatePost;
  const FeedEmptyState({super.key, required this.onCreatePost});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Using a softer background for the icon to make it look "designed"
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded, 
                size: 64, 
                color: AppColors.accent
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your feed is quiet', 
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.w800,
                color: AppColors.textMain,
                letterSpacing: -0.5,
              )
            ),
            const SizedBox(height: 12),
            const Text(
              'Be the pioneer of this community. Share your thoughts and start a conversation today.',
              textAlign: TextAlign.center, 
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 15,
                height: 1.5,
              )
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onCreatePost, 
                icon: const Icon(Icons.add_rounded, size: 20), 
                label: const Text(
                  'Create First Post',
                  style: TextStyle(fontWeight: FontWeight.bold),
                )
              ),
            )
          ],
        ),
      ),
    );
  }
}

class FeedErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const FeedErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.cloud_off_rounded, 
                size: 48, 
                color: AppColors.error
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Connection Issue', 
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.w700,
                color: AppColors.textMain
              )
            ),
            const SizedBox(height: 12),
            Text(
              message, 
              textAlign: TextAlign.center, 
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              )
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: onRetry, 
              icon: const Icon(Icons.refresh_rounded, size: 20), 
              label: const Text(
                'Try Again',
                style: TextStyle(fontWeight: FontWeight.w700),
              )
            ),
          ],
        ),
      ),
    );
  }
}