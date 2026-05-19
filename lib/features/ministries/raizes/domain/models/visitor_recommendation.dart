// Modelo da sugestão de padrinho/madrinha gerada pelo MR4C.1.
// Reflete `visitor_recommendation` (migration 20260515000003) + opcionalmente
// info joined de visitor + sponsor (queries que precisam mostrar nomes).

enum VisitorRecommendationStatus {
  pending('pending', 'Pendente'),
  accepted('accepted', 'Aceita'),
  rejected('rejected', 'Recusada'),
  archived('archived', 'Arquivada');

  final String value;
  final String label;
  const VisitorRecommendationStatus(this.value, this.label);

  static VisitorRecommendationStatus fromValue(String value) {
    return VisitorRecommendationStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => VisitorRecommendationStatus.pending,
    );
  }
}

class VisitorRecommendation {
  final String id;
  final String tenantId;
  final String ministryId;
  final String visitorId;
  final String sponsorProfileId;
  final int score;
  final List<String> reasons;
  final VisitorRecommendationStatus status;
  final String? decidedBy;
  final DateTime? decidedAt;
  final String? notes;
  final DateTime generatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined: visitante.
  final String? visitorFirstName;
  final String? visitorLastName;
  final String? visitorPhotoUrl;

  // Joined: padrinho (vem do sponsor_profile.user).
  final String? sponsorUserId;
  final String? sponsorFirstName;
  final String? sponsorLastName;
  final String? sponsorPhotoUrl;

  const VisitorRecommendation({
    required this.id,
    required this.tenantId,
    required this.ministryId,
    required this.visitorId,
    required this.sponsorProfileId,
    required this.score,
    required this.reasons,
    required this.status,
    this.decidedBy,
    this.decidedAt,
    this.notes,
    required this.generatedAt,
    required this.createdAt,
    required this.updatedAt,
    this.visitorFirstName,
    this.visitorLastName,
    this.visitorPhotoUrl,
    this.sponsorUserId,
    this.sponsorFirstName,
    this.sponsorLastName,
    this.sponsorPhotoUrl,
  });

  String get visitorDisplayName {
    final first = (visitorFirstName ?? '').trim();
    final last = (visitorLastName ?? '').trim();
    final full = '$first $last'.trim();
    return full.isEmpty ? 'Visitante' : full;
  }

  String get sponsorDisplayName {
    final first = (sponsorFirstName ?? '').trim();
    final last = (sponsorLastName ?? '').trim();
    final full = '$first $last'.trim();
    return full.isEmpty ? 'Padrinho/Madrinha' : full;
  }

  factory VisitorRecommendation.fromJson(Map<String, dynamic> json) {
    final rawReasons = json['reasons'];
    final reasons = <String>[];
    if (rawReasons is List) {
      for (final r in rawReasons) {
        if (r is String) reasons.add(r);
      }
    }

    final visitor = json['visitor'] as Map<String, dynamic>?;
    final sponsorProfile = json['sponsor_profile'] as Map<String, dynamic>?;
    final sponsorUser = sponsorProfile?['user'] as Map<String, dynamic>?;

    return VisitorRecommendation(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      ministryId: json['ministry_id'] as String,
      visitorId: json['visitor_id'] as String,
      sponsorProfileId: json['sponsor_profile_id'] as String,
      score: (json['score'] as num?)?.toInt() ?? 0,
      reasons: reasons,
      status: VisitorRecommendationStatus.fromValue(
        (json['status'] as String?) ?? 'pending',
      ),
      decidedBy: json['decided_by'] as String?,
      decidedAt: json['decided_at'] != null
          ? DateTime.parse(json['decided_at'] as String)
          : null,
      notes: json['notes'] as String?,
      generatedAt: DateTime.parse(json['generated_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      visitorFirstName: visitor?['first_name'] as String?,
      visitorLastName: visitor?['last_name'] as String?,
      visitorPhotoUrl: visitor?['photo_url'] as String?,
      sponsorUserId: sponsorProfile?['user_id'] as String?,
      sponsorFirstName: sponsorUser?['first_name'] as String?,
      sponsorLastName: sponsorUser?['last_name'] as String?,
      sponsorPhotoUrl: sponsorUser?['photo_url'] as String?,
    );
  }
}

/// Helper para converter um reason string ("age_in_range:25", "interest:filhos")
/// em um label legível em pt-BR.
String formatRecommendationReason(String reason) {
  final colonIdx = reason.indexOf(':');
  final key = colonIdx == -1 ? reason : reason.substring(0, colonIdx);
  final value = colonIdx == -1 ? '' : reason.substring(colonIdx + 1);

  switch (key) {
    case 'age_in_range':
      return 'Idade ($value anos) dentro da faixa';
    case 'gender_match':
      return 'Gênero compatível (${_translateGender(value)})';
    case 'marital_status_match':
      return 'Estado civil compatível (${_translateMaritalStatus(value)})';
    case 'life_stage_match':
      return 'Etapa de vida (${_translateLifeStage(value)})';
    case 'interest':
      return 'Interesse em comum: $value';
    default:
      return reason;
  }
}

String _translateGender(String v) {
  switch (v.toLowerCase()) {
    case 'male':
      return 'Masculino';
    case 'female':
      return 'Feminino';
    default:
      return v;
  }
}

String _translateMaritalStatus(String v) {
  switch (v.toLowerCase()) {
    case 'single':
      return 'Solteiro(a)';
    case 'married':
      return 'Casado(a)';
    case 'divorced':
      return 'Divorciado(a)';
    case 'widowed':
      return 'Viúvo(a)';
    default:
      return v;
  }
}

String _translateLifeStage(String v) {
  switch (v.toLowerCase()) {
    case 'crianca':
      return 'Criança';
    case 'adolescente':
      return 'Adolescente';
    case 'jovem':
      return 'Jovem';
    case 'adulto':
      return 'Adulto';
    case 'idoso':
      return 'Idoso';
    default:
      return v;
  }
}
