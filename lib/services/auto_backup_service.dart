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
  Duration? _interval; // 当前备份间隔

  /// 将下次备份时间持久化到本地（模拟本地版的 user_settings.auto_backup_next_time）
  Future<void> _saveNextBackupTime(DateTime? time) async {
    _nextBackupTime = time;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (time == null) {
        await prefs.remove('auto_backup_next_time');
      } else {
        await prefs.setString('auto_backup_next_time', time.toIso8601String());
      }
    } catch (e) {
      // 持久化失败不影响备份逻辑
      print('保存下次自动备份时间失败（不影响备份）: $e');
    }
  }

  /// 从本地恢复下次备份时间（模拟本地版的 user_settings.auto_backup_next_time）
  Future<DateTime?> _loadNextBackupTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nextTimeStr = prefs.getString('auto_backup_next_time');
      if (nextTimeStr == null || nextTimeStr.isEmpty) {
        return null;
      }
      return DateTime.tryParse(nextTimeStr);
    } catch (e) {
      print('加载下次自动备份时间失败（不影响备份）: $e');
      return null;
    }
  }

  // 启动自动备份
  Future<void> startAutoBackup(int intervalMinutes) async {
    await stopAutoBackup(); // 先停止现有的定时器

    _interval = Duration(minutes: intervalMinutes);
    print('启动自动备份服务，间隔: $intervalMinutes 分钟');

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final lastBackupTimeStr = prefs.getString('last_backup_time');

    // 优先尝试从已记录的下一次备份时间恢复（对应本地版的 auto_backup_next_time）
    final storedNextTime = await _loadNextBackupTime();
    if (storedNextTime != null && storedNextTime.isAfter(now)) {
      _nextBackupTime = storedNextTime;
      _scheduleNextTimer();
      return;
    }

    if (lastBackupTimeStr != null) {
      try {
        final lastBackupTime = DateTime.parse(lastBackupTimeStr);
        final candidateNext = lastBackupTime.add(_interval!);
        if (candidateNext.isAfter(now)) {
          // 上次备份时间 + 间隔 仍在未来，按原计划时间继续
          await _saveNextBackupTime(candidateNext);
        } else {
          // 在应用关闭期间已经错过了计划备份，启动后尽快执行一次（例如 10 秒后）
          await _saveNextBackupTime(now.add(const Duration(seconds: 10)));
        }
      } catch (_) {
        // 解析失败时退回为从现在开始计算
        await _saveNextBackupTime(now.add(_interval!));
      }
    } else {
      // 从未备份过，从现在开始计算
      await _saveNextBackupTime(now.add(_interval!));
    }

    _scheduleNextTimer();
  }

  /// 使用新的间隔重新启动自动备份调度（从当前时间开始，不使用上次记录的下次备份时间）
  Future<void> restartWithNewInterval(int intervalMinutes) async {
    await stopAutoBackup();

    _interval = Duration(minutes: intervalMinutes);
    print('使用新间隔重新启动自动备份服务，间隔: $intervalMinutes 分钟');

    final now = DateTime.now();
    await _saveNextBackupTime(now.add(_interval!));
    _scheduleNextTimer();
  }

  // 停止自动备份
  Future<void> stopAutoBackup() async {
    _autoBackupTimer?.cancel();
    _autoBackupTimer = null;
    _nextBackupTime = null; // 清除内存中的下次备份时间（本地存储可保留，用于下次恢复）
    _interval = null;
    print('停止自动备份服务');
  }

  // 安排下一次备份的定时器（单次定时，执行后再安排下一次）
  void _scheduleNextTimer() {
    if (_nextBackupTime == null || _interval == null) {
      return;
    }

    final now = DateTime.now();
    var delay = _nextBackupTime!.difference(now);
    if (delay.inSeconds <= 0) {
      delay = const Duration(seconds: 1);
    }

    _autoBackupTimer = Timer(delay, () async {
      await performAutoBackup();
      // 每次备份后更新下次备份时间
      await _saveNextBackupTime(DateTime.now().add(_interval!));
      _scheduleNextTimer();
    });
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

  /// 如果开启了"退出时自动备份"，在退出账号或应用进入后台前调用一次
  Future<void> backupOnExitIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backupOnExit = prefs.getBool('auto_backup_on_exit') ?? false;
      final username = prefs.getString('current_username');

      if (!backupOnExit || username == null || username.isEmpty) {
        return;
      }

      // 标记退出时备份正在进行（用于检测异常退出后未完成的备份）
      await prefs.setBool('exit_backup_in_progress', true);

      final success = await performAutoBackup();
      print('退出前自动备份结果: $success');

      // 备份完成后清除标记
      await prefs.setBool('exit_backup_in_progress', false);
    } catch (e) {
      // 退出前自动备份失败不影响退出或关闭应用
      print('退出前自动备份失败（不影响退出）: $e');
      // 尝试清除标记（可能会失败，因为应用可能正在被杀掉）
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('exit_backup_in_progress', false);
      } catch (_) {}
    }
  }

  /// 检查上次退出时的备份是否未完成，如果是，执行一次补充备份
  /// 应该在启动时自动备份之前调用
  Future<void> checkAndRecoverExitBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final exitBackupInProgress = prefs.getBool('exit_backup_in_progress') ?? false;
      final backupOnExit = prefs.getBool('auto_backup_on_exit') ?? false;

      if (exitBackupInProgress && backupOnExit) {
        print('检测到上次退出时的备份未完成，正在补充执行...');
        // 清除标记
        await prefs.setBool('exit_backup_in_progress', false);
        // 执行补充备份
        final success = await performAutoBackup();
        print('补充退出时备份结果: $success');
      } else if (exitBackupInProgress) {
        // 标记存在但退出备份未开启，只清除标记
        await prefs.setBool('exit_backup_in_progress', false);
      }
    } catch (e) {
      print('检查退出时备份状态失败: $e');
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
