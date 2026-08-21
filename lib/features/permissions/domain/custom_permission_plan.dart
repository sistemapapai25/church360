/// Estado de uma permissão para um usuário: o que o cargo concede
/// (`roleGranted`) e o override manual, quando existe (`customGranted`,
/// `null` = sem override, então vale o cargo).
class UserPermissionState {
  const UserPermissionState({
    required this.permissionId,
    required this.roleGranted,
    this.customGranted,
  });

  final String permissionId;
  final bool roleGranted;
  final bool? customGranted;

  bool get isGranted => customGranted ?? roleGranted;

  bool get isOverridden => customGranted != null;
}

/// Gravação em lote de overrides de permissão (CHU-317).
///
/// A tela de Usuário grava direto no banco a cada toque, e a decisão por
/// permissão não é um on/off: ela compara o que vem do cargo com o override
/// manual e escolhe entre gravar ou remover o override. Marcar uma categoria
/// inteira item a item seria um round-trip por permissão (`ministries` tem 19).
/// Esta classe resolve a mesma regra para N permissões de uma vez e agrupa o
/// resultado em três listas, que o repositório aplica em no máximo duas
/// requisições.
class CustomPermissionPlan {
  const CustomPermissionPlan({
    required this.grantIds,
    required this.denyIds,
    required this.clearIds,
  });

  /// Overrides a gravar com `is_granted = true`.
  final List<String> grantIds;

  /// Overrides a gravar com `is_granted = false`.
  final List<String> denyIds;

  /// Overrides a remover — a permissão volta a seguir o cargo.
  final List<String> clearIds;

  bool get isEmpty => grantIds.isEmpty && denyIds.isEmpty && clearIds.isEmpty;

  bool get isNotEmpty => !isEmpty;

  int get affectedCount => grantIds.length + denyIds.length + clearIds.length;

  /// Monta o plano para deixar todas as [permissions] com o valor efetivo
  /// [isGranted]. Permissões que já estão no estado desejado ficam de fora, o
  /// que mantém o payload pequeno e evita gravar linha que não muda nada.
  factory CustomPermissionPlan.forTarget({
    required Iterable<UserPermissionState> permissions,
    required bool isGranted,
  }) {
    final grantIds = <String>[];
    final denyIds = <String>[];
    final clearIds = <String>[];

    for (final permission in permissions) {
      if (isGranted) {
        if (permission.roleGranted) {
          // O cargo já habilita: basta remover um bloqueio manual, se houver.
          if (permission.isOverridden) clearIds.add(permission.permissionId);
        } else if (permission.customGranted != true) {
          // O cargo não habilita: precisa de override explícito.
          grantIds.add(permission.permissionId);
        }
      } else {
        if (permission.roleGranted) {
          // O cargo habilita: precisa de bloqueio manual.
          if (permission.customGranted != false) {
            denyIds.add(permission.permissionId);
          }
        } else if (permission.isOverridden) {
          // O cargo já não habilita: remover o override volta ao padrão false.
          clearIds.add(permission.permissionId);
        }
      }
    }

    return CustomPermissionPlan(
      grantIds: grantIds,
      denyIds: denyIds,
      clearIds: clearIds,
    );
  }
}
