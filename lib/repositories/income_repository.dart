/// 进账仓库
/// 处理进账记录的增删改查功能

import '../models/api_response.dart';
import '../models/api_error.dart';
import '../services/api_service.dart';

/// 支付方式枚举
enum PaymentMethod {
  cash('现金'),
  wechat('微信转账'),
  bankCard('银行卡');

  final String value;
  const PaymentMethod(this.value);

  static PaymentMethod fromString(String value) {
    return PaymentMethod.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PaymentMethod.cash,
    );
  }
}

/// 进账记录模型
class Income {
  final int id;
  final int userId;
  final String incomeDate;
  final int? customerId;
  final double amount;
  final double discount;
  final int? employeeId;
  final PaymentMethod paymentMethod;
  final String? note;
  final String? createdAt;

  Income({
    required this.id,
    required this.userId,
    required this.incomeDate,
    this.customerId,
    required this.amount,
    this.discount = 0.0,
    this.employeeId,
    required this.paymentMethod,
    this.note,
    this.createdAt,
  });

  factory Income.fromJson(Map<String, dynamic> json) {
    return Income(
      id: json['id'] as int,
      userId: json['userId'] as int? ?? json['user_id'] as int,
      incomeDate: json['incomeDate'] as String? ?? json['income_date'] as String,
      customerId: json['customerId'] as int? ?? json['customer_id'] as int?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
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
      'incomeDate': incomeDate,
      if (customerId != null) 'customerId': customerId,
      'amount': amount,
      'discount': discount,
      if (employeeId != null) 'employeeId': employeeId,
      'paymentMethod': paymentMethod.value,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  Income copyWith({
    int? id,
    int? userId,
    String? incomeDate,
    int? customerId,
    double? amount,
    double? discount,
    int? employeeId,
    PaymentMethod? paymentMethod,
    String? note,
    String? createdAt,
  }) {
    return Income(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      incomeDate: incomeDate ?? this.incomeDate,
      customerId: customerId ?? this.customerId,
      amount: amount ?? this.amount,
      discount: discount ?? this.discount,
      employeeId: employeeId ?? this.employeeId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 进账创建请求
class IncomeCreate {
  final String incomeDate;
  final int? customerId;
  final double amount; // 进账金额（必须大于0）
  final double discount; // 优惠金额
  final int? employeeId;
  final PaymentMethod paymentMethod;
  final String? note;

  IncomeCreate({
    required this.incomeDate,
    this.customerId,
    required this.amount,
    this.discount = 0.0,
    this.employeeId,
    required this.paymentMethod,
    this.note,
  }) : assert(amount > 0, '进账金额必须大于0');

  Map<String, dynamic> toJson() {
    return {
      'incomeDate': incomeDate,
      if (customerId != null) 'customerId': customerId,
      'amount': amount,
      'discount': discount,
      if (employeeId != null) 'employeeId': employeeId,
      'paymentMethod': paymentMethod.value,
      if (note != null) 'note': note,
    };
  }
}

/// 进账更新请求
class IncomeUpdate {
  final String? incomeDate;
  final int? customerId;
  final double? amount; // 进账金额（必须大于0）
  final double? discount; // 优惠金额
  final int? employeeId;
  final PaymentMethod? paymentMethod;
  final String? note;

  IncomeUpdate({
    this.incomeDate,
    this.customerId,
    this.amount,
    this.discount,
    this.employeeId,
    this.paymentMethod,
    this.note,
  }) : assert(amount == null || amount! > 0, '进账金额必须大于0');

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (incomeDate != null) json['incomeDate'] = incomeDate;
    if (customerId != null) json['customerId'] = customerId;
    if (amount != null) json['amount'] = amount;
    if (discount != null) json['discount'] = discount;
    if (employeeId != null) json['employeeId'] = employeeId;
    if (paymentMethod != null) json['paymentMethod'] = paymentMethod!.value;
    if (note != null) json['note'] = note;
    return json;
  }
}

class IncomeRepository {
  final ApiService _apiService = ApiService();

  /// 获取进账记录列表
  /// 
  /// [page] 页码，从 1 开始
  /// [pageSize] 每页数量
  /// [search] 搜索关键词（备注）
  /// [startDate] 开始日期（ISO8601格式）
  /// [endDate] 结束日期（ISO8601格式）
  /// [customerId] 客户ID筛选（null 表示不筛选，0 表示未分配客户）
  /// 
  /// 返回分页的进账记录列表
  Future<PaginatedResponse<Income>> getIncomes({
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
        '/api/income',
        queryParameters: queryParams,
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return PaginatedResponse<Income>.fromJson(
          response.data!,
          (json) => Income.fromJson(json as Map<String, dynamic>),
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
      throw ApiError.unknown('获取进账记录列表失败', e);
    }
  }

  /// 获取单个进账记录详情
  /// 
  /// [incomeId] 进账记录ID
  /// 
  /// 返回进账记录详情
  Future<Income> getIncome(int incomeId) async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/income/$incomeId',
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Income.fromJson(response.data!);
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('获取进账记录详情失败', e);
    }
  }

  /// 创建进账记录
  /// 
  /// [income] 进账创建请求
  /// 
  /// 返回创建的进账记录
  Future<Income> createIncome(IncomeCreate income) async {
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        '/api/income',
        body: income.toJson(),
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Income.fromJson(response.data!);
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('创建进账记录失败', e);
    }
  }

  /// 更新进账记录
  /// 
  /// [incomeId] 进账记录ID
  /// [update] 进账更新请求
  /// 
  /// 返回更新后的进账记录
  Future<Income> updateIncome(int incomeId, IncomeUpdate update) async {
    try {
      final response = await _apiService.put<Map<String, dynamic>>(
        '/api/income/$incomeId',
        body: update.toJson(),
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Income.fromJson(response.data!);
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('更新进账记录失败', e);
    }
  }

  /// 删除进账记录
  /// 
  /// [incomeId] 进账记录ID
  Future<void> deleteIncome(int incomeId) async {
    try {
      final response = await _apiService.delete(
        '/api/income/$incomeId',
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
      throw ApiError.unknown('删除进账记录失败', e);
    }
  }
}

