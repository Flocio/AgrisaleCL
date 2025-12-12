// lib/main.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/product_screen.dart';
import 'screens/purchase_screen.dart';
import 'screens/sales_screen.dart';
import 'screens/returns_screen.dart';
import 'screens/stock_report_screen.dart';
import 'screens/purchase_report_screen.dart';
import 'screens/sales_report_screen.dart';
import 'screens/returns_report_screen.dart';
import 'screens/total_sales_report_screen.dart';
import 'screens/financial_statistics_screen.dart';
import 'screens/customer_screen.dart';
import 'screens/supplier_screen.dart';
import 'screens/employee_screen.dart';
import 'screens/income_screen.dart';
import 'screens/remittance_screen.dart';
import 'screens/sales_income_analysis_screen.dart';
import 'screens/purchase_remittance_analysis_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/data_assistant_screen.dart';
import 'screens/auto_backup_screen.dart';
import 'screens/auto_backup_list_screen.dart';
import 'screens/server_config_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 为桌面平台初始化SQLite（保留用于本地缓存，如果需要）
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // 初始化FFI
    sqfliteFfiInit();
    // 设置全局数据库工厂
    databaseFactory = databaseFactoryFfi;
  }
  
  // 初始化 API 服务
  await _initializeApiService();
  
  runApp(MyApp());
}

/// 初始化 API 服务
Future<void> _initializeApiService() async {
  final prefs = await SharedPreferences.getInstance();
  
  // 从 SharedPreferences 读取服务器地址（如果已配置）
  final serverUrl = prefs.getString('server_url');
  if (serverUrl != null && serverUrl.isNotEmpty) {
    ApiService().setBaseUrl(serverUrl);
    print('API 服务已初始化，服务器地址: $serverUrl');
  } else {
    // 默认服务器地址（开发环境）
    // 生产环境应该从配置文件或环境变量读取
    // 如果树莓派 IP 是固定的，可以在这里修改默认地址
    const defaultServerUrl = 'http://192.168.10.12:8000'; // 树莓派 IP 地址
    ApiService().setBaseUrl(defaultServerUrl);
    print('API 服务已初始化，使用默认服务器地址: $defaultServerUrl');
  }
  
  // 初始化认证服务（AuthService 是单例，无需显式初始化）
  
  // 尝试自动登录（如果有保存的 Token）
  final token = await ApiService().getToken();
  if (token != null) {
    print('检测到已保存的 Token，尝试自动登录...');
    try {
      await AuthService().autoLogin();
      print('自动登录成功');
    } catch (e) {
      print('自动登录失败: $e');
      // 清除无效的 Token
      await ApiService().clearToken();
    }
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '农资管理系统',
      // 配置中文本地化
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('zh', 'CN'), // 简体中文
      ],
      locale: const Locale('zh', 'CN'), // 设置默认语言为中文
      theme: ThemeData(
        primarySwatch: Colors.green, // 使用绿色作为主色调，与农资主题相符
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.green,
          accentColor: Colors.lightGreen, // 强调色
          brightness: Brightness.light,
        ),
        // 只在Windows平台设置字体，解决中文字体不一致问题，不影响其他平台
        textTheme: Platform.isWindows ? GoogleFonts.notoSansScTextTheme() : null,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.green,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        listTileTheme: ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        ),
        dataTableTheme: DataTableThemeData(
          headingRowColor: MaterialStateProperty.all(Colors.green[50]),
          dividerThickness: 1,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(),
        '/main': (context) => MainScreen(),
        '/products': (context) => ProductScreen(),
        '/purchases': (context) => PurchaseScreen(),
        '/sales': (context) => SalesScreen(),
        '/returns': (context) => ReturnsScreen(),
        '/income': (context) => IncomeScreen(),
        '/remittance': (context) => RemittanceScreen(),
        '/stock_report': (context) => StockReportScreen(),
        '/purchase_report': (context) => PurchaseReportScreen(),
        '/sales_report': (context) => SalesReportScreen(),
        '/returns_report': (context) => ReturnsReportScreen(),
        '/total_sales_report': (context) => TotalSalesReportScreen(),
        '/sales_income_analysis': (context) => SalesIncomeAnalysisScreen(),
        '/purchase_remittance_analysis': (context) => PurchaseRemittanceAnalysisScreen(),
        '/financial_statistics': (context) => FinancialStatisticsScreen(),
        '/customers': (context) => CustomerScreen(),
        '/suppliers': (context) => SupplierScreen(),
        '/employees': (context) => EmployeeScreen(),
        '/settings': (context) => SettingsScreen(),
        '/data_assistant': (context) => DataAssistantScreen(),
        '/auto_backup': (context) => AutoBackupScreen(),
        '/auto_backup_list': (context) => AutoBackupListScreen(),
        '/server_config': (context) => ServerConfigScreen(),
      },
    );
  }
}