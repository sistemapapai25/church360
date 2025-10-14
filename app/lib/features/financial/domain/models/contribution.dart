/// Modelo de contribuição financeira
class Contribution {
  final String id;
  final String? memberId;
  final String? memberName;
  final ContributionType type;
  final double amount;
  final PaymentMethod paymentMethod;
  final DateTime date;
  final String? description;
  final String? notes;
  final DateTime createdAt;

  const Contribution({
    required this.id,
    this.memberId,
    this.memberName,
    required this.type,
    required this.amount,
    required this.paymentMethod,
    required this.date,
    this.description,
    this.notes,
    required this.createdAt,
  });

  factory Contribution.fromJson(Map<String, dynamic> json) {
    return Contribution(
      id: json['id'] as String,
      memberId: json['member_id'] as String?,
      memberName: json['member'] != null
          ? '${json['member']['first_name']} ${json['member']['last_name']}'
          : null,
      type: ContributionType.fromValue(json['type'] as String),
      amount: (json['amount'] as num).toDouble(),
      paymentMethod: PaymentMethod.fromValue(json['payment_method'] as String),
      date: DateTime.parse(json['date'] as String),
      description: json['description'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'member_id': memberId,
      'type': type.value,
      'amount': amount,
      'payment_method': paymentMethod.value,
      'date': date.toIso8601String().split('T')[0],
      'description': description,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Contribution copyWith({
    String? id,
    String? memberId,
    String? memberName,
    ContributionType? type,
    double? amount,
    PaymentMethod? paymentMethod,
    DateTime? date,
    String? description,
    String? notes,
    DateTime? createdAt,
  }) {
    return Contribution(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      date: date ?? this.date,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Tipo de contribuição
enum ContributionType {
  tithe('tithe', 'Dízimo'),
  offering('offering', 'Oferta'),
  missions('missions', 'Missões'),
  building('building', 'Construção'),
  special('special', 'Especial'),
  other('other', 'Outro');

  final String value;
  final String label;

  const ContributionType(this.value, this.label);

  static ContributionType fromValue(String value) {
    return ContributionType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ContributionType.other,
    );
  }
}

/// Método de pagamento
enum PaymentMethod {
  cash('cash', 'Dinheiro'),
  debit('debit', 'Débito'),
  credit('credit', 'Crédito'),
  pix('pix', 'PIX'),
  transfer('transfer', 'Transferência'),
  check('check', 'Cheque'),
  other('other', 'Outro');

  final String value;
  final String label;

  const PaymentMethod(this.value, this.label);

  static PaymentMethod fromValue(String value) {
    return PaymentMethod.values.firstWhere(
      (method) => method.value == value,
      orElse: () => PaymentMethod.other,
    );
  }
}

/// Modelo de meta financeira
class FinancialGoal {
  final String id;
  final String name;
  final String? description;
  final double targetAmount;
  final double currentAmount;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FinancialGoal({
    required this.id,
    required this.name,
    this.description,
    required this.targetAmount,
    required this.currentAmount,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  double get progress => currentAmount / targetAmount;
  int get progressPercentage => (progress * 100).round();
  double get remaining => targetAmount - currentAmount;

  factory FinancialGoal.fromJson(Map<String, dynamic> json) {
    return FinancialGoal(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      targetAmount: (json['target_amount'] as num).toDouble(),
      currentAmount: (json['current_amount'] as num).toDouble(),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Modelo de despesa
class Expense {
  final String id;
  final String category;
  final double amount;
  final PaymentMethod paymentMethod;
  final DateTime date;
  final String description;
  final String? notes;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.paymentMethod,
    required this.date,
    required this.description,
    this.notes,
    required this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      paymentMethod: PaymentMethod.fromValue(json['payment_method'] as String),
      date: DateTime.parse(json['date'] as String),
      description: json['description'] as String,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'amount': amount,
      'payment_method': paymentMethod.value,
      'date': date.toIso8601String().split('T')[0],
      'description': description,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

