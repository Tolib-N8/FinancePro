import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/endpoints.dart';
import '../core/models/category.dart';
import 'api_client_provider.dart';

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final client = await ref.watch(apiClientProvider.future);
  final response = await client.get(Endpoints.categories);
  return (response.data as List).map((e) => Category.fromJson(e)).toList();
});
