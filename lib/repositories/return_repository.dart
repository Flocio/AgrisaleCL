/// 退货仓库
/// 处理退货记录的增删改查功能

import '../models/api_response.dart';
import '../models/api_error.dart';
import '../services/api_service.dart';

/// 退货记录模型
class Return {
  final int id;
  final int userId;
  final String productName;
  final double quantity; // 退货数量（必须大于0）
  final int? customerId;
  final String? returnDate;
  final double? totalReturnPrice;
  final String? note;
  final String? createdAt;

  Return({
    required this.id,
    required this.userId,
    required this.productName,
    required this.quantity,
    this.customerId,
    this.returnDate,
    this.totalReturnPrice,
    this.note,
    this.createdAt,
  });

  factory Return.fromJson(Map<String, dynamic> json) {
    return Return(
      id: json['id'] as int,
      userId: json['userId'] as int? ?? json['user_id'] as int,
      productName: json['productName'] as String? ?? json['product_name'] as String,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      customerId: json['customerId'] as int? ?? json['customer_id'] as int?,
      returnDate: json['returnDate'] as String? ?? json['return_date'] as String?,
      totalReturnPrice: (json['totalReturnPrice'] as num?)?.toDouble() ??
          (json['total_return_price'] as num?)?.toDouble(),
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
      if (returnDate != null) 'returnDate': returnDate,
      if (totalReturnPrice != null) 'totalReturnPrice': totalReturnPrice,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  Return copyWith({
    int? id,
    int? userId,
    String? productName,
    double? quantity,
    int? customerId,
    String? returnDate,
    double? totalReturnPrice,
    String? note,
    String? createdAt,
  }) {
    return Return(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      customerId: customerId ?? this.customerId,
      returnDate: returnDate ?? this.returnDate,
      totalReturnPrice: totalReturnPrice ?? this.totalReturnPrice,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 退货创建请求
class ReturnCreate {
  final String productName;
  final double quantity; // 退货数量（必须大于0）
  final int? customerId;
  final String? returnDate;
  final double? totalReturnPrice;
  final String? note;

  ReturnCreate({
    required this.productName,
    required this.quantity,
    this.customerId,
    this.returnDate,
    this.totalReturnPrice,
    this.note,
  }) : assert(quantity > 0, '退货数量必须大于0');

  Map<String, dynamic> toJson() {
    return {
      'productName': productName,
      'quantity': quantity,
      if (customerId != null) 'customerId': customerId,
      if (returnDate != null) 'returnDate': returnDate,
      if (totalReturnPrice != null) 'totalReturnPrice': totalReturnPrice,
      if (note != null) 'note': note,
    };
  }
}

/// 退货更新请求
class ReturnUpdate {
  final String? productName;
  final double? quantity; // 退货数量（必须大于0）
  final int? customerId;
  final String? returnDate;
  final double? totalReturnPrice;
  final String? note;

  ReturnUpdate({
    this.productName,
    this.quantity,
    this.customerId,
    this.returnDate,
    this.totalReturnPrice,
    this.note,
  }) : assert(quantity == null || quantity! > 0, '退货数量必须大于0');

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (productName != null) json['productName'] = productName;
    if (quantity != null) json['quantity'] = quantity;
    if (customerId != null) json['customerId'] = customerId;
    if (returnDate != null) json['returnDate'] = returnDate;
    if (totalReturnPrice != null) json['totalReturnPrice'] = totalReturnPrice;
    if (note != null) json['note'] = note;
    return json;
  }
}

class ReturnRepository {
  final ApiService _apiService = ApiService();

  /// 获取退货记录列表
  /// 
  /// [page] 页码，从 1 开始
  /// [pageSize] 每页数量
  /// [search] 搜索关键词（产品名称）
  /// [startDate] 开始日期（ISO8601格式）
  /// [endDate] 结束日期（ISO8601格式）
  /// [customerId] 客户ID筛选（null 表示不筛选，0 表示未分配客户）
  /// 
  /// 返回分页的退货记录列表
  Future<PaginatedResponse<Return>> getReturns({
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
        '/api/returns',
        queryParameters: queryParams,
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return PaginatedResponse<Return>.fromJson(
          response.data!,
          (json) => Return.fromJson(json as Map<String, dynamic>),
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
      throw ApiError.unknown('获取退货记录列表失败', e);
    }
  }

  /// 获取单个退货记录详情
  /// 
  /// [returnId] 退货记录ID
  /// 
  /// 返回退货记录详情
  Future<Return> getReturn(int returnId) async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/returns/$returnId',
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Return.fromJson(response.data!);
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('获取退货记录详情失败', e);
    }
  }

  /// 创建退货记录
  /// 
  /// [returnRecord] 退货创建请求
  /// 
  /// 注意：退货时会自动增加产品库存（退货数量必须大于0）
  /// 
  /// 返回创建的退货记录
  Future<Return> createReturn(ReturnCreate returnRecord) async {
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        '/api/returns',
        body: returnRecord.toJson(),
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Return.fromJson(response.data!);
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('创建退货记录失败', e);
    }
  }

  /// 更新退货记录
  /// 
  /// [returnId] 退货记录ID
  /// [update] 退货更新请求
  /// 
  /// 注意：更新时会计算库存变化差值并更新产品库存
  /// - 如果新数量 > 旧数量，需要增加更多库存
  /// - 如果新数量 < 旧数量，需要减少库存（需检查库存是否足够）
  /// 
  /// 返回更新后的退货记录
  Future<Return> updateReturn(int returnId, ReturnUpdate update) async {
    try {
      final response = await _apiService.put<Map<String, dynamic>>(
        '/api/returns/$returnId',
        body: update.toJson(),
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Return.fromJson(response.data!);
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
      throw ApiError.unknown('更新退货记录失败', e);
    }
  }

  /// 删除退货记录
  /// 
  /// [returnId] 退货记录ID
  /// 
  /// 注意：删除时会自动减少产品库存（因为退货被撤销）
  /// 需要检查删除后库存不能为负
  Future<void> deleteReturn(int returnId) async {
    try {
      final response = await _apiService.delete(
        '/api/returns/$returnId',
        fromJsonT: (json) => json,
      );

      if (!response.isSuccess) {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError catch (e) {
      // 如果是库存不足错误
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
      throw ApiError.unknown('删除退货记录失败', e);
    }
  }
}


