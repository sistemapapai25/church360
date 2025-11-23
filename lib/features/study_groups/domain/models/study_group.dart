import 'package:flutter/material.dart';

// =====================================================
// ENUMS
// =====================================================

enum StudyGroupStatus {
  active('active', 'Ativo', Colors.green),
  paused('paused', 'Pausado', Colors.orange),
  completed('completed', 'Concluído', Colors.blue),
  cancelled('cancelled', 'Cancelado', Colors.red);

  final String value;
  final String displayName;
  final Color color;

  const StudyGroupStatus(this.value, this.displayName, this.color);

  static StudyGroupStatus fromString(String value) {
    return StudyGroupStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => StudyGroupStatus.active,
    );
  }
}

enum LessonStatus {
  draft('draft', 'Rascunho', Icons.edit),
  published('published', 'Publicada', Icons.check_circle),
  archived('archived', 'Arquivada', Icons.archive);

  final String value;
  final String displayName;
  final IconData icon;

  const LessonStatus(this.value, this.displayName, this.icon);

  static LessonStatus fromString(String value) {
    return LessonStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => LessonStatus.draft,
    );
  }
}

enum ParticipantRole {
  leader('leader', 'Líder', Icons.star),
  coLeader('co_leader', 'Co-líder', Icons.star_half),
  participant('participant', 'Participante', Icons.person);

  final String value;
  final String displayName;
  final IconData icon;

  const ParticipantRole(this.value, this.displayName, this.icon);

  static ParticipantRole fromString(String value) {
    return ParticipantRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ParticipantRole.participant,
    );
  }
}

enum AttendanceStatus {
  present('present', 'Presente', Colors.green),
  absent('absent', 'Ausente', Colors.red),
  justified('justified', 'Justificado', Colors.orange);

  final String value;
  final String displayName;
  final Color color;

  const AttendanceStatus(this.value, this.displayName, this.color);

  static AttendanceStatus fromString(String value) {
    return AttendanceStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AttendanceStatus.absent,
    );
  }
}

// =====================================================
// MODELS
// =====================================================

