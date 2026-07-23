import '../datasources/supabase_datasource.dart';
import '../datasources/local_datasource.dart';
import '../../core/utils/connectivity_helper.dart';
import '../models/partner_model.dart';

class PartnerRepository {
  final SupabaseDatasource _cloud;
  final LocalDatasource _local;

  PartnerRepository({SupabaseDatasource? cloud, LocalDatasource? local})
      : _cloud = cloud ?? SupabaseDatasource(),
        _local = local ?? LocalDatasource();

  Future<List<PartnerModel>> getAll() async {
    final localData = await _local.getAllPartners();
    if (await ConnectivityHelper.isOnline) {
      try {
        final cloudData = await _cloud.getAllPartners();
        if (cloudData.isNotEmpty) return cloudData;
      } catch (_) {}
    }
    return localData;
  }

  Future<PartnerModel?> getById(String id) async {
    return _local.getPartnerById(id);
  }

  Future<PartnerModel?> getByTaxCode(String taxCode) async {
    return _local.getPartnerByTaxCode(taxCode);
  }

  Future<void> add(PartnerModel partner) async {
    await _local.insertPartner(partner);
    if (await ConnectivityHelper.isOnline) {
      try {
        await _cloud.insertPartner(partner);
      } catch (_) {}
    }
  }

  Future<void> update(PartnerModel partner) async {
    await _local.updatePartner(partner);
    if (await ConnectivityHelper.isOnline) {
      try {
        await _cloud.updatePartner(partner);
      } catch (_) {}
    }
  }

  Future<void> remove(String id) async {
    await _local.deletePartner(id);
    if (await ConnectivityHelper.isOnline) {
      try {
        await _cloud.deletePartner(id);
      } catch (_) {}
    }
  }
}
