import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/endpoints.dart';
import '../core/models/account.dart';
import 'api_client_provider.dart';

final accountsProvider = FutureProvider<List<Account>>((ref) async {
  final clientAsync = await ref.watch(apiClientProvider.future);
  final response = await clientAsync.get(Endpoints.accounts);
  return (response.data as List).map((e) => Account.fromJson(e)).toList();
});

final accountDetailProvider =
    FutureProvider.family<Account, String>((ref, id) async {
  final client = await ref.watch(apiClientProvider.future);
  final response = await client.get(Endpoints.account(id));
  return Account.fromJson(response.data);
});
