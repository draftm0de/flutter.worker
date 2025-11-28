import 'dart:async';
import 'package:draftmode_ui/context.dart';
import 'package:flutter/cupertino.dart';
//
import 'app.dart';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DraftModeUIContext.init(navigatorKey: _navigatorKey);
  runApp(App(navigatorKey: _navigatorKey));
}

