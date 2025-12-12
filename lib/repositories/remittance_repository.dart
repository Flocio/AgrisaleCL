/// 汇款仓库
/// 处理汇款记录的增删改查功能

import '../models/api_response.dart';
import '../models/api_error.dart';
import '../services/api_service.dart';
import 'income_repository.dart'; // 复用 PaymentMethod 枚举

/// 汇款记录模型
class Remittance {
  final int id;
  final int userId;
  final String remittanceDate;
  final int? supplierId;
  final double amount;
  final int? employeeId;
  final PaymentMethod paymentMethod;
  final String? note;
  final String? createdAt;

  Remittance({
    required this.id,
    required this.userId,
    required this.remittanceDate,
    this.supplierId,
    required this.amount,
    this.employeeId,
    required this.paymentMethod,
    this.note,
    this.createdAt,
  });

  factory Remittance.fromJson(Map<String, dynamic> json) {
    return Remittance(
      id: json['id'] as int,
      userId: json['userId'] as int? ?? json['user_id'] as int,
      remittanceDate: json['remittanceDate'] as String? ?? json['remittance_date'] as String,
      supplierId: json['supplierId'] as int? ?? json['supplier_id'] as int?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      employeeId: json['employeeId'] as int? ?? json['employee_id'] as int?,
      paymentMethod: PaymentMethod.fromString(
        json['paymentMethod'] as String? ?? json['payment_method'] as String? ?? '现金',
      ),
      note: json['note'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'remittanceDate': remittanceDate,
      if (supplierId != null) 'supplierId': supplierId,
      'amount': amount,
      if (employeeId != null) 'employeeId': employeeId,
      'paymentMethod': paymentMethod.value,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  Remittance copyWith({
    int? id,
    int? userId,
    String? remittanceDate,
    int? supplierId,
    double? amount,
    int? employeeId,
    PaymentMethod? paymentMethod,
    String? note,
    String? createdAt,
  }) {
    return Remittance(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      remittanceDate: remittanceDate ?? this.remittanceDate,
      supplierId: supplierId ?? this.supplierId,
      amount: amount ?? this.amount,
      employeeId: employeeId ?? this.employeeId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 汇款创建请求
class RemittanceCreate {
  final String remittanceDate;
  final int? supplierId;
  final double amount; // 汇款金额（必须大于0）
  final int? employeeId;
  final PaymentMethod paymentMethod;
  final String? note;

  RemittanceCreate({
    required this.remittanceDate,
    this.supplierId,
    required this.amount,
    this.employeeId,
    required this.paymentMethod,
    this.note,
  }) : assert(amount > 0, '汇款金额必须大于0');

  Map<String, dynamic> toJson() {
    return {
      'remittanceDate': remittanceDate,
      if (supplierId != null) 'supplierId': supplierId,
      'amount': amount,
      if (employeeId != null) 'employeeId': employeeId,
      'paymentMethod': paymentMethod.value,
      if (note != null) 'note': note,
    };
  }
}

/// 汇款更新请求
class RemittanceUpdate {
  final String? remittanceDate;
  final int? supplierId;
  final double? amount; // 汇款金额（必须大于0）
  final int? employeeId;
  final PaymentMethod? paymentMethod;
  final String? note;

  RemittanceUpdate({
    this.remittanceDate,
    this.supplierId,
    this.amount,
    this.employeeId,
    this.paymentMethod,
    this.note,
  }) : assert(amount == null || amount! > 0, '汇款金额必须大于0');

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (remittanceDate != null) json['remittanceDate'] = remittanceDate;
    if (supplierId != null) json['supplierId'] = supplierId;
    if (amount != null) json['amount'] = amount;
    if (employeeId != null) json['employeeId'] = employeeId;
    if (paymentMethod != null) json['paymentMethod'] = paymentMethod!.value;
    if (note != null) json['note'] = note;
    return json;
  }
}

class RemittanceRepository {
  final ApiService _apiService = ApiService();

  /// 获取汇款记录列表
  /// 
  /// [page] 页码，从 1 开始
  /// [pageSize] 每页数量
  /// [search] 搜索关键词（备注）
  /// [startDate] 开始日期（ISO8601格式）
  /// [endDate] 结束日期（ISO8601格式）
  /// [supplierId] 供应商ID筛选（null 表示不筛选，0 表示未分配供应商）
  /// 
  /// 返回分页的汇款记录列表
  Future<PaginatedResponse<Remittance>> getRemittances({
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
        '/api/remittance',
        queryParameters: queryParams,
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return PaginatedResponse<Remittance>.fromJson(
          response.data!,
          (json) => Remittance.fromJson(json as Map<String, dynamic>),
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
      throw ApiError.unknown('获取汇款记录列表失败', e);
    }
  }

  /// 获取单个汇款记录详情
  /// 
  /// [remittanceId] 汇款记录ID
  /// 
  /// 返回汇款记录详情
  Future<Remittance> getRemittance(int remittanceId) async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/remittance/$remittanceId',
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Remittance.fromJson(response.data!);
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('获取汇款记录详情失败', e);
    }
  }

  /// 创建汇款记录
  /// 
  /// [remittance] 汇款创建请求
  /// 
  /// 返回创建的汇款记录
  Future<Remittance> createRemittance(RemittanceCreate remittance) async {
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        '/api/remittance',
        body: remittance.toJson(),
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Remittance.fromJson(response.data!);
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('创建汇款记录失败', e);
    }
  }

  /// 更新汇款记录
  /// 
  /// [remittanceId] 汇款记录ID
  /// [update] 汇款更新请求
  /// 
  /// 返回更新后的汇款记录
  Future<Remittance> updateRemittance(int remittanceId, RemittanceUpdate update) async {
    try {
      final response = await _apiService.put<Map<String, dynamic>>(
        '/api/remittance/$remittanceId',
        body: update.toJson(),
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Remittance.fromJson(response.data!);
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('更新汇款记录失败', e);
    }
  }

  /// 删除汇款记录
  /// 
  /// [remittanceId] 汇款记录ID
  Future<void> deleteRemittance(int remittanceId) async {
    try {
      final response = await _apiService.delete(
        '/api/remittance/$remittanceId',
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
      throw ApiError.unknown('删除汇款记录失败', e);
    }
  }
}

