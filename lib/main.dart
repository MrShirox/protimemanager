import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/chrono_provider.dart';
import 'providers/planning_provider.dart';
import 'providers/constantes_provider.dart';
import 'providers/medications_provider.dart';
import 'database/db_helper.dart';
import 'services/work_sessions.dart';
import 'services/work_home_widget.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  await DBHelper.instance.database;
  runApp(const ProTimeManagerApp());
}

class ProTimeManagerApp extends StatelessWidget {
  const ProTimeManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
            create: (_) {
              final store = WorkSessions();
              connectWorkWidget(store);
              return store;
            },
            lazy: false),
        ChangeNotifierProvider(
            create: (context) =>
                PlanningProvider(context.read<WorkSessions>())),
        ChangeNotifierProvider(
            create: (context) => ChronoProvider(context.read<WorkSessions>())),
        ChangeNotifierProvider(create: (_) => ConstantesProvider()),
        ChangeNotifierProvider(
            lazy: false, create: (_) => MedicationsProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'ProTimeManager',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
