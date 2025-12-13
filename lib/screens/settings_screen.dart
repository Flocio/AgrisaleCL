import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'dart:io';
import '../widgets/footer_widget.dart';
import '../services/auto_backup_service.dart';
import '../repositories/settings_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/supplier_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/employee_repository.dart';
import '../repositories/purchase_repository.dart';
import '../repositories/sale_repository.dart';
import '../repositories/return_repository.dart';
import '../repositories/income_repository.dart';
import '../repositories/remittance_repository.dart';
import '../services/auth_service.dart';
import '../services/user_status_service.dart';
import '../models/api_error.dart';
import '../models/api_response.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _username;
  
  final SettingsRepository _settingsRepo = SettingsRepository();
  final ProductRepository _productRepo = ProductRepository();
  final SupplierRepository _supplierRepo = SupplierRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  final EmployeeRepository _employeeRepo = EmployeeRepository();
  final PurchaseRepository _purchaseRepo = PurchaseRepository();
  final SaleRepository _saleRepo = SaleRepository();
  final ReturnRepository _returnRepo = ReturnRepository();
  final IncomeRepository _incomeRepo = IncomeRepository();
  final RemittanceRepository _remittanceRepo = RemittanceRepository();
  final AuthService _authService = AuthService();
  
  // 在线设备提示开关
  bool _showOnlineUsers = true;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadSystemSettings();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('current_username') ?? '未登录';
    });
  }
  
  Future<void> _loadSystemSettings() async {
    try {
      final settings = await _settingsRepo.getUserSettings();
      setState(() {
        _showOnlineUsers = settings.isShowOnlineUsers;
      });
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载设置失败: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载设置失败: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _saveSettings() async {
    try {
      await _settingsRepo.updateUserSettings(
        UserSettingsUpdate(
          showOnlineUsers: _showOnlineUsers ? 1 : 0,
        ),
      );
      return true; // 保存成功
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存设置失败: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false; // 保存失败
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存设置失败: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false; // 保存失败
    }
  }

  // 自动保存设置（不显示成功提示，失败时显示错误提示）
  Future<void> _autoSaveSettings() async {
    final success = await _saveSettings();
    // 如果保存失败，重新从服务器加载设置以恢复一致状态
    if (!success) {
      await _loadSystemSettings();
    }
  }

  // 手动保存设置（显示成功提示）
  Future<void> _manualSaveSettings() async {
    final success = await _saveSettings();
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('设置已保存')),
      );
    }
    // 如果保存失败，重新从服务器加载设置以恢复一致状态
    if (!success) {
      await _loadSystemSettings();
    }
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      await _authService.changePassword(
        _currentPasswordController.text,
        _newPasswordController.text,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('密码已更新'),
          backgroundColor: Colors.green,
        ),
      );

      // 清空输入框
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } on ApiError catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('更新密码失败: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('更新密码失败: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 导出全部数据功能
  Future<void> _exportAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('current_username');
      
      if (username == null) {
    ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('请先登录')),
      );
      return;
    }

      // 显示加载对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('正在导出数据...'),
            ],
          ),
        ),
      );

      // 验证用户登录状态
      final userInfo = await _authService.getCurrentUser();
      if (userInfo == null) {
        Navigator.of(context).pop(); // 关闭加载对话框
    ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('请先登录')),
        );
        return;
      }

      // 从 API 获取当前用户的所有数据
      final results = await Future.wait([
        _productRepo.getProducts(page: 1, pageSize: 10000),
        _supplierRepo.getAllSuppliers(),
        _customerRepo.getAllCustomers(),
        _employeeRepo.getAllEmployees(),
        _purchaseRepo.getPurchases(page: 1, pageSize: 10000),
        _saleRepo.getSales(page: 1, pageSize: 10000),
        _returnRepo.getReturns(page: 1, pageSize: 10000),
        _incomeRepo.getIncomes(page: 1, pageSize: 10000),
        _remittanceRepo.getRemittances(page: 1, pageSize: 10000),
      ]);
      
      // 转换为 Map 格式以保持兼容性
      final products = (results[0] as PaginatedResponse).items.map((p) => p.toJson()).toList();
      final suppliers = (results[1] as List).map((s) => s.toJson()).toList();
      final customers = (results[2] as List).map((c) => c.toJson()).toList();
      final employees = (results[3] as List).map((e) => e.toJson()).toList();
      final purchases = (results[4] as PaginatedResponse).items.map((p) => p.toJson()).toList();
      final sales = (results[5] as PaginatedResponse).items.map((s) => s.toJson()).toList();
      final returns = (results[6] as PaginatedResponse).items.map((r) => r.toJson()).toList();
      final income = (results[7] as PaginatedResponse).items.map((i) => i.toJson()).toList();
      final remittance = (results[8] as PaginatedResponse).items.map((r) => r.toJson()).toList();
      // 不导出 user_settings（包含个人隐私数据如 API Key）
      
      // 构建导出数据
      final exportData = {
        'exportInfo': {
          'username': username,
          'exportTime': DateTime.now().toIso8601String(),
          'version': (await PackageInfo.fromPlatform()).version, // 从 package_info_plus 获取版本号
        },
        'data': {
          'products': products,
          'suppliers': suppliers,
          'customers': customers,
          'employees': employees,
          'purchases': purchases,
          'sales': sales,
          'returns': returns,
          'income': income,
          'remittance': remittance,
          // 用户设置（user_settings）不导出
          // 理由：包含个人隐私数据（API Key）和个人偏好，与业务数据无关
        }
      };

      // 转换为JSON
      final jsonString = jsonEncode(exportData);
      
      // 生成文件名
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
      final fileName = '${username}_农资数据_$timestamp.json';

      if (Platform.isMacOS || Platform.isWindows) {
        // macOS 和 Windows: 使用 file_picker 让用户选择保存位置
        String? selectedPath = await FilePicker.platform.saveFile(
          dialogTitle: '保存数据备份',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        
        if (selectedPath != null) {
          final file = File(selectedPath);
          await file.writeAsString(jsonString);
          
          Navigator.of(context).pop(); // 关闭加载对话框
          
    ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('数据导出成功: $selectedPath'),
              duration: Duration(seconds: 3),
            ),
    );
        } else {
          Navigator.of(context).pop(); // 关闭加载对话框
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已取消导出')),
    );
  }
        return;
      }

      String path;
      if (Platform.isAndroid) {
        // 请求存储权限
        if (await Permission.storage.request().isGranted) {
          final directory = Directory('/storage/emulated/0/Download');
          path = '${directory.path}/$fileName';
        } else {
          Navigator.of(context).pop(); // 关闭加载对话框
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('存储权限被拒绝')),
          );
          return;
        }
      } else if (Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        path = '${directory.path}/$fileName';
      } else {
        // 其他平台使用应用文档目录作为后备方案
        final directory = await getApplicationDocumentsDirectory();
        path = '${directory.path}/$fileName';
      }

      // 写入文件
      final file = File(path);
      await file.writeAsString(jsonString);

      Navigator.of(context).pop(); // 关闭加载对话框

      if (Platform.isIOS) {
        // iOS 让用户手动选择存储位置
        await Share.shareFiles([file.path], text: 'AgrisaleCL数据备份文件');
      } else {
        // Android 直接存入 Download 目录，并提示用户
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('数据导出成功: $path'),
            duration: Duration(seconds: 3),
          ),
        );
      }

    } catch (e) {
      Navigator.of(context).pop(); // 关闭加载对话框
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    }
  }

  // 数据恢复功能（仅覆盖模式）
  Future<void> _importData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('current_username');
      
      if (username == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('请先登录')),
    );
        return;
      }

      // 选择文件
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();
        
        // 解析JSON数据
        final Map<String, dynamic> importData = jsonDecode(jsonString);
        
        // 验证数据格式
        if (!importData.containsKey('exportInfo') || !importData.containsKey('data')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('文件格式错误，请选择正确的备份文件')),
          );
          return;
        }

        // 检查数据来源
        final backupUsername = importData['exportInfo']['username'] ?? '未知';
        final backupVersion = importData['exportInfo']['version'] ?? '未知';
        final backupTime = importData['exportInfo']['exportTime'] ?? '未知';
        final isFromDifferentUser = backupUsername != username;
        
        // 检查数据量
        final data = importData['data'] as Map<String, dynamic>;
        final backupSupplierCount = (data['suppliers'] as List?)?.length ?? 0;
        final backupCustomerCount = (data['customers'] as List?)?.length ?? 0;
        final backupProductCount = (data['products'] as List?)?.length ?? 0;
        final backupEmployeeCount = (data['employees'] as List?)?.length ?? 0;
        final backupPurchaseCount = (data['purchases'] as List?)?.length ?? 0;
        final backupSaleCount = (data['sales'] as List?)?.length ?? 0;
        final backupReturnCount = (data['returns'] as List?)?.length ?? 0;
        final backupIncomeCount = (data['income'] as List?)?.length ?? 0;
        final backupRemittanceCount = (data['remittance'] as List?)?.length ?? 0;

        // 显示确认对话框
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('确认覆盖数据', style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 数据来源信息
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                            SizedBox(width: 8),
                            Text('备份信息', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        Divider(height: 16),
                        _buildInfoRow('来源用户', backupUsername),
                        _buildInfoRow('导出时间', backupTime.split('T')[0]),
                        _buildInfoRow('数据版本', backupVersion),
                        Divider(height: 16),
                        Text('数据统计:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        _buildDataCountRow('供应商', backupSupplierCount),
                        _buildDataCountRow('客户', backupCustomerCount),
                        _buildDataCountRow('产品', backupProductCount),
                        _buildDataCountRow('员工', backupEmployeeCount),
                        _buildDataCountRow('采购记录', backupPurchaseCount),
                        _buildDataCountRow('销售记录', backupSaleCount),
                        _buildDataCountRow('退货记录', backupReturnCount),
                        _buildDataCountRow('进账记录', backupIncomeCount),
                        _buildDataCountRow('汇款记录', backupRemittanceCount),
                      ],
                    ),
                  ),
                  
                  // 不同用户警告
                  if (isFromDifferentUser) ...[
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[300]!, width: 2),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange[700], size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '警告：此备份来自不同用户（$backupUsername）！',
                              style: TextStyle(fontSize: 13, color: Colors.orange[900], fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // 覆盖警告
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[400]!, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '覆盖模式',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red[900]),
                              ),
                            ),
                          ],
                        ),
                        Divider(height: 12, color: Colors.red[300]),
                        Text('• 将删除当前所有业务数据', style: TextStyle(fontSize: 13, color: Colors.red[800])),
                        Text('• 完全替换为备份中的数据', style: TextStyle(fontSize: 13, color: Colors.red[800])),
                        Text('• 此操作不可撤销！', style: TextStyle(fontSize: 13, color: Colors.red[900], fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green[600], size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '您的个人设置（API Key等）不会改变',
                                  style: TextStyle(fontSize: 12, color: Colors.green[800]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('取消', style: TextStyle(fontSize: 16)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text('确认覆盖', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (confirm != true) return;

        // 显示加载对话框
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('正在覆盖数据...'),
              ],
            ),
          ),
        );

        try {
          // 通过 API 导入数据到服务器
          final result = await _settingsRepo.importData(importData);
          
          Navigator.of(context).pop(); // 关闭加载对话框

          final counts = result['counts'] as Map<String, dynamic>?;
          final countsText = counts != null
              ? '供应商: ${counts['suppliers']}, 客户: ${counts['customers']}, 员工: ${counts['employees']}, 产品: ${counts['products']}, 采购: ${counts['purchases']}, 销售: ${counts['sales']}, 退货: ${counts['returns']}, 进账: ${counts['income']}, 汇款: ${counts['remittance']}'
              : '';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('数据覆盖成功！\n$countsText'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 5),
            ),
          );

          // 重新加载设置
          _loadSystemSettings();
        } on ApiError catch (e) {
          Navigator.of(context).pop(); // 关闭加载对话框
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('数据导入失败: ${e.message}'),
              backgroundColor: Colors.red,
            ),
          );
        } catch (e) {
          Navigator.of(context).pop(); // 关闭加载对话框
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('数据导入失败: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }


      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('未选择文件')),
        );
      }

    } catch (e) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // 关闭加载对话框
      }
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('数据恢复失败: $e')),
    );
    }
  }
  
  // 辅助方法：构建信息行
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
  
  // 辅助方法：构建数据计数行
  Widget _buildDataCountRow(String label, int count) {
    return Padding(
      padding: EdgeInsets.only(left: 8, top: 2),
      child: Text('• $label: $count 条', style: TextStyle(fontSize: 12)),
    );
  }
  
  // 退出登录
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认退出'),
        content: Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('退出'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        // 先发送一次心跳，确保设备ID已同步到服务器
        // 然后停止心跳服务（必须在清除 Token 之前，因为需要 Token 来调用服务器接口）
        final userStatusService = UserStatusService();
        try {
          // 发送最后一次心跳，确保设备ID在服务器端
          await userStatusService.updateHeartbeat();
        } catch (e) {
          print('发送最后心跳失败: $e');
        }
        userStatusService.stopHeartbeat();
        
        // 停止自动备份服务
        await AutoBackupService().stopAutoBackup();
        
        // 调用 AuthService 的 logout 方法，清除 Token 和用户名
        // logout 方法会发送 device_id 到服务器，只删除当前设备的记录
        await AuthService().logout();
        
        // 跳转到登录界面
        Navigator.of(context).pushReplacementNamed('/');
      } catch (e) {
        print('退出登录时出错: $e');
        // 即使出错，也要清除本地 Token 并跳转
        try {
          await AuthService().logout();
        } catch (e2) {
          print('清除 Token 时出错: $e2');
        }
        Navigator.of(context).pushReplacementNamed('/');
      }
    }
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('账户设置', 
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          )
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(16.0),
              children: [
                // 数据管理卡片 - 移到最顶端
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '数据管理',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Divider(),
                        ListTile(
                          leading: Icon(Icons.download, color: Colors.green),
                          title: Text('导出全部数据'),
                          subtitle: Text('将当前用户的所有数据导出为JSON备份文件'),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: _exportAllData,
                        ),
                        Divider(),
                        ListTile(
                          leading: Icon(Icons.upload, color: Colors.orange),
                          title: Text('导入数据（覆盖）'),
                          subtitle: Text('从备份文件恢复数据，将完全替换当前业务数据'),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: _importData,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                
                // 账户设置卡片
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '账户设置',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Divider(),
                        SizedBox(height: 8),
                        Text('当前用户: $_username'),
                        SizedBox(height: 16),
                        Text(
                          '修改密码',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _currentPasswordController,
                                decoration: InputDecoration(
                                  labelText: '当前密码',
                                  border: OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureCurrentPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureCurrentPassword = !_obscureCurrentPassword;
                                      });
                                    },
                                  ),
                                ),
                                obscureText: _obscureCurrentPassword,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '请输入当前密码';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 8),
                              TextFormField(
                                controller: _newPasswordController,
                                decoration: InputDecoration(
                                  labelText: '新密码',
                                  border: OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureNewPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureNewPassword = !_obscureNewPassword;
                                      });
                                    },
                                  ),
                                ),
                                obscureText: _obscureNewPassword,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '请输入新密码';
                                  }
                                  if (value.length < 3) {
                                    return '密码长度至少为3个字符';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 8),
                              TextFormField(
                                controller: _confirmPasswordController,
                                decoration: InputDecoration(
                                  labelText: '确认新密码',
                                  border: OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword = !_obscureConfirmPassword;
                                      });
                                    },
                                  ),
                                ),
                                obscureText: _obscureConfirmPassword,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '请确认新密码';
                                  }
                                  if (value != _newPasswordController.text) {
                                    return '两次输入的密码不一致';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _changePassword,
                                child: Text('更新密码'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: Size(double.infinity, 50),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                
                // 在线设备卡片
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '在线设备',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Divider(),
                        SwitchListTile(
                          title: Text('显示在线设备提示'),
                          subtitle: Text('在主界面显示该账号的在线设备数量'),
                          value: _showOnlineUsers,
                          onChanged: (value) {
                            setState(() {
                              _showOnlineUsers = value;
                            });
                            // 自动保存设置
                            _autoSaveSettings();
                          },
                          secondary: Icon(Icons.devices, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _logout,
                  child: Text('退出登录'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[100],
                    foregroundColor: Colors.red[800],
                    minimumSize: Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
          FooterWidget(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}