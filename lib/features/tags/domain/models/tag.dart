import 'package:flutter/material.dart';

/// Modelo de Tag
class Tag {
  final String id;
  final String name;
  final String? color; // Hex color (ex: "#FF5733")
  final String? category;
  final DateTime createdAt;
  final int? memberCount; // Computed from join

  Tag({
    required this.id,
    required this.name,
    this.color,
    this.category,
    required this.createdAt,
    this.memberCount,
  });

  /// Criar a partir de JSON
  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'] as String,
      name: json['name'] as String,
      color: json['color'] as String?,
      category: json['category'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      memberCount: json['member_count'] as int?,
    );
  }

  /// Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'category': category,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Obter cor como Color do Flutter
  Color get colorValue {
    if (color == null || color!.isEmpty) {
      return Colors.blue; // Cor padrão
    }
    
    try {
      // Remove o # se existir
      final hexColor = color!.replaceAll('#', '');
      
      // Adiciona FF no início para opacidade total
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (e) {
      return Colors.blue; // Cor padrão em caso de erro
    }
  }

  /// Copiar com alterações
  Tag copyWith({
    String? id,
    String? name,
    String? color,
    String? category,
    DateTime? createdAt,
    int? memberCount,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      memberCount: memberCount ?? this.memberCount,
    );
  }
}

/// Modelo de associação Membro-Tag
class MemberTag {
  final String memberId;
  final String tagId;
  final String? tagName; // Computed from join
  final String? tagColor; // Computed from join
  final DateTime assignedAt;

  MemberTag({
    required this.memberId,
    required this.tagId,
    this.tagName,
    this.tagColor,
    required this.assignedAt,
  });

  /// Criar a partir de JSON
  factory MemberTag.fromJson(Map<String, dynamic> json) {
    return MemberTag(
      memberId: json['member_id'] as String,
      tagId: json['tag_id'] as String,
      tagName: json['tag_name'] as String?,
      tagColor: json['tag_color'] as String?,
      assignedAt: DateTime.parse(json['assigned_at'] as String),
    );
  }

  /// Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'member_id': memberId,
      'tag_id': tagId,
      'assigned_at': assignedAt.toIso8601String(),
    };
  }
}

