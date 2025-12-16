/// 采购仓库
/// 处理采购记录的增删改查功能

import '../models/api_response.dart';
import '../models/api_error.dart';
import '../services/api_service.dart';

/// 采购记录模型
class Purchase {
  final int id;
  final int userId;
  final String productName;
  final double quantity; // 采购数量（可为负数表示采购退货）
  final String? purchaseDate;
  final int? supplierId;
  final double? totalPurchasePrice;
  final String? note;
  final String? createdAt;

  Purchase({
    required this.id,
    required this.userId,
    required this.productName,
    required this.quantity,
    this.purchaseDate,
    this.supplierId,
    this.totalPurchasePrice,
    this.note,
    this.createdAt,
  });

  factory Purchase.fromJson(Map<String, dynamic> json) {
    return Purchase(
      id: json['id'] as int,
      userId: json['userId'] as int? ?? json['user_id'] as int,
      productName: json['productName'] as String? ?? json['product_name'] as String,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      purchaseDate: json['purchaseDate'] as String? ?? json['purchase_date'] as String?,
      supplierId: json['supplierId'] as int? ?? json['supplier_id'] as int?,
      totalPurchasePrice: (json['totalPurchasePrice'] as num?)?.toDouble() ??
          (json['total_purchase_price'] as num?)?.toDouble(),
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
      if (purchaseDate != null) 'purchaseDate': purchaseDate,
      if (supplierId != null) 'supplierId': supplierId,
      if (totalPurchasePrice != null) 'totalPurchasePrice': totalPurchasePrice,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  Purchase copyWith({
    int? id,
    int? userId,
    String? productName,
    double? quantity,
    String? purchaseDate,
    int? supplierId,
    double? totalPurchasePrice,
    String? note,
    String? createdAt,
  }) {
    return Purchase(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      supplierId: supplierId ?? this.supplierId,
      totalPurchasePrice: totalPurchasePrice ?? this.totalPurchasePrice,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 采购创建请求
class PurchaseCreate {
  final String productName;
  final double quantity; // 采购数量（可为负数表示采购退货）
  final String? purchaseDate;
  final int? supplierId;
  final double? totalPurchasePrice;
  final String? note;

  PurchaseCreate({
    required this.productName,
    required this.quantity,
    this.purchaseDate,
    this.supplierId,
    this.totalPurchasePrice,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'productName': productName,
      'quantity': quantity,
      if (purchaseDate != null) 'purchaseDate': purchaseDate,
      // 如果 supplierId 为 0，也发送 0（服务器端会将其转换为 NULL）
      if (supplierId != null) 'supplierId': supplierId,
      if (totalPurchasePrice != null) 'totalPurchasePrice': totalPurchasePrice,
      if (note != null) 'note': note,
    };
  }
}

/// 采购更新请求
class PurchaseUpdate {
  final String? productName;
  final double? quantity;
  final String? purchaseDate;
  final int? supplierId;
  final double? totalPurchasePrice;
  final String? note;

  PurchaseUpdate({
    this.productName,
    this.quantity,
    this.purchaseDate,
    this.supplierId,
    this.totalPurchasePrice,
    this.note,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (productName != null) json['productName'] = productName;
    if (quantity != null) json['quantity'] = quantity;
    if (purchaseDate != null) json['purchaseDate'] = purchaseDate;
    if (supplierId != null) json['supplierId'] = supplierId;
    if (totalPurchasePrice != null) json['totalPurchasePrice'] = totalPurchasePrice;
    if (note != null) json['note'] = note;
    return json;
  }
}

class PurchaseRepository {
  final ApiService _apiService = ApiService();

  /// 获取采购记录列表
  /// 
  /// [page] 页码，从 1 开始
  /// [pageSize] 每页数量
  /// [search] 搜索关键词（产品名称）
  /// [startDate] 开始日期（ISO8601格式）
  /// [endDate] 结束日期（ISO8601格式）
  /// [supplierId] 供应商ID筛选（null 表示不筛选，0 表示未分配供应商）
  /// 
  /// 返回分页的采购记录列表
  Future<PaginatedResponse<Purchase>> getPurchases({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? startDate,
    String? endDate,
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

      if (startDate != null) {
        queryParams['start_date'] = startDate;
      }

      if (endDate != null) {
        queryParams['end_date'] = endDate;
      }

      if (supplierId != null) {
        queryParams['supplier_id'] = supplierId.toString();
      }

      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/purchases',
        queryParameters: queryParams,
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return PaginatedResponse<Purchase>.fromJson(
          response.data!,
          (json) => Purchase.fromJson(json as Map<String, dynamic>),
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
      throw ApiError.unknown('获取采购记录列表失败', e);
    }
  }

  /// 获取单个采购记录详情
  /// 
  /// [purchaseId] 采购记录ID
  /// 
  /// 返回采购记录详情
  Future<Purchase> getPurchase(int purchaseId) async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/purchases/$purchaseId',
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Purchase.fromJson(response.data!);
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('获取采购记录详情失败', e);
    }
  }

  /// 创建采购记录
  /// 
  /// [purchase] 采购创建请求
  /// 
  /// 注意：采购时会自动更新产品库存
  /// - 正数数量：增加库存
  /// - 负数数量：减少库存（采购退货，需要检查库存是否足够）
  /// 
  /// 返回创建的采购记录
  Future<Purchase> createPurchase(PurchaseCreate purchase) async {
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        '/api/purchases',
        body: purchase.toJson(),
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Purchase.fromJson(response.data!);
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
      throw ApiError.unknown('创建采购记录失败', e);
    }
  }

  /// 更新采购记录
  /// 
  /// [purchaseId] 采购记录ID
  /// [update] 采购更新请求
  /// 
  /// 注意：更新时会计算库存变化差值并更新产品库存
  /// 
  /// 返回更新后的采购记录
  Future<Purchase> updatePurchase(int purchaseId, PurchaseUpdate update) async {
    try {
      final response = await _apiService.put<Map<String, dynamic>>(
        '/api/purchases/$purchaseId',
        body: update.toJson(),
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Purchase.fromJson(response.data!);
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
      throw ApiError.unknown('更新采购记录失败', e);
    }
  }

  /// 删除采购记录
  /// 
  /// [purchaseId] 采购记录ID
  /// 
  /// 注意：删除时会自动恢复产品库存（减去采购数量）
  Future<void> deletePurchase(int purchaseId) async {
    try {
      final response = await _apiService.delete(
        '/api/purchases/$purchaseId',
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
      throw ApiError.unknown('删除采购记录失败', e);
    }
  }
}


