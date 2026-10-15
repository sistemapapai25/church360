/// Prova do módulo (E4 do roadmap Home/culto/Dashboard, `course_quiz`).
/// `subjectId` nulo = prova final do curso.
class CourseQuiz {
  final String id;
  final String courseId;
  final String? subjectId;
  final String title;

  /// Nota mínima para aprovar (D10, padrão 70).
  final int passScore;

  const CourseQuiz({
    required this.id,
    required this.courseId,
    this.subjectId,
    required this.title,
    this.passScore = 70,
  });

  factory CourseQuiz.fromJson(Map<String, dynamic> json) => CourseQuiz(
    id: json['id'] as String,
    courseId: json['course_id'] as String,
    subjectId: json['subject_id'] as String?,
    title: json['title'] as String,
    passScore: (json['pass_score'] as int?) ?? 70,
  );

  bool get isFinal => subjectId == null;
}

/// Questão como o aluno a vê (`course_quiz_question` sem `correct_index`).
/// Para a gestão, [correctIndex] vem preenchido por `quiz_admin_questions`.
class QuizQuestion {
  final String id;
  final int orderIndex;
  final String text;
  final List<String> options;
  final String? explanation;
  final int? correctIndex;

  const QuizQuestion({
    required this.id,
    required this.orderIndex,
    required this.text,
    required this.options,
    this.explanation,
    this.correctIndex,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
    id: json['id'] as String,
    orderIndex: (json['order_index'] as int?) ?? 0,
    text: json['text'] as String,
    options: [for (final o in json['options'] as List) o.toString()],
    explanation: json['explanation'] as String?,
    correctIndex: json['correct_index'] as int?,
  );

  /// Formato que `quiz_save` recebe.
  Map<String, dynamic> toSaveJson() => {
    'text': text,
    'options': options,
    'correct_index': correctIndex ?? 0,
    'explanation': explanation,
  };
}

/// Tentativa do aluno (`course_quiz_attempt`, só as próprias).
class QuizAttempt {
  final String id;
  final String quizId;
  final int score;
  final bool passed;
  final DateTime createdAt;

  const QuizAttempt({
    required this.id,
    required this.quizId,
    required this.score,
    required this.passed,
    required this.createdAt,
  });

  factory QuizAttempt.fromJson(Map<String, dynamic> json) => QuizAttempt(
    id: json['id'] as String,
    quizId: json['quiz_id'] as String,
    score: json['score'] as int,
    passed: json['passed'] as bool,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

/// Correção de uma questão, devolvida por `quiz_submit`.
class QuizCorrection {
  final String questionId;
  final int? chosen;
  final int correctIndex;
  final String? explanation;

  const QuizCorrection({
    required this.questionId,
    this.chosen,
    required this.correctIndex,
    this.explanation,
  });

  factory QuizCorrection.fromJson(Map<String, dynamic> json) => QuizCorrection(
    questionId: json['question_id'] as String,
    chosen: json['chosen'] as int?,
    correctIndex: json['correct_index'] as int,
    explanation: json['explanation'] as String?,
  );

  bool get isRight => chosen == correctIndex;
}

/// Resultado de `quiz_submit`: nota calculada no servidor + gabarito.
class QuizResult {
  final int score;
  final bool passed;
  final int passScore;
  final int total;
  final int correct;
  final List<QuizCorrection> questions;

  const QuizResult({
    required this.score,
    required this.passed,
    required this.passScore,
    required this.total,
    required this.correct,
    required this.questions,
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) => QuizResult(
    score: json['score'] as int,
    passed: json['passed'] as bool,
    passScore: json['pass_score'] as int,
    total: json['total'] as int,
    correct: json['correct'] as int,
    questions: [
      for (final q in (json['questions'] as List? ?? const []))
        QuizCorrection.fromJson(Map<String, dynamic>.from(q as Map)),
    ],
  );
}

/// Certificado do curso (`course_certificate`, E5).
class CourseCertificate {
  final String code;
  final String courseId;
  final DateTime issuedAt;

  const CourseCertificate({
    required this.code,
    required this.courseId,
    required this.issuedAt,
  });

  factory CourseCertificate.fromJson(Map<String, dynamic> json) =>
      CourseCertificate(
        code: json['code'] as String,
        courseId: json['course_id'] as String,
        issuedAt: DateTime.parse(json['issued_at'] as String),
      );
}

/// O que a página pública `/certificado/:code` mostra (`certificate_lookup`).
class CertificateInfo {
  final String code;
  final String personName;
  final String courseTitle;
  final String churchName;
  final DateTime issuedAt;

  const CertificateInfo({
    required this.code,
    required this.personName,
    required this.courseTitle,
    required this.churchName,
    required this.issuedAt,
  });

  factory CertificateInfo.fromJson(Map<String, dynamic> json) =>
      CertificateInfo(
        code: json['code'] as String,
        personName: json['person_name'] as String? ?? 'Aluno',
        courseTitle: json['course_title'] as String,
        churchName: json['church_name'] as String? ?? '',
        issuedAt: DateTime.parse(json['issued_at'] as String),
      );
}
