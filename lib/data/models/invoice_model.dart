enum InvoiceStatus { draft, pending, approved, rejected }

extension InvoiceStatusExt on InvoiceStatus {
  String get label {
    switch (this) {
      case InvoiceStatus.draft:    return 'Nháp';
      case InvoiceStatus.pending:  return 'Chờ duyệt';
      case InvoiceStatus.approved: return 'Đã duyệt';
      case InvoiceStatus.rejected: return 'Từ chối';
    }
  }
}

enum VatRate { vat8, vat10, none }

extension VatRateExt on VatRate {
  String get label {
    switch (this) {
      case VatRate.vat8:  return '8%';
      case VatRate.vat10: return '10%';
      case VatRate.none:  return 'Không có';
    }
  }
  double get rate {
    switch (this) {
      case VatRate.vat8:  return 0.08;
      case VatRate.vat10: return 0.10;
      case VatRate.none:  return 0.0;
    }
  }
}

class InvoiceItem {
  final String name;
  final int quantity;
  final int unitPrice;
  final String? unit;

  const InvoiceItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.unit,
  });

  int get total => quantity * unitPrice;
  int get lineTotal => total;

  Map<String, dynamic> toMap() => {
        'item_name': name,
        'quantity': quantity,
        'unit_price': unitPrice,
        'unit': unit ?? 'cái',
        'line_total': lineTotal,
      };

  factory InvoiceItem.fromMap(Map<String, dynamic> m) => InvoiceItem(
        name: m['item_name'] as String? ?? m['name'] as String? ?? '',
        quantity: (m['quantity'] as num?)?.toInt() ?? 1,
        unitPrice: (m['unit_price'] as num?)?.toInt() ?? 0,
        unit: m['unit'] as String?,
      );
}

class InvoiceModel {
  final String id;
  final String invoiceNumber;
  final String? partnerId;
  final String? createdBy;
  final String invoiceType; // IN | OUT
  final int subtotal;
  final VatRate vatRate;
  final int vatAmount;
  final int totalAmount;
  final DateTime invoiceDate;
  final InvoiceStatus status;
  final List<InvoiceItem> items;
  final String? imagePath;
  final String? pdfUrl;
  final String? ocrText;
  final String? note;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    this.partnerId,
    this.createdBy,
    this.invoiceType = 'IN',
    required this.subtotal,
    required this.vatRate,
    required this.vatAmount,
    required this.totalAmount,
    required this.invoiceDate,
    required this.status,
    required this.items,
    this.imagePath,
    this.pdfUrl,
    this.ocrText,
    this.note,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isDraft => status == InvoiceStatus.draft;
  bool get isPending => status == InvoiceStatus.pending;
  bool get isApproved => status == InvoiceStatus.approved;
  bool get isRejected => status == InvoiceStatus.rejected;
  bool get isIncoming => invoiceType == 'IN';
  bool get isOutgoing => invoiceType == 'OUT';

  Map<String, dynamic> toMap() => {
        'id': id,
        'invoice_number': invoiceNumber,
        'partner_id': partnerId,
        'created_by': createdBy,
        'invoice_type': invoiceType,
        'subtotal': subtotal,
        'vat_rate': vatRate.name,
        'vat_amount': vatAmount,
        'total_amount': totalAmount,
        'invoice_date': invoiceDate.toIso8601String(),
        'status': status.name.toUpperCase(),
        'image_path': imagePath,
        'pdf_url': pdfUrl,
        'ocr_text': ocrText,
        'note': note,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory InvoiceModel.fromMap(Map<String, dynamic> m, {List<InvoiceItem>? items}) {
    final parsedItems = items ?? [];

    return InvoiceModel(
      id: m['id'] as String,
      invoiceNumber: m['invoice_number'] as String,
      partnerId: m['partner_id'] as String?,
      createdBy: m['created_by'] as String?,
      invoiceType: (m['invoice_type'] as String?) ?? 'IN',
      subtotal: (m['subtotal'] as num).toInt(),
      vatRate: VatRate.values.firstWhere(
        (e) => e.name == (m['vat_rate'] ?? 'none'),
        orElse: () => VatRate.none,
      ),
      vatAmount: (m['vat_amount'] as num?)?.toInt() ?? 0,
      totalAmount: (m['total_amount'] as num?)?.toInt() ?? 0,
      invoiceDate: DateTime.parse(m['invoice_date'] as String),
      status: InvoiceStatus.values.firstWhere(
        (e) => e.name == (m['status'] as String?)?.toLowerCase(),
        orElse: () => InvoiceStatus.draft,
      ),
      items: parsedItems,
      imagePath: m['image_path'] as String?,
      pdfUrl: m['pdf_url'] as String?,
      ocrText: m['ocr_text'] as String?,
      note: m['note'] as String?,
      createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: m['updated_at'] != null ? DateTime.tryParse(m['updated_at'] as String) : null,
    );
  }

  InvoiceModel copyWith({
    InvoiceStatus? status,
    String? invoiceNumber,
    String? partnerId,
    String? invoiceType,
    int? subtotal,
    VatRate? vatRate,
    int? vatAmount,
    int? totalAmount,
    List<InvoiceItem>? items,
    String? imagePath,
    String? pdfUrl,
    String? ocrText,
    String? note,
  }) =>
      InvoiceModel(
        id: id,
        invoiceNumber: invoiceNumber ?? this.invoiceNumber,
        partnerId: partnerId ?? this.partnerId,
        createdBy: createdBy,
        invoiceType: invoiceType ?? this.invoiceType,
        subtotal: subtotal ?? this.subtotal,
        vatRate: vatRate ?? this.vatRate,
        vatAmount: vatAmount ?? this.vatAmount,
        totalAmount: totalAmount ?? this.totalAmount,
        invoiceDate: invoiceDate,
        status: status ?? this.status,
        items: items ?? this.items,
        imagePath: imagePath ?? this.imagePath,
        pdfUrl: pdfUrl ?? this.pdfUrl,
        ocrText: ocrText ?? this.ocrText,
        note: note ?? this.note,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
