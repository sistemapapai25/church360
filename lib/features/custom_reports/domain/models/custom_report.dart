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

/// Model para permissão de relatório
class CustomReportPermission {
  final String id;
  final String reportId;
  final PermissionType permissionType;
  final String? userId;
  final String? groupId;
  final bool canView;
  final bool canEdit;
  final bool canDelete;
  final DateTime createdAt;

  const CustomReportPermission({
    required this.id,
    required this.reportId,
    required this.permissionType,
    this.userId,
    this.groupId,
    this.canView = true,
    this.canEdit = false,
    this.canDelete = false,
    required this.createdAt,
  });

  factory CustomReportPermission.fromJson(Map<String, dynamic> json) {
    return CustomReportPermission(
      id: json['id'] as String,
      reportId: json['report_id'] as String,
      permissionType: PermissionType.fromValue(json['permission_type'] as String),
      userId: json['user_id'] as String?,
      groupId: json['group_id'] as String?,
      canView: json['can_view'] as bool? ?? true,
      canEdit: json['can_edit'] as bool? ?? false,
      canDelete: json['can_delete'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'report_id': reportId,
      'permission_type': permissionType.value,
      'user_id': userId,
      'group_id': groupId,
      'can_view': canView,
      'can_edit': canEdit,
      'can_delete': canDelete,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Converte para formato de inserção no banco
  Map<String, dynamic> toInsertJson() {
    return {
      'report_id': reportId,
      'permission_type': permissionType.value,
      'user_id': userId,
      'group_id': groupId,
      'can_view': canView,
      'can_edit': canEdit,
      'can_delete': canDelete,
    };
  }

  CustomReportPermission copyWith({
    String? id,
    String? reportId,
    PermissionType? permissionType,
    String? userId,
    String? groupId,
    bool? canView,
    bool? canEdit,
    bool? canDelete,
    DateTime? createdAt,
  }) {
    return CustomReportPermission(
      id: id ?? this.id,
      reportId: reportId ?? this.reportId,
      permissionType: permissionType ?? this.permissionType,
      userId: userId ?? this.userId,
      groupId: groupId ?? this.groupId,
      canView: canView ?? this.canView,
      canEdit: canEdit ?? this.canEdit,
      canDelete: canDelete ?? this.canDelete,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'CustomReportPermission(id: $id, reportId: $reportId, permissionType: ${permissionType.label})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CustomReportPermission && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

