/// 操作日志仓库
/// 处理操作日志的查询功能

import '../models/api_response.dart';
import '../models/api_error.dart';
import '../models/audit_log.dart';
import '../services/api_service.dart';

class AuditLogRepository {
  final ApiService _apiService = ApiService();

  /// 获取操作日志列表
  /// 
  /// [page] 页码（从1开始）
  /// [pageSize] 每页数量
  /// [operationType] 操作类型筛选（CREATE/UPDATE/DELETE）
  /// [entityType] 实体类型筛选
  /// [startTime] 开始时间（ISO8601格式）
  /// [endTime] 结束时间（ISO8601格式）
  /// [search] 搜索关键词（实体名称、备注）
  Future<PaginatedResponse<AuditLog>> getAuditLogs({
    int page = 1,
    int pageSize = 20,
    String? operationType,
    String? entityType,
    String? startTime,
    String? endTime,
    String? search,
  }) async {
    try {
      // 构建查询参数
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (operationType != null && operationType.isNotEmpty) {
        queryParams['operation_type'] = operationType;
      }

      if (entityType != null && entityType.isNotEmpty) {
        queryParams['entity_type'] = entityType;
      }

      if (startTime != null && startTime.isNotEmpty) {
        queryParams['start_time'] = startTime;
      }

      if (endTime != null && endTime.isNotEmpty) {
        queryParams['end_time'] = endTime;
      }

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      // 发送请求
      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/audit-logs',
        queryParameters: queryParams,
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        final listResponse = AuditLogListResponse.fromJson(response.data!);

        return PaginatedResponse<AuditLog>(
          items: listResponse.logs,
          total: listResponse.total,
          page: listResponse.page,
          pageSize: listResponse.pageSize,
          totalPages: listResponse.totalPages,
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
      throw ApiError.unknown('获取操作日志失败', e);
    }
  }

  /// 获取操作日志详情
  /// 
  /// [logId] 日志ID
  Future<AuditLog> getAuditLogDetail(int logId) async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/audit-logs/$logId',
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return AuditLog.fromJson(response.data!);
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('获取操作日志详情失败', e);
    }
  }
}

