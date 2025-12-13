// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import '../widgets/footer_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/user_status_service.dart';
import '../services/auto_backup_service.dart';
import '../repositories/settings_repository.dart';
import '../models/api_error.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController(); // 注册时确认密码
  bool _obscurePassword = true; // 控制密码显示/隐藏
  bool _obscureConfirmPassword = true; // 控制确认密码显示/隐藏
  bool _isLoading = false; // 加载状态
  bool _isLoginMode = true; // true为登录模式，false为注册模式

  @override
  void initState() {
    super.initState();
    _checkLoginStatus(); // 检查是否已登录
  }
  
  final AuthService _authService = AuthService();
  final UserStatusService _userStatusService = UserStatusService();
  final SettingsRepository _settingsRepo = SettingsRepository();

  // 检查登录状态，如果已登录则自动跳转
  Future<void> _checkLoginStatus() async {
    try {
      // 尝试自动登录（使用保存的 Token）
      final userInfo = await _authService.autoLogin();
      
      if (userInfo != null) {
        // 自动登录成功
        // 启动用户状态服务（心跳）
        await _userStatusService.startHeartbeat();
        
        // 启动自动备份服务
        await _startAutoBackupService();
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/main');
        });
      } else {
        // 没有有效的登录状态，加载上次登录的用户名
        _loadLastUsername();
      }
    } catch (e) {
      // 自动登录失败，加载上次登录的用户名
      print('自动登录失败: $e');
      _loadLastUsername();
    }
  }

  // 加载上次登录的用户名
  Future<void> _loadLastUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUsername = prefs.getString('last_username') ?? '';
    if (lastUsername.isNotEmpty) {
      _usernameController.text = lastUsername;
    }
  }
  
  // 启动自动备份服务（从 API 获取设置）
  Future<void> _startAutoBackupService() async {
    try {
      final settings = await _settingsRepo.getUserSettings();
      
      if (settings.isAutoBackupEnabled) {
        await AutoBackupService().startAutoBackup(settings.autoBackupInterval);
        print('自动备份服务已启动，间隔: ${settings.autoBackupInterval} 分钟');
      }
    } catch (e) {
      print('启动自动备份服务失败: $e');
      // 失败不影响登录流程
    }
  }

  // 切换登录/注册模式
  void _toggleMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
      _confirmPasswordController.clear(); // 切换时清空确认密码
    });
  }

  Future<void> _login() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请输入用户名和密码')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final username = _usernameController.text;
      final password = _passwordController.text;

      print('开始登录: $username'); // 调试日志
      
      // 使用 API 登录
      final loginResponse = await _authService.login(username, password);
      
      print('登录成功: ${loginResponse.user.username}'); // 调试日志
      
      // 保存上次登录的用户名
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_username', username);
      
      // 启动用户状态服务（心跳）
      await _userStatusService.startHeartbeat();
      
      // 启动自动备份服务
      await _startAutoBackupService();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('登录成功！'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pushReplacementNamed(context, '/main');
    } on ApiError catch (e) {
      print('登录失败 (ApiError): ${e.message}, 错误代码: ${e.errorCode}'); // 调试日志
      
      String errorMessage = e.message;
      
      // 根据错误类型提供更友好的提示
      if (e.isTimeoutError) {
        errorMessage = '连接超时，请检查：\n1. 是否与服务器在同一网络\n2. 服务器地址是否正确\n3. 网络连接是否正常';
      } else if (e.isNetworkError) {
        errorMessage = '网络连接失败，请检查：\n1. 是否与服务器在同一网络\n2. 服务器地址是否正确\n3. 防火墙是否阻止连接';
      } else if (e.isUnauthorized) {
        errorMessage = '用户名或密码错误';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5), // 延长显示时间
        ),
      );
    } catch (e, stackTrace) {
      print('登录失败 (未知错误): $e'); // 调试日志
      print('堆栈跟踪: $stackTrace'); // 调试日志
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('登录失败: ${e.toString()}\n请检查网络连接和服务器地址'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5), // 延长显示时间
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _register() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请填写所有字段')),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('两次输入的密码不一致')),
      );
      return;
    }

    if (_passwordController.text.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('密码长度至少为3个字符')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final username = _usernameController.text;
      final password = _passwordController.text;

      // 使用 API 注册
      final loginResponse = await _authService.register(username, password);
      
      // 保存上次登录的用户名
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_username', username);
      
      // 启动用户状态服务（心跳）
      await _userStatusService.startHeartbeat();
      
      // 启动自动备份服务（新用户默认未开启，所以这里不会实际启动）
      await _startAutoBackupService();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('注册成功！'),
          backgroundColor: Colors.green,
        ),
      );

      // 注册成功后自动登录
      Navigator.pushReplacementNamed(context, '/main');
    } on ApiError catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('注册失败: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 80.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(height: 60), // 增加顶部间距
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/background.png',
                              width: 50,
                              height: 50,
                            ),
                            SizedBox(width: 10),
                            Text(
                              '农资管理系统',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 80), // 增加标题和卡片之间的间距
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            children: [
                              // 切换按钮
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          if (!_isLoginMode) _toggleMode();
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(vertical: 12),
                                          decoration: BoxDecoration(
                                            color: _isLoginMode ? Colors.green : Colors.transparent,
                                            borderRadius: BorderRadius.circular(25),
                                          ),
                                          child: Text(
                                            '登录',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: _isLoginMode ? Colors.white : Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          if (_isLoginMode) _toggleMode();
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(vertical: 12),
                                          decoration: BoxDecoration(
                                            color: !_isLoginMode ? Colors.green : Colors.transparent,
                                            borderRadius: BorderRadius.circular(25),
                                          ),
                                          child: Text(
                                            '注册',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: !_isLoginMode ? Colors.white : Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 24),
                              TextField(
                                controller: _usernameController,
                                decoration: InputDecoration(
                                  labelText: '用户名',
                                  prefixIcon: Icon(Icons.person, color: Colors.green),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              SizedBox(height: 20),
                              TextField(
                                controller: _passwordController,
                                decoration: InputDecoration(
                                  labelText: '密码',
                                  prefixIcon: Icon(Icons.lock, color: Colors.green),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                      color: Colors.green,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                obscureText: _obscurePassword,
                                onSubmitted: (_) => _isLoginMode ? _login() : null,
                              ),
                              // 注册模式下显示确认密码输入框
                              if (!_isLoginMode) ...[
                                SizedBox(height: 20),
                                TextField(
                                  controller: _confirmPasswordController,
                                  decoration: InputDecoration(
                                    labelText: '确认密码',
                                    prefixIcon: Icon(Icons.lock_outline, color: Colors.green),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                        color: Colors.green,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureConfirmPassword = !_obscureConfirmPassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  obscureText: _obscureConfirmPassword,
                                  onSubmitted: (_) => _register(),
                                ),
                              ],
                              SizedBox(height: 30),
                              _isLoading
                                  ? CircularProgressIndicator()
                                  : ElevatedButton(
                                      onPressed: _isLoginMode ? _login : _register,
                                      child: Text(
                                        _isLoginMode ? '登录' : '注册',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: Size(double.infinity, 50),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            FooterWidget(), // 保持脚标不变
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}