String lgpdRequestTypeLabel(String type) {
  switch (type.trim().toLowerCase()) {
    case 'export':
      return 'Exportação de dados';
    case 'deletion':
      return 'Exclusão de dados';
    case 'anonymization':
      return 'Anonimização';
    case 'retention':
      return 'Retenção';
    default:
      return type;
  }
}

String lgpdStatusLabel(String status) {
  switch (status.trim().toLowerCase()) {
    case 'all':
      return 'Todos';
    case 'pending':
      return 'Pendente';
    case 'in_review':
      return 'Em análise';
    case 'approved':
      return 'Aprovada';
    case 'rejected':
      return 'Rejeitada';
    case 'completed':
      return 'Concluída';
    default:
      return status;
  }
}
