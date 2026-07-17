class AuditLogModel {
  final String id;
  final String? companyId;
  final String action;
  final String entityType;
  final String entityId;
  final String? oldValue;
  final String? newValue;
  final String performedBy;
  final DateTime createdAt;

  const AuditLogModel({
    required this.id,
    this.companyId,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.oldValue,
    this.newValue,
    required this.performedBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'company_id': companyId,
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'old_value': oldValue,
        'new_value': newValue,
        'performed_by': performedBy,
        'created_at': createdAt.toIso8601String(),
      };

  factory AuditLogModel.fromMap(Map<String, dynamic> m) => AuditLogModel(
        id: m['id'],
        companyId: m['company_id'],
        action: m['action'],
        entityType: m['entity_type'],
        entityId: m['entity_id'],
        oldValue: m['old_value'],
        newValue: m['new_value'],
        performedBy: m['performed_by'],
        createdAt: DateTime.parse(m['created_at']),
      );
}
