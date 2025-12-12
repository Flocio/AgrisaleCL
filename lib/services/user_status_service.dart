/// 用户在线状态服务
/// 处理用户心跳、在线用户列表、操作状态更新等功能

import 'dart:async';
import '../models/api_response.dart';
import '../models/api_error.dart';
import 'api_service.dart';

/// 在线用户信息模型
class OnlineUser {
  final int userId;
  final String username;
  final String lastHeartbeat;
  final String? currentAction;

  OnlineUser({
    required this.userId,
    required this.username,
    required this.lastHeartbeat,
    this.currentAction,
  });

  factory OnlineUser.fromJson(Map<String, dynamic> json) {
    return OnlineUser(
      userId: json['userId'] as int? ?? json['user_id'] as int,
      username: json['username'] as String,
      lastHeartbeat: json['last_heartbeat'] as String? ?? json['lastHeartbeat'] as String,
      currentAction: json['current_action'] as String? ?? json['currentAction'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'last_heartbeat': lastHeartbeat,
      if (currentAction != null) 'current_action': currentAction,
    };
  }
}

/// 在线用户列表响应
class OnlineUsersResponse {
  final List<OnlineUser> onlineUsers;
  final int count;

  OnlineUsersResponse({
    required this.onlineUsers,
    required this.count,
  });

  factory OnlineUsersResponse.fromJson(Map<String, dynamic> json) {
    final usersJson = json['online_users'] as List<dynamic>? ?? [];
    return OnlineUsersResponse(
      onlineUsers: usersJson
          .map((user) => OnlineUser.fromJson(user as Map<String, dynamic>))
          .toList(),
      count: json['count'] as int? ?? 0,
    );
  }
}

class UserStatusService {
  // 单例模式
  static final UserStatusService _instance = UserStatusService._internal();
  factory UserStatusService() => _instance;
  UserStatusService._internal();

  final ApiService _apiService = ApiService();

  /// 心跳定时器
  Timer? _heartbeatTimer;

  /// 在线用户列表更新定时器
  Timer? _onlineUsersTimer;

  /// 心跳间隔（秒），默认 10 秒
  int heartbeatInterval = 10;

  /// 在线用户列表更新间隔（秒），默认 5 秒
  int onlineUsersUpdateInterval = 5;

  /// 是否正在运行
  bool _isRunning = false;

  /// 当前操作描述
  String? _currentAction;

  /// 在线用户列表
  List<OnlineUser> _onlineUsers = [];

  /// 在线用户数量
  int _onlineUsersCount = 0;

  /// 在线用户列表更新回调
  Function(List<OnlineUser>, int)? onOnlineUsersUpdated;

  /// 在线用户数量更新回调
  Function(int)? onOnlineUsersCountUpdated;

  /// 是否正在运行
  bool get isRunning => _isRunning;

  /// 获取当前在线用户列表
  List<OnlineUser> get onlineUsers => List.unmodifiable(_onlineUsers);

  /// 获取在线用户数量
  int get onlineUsersCount => _onlineUsersCount;

  /// 启动心跳服务
  /// 
  /// [interval] 心跳间隔（秒），默认 10 秒
  Future<void> startHeartbeat({int? interval}) async {
    if (_isRunning) {
      return; // 已经在运行
    }

    if (interval != null) {
      heartbeatInterval = interval;
    }

    _isRunning = true;

    // 立即发送一次心跳
    await updateHeartbeat();

    // 启动定时心跳
    _heartbeatTimer = Timer.periodic(
      Duration(seconds: heartbeatInterval),
      (_) => updateHeartbeat(),
    );
  }

  /// 停止心跳服务
  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isRunning = false;
  }

  /// 更新心跳
  /// 
  /// [action] 当前操作描述（可选）
  Future<void> updateHeartbeat({String? action}) async {
    try {
      _currentAction = action;
      
      await _apiService.post(
        '/api/users/heartbeat',
        body: action != null
            ? {'current_action': action}
            : null,
        fromJsonT: (json) => json,
      );
    } catch (e) {
      // 心跳失败不影响主流程，只打印日志
      print('心跳更新失败: $e');
    }
  }

  /// 启动在线用户列表自动更新
  /// 
  /// [interval] 更新间隔（秒），默认 5 秒
  /// [onUpdated] 更新回调
  void startOnlineUsersUpdate({
    int? interval,
    Function(List<OnlineUser>, int)? onUpdated,
  }) {
    if (interval != null) {
      onlineUsersUpdateInterval = interval;
    }

    if (onUpdated != null) {
      onOnlineUsersUpdated = onUpdated;
    }

    // 立即获取一次
    getOnlineUsers();

    // 启动定时更新
    _onlineUsersTimer?.cancel();
    _onlineUsersTimer = Timer.periodic(
      Duration(seconds: onlineUsersUpdateInterval),
      (_) => getOnlineUsers(),
    );
  }

  /// 停止在线用户列表自动更新
  void stopOnlineUsersUpdate() {
    _onlineUsersTimer?.cancel();
    _onlineUsersTimer = null;
    onOnlineUsersUpdated = null;
  }

  /// 获取在线用户列表
  Future<List<OnlineUser>> getOnlineUsers() async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/users/online',
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        final onlineUsersResponse = OnlineUsersResponse.fromJson(response.data!);
        _onlineUsers = onlineUsersResponse.onlineUsers;
        _onlineUsersCount = onlineUsersResponse.count;

        // 触发回调
        onOnlineUsersUpdated?.call(_onlineUsers, _onlineUsersCount);

        return _onlineUsers;
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('获取在线用户列表失败', e);
    }
  }

  /// 获取在线用户数量（轻量级接口）
  Future<int> getOnlineUsersCount() async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/users/online/count',
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        final count = response.data!['count'] as int? ?? 0;
        _onlineUsersCount = count;

        // 触发回调
        onOnlineUsersCountUpdated?.call(_onlineUsersCount);

        return count;
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('获取在线用户数量失败', e);
    }
  }

  /// 更新当前操作描述
  /// 
  /// [action] 当前操作描述（如"正在查看产品列表"）
  Future<void> updateCurrentAction(String action) async {
    try {
      _currentAction = action;

      await _apiService.post(
        '/api/users/online/update-action',
        body: {'current_action': action},
        fromJsonT: (json) => json,
      );

      // 同时更新心跳（确保在线状态）
      await updateHeartbeat(action: action);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('更新操作状态失败', e);
    }
  }

  /// 清除当前操作描述
  Future<void> clearCurrentAction() async {
    try {
      _currentAction = null;

      await _apiService.post(
        '/api/users/online/clear-action',
        fromJsonT: (json) => json,
      );

      // 同时更新心跳（确保在线状态）
      await updateHeartbeat();
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('清除操作状态失败', e);
    }
  }

  /// 获取指定用户的在线状态
  /// 
  /// [userId] 用户ID
  Future<Map<String, dynamic>> getUserOnlineStatus(int userId) async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/users/online/$userId/status',
        fromJsonT: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess && response.data != null) {
        return response.data!;
      } else {
        throw ApiError(
          message: response.message,
          errorCode: response.errorCode,
        );
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError.unknown('获取用户在线状态失败', e);
    }
  }

  /// 停止所有服务
  void stopAll() {
    stopHeartbeat();
    stopOnlineUsersUpdate();
    _currentAction = null;
  }

  /// 清理资源
  void dispose() {
    stopAll();
    onOnlineUsersUpdated = null;
    onOnlineUsersCountUpdated = null;
  }
}

