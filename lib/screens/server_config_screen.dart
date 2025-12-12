import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/api_error.dart';
import 'dart:io';

class ServerConfigScreen extends StatefulWidget {
  @override
  _ServerConfigScreenState createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends State<ServerConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController();
  bool _isLoading = false;
  bool _isTesting = false;
  String? _testResult;
  String? _currentServerUrl;

  @override
  void initState() {
    super.initState();
    _loadCurrentServerUrl();
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  // 加载当前服务器地址
  Future<void> _loadCurrentServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString('server_url');
    final defaultUrl = 'http://192.168.10.12:8000';
    setState(() {
      _currentServerUrl = serverUrl ?? defaultUrl;
      _serverUrlController.text = _currentServerUrl ?? defaultUrl;
    });
  }

  // 测试服务器连接
  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final testUrl = _serverUrlController.text.trim();
      final apiService = ApiService();
      final originalUrl = apiService.baseUrl;
      
      // 临时设置测试URL
      apiService.setBaseUrl(testUrl);
      
      // 测试连接
      final response = await apiService.get<Map<String, dynamic>>(
        '/health',
        fromJsonT: (json) => json as Map<String, dynamic>,
      );
      
      if (response.isSuccess && response.data != null && response.data!['status'] == 'healthy') {
        setState(() {
          _testResult = '连接成功！服务器运行正常';
        });
      } else {
        setState(() {
          _testResult = '连接失败：服务器响应异常';
        });
      }
      
      // 恢复原始URL
      apiService.setBaseUrl(originalUrl);
    } on ApiError catch (e) {
      setState(() {
        _testResult = '连接失败：${e.message}';
      });
    } on SocketException catch (e) {
      setState(() {
        _testResult = '连接失败：无法连接到服务器，请检查地址和网络';
      });
    } catch (e) {
      setState(() {
        _testResult = '连接失败：${e.toString()}';
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  // 保存服务器地址
  Future<void> _saveServerUrl() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final serverUrl = _serverUrlController.text.trim();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_url', serverUrl);
      
      // 更新 ApiService
      ApiService().setBaseUrl(serverUrl);
      
      setState(() {
        _currentServerUrl = serverUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('服务器地址已保存'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败：${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // URL验证
  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入服务器地址';
    }
    
    final url = value.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return '地址必须以 http:// 或 https:// 开头';
    }
    
    try {
      final uri = Uri.parse(url);
      if (uri.host.isEmpty) {
        return '请输入有效的服务器地址';
      }
    } catch (e) {
      return '地址格式不正确';
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('服务器配置', style: TextStyle(color: Colors.white)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // 说明卡片
            Card(
              elevation: 2,
              color: Colors.blue[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        SizedBox(width: 8),
                        Text(
                          '配置说明',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      '• 局域网内访问：使用内网IP，如 http://192.168.10.12:8000',
                      style: TextStyle(fontSize: 13, color: Colors.blue[800]),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• 外网访问：使用内网穿透地址，如 http://your-domain.ngrok.io',
                      style: TextStyle(fontSize: 13, color: Colors.blue[800]),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• 修改后需要重新登录才能生效',
                      style: TextStyle(fontSize: 13, color: Colors.blue[800]),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 24),
            
            // 当前服务器地址
            if (_currentServerUrl != null) ...[
              Text(
                '当前服务器地址',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  _currentServerUrl!,
                  style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                ),
              ),
              SizedBox(height: 24),
            ],
            
            // 服务器地址输入
            Text(
              '服务器地址',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            TextFormField(
              controller: _serverUrlController,
              decoration: InputDecoration(
                hintText: 'http://192.168.10.12:8000',
                prefixIcon: Icon(Icons.dns),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              keyboardType: TextInputType.url,
              validator: _validateUrl,
              enabled: !_isLoading && !_isTesting,
            ),
            
            SizedBox(height: 16),
            
            // 测试连接按钮
            ElevatedButton.icon(
              onPressed: _isTesting ? null : _testConnection,
              icon: _isTesting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(Icons.network_check),
              label: Text(_isTesting ? '测试中...' : '测试连接'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            
            // 测试结果
            if (_testResult != null) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _testResult!.contains('成功')
                      ? Colors.green[50]
                      : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _testResult!.contains('成功')
                        ? Colors.green[300]!
                        : Colors.red[300]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _testResult!.contains('成功')
                          ? Icons.check_circle
                          : Icons.error,
                      color: _testResult!.contains('成功')
                          ? Colors.green[700]
                          : Colors.red[700],
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _testResult!,
                        style: TextStyle(
                          fontSize: 13,
                          color: _testResult!.contains('成功')
                              ? Colors.green[900]
                              : Colors.red[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            SizedBox(height: 24),
            
            // 保存按钮
            ElevatedButton(
              onPressed: _isLoading ? null : _saveServerUrl,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      '保存配置',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            
            SizedBox(height: 16),
            
            // 快速配置按钮
            Text(
              '快速配置',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: Text('局域网 (192.168.10.12)'),
                  onPressed: () {
                    _serverUrlController.text = 'http://192.168.10.12:8000';
                  },
                  avatar: Icon(Icons.home, size: 18),
                ),
                ActionChip(
                  label: Text('本地 (localhost)'),
                  onPressed: () {
                    _serverUrlController.text = 'http://localhost:8000';
                  },
                  avatar: Icon(Icons.computer, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

