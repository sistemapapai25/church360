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

/// Texto de erro para a tela. As RPCs da Fase C já levantam mensagem em
/// português (sem acento); o resto cai no `toString`.
String praiseErrorText(Object e) => e is PostgrestException ? e.message : '$e';

/// Música de um repertório (`public.praise_setlist_item`). Aponta para a
/// VERSÃO; tom/capo/BPM/observação são do culto e não mexem na versão.
class PraiseSetlistItem {
  final PraiseSongVersion version;
  final String songTitle;
  final String? artist;
  final String? selectedKey;
  final int capo;
  final int? bpm;
  final String? notes;

  /// `null` enquanto o item só existe na tela (rascunho não salvo).
  final String? id;

  const PraiseSetlistItem({
    this.id,
    required this.version,
    required this.songTitle,
    this.artist,
    this.selectedKey,
    this.capo = 0,
    this.bpm,
    this.notes,
  });

  factory PraiseSetlistItem.fromJson(Map<String, dynamic> j) {
    final v = j['praise_song_version'] as Map<String, dynamic>;
    final song = v['praise_song'] as Map<String, dynamic>? ?? const {};
    return PraiseSetlistItem(
      id: j['id'] as String,
      version: PraiseSongVersion.fromJson(v),
      songTitle: song['title'] as String? ?? 'Música',
      artist: song['artist'] as String?,
      selectedKey: j['selected_key'] as String?,
      capo: (j['capo'] as int?) ?? 0,
      bpm: j['bpm'] as int?,
      notes: j['notes'] as String?,
    );
  }

  /// Formato de `p_items` de `praise_setlist_save_draft`.
  Map<String, dynamic> toRpc() => {
    'song_version_id': version.id,
    'selected_key': selectedKey,
    'capo': capo,
    'bpm': bpm,
    'notes': notes,
  };
}

/// Revisão do repertório: `draft` → `published` → `archived`.
class PraiseSetlistRevision {
  final String id;
  final int number;
  final String title;
  final String status;
  final DateTime? publishedAt;
  final int itemCount;

  /// Só vem preenchido no detalhe ([PraiseRepository.getSetlist]).
  final List<PraiseSetlistItem> items;

  const PraiseSetlistRevision({
    required this.id,
    required this.number,
    required this.title,
    required this.status,
    this.publishedAt,
    this.itemCount = 0,
    this.items = const [],
  });

  bool get isDraft => status == 'draft';

  factory PraiseSetlistRevision.fromJson(Map<String, dynamic> j) {
    final raw = j['praise_setlist_item'] as List? ?? const [];
    // Na lista vem `[{count: n}]`; no detalhe, os itens.
    final isCount = raw.length == 1 && (raw.first as Map).containsKey('count');
    final items = isCount
        ? <PraiseSetlistItem>[]
        : ([for (final i in raw) i as Map<String, dynamic>]..sort(
                (a, b) =>
                    (a['position'] as int).compareTo(b['position'] as int),
              ))
              .map(PraiseSetlistItem.fromJson)
              .toList();
    return PraiseSetlistRevision(
      id: j['id'] as String,
      number: j['revision_number'] as int,
      title: j['title'] as String,
      status: j['status'] as String,
      publishedAt: j['published_at'] == null
          ? null
          : DateTime.parse(j['published_at'] as String),
      itemCount: isCount ? (raw.first as Map)['count'] as int : items.length,
      items: items,
    );
  }
}

/// Repertório (`public.praise_setlist`). Com evento, a data é a do evento —
/// [eventStart] está no contrato de parede (hora de SP rotulada como UTC),
/// então se formata direto, sem `toLocal()`.
class PraiseSetlist {
  final String id;
  final String? eventId;
  final String? eventName;
  final DateTime? eventStart;

  /// Ministério dono (quem montou). Só vem nas leituras do destinatário.
  final String? ministryName;

  /// Publicada vigente e rascunho aberto. A RLS só devolve o rascunho a quem
  /// monta ou publica, então para o integrante [draft] é sempre nulo.
  final PraiseSetlistRevision? published;
  final PraiseSetlistRevision? draft;

  const PraiseSetlist({
    required this.id,
    this.eventId,
    this.eventName,
    this.eventStart,
    this.ministryName,
    this.published,
    this.draft,
  });

  /// O que a tela mostra: o rascunho para quem o enxerga, senão o publicado.
  PraiseSetlistRevision? get current => draft ?? published;

