class Validators {
  static String? required(String? value, [String fieldName = 'Trường này']) {
    if (value == null || value.trim().isEmpty) return '$fieldName không được để trống';
    return null;
  }

  static String? amount(String? value) {
    if (value == null || value.trim().isEmpty) return 'Vui lòng nhập số tiền';
    final cleaned = value.replaceAll(RegExp(r'[,.\s₫]'), '');
    final parsed = int.tryParse(cleaned);
    if (parsed == null) return 'Định dạng số tiền không hợp lệ (chỉ nhập số)';
    if (parsed <= 0) return 'Số tiền phải lớn hơn 0';
    if (parsed > 100000000000) return 'Số tiền vượt quá giới hạn cho phép';
    return null;
  }

  static String? invoiceNumber(String? value) {
    if (value == null || value.trim().isEmpty) return 'Vui lòng nhập số hóa đơn';
    if (value.length < 3) return 'Số hóa đơn quá ngắn';
    return null;
  }

  static String? taxCode(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    final cleaned = value.replaceAll('-', '');
    if (!RegExp(r'^\d{10}(\d{3})?$').hasMatch(cleaned)) {
      return 'Mã số thuế không hợp lệ (10 hoặc 13 chữ số)';
    }
    return null;
  }
}
