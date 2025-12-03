/// Modelo de Informações de Contribuição
class ContributionInfo {
  final String id;
  final String churchName;
  final String? pixKey;
  final String? pixType; // CPF, CNPJ, Email, Telefone, Aleatória
  final String? bankName;
  final String? bankCode;
  final String? agency;
  final String? accountNumber;
  final String? accountType; // Corrente, Poupança
  final String? accountHolder;
  final String? accountHolderDocument; // CPF/CNPJ
  final String? instructions;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ContributionInfo({
    required this.id,
    required this.churchName,
    this.pixKey,
    this.pixType,
    this.bankName,
    this.bankCode,
    this.agency,
    this.accountNumber,
    this.accountType,
    this.accountHolder,
    this.accountHolderDocument,
    this.instructions,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Criar a partir de JSON
  factory ContributionInfo.fromJson(Map<String, dynamic> json) {
    return ContributionInfo(
      id: json['id'] as String,
      churchName: json['church_name'] as String,
      pixKey: json['pix_key'] as String?,
      pixType: json['pix_type'] as String?,
      bankName: json['bank_name'] as String?,
      bankCode: json['bank_code'] as String?,
      agency: json['agency'] as String?,
      accountNumber: json['account_number'] as String?,
      accountType: json['account_type'] as String?,
      accountHolder: json['account_holder'] as String?,
      accountHolderDocument: json['account_holder_document'] as String?,
      instructions: json['instructions'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'church_name': churchName,
      'pix_key': pixKey,
      'pix_type': pixType,
      'bank_name': bankName,
      'bank_code': bankCode,
      'agency': agency,
      'account_number': accountNumber,
      'account_type': accountType,
      'account_holder': accountHolder,
      'account_holder_document': accountHolderDocument,
      'instructions': instructions,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Copiar com alterações
  ContributionInfo copyWith({
    String? id,
    String? churchName,
    String? pixKey,
    String? pixType,
    String? bankName,
    String? bankCode,
    String? agency,
    String? accountNumber,
    String? accountType,
    String? accountHolder,
    String? accountHolderDocument,
    String? instructions,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ContributionInfo(
      id: id ?? this.id,
      churchName: churchName ?? this.churchName,
      pixKey: pixKey ?? this.pixKey,
      pixType: pixType ?? this.pixType,
      bankName: bankName ?? this.bankName,
      bankCode: bankCode ?? this.bankCode,
      agency: agency ?? this.agency,
      accountNumber: accountNumber ?? this.accountNumber,
      accountType: accountType ?? this.accountType,
      accountHolder: accountHolder ?? this.accountHolder,
      accountHolderDocument: accountHolderDocument ?? this.accountHolderDocument,
      instructions: instructions ?? this.instructions,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContributionInfo &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ContributionInfo(id: $id, churchName: $churchName, isActive: $isActive)';
  }
}

