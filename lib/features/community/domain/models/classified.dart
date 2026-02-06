class Classified {
  final String id;
  final String authorId;
  final String title;
  final String description;
  final double? price;
  final String category; // 'product', 'service', 'job', 'donation'
  final String? contactInfo;
  final List<String> imageUrls;
  final String status; // 'pending_approval', 'approved', 'rejected'
  final String dealStatus; // 'available', 'sold', 'bought', 'donated'
  final int viewsCount;
  final int likesCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Dados do autor (join)
  final String? authorName;
  final String? authorAvatarUrl;
  final String? authorNickname;
  final bool isLikedByMe;
  final String? myReaction;

  Classified({
    required this.id,
    required this.authorId,
    required this.title,
    required this.description,
    this.price,
    required this.category,
    this.contactInfo,
    this.imageUrls = const [],
    required this.status,
    this.dealStatus = 'available',
    this.viewsCount = 0,
    this.likesCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.authorName,
    this.authorAvatarUrl,
    this.authorNickname,
    this.isLikedByMe = false,
    this.myReaction,
  });

  factory Classified.fromJson(Map<String, dynamic> json) {
    return Classified(
      id: json['id'],
      authorId: json['author_id'],
      title: json['title'],
      description: json['description'],
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      category: json['category'],
      contactInfo: json['contact_info'],
      imageUrls: json['image_urls'] != null 
          ? List<String>.from(json['image_urls']) 
          : [],
      status: json['status'],
      dealStatus: (json['deal_status'] ?? 'available').toString(),
      viewsCount: json['views_count'] ?? 0,
      likesCount: json['likes_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      authorName: json['author'] != null ? json['author']['full_name'] : null,
      authorAvatarUrl: json['author'] != null 
          ? (json['author']['avatar_url'] ?? json['author']['photo_url'] ?? json['author']['foto'])
          : null,
      authorNickname: json['author'] != null ? json['author']['nickname'] ?? json['author']['apelido'] : null,
      isLikedByMe: json['is_liked_by_me'] ?? false,
      myReaction: json['my_reaction'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author_id': authorId,
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'contact_info': contactInfo,
      'image_urls': imageUrls,
      'status': status,
      'deal_status': dealStatus,
      'views_count': viewsCount,
      'likes_count': likesCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
