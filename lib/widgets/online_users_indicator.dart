/// 在线用户指示器组件
/// 显示当前在线用户数量和列表

import 'package:flutter/material.dart';
import '../services/user_status_service.dart';
import '../repositories/settings_repository.dart';

class OnlineUsersIndicator extends StatefulWidget {
  /// 是否显示详细信息（点击后显示用户列表）
  final bool showDetails;

  /// 指示器位置
  final Alignment alignment;

  const OnlineUsersIndicator({
    Key? key,
    this.showDetails = true,
    this.alignment = Alignment.topRight,
  }) : super(key: key);

  @override
  _OnlineUsersIndicatorState createState() => _OnlineUsersIndicatorState();
}

class _OnlineUsersIndicatorState extends State<OnlineUsersIndicator> {
  final UserStatusService _userStatusService = UserStatusService();
  final SettingsRepository _settingsRepo = SettingsRepository();

  int _onlineUsersCount = 0;
  List<OnlineUser> _onlineUsers = [];
  bool _showOnlineUsers = true; // 默认显示
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _startListening();
  }

  /// 加载用户设置（是否显示在线用户提示）
  Future<void> _loadSettings() async {
    try {
      final settings = await _settingsRepo.getUserSettings();
      setState(() {
        _showOnlineUsers = settings.isShowOnlineUsers;
      });
    } catch (e) {
      print('加载用户设置失败: $e');
      // 默认显示
      setState(() {
        _showOnlineUsers = true;
      });
    }
  }

  /// 开始监听在线用户更新
  void _startListening() {
    // 设置更新回调
    _userStatusService.onOnlineUsersUpdated = (users, count) {
      if (mounted) {
        setState(() {
          _onlineUsersCount = count;
          _onlineUsers = users;
          _isLoading = false;
        });
      }
    };

    // 启动在线用户列表自动更新
    _userStatusService.startOnlineUsersUpdate(
      interval: 5, // 每 5 秒更新一次
      onUpdated: (users, count) {
        if (mounted) {
          setState(() {
            _onlineUsersCount = count;
            _onlineUsers = users;
            _isLoading = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    // 注意：不要在这里停止服务，因为其他组件可能也在使用
    // _userStatusService.stopOnlineUsersUpdate();
    super.dispose();
  }

  /// 显示在线用户详情对话框
  void _showOnlineUsersDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('在线用户 (${_onlineUsersCount})'),
        content: SizedBox(
          width: double.maxFinite,
          child: _onlineUsers.isEmpty
              ? Center(
                  child: Text(
                    '暂无其他在线用户',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _onlineUsers.length,
                  itemBuilder: (context, index) {
                    final user = _onlineUsers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green,
                        child: Text(
                          user.username.isNotEmpty
                              ? user.username[0].toUpperCase()
                              : '?',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(user.username),
                      subtitle: user.currentAction != null
                          ? Text(
                              user.currentAction!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            )
                          : Text(
                              '在线',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                      trailing: Icon(
                        Icons.circle,
                        size: 8,
                        color: Colors.green,
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 如果不显示在线用户提示，返回空组件
    if (!_showOnlineUsers) {
      return SizedBox.shrink();
    }

    // 如果正在加载，显示加载指示器
    if (_isLoading) {
      return Positioned(
        top: 8,
        right: 8,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 4),
              Text(
                '加载中...',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    // 显示在线用户数量
    return Positioned(
      top: 8,
      right: 8,
      child: GestureDetector(
        onTap: widget.showDetails ? _showOnlineUsersDialog : null,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _onlineUsersCount > 1
                ? Colors.green.withOpacity(0.9)
                : Colors.grey.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people,
                size: 16,
                color: Colors.white,
              ),
              SizedBox(width: 4),
              Text(
                '在线: $_onlineUsersCount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.showDetails && _onlineUsersCount > 0) ...[
                SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: Colors.white,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

