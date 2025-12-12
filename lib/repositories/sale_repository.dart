/// 销售仓库
/// 处理销售记录的增删改查功能

import '../models/api_response.dart';
import '../models/api_error.dart';
import '../services/api_service.dart';

/// 销售记录模型
class Sale {
  final int id;
  final int userId;
  final String productName;
  final double quantity; // 销售数量（必须大于0）
  final int? customerId;
  final String? saleDate;
  final double? totalSalePrice;
  final String? note;
  final String? createdAt;

  Sale({
    required this.id,
    required this.userId,
    required this.productName,
    required this.quantity,
    this.customerId,
    this.saleDate,
    this.totalSalePrice,
    this.note,
    this.createdAt,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'] as int,
      userId: json['userId'] as int? ?? json['user_id'] as int,
      productName: json['productName'] as String? ?? json['product_name'] as String,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      customerId: json['customerId'] as int? ?? json['customer_id'] as int?,
      saleDate: json['saleDate'] as String? ?? json['sale_date'] as String?,
      totalSalePrice: (json['totalSalePrice'] as num?)?.toDouble() ??
          (json['total_sale_price'] as num?)?.toDouble(),
      note: json['note'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'productName': productName,
      'quantity': quantity,
      if (customerId != null) 'customerId': customerId,
      if (saleDate != null) 'saleDate': saleDate,
      if (totalSalePrice != null) 'totalSalePrice': totalSalePrice,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  Sale copyWith({
    int? id,
    int? userId,
    String? productName,
    double? quantity,
    int? customerId,
    String? saleDate,
    double? totalSalePrice,
    String? note,
    String? createdAt,
  }) {
    return Sale(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      customerId: customerId ?? this.customerId,
      saleDate: saleDate ?? this.saleDate,
      totalSalePrice: totalSalePrice ?? this.totalSalePrice,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 销售创建请求
class SaleCreate {
  final String productName;
  final double quantity; // 销售数量（必须大于0）
  final int? customerId;
  final String? saleDate;
  final double? totalSalePrice;
  final String? note;

  SaleCreate({
    required this.productName,
    required this.quantity,
    this.customerId,
    this.saleDate,
    this.totalSalePrice,
    this.note,
  }) : assert(quantity > 0, '销售数量必须大于0');

  Map<String, dynamic> toJson() {
    return {
      'productName': productName,
      'quantity': quantity,
      if (customerId != null) 'customerId': customerId,
      if (saleDate != null) 'saleDate': saleDate,
      if (totalSalePrice != null) 'totalSalePrice': totalSalePrice,
      if (note != null) 'note': note,
    };
  }
}

/// 销售更新请求
class SaleUpdate {
  final String? productName;
  final double? quantity; // 销售数量（必须大于0）
  final int? customerId;
  final String? saleDate;
  final double? totalSalePrice;
  final String? note;

  SaleUpdate({
    this.productName,
    this.quantity,
    this.customerId,
    this.saleDate,
    this.totalSalePrice,
    this.note,
  }) : assert(quantity == null || quantity! > 0, '销售数量必须大于0');

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (productName != null) json['productName'] = productName;
    if (quantity != null) json['quantity'] = quantity;
    if (customerId != null) json['customerId'] = customerId;
    if (saleDate != null) json['saleDate'] = saleDate;
    if (totalSalePrice != null) json['totalSalePrice'] = totalSalePrice;
    if (note != null) json['note'] = note;
    return json;
  }
}

class SaleRepository {
  final ApiService _apiService = ApiService();

  /// 获取销售记录列表
  /// 
  /// [page] 页码，从 1 开始
  /// [pageSize] 每页数量
  /// [search] 搜索关键词（产品名称）
  /// [startDate] 开始日期（ISO8601格式）
  /// [endDate] 结束日期（ISO8601格式）
  /// [customerId] 客户ID筛选（null 表示不筛选，0 表示未分配客户）
  /// 
  /// 返回分页的销售记录列表
  Future<PaginatedResponse<Sale>> getSales({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? startDate,
    String? endDate,
    int? customerId,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      if (startDate != null) {
        queryParams['start_date'] = startDate;
      }

      if (endDate != null) {
        queryParams['end_date'] = endDate;
      }

      if (customerId != null) {
        queryParams['customer_id'] = customerId.toString();
      }

      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/sales',
        queryParameters: queryParams,
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return PaginatedResponse<Sale>.fromJson(
          response.data!,
          (json) => Sale.fromJson(json as Map<String, dynamic>),
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
      throw ApiError.unknown('获取销售记录列表失败', e);
    }
  }

  /// 获取单个销售记录详情
  /// 
  /// [saleId] 销售记录ID
  /// 
  /// 返回销售记录详情
  Future<Sale> getSale(int saleId) async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/sales/$saleId',
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Sale.fromJson(response.data!);
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('获取销售记录详情失败', e);
    }
  }

  /// 创建销售记录
  /// 
  /// [sale] 销售创建请求
  /// 
  /// 注意：销售时会自动减少产品库存，销售前必须检查库存是否充足
  /// 
  /// 返回创建的销售记录
  Future<Sale> createSale(SaleCreate sale) async {
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        '/api/sales',
        body: sale.toJson(),
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Sale.fromJson(response.data!);
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError catch (e) {
      // 如果是库存不足错误，提供更友好的错误信息
      if (e.statusCode == 400 && e.message.contains('库存不足')) {
        throw ApiError(
          message: e.message,
          errorCode: 'INSUFFICIENT_STOCK',
          statusCode: 400,
        );
      }
      rethrow;
    } catch (e) {
      throw ApiError.unknown('创建销售记录失败', e);
    }
  }

  /// 更新销售记录
  /// 
  /// [saleId] 销售记录ID
  /// [update] 销售更新请求
  /// 
  /// 注意：更新时会计算库存变化差值并更新产品库存
  /// - 如果新数量 > 旧数量，需要减少更多库存（检查库存是否足够）
  /// - 如果新数量 < 旧数量，需要恢复部分库存
  /// 
  /// 返回更新后的销售记录
  Future<Sale> updateSale(int saleId, SaleUpdate update) async {
    try {
      final response = await _apiService.put<Map<String, dynamic>>(
        '/api/sales/$saleId',
        body: update.toJson(),
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Sale.fromJson(response.data!);
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError catch (e) {
      // 如果是库存不足错误，提供更友好的错误信息
      if (e.statusCode == 400 && e.message.contains('库存不足')) {
        throw ApiError(
          message: e.message,
          errorCode: 'INSUFFICIENT_STOCK',
          statusCode: 400,
        );
      }
      // 如果是版本冲突
      if (e.statusCode == 409) {
        throw ApiError(
          message: '产品库存已被其他操作修改，请刷新后重试',
          errorCode: 'VERSION_CONFLICT',
          statusCode: 409,
        );
      }
      rethrow;
    } catch (e) {
      throw ApiError.unknown('更新销售记录失败', e);
    }
  }

  /// 删除销售记录
  /// 
  /// [saleId] 销售记录ID
  /// 
  /// 注意：删除时会自动恢复产品库存（增加库存）
  Future<void> deleteSale(int saleId) async {
    try {
      final response = await _apiService.delete(
        '/api/sales/$saleId',
        fromJsonT: (json) => json,
      );

      if (!response.isSuccess) {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError catch (e) {
      // 如果是版本冲突
      if (e.statusCode == 409) {
        throw ApiError(
          message: '产品库存已被其他操作修改，请刷新后重试',
          errorCode: 'VERSION_CONFLICT',
          statusCode: 409,
        );
      }
      rethrow;
    } catch (e) {
      throw ApiError.unknown('删除销售记录失败', e);
    }
  }
}

