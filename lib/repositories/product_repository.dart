/// 产品仓库
/// 处理产品的增删改查、库存更新等功能

import '../models/api_response.dart';
import '../models/api_error.dart';
import '../services/api_service.dart';

/// 产品单位枚举
enum ProductUnit {
  jin('斤'),
  kilogram('公斤'),
  bag('袋');

  final String value;
  const ProductUnit(this.value);

  static ProductUnit fromString(String value) {
    return ProductUnit.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ProductUnit.kilogram,
    );
  }
}

/// 产品模型
class Product {
  final int id;
  final int userId;
  final String name;
  final String? description;
  final double stock;
  final ProductUnit unit;
  final int? supplierId;
  final int version; // 乐观锁版本号
  final String? createdAt;
  final String? updatedAt;

  Product({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.stock,
    required this.unit,
    this.supplierId,
    required this.version,
    this.createdAt,
    this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      userId: json['userId'] as int? ?? json['user_id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      stock: (json['stock'] as num?)?.toDouble() ?? 0.0,
      unit: ProductUnit.fromString(json['unit'] as String? ?? '公斤'),
      supplierId: json['supplierId'] as int? ?? json['supplier_id'] as int?,
      version: json['version'] as int? ?? 1,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      if (description != null) 'description': description,
      'stock': stock,
      'unit': unit.value,
      if (supplierId != null) 'supplierId': supplierId,
      'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  Product copyWith({
    int? id,
    int? userId,
    String? name,
    String? description,
    double? stock,
    ProductUnit? unit,
    int? supplierId,
    int? version,
    String? createdAt,
    String? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      stock: stock ?? this.stock,
      unit: unit ?? this.unit,
      supplierId: supplierId ?? this.supplierId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 产品创建请求
class ProductCreate {
  final String name;
  final String? description;
  final double stock;
  final ProductUnit unit;
  final int? supplierId;

  ProductCreate({
    required this.name,
    this.description,
    required this.stock,
    required this.unit,
    this.supplierId,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (description != null) 'description': description,
      'stock': stock,
      'unit': unit.value,
      if (supplierId != null) 'supplierId': supplierId,
    };
  }
}

/// 产品更新请求
class ProductUpdate {
  final String? name;
  final String? description;
  final double? stock;
  final ProductUnit? unit;
  final int? supplierId;
  final int? version; // 乐观锁版本号

  ProductUpdate({
    this.name,
    this.description,
    this.stock,
    this.unit,
    this.supplierId,
    this.version,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (name != null) json['name'] = name;
    if (description != null) json['description'] = description;
    if (stock != null) json['stock'] = stock;
    if (unit != null) json['unit'] = unit!.value;
    if (supplierId != null) json['supplierId'] = supplierId;
    if (version != null) json['version'] = version;
    return json;
  }
}

/// 库存更新请求
class ProductStockUpdate {
  final double quantity; // 数量变化（正数增加，负数减少）
  final int version; // 当前版本号

  ProductStockUpdate({
    required this.quantity,
    required this.version,
  });

  Map<String, dynamic> toJson() {
    return {
      'quantity': quantity,
      'version': version,
    };
  }
}

class ProductRepository {
  final ApiService _apiService = ApiService();

  /// 获取产品列表
  /// 
  /// [page] 页码，从 1 开始
  /// [pageSize] 每页数量
  /// [search] 搜索关键词（产品名称或描述）
  /// [supplierId] 供应商ID筛选（null 表示不筛选，0 表示未分配供应商）
  /// 
  /// 返回分页的产品列表
  Future<PaginatedResponse<Product>> getProducts({
    int page = 1,
    int pageSize = 20,
    String? search,
    int? supplierId,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      if (supplierId != null) {
        queryParams['supplier_id'] = supplierId.toString();
      }

      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/products',
        queryParameters: queryParams,
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return PaginatedResponse<Product>.fromJson(
          response.data!,
          (json) => Product.fromJson(json as Map<String, dynamic>),
        );
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('获取产品列表失败', e);
    }
  }

  /// 获取单个产品详情
  /// 
  /// [productId] 产品ID
  /// 
  /// 返回产品详情
  Future<Product> getProduct(int productId) async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/products/$productId',
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Product.fromJson(response.data!);
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('获取产品详情失败', e);
    }
  }

  /// 创建产品
  /// 
  /// [product] 产品创建请求
  /// 
  /// 返回创建的产品
  Future<Product> createProduct(ProductCreate product) async {
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        '/api/products',
        body: product.toJson(),
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Product.fromJson(response.data!);
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('创建产品失败', e);
    }
  }

  /// 更新产品
  /// 
  /// [productId] 产品ID
  /// [update] 产品更新请求（必须包含版本号用于乐观锁）
  /// 
  /// 返回更新后的产品
  Future<Product> updateProduct(int productId, ProductUpdate update) async {
    try {
      final response = await _apiService.put<Map<String, dynamic>>(
        '/api/products/$productId',
        body: update.toJson(),
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Product.fromJson(response.data!);
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError catch (e) {
      // 如果是版本冲突，提供更友好的错误信息
      if (e.statusCode == 409) {
        throw ApiError(
          message: '产品已被其他操作修改，请刷新后重试',
          errorCode: 'VERSION_CONFLICT',
          statusCode: 409,
        );
      }
      rethrow;
    } catch (e) {
      throw ApiError.unknown('更新产品失败', e);
    }
  }

  /// 删除产品
  /// 
  /// [productId] 产品ID
  Future<void> deleteProduct(int productId) async {
    try {
      final response = await _apiService.delete(
        '/api/products/$productId',
        fromJsonT: (json) => json,
      );

      if (!response.isSuccess) {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('删除产品失败', e);
    }
  }

  /// 更新产品库存
  /// 
  /// [productId] 产品ID
  /// [stockUpdate] 库存更新请求（必须包含版本号用于乐观锁）
  /// 
  /// 返回更新后的产品
  Future<Product> updateProductStock(
    int productId,
    ProductStockUpdate stockUpdate,
  ) async {
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        '/api/products/$productId/stock',
        body: stockUpdate.toJson(),
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Product.fromJson(response.data!);
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError catch (e) {
      // 如果是版本冲突，提供更友好的错误信息
      if (e.statusCode == 409) {
        throw ApiError(
          message: '产品库存已被其他操作修改，请刷新后重试',
          errorCode: 'VERSION_CONFLICT',
          statusCode: 409,
        );
      }
      // 如果是库存不足
      if (e.statusCode == 400 && e.message.contains('库存不足')) {
        throw ApiError(
          message: e.message,
          errorCode: 'INSUFFICIENT_STOCK',
          statusCode: 400,
        );
      }
      rethrow;
    } catch (e) {
      throw ApiError.unknown('更新产品库存失败', e);
    }
  }

  /// 搜索所有产品（不分页，用于下拉选择等场景）
  /// 
  /// [search] 搜索关键词
  /// 
  /// 返回匹配的产品列表（最多 50 条）
  Future<List<Product>> searchAllProducts(String search) async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/products/search/all',
        queryParameters: {'search': search},
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        final productsJson = response.data!['products'] as List<dynamic>? ?? [];
        return productsJson
            .map((json) => Product.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('搜索产品失败', e);
    }
  }
}


