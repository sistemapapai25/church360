/// Modelo de widget da Dashboard
class DashboardWidget {
  final String id;
  final String widgetKey;
  final String widgetName;
  final String? description;
  final String category;
  final String? iconName;
  final bool isEnabled;
  final int displayOrder;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DashboardWidget({
    required this.id,
    required this.widgetKey,
    required this.widgetName,
    this.description,
    required this.category,
    this.iconName,
    required this.isEnabled,
    required this.displayOrder,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DashboardWidget.fromJson(Map<String, dynamic> json) {
    return DashboardWidget(
      id: json['id'] as String,
      widgetKey: json['widget_key'] as String,
      widgetName: json['widget_name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      iconName: json['icon_name'] as String?,
      isEnabled: json['is_enabled'] as bool,
      displayOrder: json['display_order'] as int,
      isDefault: json['is_default'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'widget_key': widgetKey,
      'widget_name': widgetName,
      'description': description,
      'category': category,
      'icon_name': iconName,
      'is_enabled': isEnabled,
      'display_order': displayOrder,
      'is_default': isDefault,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  DashboardWidget copyWith({
    String? id,
    String? widgetKey,
    String? widgetName,
    String? description,
    String? category,
    String? iconName,
    bool? isEnabled,
    int? displayOrder,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DashboardWidget(
      id: id ?? this.id,
      widgetKey: widgetKey ?? this.widgetKey,
      widgetName: widgetName ?? this.widgetName,
      description: description ?? this.description,
      category: category ?? this.category,
      iconName: iconName ?? this.iconName,
      isEnabled: isEnabled ?? this.isEnabled,
      displayOrder: displayOrder ?? this.displayOrder,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DashboardWidget &&
        other.id == id &&
        other.widgetKey == widgetKey &&
        other.widgetName == widgetName &&
        other.description == description &&
        other.category == category &&
        other.iconName == iconName &&
        other.isEnabled == isEnabled &&
        other.displayOrder == displayOrder &&
        other.isDefault == isDefault &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      widgetKey,
      widgetName,
      description,
      category,
      iconName,
      isEnabled,
      displayOrder,
      isDefault,
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'DashboardWidget(id: $id, widgetKey: $widgetKey, widgetName: $widgetName, description: $description, category: $category, iconName: $iconName, isEnabled: $isEnabled, displayOrder: $displayOrder, isDefault: $isDefault, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}

