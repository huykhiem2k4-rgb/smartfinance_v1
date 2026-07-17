enum InvoiceStatus { pending, approved, rejected, reviewing }

extension InvoiceStatusExt on InvoiceStatus {
  String get label {
    switch (this) {
      case InvoiceStatus.pending:   return 'Chờ kiểm tra';
      case InvoiceStatus.approved:  return 'Đã duyệt';
      case InvoiceStatus.rejected:  return 'Từ chối';
      case InvoiceStatus.reviewing: return 'Đang xét duyệt';
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
  /// Unit price in VND (int)
  final int unitPrice;

  const InvoiceItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  int get total => quantity * unitPrice;

  Map<String, dynamic> toMap() => {
        'name': name,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };

  factory InvoiceItem.fromMap(Map<String, dynamic> m) => InvoiceItem(
        name: m['name'] ?? '',
        quantity: (m['quantity'] as num?)?.toInt() ?? 1,
        unitPrice: (m['unitPrice'] as num?)?.toInt() ?? 0,
      );
}

class InvoiceModel {
  final String id;
  final String invoiceNumber;
  final String vendor;
  final String? vendorTaxCode;
  /// Subtotal (before VAT) in VND (int)
  final int subtotal;
  final VatRate vatRate;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final InvoiceStatus status;
  final double? aiConfidence;
  final String? aiNotes;
  final List<InvoiceItem> items;
  final String? imagePath;
  final DateTime createdAt;

  const InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.vendor,
    this.vendorTaxCode,
    required this.subtotal,
    required this.vatRate,
    required this.invoiceDate,
    this.dueDate,
    required this.status,
    this.aiConfidence,
    this.aiNotes,
    required this.items,
    this.imagePath,
    required this.createdAt,
  });

  int get vatAmount => (subtotal * vatRate.rate).round();
  int get totalAmount => subtotal + vatAmount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'invoice_number': invoiceNumber,
        'vendor': vendor,
        'vendor_tax_code': vendorTaxCode,
        'subtotal': subtotal,
        'vat_rate': vatRate.name,
        'invoice_date': invoiceDate.toIso8601String(),
        'due_date': dueDate?.toIso8601String(),
        'status': status.name,
        'ai_confidence': aiConfidence,
        'ai_notes': aiNotes,
        'items_json': _encodeItems(),
        'image_path': imagePath,
        'created_at': createdAt.toIso8601String(),
      };

  String _encodeItems() {
    return items.map((i) => '${i.name}|||${i.quantity}|||${i.unitPrice}').join('~~~');
  }

  factory InvoiceModel.fromMap(Map<String, dynamic> m, {List<InvoiceItem>? items}) {
    List<InvoiceItem> parsedItems = items ?? [];

    if (parsedItems.isEmpty) {
      final raw = m['items_json']?.toString() ?? '';
      if (raw.isNotEmpty) {
        parsedItems = raw.split('~~~').map((s) {
          final parts = s.split('|||');
          if (parts.length != 3) return null;
          return InvoiceItem(
            name: parts[0],
            quantity: int.tryParse(parts[1]) ?? 1,
            unitPrice: int.tryParse(parts[2]) ?? 0,
          );
        }).whereType<InvoiceItem>().toList();
      }
    }

    return InvoiceModel(
      id: m['id'],
      invoiceNumber: m['invoice_number'],
      vendor: m['vendor'],
      vendorTaxCode: m['vendor_tax_code'],
      subtotal: (m['subtotal'] as num).toInt(),
      vatRate: VatRate.values.firstWhere(
        (e) => e.name == (m['vat_rate'] ?? 'vat10'),
        orElse: () => VatRate.vat10,
      ),
      invoiceDate: DateTime.parse(m['invoice_date']),
      dueDate: m['due_date'] != null ? DateTime.parse(m['due_date']) : null,
      status: InvoiceStatus.values.firstWhere(
        (e) => e.name == m['status'],
        orElse: () => InvoiceStatus.pending,
      ),
      aiConfidence: m['ai_confidence'] != null ? (m['ai_confidence'] as num).toDouble() : null,
      aiNotes: m['ai_notes'],
      items: parsedItems,
      imagePath: m['image_path'],
      createdAt: DateTime.parse(m['created_at']),
    );
  }

  InvoiceModel copyWith({
    InvoiceStatus? status,
    double? aiConfidence,
    String? aiNotes,
    String? imagePath,
    String? invoiceNumber,
    String? vendor,
    String? vendorTaxCode,
    int? subtotal,
    VatRate? vatRate,
    List<InvoiceItem>? items,
  }) =>
      InvoiceModel(
        id: id,
        invoiceNumber: invoiceNumber ?? this.invoiceNumber,
        vendor: vendor ?? this.vendor,
        vendorTaxCode: vendorTaxCode ?? this.vendorTaxCode,
        subtotal: subtotal ?? this.subtotal,
        vatRate: vatRate ?? this.vatRate,
        invoiceDate: invoiceDate,
        dueDate: dueDate,
        status: status ?? this.status,
        aiConfidence: aiConfidence ?? this.aiConfidence,
        aiNotes: aiNotes ?? this.aiNotes,
        items: items ?? this.items,
        imagePath: imagePath ?? this.imagePath,
        createdAt: createdAt,
      );
}
