import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'menu.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  runApp(const LudoApp());
}

class LudoApp extends StatelessWidget {
  const LudoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Ludo Neo-Classic',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF5DB85C)),
        home: const MenuScreen(),
      );
}
