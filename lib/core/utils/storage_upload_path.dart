/// Monta o nome do objeto no Storage para os widgets de upload.
///
/// Sem [tenantId]: formato legado `<userId>_<timestamp>.<ext>` na raiz do
/// bucket (usado por quem ainda não tem policy por pasta).
///
/// Com [tenantId]: `<tenantId>/<userId>/<timestamp>.<ext>`. É o formato que as
/// policies de Storage por tenant exigem (CHU-370): o 1º segmento é conferido
/// contra `current_tenant_id()` e o 2º contra `auth.uid()`. Por isso [userId]
/// tem que ser o id de login (auth uid), nunca o `user_account.id`.
String buildStorageUploadPath({
  required String userId,
  required int timestamp,
  required String extension,
  String? tenantId,
}) {
  final tenant = tenantId?.trim() ?? '';
  if (tenant.isEmpty) return '${userId}_$timestamp.$extension';
  return '$tenant/$userId/$timestamp.$extension';
}
