import '../enums/report_enums.dart';
import 'report_config.dart';

/// Model para relatório customizado
class CustomReport {
  final String id;
  final String name;
  final String? description;
  final DataSource dataSource;
  final VisualizationType visualizationType;
  final ReportConfig config;
  final bool isActive;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomReport({
    required this.id,
    required this.name,
    this.description,
    required this.dataSource,
    required this.visualizationType,
    required this.config,
    this.isActive = true,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomReport.fromJson(Map<String, dynamic> json) {
    return CustomReport(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      dataSource: DataSource.fromValue(json['data_source'] as String),
      visualizationType: VisualizationType.fromValue(json['visualization_type'] as String),
      config: ReportConfig.fromJson(json['config'] as Map<String, dynamic>? ?? {}),
      isActive: json['is_active'] as bool? ?? true,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'data_source': dataSource.value,
      'visualization_type': visualizationType.value,
      'config': config.toJson(),
      'is_active': isActive,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Converte para formato de inserção no banco (sem id, created_at, updated_at)
  Map<String, dynamic> toInsertJson() {
    return {
      'name': name,
      'description': description,
      'data_source': dataSource.value,
      'visualization_type': visualizationType.value,
      'config': config.toJson(),
      'is_active': isActive,
      'created_by': createdBy,
    };
  }

  /// Converte para formato de atualização no banco
  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'description': description,
      'data_source': dataSource.value,
      'visualization_type': visualizationType.value,
      'config': config.toJson(),
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  CustomReport copyWith({
    String? id,
    String? name,
    String? description,
    DataSource? dataSource,
    VisualizationType? visualizationType,
    ReportConfig? config,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomReport(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      dataSource: dataSource ?? this.dataSource,
      visualizationType: visualizationType ?? this.visualizationType,
      config: config ?? this.config,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'CustomReport(id: $id, name: $name, dataSource: ${dataSource.label}, visualizationType: ${visualizationType.label})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CustomReport && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

