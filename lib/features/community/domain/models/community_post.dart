class CommunityPost {
  final String id;
  final String authorId;
  final String content;
  final String type; // 'prayer_request', 'testimony', 'general'
  final String status; // 'pending_approval', 'approved', 'rejected'
  final int likesCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Novos campos
  final bool isPublic;
  final bool allowWhatsappContact;
  
  // Dados de Enquete
  final List<String> pollOptions;
  final Map<String, List<dynamic>> pollVotes; // Key: option index (as string), Value: list of user IDs

  // Dados do autor (join)
  final String? authorName;
  final String? authorAvatarUrl;
  final String? authorNickname;
  final String? authorPhone;

  // Estado local
  final bool isLikedByMe;
  final String? myReaction;

  CommunityPost({
    required this.id,
    required this.authorId,
    required this.content,
    required this.type,
    required this.status,
    required this.likesCount,
    required this.createdAt,
    required this.updatedAt,
    this.isPublic = false,
    this.allowWhatsappContact = false,
    this.pollOptions = const [],
    this.pollVotes = const {},
    this.authorName,
    this.authorAvatarUrl,
    this.authorNickname,
    this.authorPhone,
    this.isLikedByMe = false,
    this.myReaction,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'],
      authorId: json['author_id'],
      content: json['content'],
      type: json['type'],
      status: json['status'],
      likesCount: json['likes_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      isPublic: json['is_public'] ?? false,
      allowWhatsappContact: json['allow_whatsapp_contact'] ?? false,
      pollOptions: json['poll_options'] != null 
          ? List<String>.from(json['poll_options']) 
          : [],
      pollVotes: json['poll_votes'] != null
          ? Map<String, List<dynamic>>.from(json['poll_votes'])
          : {},
      authorName: json['author'] != null ? json['author']['full_name'] : null,
      authorAvatarUrl: json['author'] != null 
          ? (json['author']['avatar_url'] ?? json['author']['photo_url'] ?? json['author']['foto'])
          : null,
      authorNickname: json['author'] != null ? json['author']['nickname'] : null,
      authorPhone: json['author'] != null ? json['author']['phone'] : null,
      isLikedByMe: json['is_liked_by_me'] ?? false,
      myReaction: json['my_reaction'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author_id': authorId,
      'content': content,
      'type': type,
      'status': status,
      'likes_count': likesCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_public': isPublic,
      'allow_whatsapp_contact': allowWhatsappContact,
      'poll_options': pollOptions,
      'poll_votes': pollVotes,
    };
  }
}
