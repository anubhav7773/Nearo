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

  // Backward compatible getters
  String get userId => authorId;
  String get authorName => authorAlias;
  String? get authorAvatar => authorAvatarUrl;

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final authorName = (json['author_alias'] ??
            json['author_name'] ??
            json['alias_name'] ??
            json['alias'] ??
            'Verified Neighbor')
        .toString();

    final avatar = (json['author_avatar_url'] ??
            json['author_avatar'] ??
            json['avatar_url'])
        ?.toString();

    final tier = (json['author_tier'] ?? json['tier'] ?? 'free').toString();

    DateTime parsedDate = DateTime.now();
    if (json['created_at'] != null) {
      parsedDate =
          DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now();
    }

    return CommentModel(
      id: json['id']?.toString() ?? '',
      postId:
          (json['post_id'] ?? json['postId'])?.toString() ?? '',
      authorId:
          (json['author_id'] ?? json['user_id'] ?? json['userId'])?.toString() ??
              '',
      authorAlias: authorName,
      authorAvatarUrl: avatar,
      authorTier: tier,
      content: json['content']?.toString() ?? '',
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'author_id': authorId,
      'user_id': authorId,
      'author_alias': authorAlias,
      'author_name': authorAlias,
      'author_avatar_url': authorAvatarUrl,
      'author_avatar': authorAvatarUrl,
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
