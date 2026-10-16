/// Ficha da criança (cartilha do Infantil §6 e §5.3): saúde, comportamento
/// e autorização de imagem. Tabela `kids_child_profile`, gravada só pela RPC
/// `kids_save_child_profile`.
class KidsChildProfile {
  final String childId;
  final String? allergies;
  final String? intolerances;
  final String? medications;
  final String? specialNeeds;
  final String? behaviorProfile;
  final String? notes;
  final bool imageConsent;
  final DateTime? imageConsentAt;

  const KidsChildProfile({
    required this.childId,
    this.allergies,
    this.intolerances,
    this.medications,
    this.specialNeeds,
    this.behaviorProfile,
    this.notes,
    this.imageConsent = false,
    this.imageConsentAt,
  });

  /// Alergia ou intolerância cadastrada: vira selo vermelho na lista
  /// e orienta o lanche (cartilha §8.3).
  bool get hasFoodAlert =>
      (allergies?.trim().isNotEmpty ?? false) ||
      (intolerances?.trim().isNotEmpty ?? false);

  factory KidsChildProfile.fromJson(Map<String, dynamic> json) {
    return KidsChildProfile(
      childId: json['child_id'] as String,
      allergies: json['allergies'] as String?,
      intolerances: json['intolerances'] as String?,
      medications: json['medications'] as String?,
      specialNeeds: json['special_needs'] as String?,
      behaviorProfile: json['behavior_profile'] as String?,
      notes: json['notes'] as String?,
      imageConsent: json['image_consent'] as bool? ?? false,
      imageConsentAt: json['image_consent_at'] != null
          ? DateTime.parse(json['image_consent_at'] as String)
          : null,
    );
  }
}
