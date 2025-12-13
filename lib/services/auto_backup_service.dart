import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../repositories/product_repository.dart';
import '../repositories/supplier_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/employee_repository.dart';
import '../repositories/purchase_repository.dart';
import '../repositories/sale_repository.dart';
import '../repositories/return_repository.dart';
import '../repositories/income_repository.dart';
import '../repositories/remittance_repository.dart';
import '../repositories/settings_repository.dart';
import '../models/api_error.dart';
import '../models/api_response.dart';

class AutoBackupService {
  static final AutoBackupService _instance = AutoBackupService._internal();
  factory AutoBackupService() => _instance;
  AutoBackupService._internal();

  final ProductRepository _productRepo = ProductRepository();
  final SupplierRepository _supplierRepo = SupplierRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  final EmployeeRepository _employeeRepo = EmployeeRepository();
  final PurchaseRepository _purchaseRepo = PurchaseRepository();
  final SaleRepository _saleRepo = SaleRepository();
  final ReturnRepository _returnRepo = ReturnRepository();
  final IncomeRepository _incomeRepo = IncomeRepository();
  final RemittanceRepository _remittanceRepo = RemittanceRepository();
  final SettingsRepository _settingsRepo = SettingsRepository();

  Timer? _autoBackupTimer;
  bool _isBackupRunning = false;
  DateTime? _nextBackupTime; // 记录下次备份时间

  // 启动自动备份
  Future<void> startAutoBackup(int intervalMinutes) async {
    await stopAutoBackup(); // 先停止现有的定时器
    
    final interval = Duration(minutes: intervalMinutes);
    print('启动自动备份服务，间隔: $intervalMinutes 分钟');
    
    // 设置下次备份时间
    _nextBackupTime = DateTime.now().add(interval);
    
    _autoBackupTimer = Timer.periodic(interval, (timer) async {
      await performAutoBackup();
      // 每次备份后更新下次备份时间
      _nextBackupTime = DateTime.now().add(interval);
    });
  }

  // 停止自动备份
  Future<void> stopAutoBackup() async {
    _autoBackupTimer?.cancel();
    _autoBackupTimer = null;
    _nextBackupTime = null; // 清除下次备份时间
    print('停止自动备份服务');
  }
  
  // 获取距离下一次备份的剩余时间（秒）
  int? getSecondsUntilNextBackup() {
    if (_nextBackupTime == null || _autoBackupTimer == null) {
      return null;
    }
    final now = DateTime.now();
    final difference = _nextBackupTime!.difference(now);
    return difference.inSeconds > 0 ? difference.inSeconds : 0;
  }
  
  // 格式化剩余时间为易读格式
  String formatTimeUntilNextBackup() {
    final seconds = getSecondsUntilNextBackup();
    if (seconds == null) {
      return '未启动';
    }
    
    if (seconds == 0) {
      return '即将备份...';
    }
    
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    if (hours > 0) {
      return '$hours 小时 $minutes 分钟 $secs 秒';
    } else if (minutes > 0) {
      return '$minutes 分钟 $secs 秒';
    } else {
      return '$secs 秒';
    }
  }

  // 执行一次备份
  Future<bool> performAutoBackup() async {
    if (_isBackupRunning) {
      print('备份正在进行中，跳过本次');
      return false;
    }

    _isBackupRunning = true;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('current_username');
      
      if (username == null) {
        print('未登录，跳过自动备份');
        _isBackupRunning = false;
        return false;
      }

      // 并行获取当前用户的所有数据（从 API）
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
      final suppliersList = (results[1] as List).map((s) => s.toJson()).toList();
      final customersList = (results[2] as List).map((c) => c.toJson()).toList();
      final employeesList = (results[3] as List).map((e) => e.toJson()).toList();
      final purchases = (results[4] as PaginatedResponse).items.map((p) => p.toJson()).toList();
      final sales = (results[5] as PaginatedResponse).items.map((s) => s.toJson()).toList();
      final returns = (results[6] as PaginatedResponse).items.map((r) => r.toJson()).toList();
      final income = (results[7] as PaginatedResponse).items.map((i) => i.toJson()).toList();
      final remittance = (results[8] as PaginatedResponse).items.map((r) => r.toJson()).toList();
      
      // 获取应用版本号
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = packageInfo.version;
      
      // 构建备份数据
      final backupData = {
        'backupInfo': {
          'type': 'auto_backup',
          'username': username,
          'backupTime': DateTime.now().toIso8601String(),
          'version': appVersion, // 从 package_info_plus 获取版本号
        },
        'data': {
          'products': products,
          'suppliers': suppliersList,
          'customers': customersList,
          'employees': employeesList,
          'purchases': purchases,
          'sales': sales,
          'returns': returns,
          'income': income,
          'remittance': remittance,
        }
      };

      // 转换为JSON
      final jsonString = jsonEncode(backupData);
      
      // 生成文件名
      final now = DateTime.now();
      final fileName = 'auto_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}.json';
      
      // 获取备份目录并保存
      final backupDir = await getAutoBackupDirectory();
      final file = File('${backupDir.path}/$fileName');
      await file.writeAsString(jsonString);
      
      print('自动备份成功: $fileName');
      
      // 更新最后备份时间（保存到本地 SharedPreferences）
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_backup_time', DateTime.now().toIso8601String());
      } catch (e) {
        print('更新备份时间失败: $e');
      }
      
