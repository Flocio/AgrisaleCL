// lib/screens/help_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';

class HelpScreen extends StatefulWidget {
  @override
  _HelpScreenState createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String? _helpContent;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHelp();
  }

  Future<void> _loadHelp() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = ApiService();
      // 获取 Markdown 格式的帮助文档
      final response = await http.get(
        Uri.parse('${apiService.baseUrl}/api/help'),
        headers: {
          'Accept': 'text/plain',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _helpContent = response.body;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = '加载帮助文档失败（状态码：${response.statusCode}）';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '加载帮助文档失败：$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '帮助文档',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在加载帮助文档...'),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadHelp,
                        icon: Icon(Icons.refresh),
                        label: Text('重试'),
                      ),
                    ],
                  ),
                )
              : _helpContent != null
                  ? Markdown(
                      data: _helpContent!,
                      padding: EdgeInsets.all(16),
                      styleSheet: MarkdownStyleSheet(
                        h1: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                        h2: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[600],
                        ),
                        h3: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                        h4: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                        p: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                        ),
                        listBullet: TextStyle(
                          fontSize: 14,
                        ),
                        strong: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                        code: TextStyle(
                          backgroundColor: Colors.grey[200],
                          fontFamily: 'monospace',
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    )
                  : Center(
                      child: Text('帮助文档为空'),
                    ),
    );
  }

}
