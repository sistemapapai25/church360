// Modelo do perfil de padrinho/madrinha do Raízes (`raizes_sponsor_profile`,
// migration 20260513000003). Carrega info joined do user_account quando
// disponível.

class RaizesSponsorProfile {
  final String id;
  final String tenantId;
  final String ministryId;
  final String userId;
  final int? minAge;
  final int? maxAge;
  final List<String> maritalStatuses;
  final List<String> genders;
  final List<String> lifeStages;
  final List<String> interests;
  final bool isActive;
  final String? notes;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined user info (opcional — pode vir vazio em criações).
  final String? userFirstName;
  final String? userLastName;
  final String? userPhotoUrl;

  const RaizesSponsorProfile({
    required this.id,
    required this.tenantId,
    required this.ministryId,
    required this.userId,
    this.minAge,
    this.maxAge,
    required this.maritalStatuses,
    required this.genders,
    required this.lifeStages,
    required this.interests,
    required this.isActive,
    this.notes,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.userFirstName,
    this.userLastName,
    this.userPhotoUrl,
  });

  String get displayName {
    final first = (userFirstName ?? '').trim();
    final last = (userLastName ?? '').trim();
    final full = '$first $last'.trim();
    return full.isEmpty ? 'Padrinho/Madrinha' : full;
  }

  String get initial {
    final f = (userFirstName ?? '').trim();
    return f.isEmpty ? '?' : f.substring(0, 1).toUpperCase();
  }

  factory RaizesSponsorProfile.fromJson(Map<String, dynamic> json) {
    List<String> toStringList(dynamic raw) {
      if (raw is List) {
        return raw.whereType<String>().toList();
      }
      return const <String>[];
    }

    final user = json['user'] as Map<String, dynamic>?;

    return RaizesSponsorProfile(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      ministryId: json['ministry_id'] as String,
      userId: json['user_id'] as String,
      minAge: (json['min_age'] as num?)?.toInt(),
      maxAge: (json['max_age'] as num?)?.toInt(),
      maritalStatuses: toStringList(json['marital_statuses']),
      genders: toStringList(json['genders']),
      lifeStages: toStringList(json['life_stages']),
      interests: toStringList(json['interests']),
      isActive: json['is_active'] as bool? ?? true,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      userFirstName: user?['first_name'] as String?,
      userLastName: user?['last_name'] as String?,
      userPhotoUrl: user?['photo_url'] as String?,
    );
  }
}

/// Opções canônicas para os critérios de match (espelha os enums e a
/// convenção pt-BR de life_stages usada na RPC MR4C.1).
class SponsorCriteriaOptions {
  static const genders = <String, String>{
    'male': 'Masculino',
    'female': 'Feminino',
    'other': 'Outro',
  };

  static const maritalStatuses = <String, String>{
    'single': 'Solteiro(a)',
    'married': 'Casado(a)',
    'divorced': 'Divorciado(a)',
    'widowed': 'Viúvo(a)',
    'other': 'Outro',
  };

  static const lifeStages = <String, String>{
    'crianca': 'Criança',
    'adolescente': 'Adolescente',
    'jovem': 'Jovem',
    'adulto': 'Adulto',
    'idoso': 'Idoso',
  };
}
