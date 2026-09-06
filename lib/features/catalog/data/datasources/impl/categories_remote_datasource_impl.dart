import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/features/catalog/data/datasources/categories_remote_datasource.dart';
import 'package:reem/features/catalog/data/models/category_node_model.dart';
import 'package:reem/features/catalog/domain/entities/category_attributes.dart';
import 'package:reem/features/catalog/domain/entities/category_node.dart';

final class CategoriesRemoteDataSourceImpl extends BaseRemoteDataSource
    implements CategoriesRemoteDataSource {
  const CategoriesRemoteDataSourceImpl(super.dio);

  @override
  Future<List<CategoryNode>> tree() async =>
      CategoryNodeModel.listFromJson(await getList(ApiEndpoints.categories));

  @override
  Future<CategoryAttributeSchema> attributeSchema(String categoryId) async {
    final json = await getJson(ApiEndpoints.categoryById(categoryId));
    return CategoryAttributeSchema.fromJson(json['attribute_schema']);
  }
}
