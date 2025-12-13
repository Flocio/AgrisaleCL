/// 员工仓库
/// 处理员工的增删改查功能

import '../models/api_response.dart';
import '../models/api_error.dart';
import '../services/api_service.dart';

/// 员工模型
class Employee {
  final int id;
  final int userId;
  final String name;
  final String? note;
  final String? createdAt;
  final String? updatedAt;

  Employee({
    required this.id,
    required this.userId,
    required this.name,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
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

  Employee copyWith({
    int? id,
    int? userId,
    String? name,
    String? note,
    String? createdAt,
    String? updatedAt,
  }) {
    return Employee(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 员工创建请求
class EmployeeCreate {
  final String name;
  final String? note;

  EmployeeCreate({
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

/// 员工更新请求
class EmployeeUpdate {
  final String? name;
  final String? note;

  EmployeeUpdate({
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

class EmployeeRepository {
  final ApiService _apiService = ApiService();

  /// 获取员工列表
  /// 
  /// [page] 页码，从 1 开始
  /// [pageSize] 每页数量
  /// [search] 搜索关键词（员工名称或备注）
  /// 
  /// 返回分页的员工列表
  Future<PaginatedResponse<Employee>> getEmployees({
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
        '/api/employees',
        queryParameters: queryParams,
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return PaginatedResponse<Employee>.fromJson(
          response.data!,
          (json) => Employee.fromJson(json as Map<String, dynamic>),
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
      throw ApiError.unknown('获取员工列表失败', e);
    }
  }

  /// 获取所有员工（不分页，用于下拉选择等场景）
  /// 
  /// 返回所有员工列表
  Future<List<Employee>> getAllEmployees() async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/employees/all',
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        final employeesJson = response.data!['employees'] as List<dynamic>? ?? [];
        return employeesJson
            .map((json) => Employee.fromJson(json as Map<String, dynamic>))
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
      throw ApiError.unknown('获取员工列表失败', e);
    }
  }

  /// 获取单个员工详情
  /// 
  /// [employeeId] 员工ID
  /// 
  /// 返回员工详情
  Future<Employee> getEmployee(int employeeId) async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/employees/$employeeId',
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Employee.fromJson(response.data!);
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('获取员工详情失败', e);
    }
  }

  /// 创建员工
  /// 
  /// [employee] 员工创建请求
  /// 
  /// 返回创建的员工
  Future<Employee> createEmployee(EmployeeCreate employee) async {
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        '/api/employees',
        body: employee.toJson(),
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Employee.fromJson(response.data!);
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('创建员工失败', e);
    }
  }

  /// 更新员工
  /// 
  /// [employeeId] 员工ID
  /// [update] 员工更新请求
  /// 
  /// 返回更新后的员工
  Future<Employee> updateEmployee(int employeeId, EmployeeUpdate update) async {
    try {
      final response = await _apiService.put<Map<String, dynamic>>(
        '/api/employees/$employeeId',
        body: update.toJson(),
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return Employee.fromJson(response.data!);
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('更新员工失败', e);
    }
  }

  /// 删除员工
  /// 
  /// [employeeId] 员工ID
  /// 
  /// 注意：删除员工不会删除相关的进账、汇款记录，这些记录的 employeeId 会被设置为 NULL
  Future<void> deleteEmployee(int employeeId) async {
    try {
      final response = await _apiService.delete(
        '/api/employees/$employeeId',
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
      throw ApiError.unknown('删除员工失败', e);
    }
  }

  /// 搜索所有员工（不分页，用于下拉选择等场景）
  /// 
  /// [search] 搜索关键词
  /// 
  /// 返回匹配的员工列表（最多 50 条）
  Future<List<Employee>> searchAllEmployees(String search) async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/employees/search/all',
        queryParameters: {'search': search},
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        final employeesJson = response.data!['employees'] as List<dynamic>? ?? [];
        return employeesJson
            .map((json) => Employee.fromJson(json as Map<String, dynamic>))
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
      throw ApiError.unknown('搜索员工失败', e);
    }
  }
}