class StudyGroup {
  final String id;
  final String name;
  final String? description;
  final String? studyTopic;
  final StudyGroupStatus status;
  final DateTime startDate;
  final DateTime? endDate;
  final String? meetingDay;
  final String? meetingTime;
  final String? meetingLocation;
  final int? maxParticipants;
  final bool isPublic;
  final String? coverImageUrl;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudyGroup({
    required this.id,
    required this.name,
    this.description,
    this.studyTopic,
    required this.status,
    required this.startDate,
    this.endDate,
    this.meetingDay,
    this.meetingTime,
    this.meetingLocation,
    this.maxParticipants,
    required this.isPublic,
    this.coverImageUrl,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudyGroup.fromJson(Map<String, dynamic> json) {
    return StudyGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      studyTopic: json['study_topic'] as String?,
      status: StudyGroupStatus.fromString(json['status'] as String),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
      meetingDay: json['meeting_day'] as String?,
      meetingTime: json['meeting_time'] as String?,
      meetingLocation: json['meeting_location'] as String?,
      maxParticipants: json['max_participants'] as int?,
      isPublic: json['is_public'] as bool,
      coverImageUrl: json['cover_image_url'] as String?,
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
      'study_topic': studyTopic,
      'status': status.value,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'meeting_day': meetingDay,
      'meeting_time': meetingTime,
      'meeting_location': meetingLocation,
      'max_participants': maxParticipants,
      'is_public': isPublic,
      'cover_image_url': coverImageUrl,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isActive => status == StudyGroupStatus.active;
  bool get isCompleted => status == StudyGroupStatus.completed;
  bool get hasEnded => endDate != null && endDate!.isBefore(DateTime.now());
}

class StudyLesson {
  final String id;
  final String studyGroupId;
  final int lessonNumber;
  final String title;
  final String? description;
  final String? bibleReferences;
  final String? content;
  final List<String>? discussionQuestions;
  final LessonStatus status;
  final DateTime? scheduledDate;
  final String? videoUrl;
  final String? audioUrl;
  final String? pdfUrl;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudyLesson({
    required this.id,
    required this.studyGroupId,
    required this.lessonNumber,
    required this.title,
    this.description,
    this.bibleReferences,
    this.content,
    this.discussionQuestions,
    required this.status,
    this.scheduledDate,
    this.videoUrl,
    this.audioUrl,
    this.pdfUrl,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudyLesson.fromJson(Map<String, dynamic> json) {
    List<String>? questions;
    if (json['discussion_questions'] != null) {
      final questionsJson = json['discussion_questions'];
      if (questionsJson is List) {
        questions = questionsJson.map((q) => q.toString()).toList();
      }
    }

    return StudyLesson(
      id: json['id'] as String,
      studyGroupId: json['study_group_id'] as String,
      lessonNumber: json['lesson_number'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      bibleReferences: json['bible_references'] as String?,
      content: json['content'] as String?,
      discussionQuestions: questions,
      status: LessonStatus.fromString(json['status'] as String),
      scheduledDate: json['scheduled_date'] != null ? DateTime.parse(json['scheduled_date'] as String) : null,
      videoUrl: json['video_url'] as String?,
      audioUrl: json['audio_url'] as String?,
      pdfUrl: json['pdf_url'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'study_group_id': studyGroupId,
      'lesson_number': lessonNumber,
      'title': title,
      'description': description,
      'bible_references': bibleReferences,
      'content': content,
      'discussion_questions': discussionQuestions,
      'status': status.value,
      'scheduled_date': scheduledDate?.toIso8601String(),
      'video_url': videoUrl,
      'audio_url': audioUrl,
      'pdf_url': pdfUrl,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isPublished => status == LessonStatus.published;
  bool get isDraft => status == LessonStatus.draft;
  bool get hasScheduledDate => scheduledDate != null;
  bool get isPast => scheduledDate != null && scheduledDate!.isBefore(DateTime.now());
}

class StudyParticipant {
  final String id;
  final String studyGroupId;
  final String userId;
  final ParticipantRole role;
  final bool isActive;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudyParticipant({
    required this.id,
    required this.studyGroupId,
    required this.userId,
    required this.role,
    required this.isActive,
    required this.joinedAt,
    this.leftAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudyParticipant.fromJson(Map<String, dynamic> json) {
    return StudyParticipant(
      id: json['id'] as String,
      studyGroupId: json['study_group_id'] as String,
      userId: json['user_id'] as String,
      role: ParticipantRole.fromString(json['role'] as String),
      isActive: json['is_active'] as bool,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      leftAt: json['left_at'] != null ? DateTime.parse(json['left_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'study_group_id': studyGroupId,
      'user_id': userId,
      'role': role.value,
      'is_active': isActive,
      'joined_at': joinedAt.toIso8601String(),
      'left_at': leftAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isLeader => role == ParticipantRole.leader;
  bool get isCoLeader => role == ParticipantRole.coLeader;
  bool get canManageGroup => isLeader || isCoLeader;
}

class StudyAttendance {
  final String id;
  final String studyLessonId;
  final String userId;
  final AttendanceStatus status;
  final String? justification;
  final String? notes;
  final String? markedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudyAttendance({
    required this.id,
    required this.studyLessonId,
    required this.userId,
    required this.status,
    this.justification,
    this.notes,
    this.markedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudyAttendance.fromJson(Map<String, dynamic> json) {
    return StudyAttendance(
      id: json['id'] as String,
      studyLessonId: json['study_lesson_id'] as String,
      userId: json['user_id'] as String,
      status: AttendanceStatus.fromString(json['status'] as String),
      justification: json['justification'] as String?,
      notes: json['notes'] as String?,
      markedBy: json['marked_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'study_lesson_id': studyLessonId,
      'user_id': userId,
      'status': status.value,
      'justification': justification,
      'notes': notes,
      'marked_by': markedBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isPresent => status == AttendanceStatus.present;
  bool get isAbsent => status == AttendanceStatus.absent;
  bool get isJustified => status == AttendanceStatus.justified;
}

class StudyComment {
  final String id;
  final String studyLessonId;
  final String authorId;
  final String content;
  final String? parentCommentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudyComment({
    required this.id,
    required this.studyLessonId,
    required this.authorId,
    required this.content,
    this.parentCommentId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudyComment.fromJson(Map<String, dynamic> json) {
    return StudyComment(
      id: json['id'] as String,
      studyLessonId: json['study_lesson_id'] as String,
      authorId: json['author_id'] as String,
      content: json['content'] as String,
      parentCommentId: json['parent_comment_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'study_lesson_id': studyLessonId,
      'author_id': authorId,
      'content': content,
      'parent_comment_id': parentCommentId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isReply => parentCommentId != null;
}

class StudyResource {
  final String id;
  final String studyGroupId;
  final String title;
  final String? description;
  final String? resourceType;
  final String url;
  final int? fileSize;
  final String? uploadedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudyResource({
    required this.id,
    required this.studyGroupId,
    required this.title,
    this.description,
    this.resourceType,
    required this.url,
    this.fileSize,
    this.uploadedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudyResource.fromJson(Map<String, dynamic> json) {
    return StudyResource(
      id: json['id'] as String,
      studyGroupId: json['study_group_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      resourceType: json['resource_type'] as String?,
      url: json['url'] as String,
      fileSize: json['file_size'] as int?,
      uploadedBy: json['uploaded_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'study_group_id': studyGroupId,
      'title': title,
      'description': description,
      'resource_type': resourceType,
      'url': url,
      'file_size': fileSize,
      'uploaded_by': uploadedBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  IconData get icon {
    switch (resourceType?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'video':
        return Icons.video_library;
      case 'audio':
        return Icons.audiotrack;
      case 'image':
        return Icons.image;
      case 'link':
        return Icons.link;
      default:
        return Icons.insert_drive_file;
    }
  }

  String get fileSizeFormatted {
    if (fileSize == null) return '';
    final kb = fileSize! / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}