  factory PraiseSetlist.fromJson(Map<String, dynamic> j) {
    final revs = [
      for (final r in (j['praise_setlist_revision'] as List? ?? const []))
        PraiseSetlistRevision.fromJson(r as Map<String, dynamic>),
    ];
    final event = j['event'] as Map<String, dynamic>?;
    return PraiseSetlist(
      id: j['id'] as String,
      eventId: j['event_id'] as String?,
      eventName: event?['name'] as String?,
      eventStart: event?['start_date'] == null
          ? null
          : DateTime.parse(event!['start_date'] as String),
      ministryName:
          (j['ministry'] as Map<String, dynamic>?)?['name'] as String?,
      published: revs.where((r) => r.status == 'published').firstOrNull,
      draft: revs.where((r) => r.isDraft).firstOrNull,
    );
  }
}

/// Tom do item no culto (o escolhido, senão o original da versão).
String praiseItemKey(PraiseSetlistItem i) =>
    i.selectedKey ?? i.version.originalKey ?? '—';

/// "O que mudou" de [before] para [after], por música: entrou, saiu, tom.
List<({String sign, String text})> setlistChanges(
  PraiseSetlistRevision before,
  PraiseSetlistRevision after,
) {
  final old = {for (final i in before.items) i.version.songId: i};
  final now = {for (final i in after.items) i.version.songId: i};
  return [
    for (final i in after.items)
      if (!old.containsKey(i.version.songId))
        (sign: '+', text: '${i.songTitle} entrou'),
    for (final i in before.items)
      if (!now.containsKey(i.version.songId))
        (sign: '−', text: '${i.songTitle} saiu'),
    for (final i in after.items)
      if (old[i.version.songId] case final o?
          when praiseItemKey(o) != praiseItemKey(i))
        (
          sign: '♯',
          text: '${i.songTitle}: tom ${praiseItemKey(o)} → ${praiseItemKey(i)}',
        ),
  ];
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

  /// Em quantos repertórios cada música entrou (música → repertórios
  /// distintos), para "Mais usadas". Revisões do mesmo repertório contam 1.
  Future<Map<String, int>> songUsage() async {
    final rows = await _db
        .from('praise_setlist_item')
        .select(
          'praise_song_version(song_id), praise_setlist_revision(setlist_id)',
        );
    final seen = <String, Set<String>>{};
    for (final r in rows) {
      final song = (r['praise_song_version'] as Map?)?['song_id'] as String?;
      final list =
          (r['praise_setlist_revision'] as Map?)?['setlist_id'] as String?;
      if (song != null && list != null) (seen[song] ??= {}).add(list);
    }
    return {for (final e in seen.entries) e.key: e.value.length};
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

  // ---------------------------------------------------------------- Fase C
  // Escrita só pelas RPCs praise_setlist_* (o banco não dá INSERT/UPDATE).

  Future<({bool canManage, bool canPublish})> setlistAccess() async {
    final r = await Future.wait([
      _db.rpc('praise_can_manage_setlist'),
      _db.rpc('praise_can_publish_setlist'),
    ]);
    return (canManage: r[0] == true, canPublish: r[1] == true);
  }

  static const _revisionCols =
      'id, revision_number, title, status, published_at';

  /// Repertórios do ministério com a publicada e o rascunho (arquivadas
  /// ficam de fora) e a contagem de itens.
  Future<List<PraiseSetlist>> listSetlists(String ministryId) async {
    final rows = await _db
        .from('praise_setlist')
        .select(
          'id, event_id, event(name, start_date), '
          'praise_setlist_revision($_revisionCols, praise_setlist_item(count))',
        )
        .eq('ministry_id', ministryId)
        .inFilter('praise_setlist_revision.status', ['draft', 'published'])
        .order('created_at', ascending: false);
    return [for (final r in rows) PraiseSetlist.fromJson(r)];
  }

  Future<PraiseSetlist?> getSetlist(String setlistId) async {
    final row = await _db
        .from('praise_setlist')
        .select(
          'id, event_id, event(name, start_date), ministry(name), '
          'praise_setlist_revision($_revisionCols, '
          'praise_setlist_item(id, position, selected_key, capo, bpm, notes, '
          'praise_song_version(song_id, $_versionCols, praise_song(title, artist))))',
        )
        .eq('id', setlistId)
        .inFilter('praise_setlist_revision.status', ['draft', 'published'])
        .maybeSingle();
    return row == null ? null : PraiseSetlist.fromJson(row);
  }

  /// Cria o repertório com a revisão 1 em rascunho. Devolve o id.
  Future<String> createSetlist({
    required String ministryId,
    required String title,
    String? eventId,
  }) async =>
      await _db.rpc(
            'praise_setlist_create',
            params: {
              'p_ministry_id': ministryId,
              'p_title': title,
              'p_event_id': eventId,
            },
          )
          as String;

  /// Troca título e a lista inteira de itens (posição = ordem da lista).
  Future<void> saveDraft(
    String revisionId,
    String title,
    List<PraiseSetlistItem> items,
  ) => _db.rpc(
    'praise_setlist_save_draft',
    params: {
      'p_revision_id': revisionId,
      'p_title': title,
      'p_items': [for (final i in items) i.toRpc()],
    },
  );

  Future<void> publishSetlist(String revisionId) =>
      _db.rpc('praise_setlist_publish', params: {'p_revision_id': revisionId});

  /// "Editar" um publicado: abre (ou devolve) o rascunho N+1.
  Future<void> newSetlistRevision(String setlistId) => _db.rpc(
    'praise_setlist_new_revision',
    params: {'p_setlist_id': setlistId},
  );

  /// Apaga o rascunho. `true` = o repertório nunca foi publicado e foi
  /// apagado junto.
  Future<bool> discardDraft(String revisionId) async =>
      await _db.rpc(
        'praise_setlist_discard_draft',
        params: {'p_revision_id': revisionId},
      ) ==
      true;

  /// Apaga o repertório inteiro, publicado inclusive (exige publish).
  Future<void> deleteSetlist(String setlistId) =>
      _db.rpc('praise_setlist_delete', params: {'p_setlist_id': setlistId});

  /// Só com rascunho aberto (trigger). Vale também para a publicada.
  Future<void> setSetlistEvent(String setlistId, String? eventId) => _db
      .from('praise_setlist')
      .update({'event_id': eventId})
      .eq('id', setlistId);

  /// Nome de quem publicou (a RLS de user_account não deixa ler a ficha).
  Future<String?> publisherName(String revisionId) async =>
      await _db.rpc(
            'praise_setlist_publisher_name',
            params: {'p_revision_id': revisionId},
          )
          as String?;

  // ---------------------------------------------------------------- Fase D

  static const _itemCols =
      'praise_setlist_item(id, position, selected_key, capo, bpm, notes, '
      'praise_song_version(song_id, $_versionCols, praise_song(title, artist)))';

  /// Revisão [number] do repertório com os itens (para o "o que mudou" o
  /// destinatário lê a arquivada anterior).
  Future<PraiseSetlistRevision?> getRevision(
    String setlistId,
    int number,
  ) async {
    final row = await _db
        .from('praise_setlist_revision')
        .select('$_revisionCols, $_itemCols')
        .eq('setlist_id', setlistId)
        .eq('revision_number', number)
        .maybeSingle();
    return row == null ? null : PraiseSetlistRevision.fromJson(row);
  }

  /// Ministérios destinatários da revisão.
  Future<List<({String id, String name})>> listRecipients(
    String revisionId,
  ) async {
    final rows = await _db
        .from('praise_setlist_recipient')
        .select('ministry_id, ministry(name)')
        .eq('revision_id', revisionId);
    return [
      for (final r in rows)
        (
          id: r['ministry_id'] as String,
          name: (r['ministry'] as Map?)?['name'] as String? ?? 'Ministério',
        ),
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Troca a lista inteira (rascunho ou publicada; exige publish).
  Future<void> setRecipients(String revisionId, Iterable<String> ministryIds) =>
      _db.rpc(
        'praise_setlist_set_recipients',
        params: {
          'p_revision_id': revisionId,
          'p_ministry_ids': ministryIds.toList(),
        },
      );

  /// Repertórios que [ministryId] recebeu: a revisão publicada tem ele como
  /// destinatário.
  Future<List<PraiseSetlist>> receivedSetlists(String ministryId) async {
    final rows = await _db
        .from('praise_setlist_recipient')
        .select(
          'praise_setlist_revision!inner($_revisionCols, '
          'praise_setlist_item(count), '
          'praise_setlist!inner(id, event_id, event(name, start_date), ministry(name)))',
        )
        .eq('ministry_id', ministryId)
        .eq('praise_setlist_revision.status', 'published');
    return [
      for (final r in rows)
        if (r['praise_setlist_revision'] case final Map<String, dynamic> rev)
          PraiseSetlist.fromJson({
            ...rev['praise_setlist'] as Map<String, dynamic>,
            'praise_setlist_revision': [rev],
          }),
    ];
  }

  Future<void> archive(String songId) => _db
      .from('praise_song')
      .update({'archived_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', songId);
}
