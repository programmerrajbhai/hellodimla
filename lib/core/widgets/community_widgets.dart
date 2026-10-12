import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.muted,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

class ContentState extends StatelessWidget {
  const ContentState({
    super.key,
    required this.loading,
    required this.error,
    required this.empty,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.child,
    required this.onRetry,
  });

  final bool loading;
  final String error;
  final bool empty;
  final String emptyTitle;
  final String emptyMessage;
  final Widget child;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (error.isNotEmpty) {
      return EmptyPanel(
        icon: Icons.cloud_off_rounded,
        title: error,
        message: 'সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।',
        action: 'আবার চেষ্টা',
        onAction: onRetry,
      );
    }

    if (empty) {
      return EmptyPanel(
        icon: Icons.inbox_outlined,
        title: emptyTitle,
        message: emptyMessage,
      );
    }

    return child;
  }
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7EBE4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              height: 1.5,
            ),
          ),
          if (action != null && onAction != null) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: onAction,
              child: Text(action!),
            ),
          ],
        ],
      ),
    );
  }
}

class CommunityImage extends StatelessWidget {
  const CommunityImage({
    super.key,
    required this.url,
    this.height = 110,
    this.width,
    this.icon = Icons.shopping_bag_outlined,
  });

  final String url;
  final double height;
  final double? width;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      height: height,
      width: width,
      color: const Color(0xFFEEF1E8),
      child: Center(
        child: Icon(
          icon,
          size: 34,
          color: AppColors.pine,
        ),
      ),
    );

    if (url.isEmpty) return fallback;

    return Image.network(
      url,
      height: height,
      width: width,
      fit: BoxFit.cover,
      errorBuilder: (_, error, stackTrace) => fallback,
      loadingBuilder: (context, child, progress) {
        return progress == null ? child : fallback;
      },
    );
  }
}

/// Temporary body for destination screens not implemented yet.
class FeatureStarter extends StatelessWidget {
  const FeatureStarter({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: EmptyPanel(
            icon: Icons.auto_awesome_outlined,
            title: 'শীঘ্রই আসছে',
            message: 'এই বিভাগ প্রস্তুত হচ্ছে।',
          ),
        ),
      ),
    );
  }
}