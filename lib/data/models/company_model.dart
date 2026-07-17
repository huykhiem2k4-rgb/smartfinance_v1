class CompanyModel {
  final String id;
  final String name;
  final String? taxCode;
  final String? address;
  final String? phone;
  final String? email;
  final String? logoUrl;
  final DateTime createdAt;

  const CompanyModel({
    required this.id,
    required this.name,
    this.taxCode,
    this.address,
    this.phone,
    this.email,
    this.logoUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'tax_code': taxCode,
        'address': address,
        'phone': phone,
        'email': email,
        'logo_url': logoUrl,
        'created_at': createdAt.toIso8601String(),
      };

  factory CompanyModel.fromMap(Map<String, dynamic> m) => CompanyModel(
        id: m['id'],
        name: m['name'],
        taxCode: m['tax_code'],
        address: m['address'],
        phone: m['phone'],
        email: m['email'],
        logoUrl: m['logo_url'],
        createdAt: DateTime.parse(m['created_at']),
      );

  CompanyModel copyWith({String? name, String? taxCode, String? address, String? phone, String? email}) =>
      CompanyModel(
        id: id,
        name: name ?? this.name,
        taxCode: taxCode ?? this.taxCode,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        logoUrl: logoUrl,
        createdAt: createdAt,
      );
}
