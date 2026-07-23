import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../../data/models/partner_model.dart';
import '../../../core/theme/app_theme.dart';

class PartnerManagementScreen extends StatefulWidget {
  const PartnerManagementScreen({super.key});
  @override
  State<PartnerManagementScreen> createState() => _PartnerManagementScreenState();
}

class _PartnerManagementScreenState extends State<PartnerManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<PartnerModel> _filterByType(List<PartnerModel> list, String type) =>
      list.where((p) => p.partnerType == type).toList();

  void _showAddDialog({PartnerModel? existing}) {
    final result = showDialog<PartnerModel>(
      context: context,
      builder: (_) => _PartnerDialog(existing: existing),
    );
    result.then((partner) {
      if (partner == null || !mounted) return;
      final p = context.read<AppProvider>();
      if (existing != null) {
        p.updatePartner(partner);
      } else {
        p.addPartner(partner);
      }
    });
  }

  Future<void> _deletePartner(PartnerModel partner) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Xóa đối tác'),
        content: Text('Xóa "${partner.partnerName}"?\nThao tác này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      if (!mounted) return;
      await context.read<AppProvider>().deletePartner(partner.partnerId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Quản lý đối tác'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppColors.accent,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Khách hàng'),
            Tab(icon: Icon(Icons.business), text: 'Nhà cung cấp'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Thêm', style: TextStyle(color: Colors.white)),
      ),
      body: Consumer<AppProvider>(
        builder: (ctx, p, _) {
          if (p.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final customers = _filterByType(p.partners, 'CUSTOMER');
          final suppliers = _filterByType(p.partners, 'SUPPLIER');
          return TabBarView(
            controller: _tabs,
            children: [
              _PartnerList(
                partners: customers,
                emptyText: 'Chưa có khách hàng nào',
                onTap: (p) => _showAddDialog(existing: p),
                onDelete: _deletePartner,
              ),
              _PartnerList(
                partners: suppliers,
                emptyText: 'Chưa có nhà cung cấp nào',
                onTap: (p) => _showAddDialog(existing: p),
                onDelete: _deletePartner,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Partner List ─────────────────────────────────────────────────
class _PartnerList extends StatelessWidget {
  final List<PartnerModel> partners;
  final String emptyText;
  final void Function(PartnerModel) onTap;
  final Future<void> Function(PartnerModel) onDelete;

  const _PartnerList({
    required this.partners,
    required this.emptyText,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (partners.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(emptyText, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => context.read<AppProvider>().loadAll(),
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: partners.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => Dismissible(
          key: ValueKey(partners[i].partnerId),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.expense,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            await onDelete(partners[i]);
            return false;
          },
          child: _PartnerCard(
            partner: partners[i],
            onTap: () => onTap(partners[i]),
          ),
        ),
      ),
    );
  }
}

// ── Partner Card ─────────────────────────────────────────────────
class _PartnerCard extends StatelessWidget {
  final PartnerModel partner;
  final VoidCallback onTap;

  const _PartnerCard({required this.partner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCustomer = partner.isCustomer;
    final typeColor = isCustomer ? AppColors.income : AppColors.primary;
    final typeLabel = isCustomer ? 'Khách hàng' : 'Nhà cung cấp';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: typeColor.withValues(alpha: 0.12),
                    child: Text(
                      partner.partnerName.isNotEmpty
                          ? partner.partnerName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: typeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partner.partnerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          typeLabel,
                          style: TextStyle(
                            color: typeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: partner.status == 'ACTIVE'
                          ? AppColors.income.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      partner.status == 'ACTIVE' ? 'Đang hoạt động' : 'Ngừng hoạt động',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: partner.status == 'ACTIVE' ? AppColors.income : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              if (partner.taxCode != null || partner.phone != null || partner.email != null) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    if (partner.taxCode != null)
                      _InfoChip(Icons.confirmation_number_outlined, partner.taxCode!),
                    if (partner.phone != null)
                      _InfoChip(Icons.phone_outlined, partner.phone!),
                    if (partner.email != null)
                      _InfoChip(Icons.email_outlined, partner.email!),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      );
}

// ── Add / Edit Dialog ────────────────────────────────────────────
class _PartnerDialog extends StatefulWidget {
  final PartnerModel? existing;
  const _PartnerDialog({this.existing});

  @override
  State<_PartnerDialog> createState() => _PartnerDialogState();
}

class _PartnerDialogState extends State<_PartnerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _taxCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late String _type;

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.partnerName ?? '');
    _taxCtrl = TextEditingController(text: e?.taxCode ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _emailCtrl = TextEditingController(text: e?.email ?? '');
    _addressCtrl = TextEditingController(text: e?.address ?? '');
    _type = e?.partnerType ?? 'CUSTOMER';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _taxCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final partner = PartnerModel(
      partnerId: widget.existing?.partnerId ??
          'p_${DateTime.now().millisecondsSinceEpoch}',
      partnerName: _nameCtrl.text.trim(),
      partnerType: _type,
      taxCode: _taxCtrl.text.trim().isEmpty ? null : _taxCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      status: widget.existing?.status ?? 'ACTIVE',
      createdAt: widget.existing?.createdAt,
    );
    Navigator.pop(context, partner);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? 'Sửa đối tác' : 'Thêm đối tác mới'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên đối tác *',
                  prefixIcon: Icon(Icons.business),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Loại đối tác',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'CUSTOMER', child: Text('Khách hàng')),
                  DropdownMenuItem(value: 'SUPPLIER', child: Text('Nhà cung cấp')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'CUSTOMER'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _taxCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mã số thuế',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(isEditing ? 'Lưu' : 'Thêm'),
        ),
      ],
    );
  }
}
