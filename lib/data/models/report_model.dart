class ReportModel {
  final String id;
  final String? companyId;
  final String periodType;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String reportType;
  final String snapshotData;
  final String createdBy;
  final DateTime createdAt;

  const ReportModel({
    required this.id,
    this.companyId,
    required this.periodType,
    required this.periodStart,
    required this.periodEnd,
    required this.reportType,
    required this.snapshotData,
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'company_id': companyId,
        'period_type': periodType,
        'period_start': periodStart.toIso8601String(),
        'period_end': periodEnd.toIso8601String(),
        'report_type': reportType,
        'snapshot_data': snapshotData,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };

  factory ReportModel.fromMap(Map<String, dynamic> m) => ReportModel(
        id: m['id'],
        companyId: m['company_id'],
        periodType: m['period_type'],
        periodStart: DateTime.parse(m['period_start']),
        periodEnd: DateTime.parse(m['period_end']),
        reportType: m['report_type'],
        snapshotData: m['snapshot_data'] ?? '{}',
        createdBy: m['created_by'],
        createdAt: DateTime.parse(m['created_at']),
      );
}
