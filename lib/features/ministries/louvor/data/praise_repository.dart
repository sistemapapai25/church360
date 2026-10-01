import 'package:supabase_flutter/supabase_flutter.dart';

/// Versão imutável da cifra (`public.praise_song_version`). Editar a música
/// é gravar uma versão nova; `versionNumber` e `tenant_id` vêm do trigger.
class PraiseSongVersion {
  final String id;
  final String songId;
  final int versionNumber;
  final String chordpro;
  final String? originalKey;
  final int capo;
  final int? bpm;
  final String? changeNote;
  final DateTime createdAt;

  const PraiseSongVersion({
    required this.id,
    required this.songId,
    required this.versionNumber,
    required this.chordpro,
    this.originalKey,
    this.capo = 0,
    this.bpm,
    this.changeNote,
    required this.createdAt,
  });

  factory PraiseSongVersion.fromJson(Map<String, dynamic> j) =>
      PraiseSongVersion(
        id: j['id'] as String,
        songId: j['song_id'] as String,
        versionNumber: j['version_number'] as int,
        chordpro: j['chordpro'] as String,
        originalKey: j['original_key'] as String?,
        capo: (j['capo'] as int?) ?? 0,
        bpm: j['bpm'] as int?,
        changeNote: j['change_note'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

/// Louvor da biblioteca da igreja (`public.praise_song`). [latest] é nulo
/// quando o cadastro gravou a música e a versão falhou — o leitor mostra
/// "sem cifra" e deixa editar, em vez de esconder a música.
class PraiseSong {
  final String id;
  final String title;
  final String? artist;
  final String? sourceUrl;
  final PraiseSongVersion? latest;

  const PraiseSong({
    required this.id,
    required this.title,
    this.artist,
    this.sourceUrl,
    this.latest,
  });

  factory PraiseSong.fromJson(Map<String, dynamic> j) {
    final versions = [
      for (final v in (j['praise_song_version'] as List? ?? const []))
        PraiseSongVersion.fromJson({
          ...v as Map<String, dynamic>,
          'song_id': j['id'],
        }),
    ]..sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
    return PraiseSong(
      id: j['id'] as String,
      title: j['title'] as String,
      artist: j['artist'] as String?,
      sourceUrl: j['source_url'] as String?,
      latest: versions.isEmpty ? null : versions.first,
    );
  }
}

/// O que vai numa versão nova.
class PraiseVersionDraft {
  final String chordpro;
  final String? originalKey;
  final int capo;
  final int? bpm;
  final String? changeNote;

  const PraiseVersionDraft({
    required this.chordpro,
    this.originalKey,
    this.capo = 0,
    this.bpm,
    this.changeNote,
  });

  Map<String, dynamic> toJson(String songId) => {
    'song_id': songId,
    'chordpro': chordpro,
    'original_key': originalKey,
    'capo': capo,
    'bpm': bpm,
    'change_note': changeNote,
  };
}

class PraiseRepository {
  final SupabaseClient _db;
  const PraiseRepository(this._db);

  static const _versionCols =
      'id, version_number, chordpro, original_key, capo, bpm, change_note, created_at';

  /// A mesma regra que as policies chamam: tela e banco não divergem.
  Future<({bool canView, bool canManage})> access() async {
    final r = await Future.wait([
      _db.rpc('praise_can_view'),
      _db.rpc('praise_can_manage'),
    ]);
    return (canView: r[0] == true, canManage: r[1] == true);
  }

  /// Biblioteca inteira da igreja (sem arquivadas), com as versões para
  /// achar a mais recente. Filtrar no cliente basta para ~20 músicas.
  Future<List<PraiseSong>> listSongs() async {
    final rows = await _db
        .from('praise_song')
        .select(
          'id, title, artist, source_url, praise_song_version($_versionCols)',
        )
        .isFilter('archived_at', null)
        .order('title');
    return [for (final r in rows) PraiseSong.fromJson(r)];
  }

  Future<PraiseSong?> getSong(String songId) async {
    final row = await _db
        .from('praise_song')
        .select(
          'id, title, artist, source_url, praise_song_version($_versionCols)',
        )
        .eq('id', songId)
        .maybeSingle();
    return row == null ? null : PraiseSong.fromJson(row);
  }

  Future<List<PraiseSongVersion>> listVersions(String songId) async {
    final rows = await _db
        .from('praise_song_version')
        .select('song_id, $_versionCols')
        .eq('song_id', songId)
        .order('version_number', ascending: false);
    return [for (final r in rows) PraiseSongVersion.fromJson(r)];
  }

  /// Cria a música e a versão 1. Devolve o id da música.
  Future<String> createSong({
    required String title,
    String? artist,
    String? sourceUrl,
    String? fromMinistryId,
    required PraiseVersionDraft version,
  }) async {
    final song = await _db
        .from('praise_song')
        .insert({
          'title': title,
          'artist': artist,
          'source_url': sourceUrl,
          'created_from_ministry_id': fromMinistryId,
        })
        .select('id')
        .single();
    final id = song['id'] as String;
    await addVersion(id, version);
    return id;
  }

  Future<void> updateSongInfo(
    String songId, {
    required String title,
    String? artist,
    String? sourceUrl,
  }) => _db
      .from('praise_song')
      .update({'title': title, 'artist': artist, 'source_url': sourceUrl})
      .eq('id', songId);

  Future<void> addVersion(String songId, PraiseVersionDraft version) =>
      _db.from('praise_song_version').insert(version.toJson(songId));

  Future<void> archive(String songId) => _db
      .from('praise_song')
      .update({'archived_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', songId);
}
