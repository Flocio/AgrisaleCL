/// 客户仓库
/// 处理客户的增删改查功能

import '../models/api_response.dart';
import '../models/api_error.dart';
import '../services/api_service.dart';

/// 客户模型
class Customer {
  final int id;
  final int userId;
  final String name;
  final String? note;
  final String? createdAt;
  final String? updatedAt;

  Customer({
    required this.id,
    required this.userId,
    required this.name,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as int,
      userId: json['userId'] as int? ?? json['user_id'] as int,
      name: json['name'] as String,
      note: json['note'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  Customer copyWith({
    int? id,
    int? userId,
    String? name,
    String? note,
    String? createdAt,
    String? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 客户创建请求
class CustomerCreate {
  final String name;
  final String? note;

  CustomerCreate({
    required this.name,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (note != null) 'note': note,
    };
  }
}

/// 客户更新请求
class CustomerUpdate {
  final String? name;
  final String? note;

  CustomerUpdate({
    this.name,
    this.note,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (name != null) json['name'] = name;
    if (note != null) json['note'] = note;
    return json;
  }
}

class CustomerRepository {
  final ApiService _apiService = ApiService();

  /// 获取客户列表
  /// 
  /// [page] 页码，从 1 开始
  /// [pageSize] 每页数量
  /// [search] 搜索关键词（客户名称或备注）
  /// 
  /// 返回分页的客户列表
  Future<PaginatedResponse<Customer>> getCustomers({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/customers',
        queryParameters: queryParams,
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return PaginatedResponse<Customer>.fromJson(
          response.data!,
          (json) => Customer.fromJson(json as Map<String, dynamic>),
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
      throw ApiError.unknown('获取客户列表失败', e);
    }
  }

  /// 获取所有客户（不分页，用于下拉选择等场景）
  /// 
  /// 返回所有客户列表
  Future<List<Customer>> getAllCustomers() async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/customers/all',
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        final customersJson = response.data!['customers'] as List<dynamic>? ?? [];
        return customersJson
            .map((json) => Customer.fromJson(json as Map<String, dynamic>))
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
      throw ApiError.unknown('获取客户列表失败', e);
    }
  }

  /// 获取单个客户详情
  /// 
  /// [customerId] 客户ID
  /// 
  /// 返回客户详情
  Future<Customer> getCustomer(int customerId) async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/customers/$customerId',
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Customer.fromJson(response.data!);
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('获取客户详情失败', e);
    }
  }

  /// 创建客户
  /// 
  /// [customer] 客户创建请求
  /// 
  /// 返回创建的客户
  Future<Customer> createCustomer(CustomerCreate customer) async {
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        '/api/customers',
        body: customer.toJson(),
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Customer.fromJson(response.data!);
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('创建客户失败', e);
    }
  }

  /// 更新客户
  /// 
  /// [customerId] 客户ID
  /// [update] 客户更新请求
  /// 
  /// 返回更新后的客户
  Future<Customer> updateCustomer(int customerId, CustomerUpdate update) async {
    try {
      final response = await _apiService.put<Map<String, dynamic>>(
        '/api/customers/$customerId',
        body: update.toJson(),
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Customer.fromJson(response.data!);
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('更新客户失败', e);
    }
  }

  /// 删除客户
  /// 
  /// [customerId] 客户ID
  /// 
  /// 注意：删除客户不会删除相关的销售、退货、进账记录，这些记录的 customerId 会被设置为 NULL
  Future<void> deleteCustomer(int customerId) async {
    try {
      final response = await _apiService.delete(
        '/api/customers/$customerId',
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
      throw ApiError.unknown('删除客户失败', e);
    }
  }

  /// 搜索所有客户（不分页，用于下拉选择等场景）
  /// 
  /// [search] 搜索关键词
  /// 
  /// 返回匹配的客户列表（最多 50 条）
  Future<List<Customer>> searchAllCustomers(String search) async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/customers/search/all',
        queryParameters: {'search': search},
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        final customersJson = response.data!['customers'] as List<dynamic>? ?? [];
        return customersJson
            .map((json) => Customer.fromJson(json as Map<String, dynamic>))
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
      throw ApiError.unknown('搜索客户失败', e);
    }
  }
}

