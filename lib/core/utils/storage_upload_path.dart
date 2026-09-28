/// Monta o nome do objeto no Storage para os widgets de upload.
///
/// Sem [tenantId]: formato legado `<userId>_<timestamp>.<ext>` na raiz do
/// bucket (usado por quem ainda não tem policy por pasta).
///
/// Com [tenantId]: `<tenantId>/<userId>/<timestamp>.<ext>`. É o formato que as
/// policies de Storage por tenant exigem (CHU-370): o 1º segmento é conferido
/// contra `current_tenant_id()` e o 2º contra `auth.uid()`. Por isso [userId]
/// tem que ser o id de login (auth uid), nunca o `user_account.id`.
///
/// Com [namespace]: `<tenantId>/<userId>/<namespace>/<timestamp>.<ext>`. Serve
/// aos buckets multiuso, em que a policy precisa distinguir a finalidade do
/// arquivo — em `church-assets`, `church-branding` exige `church_info.edit`
/// enquanto `classifieds` é conteúdo pessoal (CHU-374). O namespace só vale
/// junto com [tenantId]: no formato legado não há pasta onde encaixá-lo.
///
/// Com [fileName]: usa esse nome no lugar do timestamp, para o caso em que o
/// upload precisa sobrescrever sempre o mesmo objeto (o wallpaper do chat de
/// suporte é o único). Continua dentro da pasta do próprio usuário.
String buildStorageUploadPath({
  required String userId,
  required int timestamp,
  required String extension,
  String? tenantId,
  String? namespace,
  String? fileName,
}) {
  final tenant = tenantId?.trim() ?? '';
  final base = (fileName?.trim().isNotEmpty ?? false)
      ? '${fileName!.trim()}.$extension'
      : '$timestamp.$extension';
  if (tenant.isEmpty) return '${userId}_$timestamp.$extension';

  final folder = namespace?.trim() ?? '';
  if (folder.isEmpty) return '$tenant/$userId/$base';
  return '$tenant/$userId/$folder/$base';
}
