/// Modelo de Informações da Igreja
class ChurchInfo {
  final String id;
  final String name;
  final String? logoUrl;
  final String? mission;
  final String? vision;
  final List<String>? values;
  final String? history;
  final String? address;
  final String? phone;
  final String? email;
  final String? website;
  final Map<String, String>? socialMedia; // {'facebook': 'url', 'instagram': 'url', etc}
  final List<ServiceTime>? serviceTimes;
  final List<Pastor>? pastors;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ChurchInfo({
    required this.id,
    required this.name,
    this.logoUrl,
    this.mission,
    this.vision,
    this.values,
    this.history,
    this.address,
    this.phone,
    this.email,
    this.website,
    this.socialMedia,
    this.serviceTimes,
    this.pastors,
    required this.createdAt,
    this.updatedAt,
  });

  /// Criar a partir de JSON
  factory ChurchInfo.fromJson(Map<String, dynamic> json) {
    return ChurchInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      logoUrl: json['logo_url'] as String?,
      mission: json['mission'] as String?,
      vision: json['vision'] as String?,
      values: json['values'] != null
          ? List<String>.from(json['values'] as List)
          : null,
      history: json['history'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      socialMedia: json['social_media'] != null
          ? Map<String, String>.from(json['social_media'] as Map)
          : null,
      serviceTimes: json['service_times'] != null
          ? (json['service_times'] as List)
              .map((e) => ServiceTime.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      pastors: json['pastors'] != null
          ? (json['pastors'] as List)
              .map((e) => Pastor.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logo_url': logoUrl,
      'mission': mission,
      'vision': vision,
      'values': values,
      'history': history,
      'address': address,
      'phone': phone,
      'email': email,
      'website': website,
      'social_media': socialMedia,
      'service_times': serviceTimes?.map((e) => e.toJson()).toList(),
      'pastors': pastors?.map((e) => e.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

/// Modelo de Horário de Culto
class ServiceTime {
  final String day;
  final String time;
  final String? description;

  ServiceTime({
    required this.day,
    required this.time,
    this.description,
  });

  factory ServiceTime.fromJson(Map<String, dynamic> json) {
    return ServiceTime(
      day: json['day'] as String,
      time: json['time'] as String,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day': day,
      'time': time,
      'description': description,
    };
  }
}

/// Modelo de Pastor
class Pastor {
  final String name;
  final String? title; // Ex: "Pastor Titular", "Pastor Auxiliar"
  final String? photoUrl;
  final String? bio;

  Pastor({
    required this.name,
    this.title,
    this.photoUrl,
    this.bio,
  });

  factory Pastor.fromJson(Map<String, dynamic> json) {
    return Pastor(
      name: json['name'] as String,
      title: json['title'] as String?,
      photoUrl: json['photo_url'] as String?,
      bio: json['bio'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'title': title,
      'photo_url': photoUrl,
      'bio': bio,
    };
  }
}

