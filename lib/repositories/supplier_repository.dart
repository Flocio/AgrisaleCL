/// 供应商仓库
/// 处理供应商的增删改查功能

import '../models/api_response.dart';
import '../models/api_error.dart';
import '../services/api_service.dart';

/// 供应商模型
class Supplier {
  final int id;
  final int userId;
  final String name;
  final String? note;
  final String? createdAt;
  final String? updatedAt;

  Supplier({
    required this.id,
    required this.userId,
    required this.name,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
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

  Supplier copyWith({
    int? id,
    int? userId,
    String? name,
    String? note,
    String? createdAt,
    String? updatedAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 供应商创建请求
class SupplierCreate {
  final String name;
  final String? note;

  SupplierCreate({
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

/// 供应商更新请求
class SupplierUpdate {
  final String? name;
  final String? note;

  SupplierUpdate({
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

class SupplierRepository {
  final ApiService _apiService = ApiService();

  /// 获取供应商列表
  /// 
  /// [page] 页码，从 1 开始
  /// [pageSize] 每页数量
  /// [search] 搜索关键词（供应商名称或备注）
  /// 
  /// 返回分页的供应商列表
  Future<PaginatedResponse<Supplier>> getSuppliers({
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
        '/api/suppliers',
        queryParameters: queryParams,
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return PaginatedResponse<Supplier>.fromJson(
          response.data!,
          (json) => Supplier.fromJson(json as Map<String, dynamic>),
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
      throw ApiError.unknown('获取供应商列表失败', e);
    }
  }

  /// 获取所有供应商（不分页，用于下拉选择等场景）
  /// 
  /// 返回所有供应商列表
  Future<List<Supplier>> getAllSuppliers() async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/suppliers/all',
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        final suppliersJson = response.data!['suppliers'] as List<dynamic>? ?? [];
        return suppliersJson
            .map((json) => Supplier.fromJson(json as Map<String, dynamic>))
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
      throw ApiError.unknown('获取供应商列表失败', e);
    }
  }

  /// 获取单个供应商详情
  /// 
  /// [supplierId] 供应商ID
  /// 
  /// 返回供应商详情
  Future<Supplier> getSupplier(int supplierId) async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/suppliers/$supplierId',
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Supplier.fromJson(response.data!);
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('获取供应商详情失败', e);
    }
  }

  /// 创建供应商
  /// 
  /// [supplier] 供应商创建请求
  /// 
  /// 返回创建的供应商
  Future<Supplier> createSupplier(SupplierCreate supplier) async {
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        '/api/suppliers',
        body: supplier.toJson(),
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Supplier.fromJson(response.data!);
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('创建供应商失败', e);
    }
  }

  /// 更新供应商
  /// 
  /// [supplierId] 供应商ID
  /// [update] 供应商更新请求
  /// 
  /// 返回更新后的供应商
  Future<Supplier> updateSupplier(int supplierId, SupplierUpdate update) async {
    try {
      final response = await _apiService.put<Map<String, dynamic>>(
        '/api/suppliers/$supplierId',
        body: update.toJson(),
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Supplier.fromJson(response.data!);
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('更新供应商失败', e);
    }
  }

  /// 删除供应商
  /// 
  /// [supplierId] 供应商ID
  /// 
  /// 注意：删除供应商不会删除相关的采购、汇款记录，这些记录的 supplierId 会被设置为 NULL
  Future<void> deleteSupplier(int supplierId) async {
    try {
      final response = await _apiService.delete(
        '/api/suppliers/$supplierId',
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
      throw ApiError.unknown('删除供应商失败', e);
    }
  }

  /// 搜索所有供应商（不分页，用于下拉选择等场景）
  /// 
  /// [search] 搜索关键词
  /// 
  /// 返回匹配的供应商列表（最多 50 条）
  Future<List<Supplier>> searchAllSuppliers(String search) async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/suppliers/search/all',
        queryParameters: {'search': search},
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        final suppliersJson = response.data!['suppliers'] as List<dynamic>? ?? [];
        return suppliersJson
            .map((json) => Supplier.fromJson(json as Map<String, dynamic>))
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
      throw ApiError.unknown('搜索供应商失败', e);
    }
  }
}