      // 清理旧备份
      await _cleanOldBackups();
      
      _isBackupRunning = false;
      return true;
      
    } on ApiError catch (e) {
      print('自动备份失败（API错误）: ${e.message}');
      _isBackupRunning = false;
      return false;
    } catch (e) {
      print('自动备份失败: $e');
      _isBackupRunning = false;
      return false;
    }
  }

  // 获取备份目录
  Future<Directory> getAutoBackupDirectory() async {
    Directory baseDir;
    
    if (Platform.isAndroid) {
      // Android: 使用外部存储
      baseDir = Directory('/storage/emulated/0/Android/data/com.yikang.agrisalecl/files');
      if (!await baseDir.exists()) {
        // 如果外部存储不可用，使用应用文档目录
        baseDir = await getApplicationDocumentsDirectory();
      }
    } else if (Platform.isIOS) {
      // iOS: 使用 Documents 目录
      baseDir = await getApplicationDocumentsDirectory();
    } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      // 桌面平台: 使用 Application Support
      baseDir = await getApplicationSupportDirectory();
    } else {
      // 其他平台：后备方案
      baseDir = await getApplicationDocumentsDirectory();
    }
    
    final autoBackupDir = Directory('${baseDir.path}/AutoBackups');
    if (!await autoBackupDir.exists()) {
      await autoBackupDir.create(recursive: true);
    }
    
    return autoBackupDir;
  }

  // 获取所有备份文件列表
  Future<List<Map<String, dynamic>>> getBackupList() async {
    try {
      final backupDir = await getAutoBackupDirectory();
      final files = backupDir.listSync()
        .where((f) => f is File && f.path.endsWith('.json'))
        .map((f) => f as File)
        .toList();
      
      // 按修改时间排序（新 → 旧）
      files.sort((a, b) => 
        b.lastModifiedSync().compareTo(a.lastModifiedSync())
      );
      
      // 构建备份信息列表
      List<Map<String, dynamic>> backupList = [];
      for (var file in files) {
        final stat = await file.stat();
        backupList.add({
          'path': file.path,
          'fileName': file.path.split('/').last,
          'modifiedTime': stat.modified,
          'size': stat.size,
        });
      }
      
      return backupList;
    } catch (e) {
      print('获取备份列表失败: $e');
      return [];
    }
  }

  // 删除指定备份
  Future<bool> deleteBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('删除备份成功: $filePath');
        return true;
      }
      return false;
    } catch (e) {
      print('删除备份失败: $e');
      return false;
    }
  }

  // 删除所有备份
  Future<int> deleteAllBackups() async {
    try {
      final backupList = await getBackupList();
      int deletedCount = 0;
      
      for (var backup in backupList) {
        if (await deleteBackup(backup['path'])) {
          deletedCount++;
        }
      }
      
      return deletedCount;
    } catch (e) {
      print('删除所有备份失败: $e');
      return 0;
    }
  }

  // 清理旧备份（保留指定数量）
  Future<void> _cleanOldBackups() async {
    try {
      // 获取最大保留数量设置（从本地 SharedPreferences）
      final prefs = await SharedPreferences.getInstance();
      final maxCount = prefs.getInt('auto_backup_max_count') ?? 20;
      
      final backupList = await getBackupList();
      
      // 如果备份数量超过最大值，删除旧的
      if (backupList.length > maxCount) {
        for (var i = maxCount; i < backupList.length; i++) {
          await deleteBackup(backupList[i]['path']);
        }
        print('清理旧备份: 删除了 ${backupList.length - maxCount} 个');
      }
    } catch (e) {
      print('清理旧备份失败: $e');
    }
  }

  // 恢复备份（通过服务器 API 导入数据）
  Future<bool> restoreBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('备份文件不存在');
        return false;
      }

      final jsonString = await file.readAsString();
      final Map<String, dynamic> backupData = jsonDecode(jsonString);
      
      // 验证数据格式
      if (!backupData.containsKey('backupInfo') || !backupData.containsKey('data')) {
        print('备份文件格式错误');
        return false;
      }

      // 转换备份格式为导入格式（兼容 exportInfo 和 backupInfo）
      final Map<String, dynamic> importData;
      if (backupData.containsKey('backupInfo')) {
        // 自动备份格式：backupInfo -> exportInfo
        importData = {
          'exportInfo': {
            'username': backupData['backupInfo']['username'] ?? '未知',
            'exportTime': backupData['backupInfo']['backupTime'] ?? DateTime.now().toIso8601String(),
            'version': backupData['backupInfo']['version'] ?? (await PackageInfo.fromPlatform()).version,
          },
          'data': backupData['data'],
        };
      } else if (backupData.containsKey('exportInfo')) {
        // 手动导出格式：直接使用
        importData = backupData;
      } else {
        print('备份文件格式错误：缺少 backupInfo 或 exportInfo');
        return false;
      }

      // 通过服务器 API 导入数据
      await _settingsRepo.importData(importData);

      print('恢复备份成功');
      return true;
    } on ApiError catch (e) {
      print('恢复备份失败（API错误）: ${e.message}');
      return false;
    } catch (e) {
      print('恢复备份失败: $e');
      return false;
    }
  }
}

