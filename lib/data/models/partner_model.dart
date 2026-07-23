class PartnerModel {
  final String partnerId;
  final String partnerName;
  final String partnerType; // CUSTOMER | SUPPLIER
  final String? taxCode;
  final String? phone;
  final String? email;
  final String? address;
  final String status; // ACTIVE | INACTIVE
  final DateTime createdAt;

  PartnerModel({
    required this.partnerId,
    required this.partnerName,
    required this.partnerType,
    this.taxCode,
    this.phone,
    this.email,
    this.address,
    this.status = 'ACTIVE',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isCustomer => partnerType == 'CUSTOMER';
  bool get isSupplier => partnerType == 'SUPPLIER';

  Map<String, dynamic> toMap() => {
    'partner_id': partnerId,
    'partner_name': partnerName,
    'partner_type': partnerType,
    'tax_code': taxCode,
    'phone': phone,
    'email': email,
    'address': address,
    'status': status,
    'created_at': createdAt.toIso8601String(),
  };

  factory PartnerModel.fromMap(Map<String, dynamic> m) => PartnerModel(
    partnerId: m['partner_id'] as String,
    partnerName: m['partner_name'] as String,
    partnerType: m['partner_type'] as String,
    taxCode: m['tax_code'] as String?,
    phone: m['phone'] as String?,
    email: m['email'] as String?,
    address: m['address'] as String?,
    status: (m['status'] as String?) ?? 'ACTIVE',
    createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
  );

  PartnerModel copyWith({
    String? partnerId,
    String? partnerName,
    String? partnerType,
    String? taxCode,
    String? phone,
    String? email,
    String? address,
    String? status,
  }) => PartnerModel(
    partnerId: partnerId ?? this.partnerId,
    partnerName: partnerName ?? this.partnerName,
    partnerType: partnerType ?? this.partnerType,
    taxCode: taxCode ?? this.taxCode,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    address: address ?? this.address,
    status: status ?? this.status,
    createdAt: createdAt,
  );
}
