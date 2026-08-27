class CommentModel {
  final String id;
  final String postId;
  final String authorId;
  final String authorAlias;
  final String? authorAvatarUrl;
  final String authorTier;
  final String content;
  final DateTime createdAt;

  CommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorAlias,
    this.authorAvatarUrl,
    this.authorTier = 'free',
    required this.content,
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id']?.toString() ?? '',
      postId: json['post_id']?.toString() ?? '',
      authorId: json['author_id']?.toString() ?? '',
      authorAlias: json['author_alias'] as String? ?? 'Resident',
      authorAvatarUrl: json['author_avatar_url'] as String?,
      authorTier: json['author_tier'] as String? ?? 'free',
      content: json['content'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'author_id': authorId,
      'author_alias': authorAlias,
      'author_avatar_url': authorAvatarUrl,
      'author_tier': authorTier,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get timeAgoFormatted {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}
