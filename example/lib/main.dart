import 'package:flutter/material.dart';
import 'package:rivium_push/rivium_push.dart';

import 'screens/home_screen.dart';
// VoIP temporarily disabled - pods not publicly available yet
// import 'package:rivium_push_voip/rivium_push_voip.dart';

import 'services/rivium_push_service.dart';
// import 'screens/call_screen.dart';

/// Global navigator key for navigation from callbacks
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  RiviumPushMessage? initialMessage;
  // CallData? initialCall;

  try {
    // Initialize RiviumPush SDK
    debugPrint('[Example] Initializing RiviumPush SDK...');
    await RiviumPushService.instance.initialize();
    debugPrint('[Example] RiviumPush SDK initialized successfully');

    // Check if app was launched from a notification
    initialMessage = await RiviumPush.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[Example] App launched from notification: ${initialMessage.title}');
    }

    // VoIP temporarily disabled
    // initialCall = await RiviumPushVoIP.getInitialCall();
    // if (initialCall != null) {
    //   debugPrint('[Example] App launched from call: ${initialCall.callerName}');
    // }
  } catch (e, stackTrace) {
    debugPrint('[Example] Error during initialization: $e');
    debugPrint('[Example] Stack trace: $stackTrace');
  }

  runApp(RiviumPushExampleApp(
    initialMessage: initialMessage,
    // initialCall: initialCall,
  ));
}

class RiviumPushExampleApp extends StatefulWidget {
  final RiviumPushMessage? initialMessage;
  // VoIP temporarily disabled
  // final CallData? initialCall;

  const RiviumPushExampleApp({
    super.key,
    this.initialMessage,
    // this.initialCall,
  });

  @override
  State<RiviumPushExampleApp> createState() => _RiviumPushExampleAppState();
}

class _RiviumPushExampleAppState extends State<RiviumPushExampleApp> {
  @override
  void initState() {
    super.initState();

    // VoIP temporarily disabled
    // Handle initial call if app was launched from VoIP notification
    // if (widget.initialCall != null) {
    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     _navigateToCallScreen(widget.initialCall!);
    //   });
    // }
  }

  // VoIP temporarily disabled
  // void _navigateToCallScreen(CallData callData) {
  //   navigatorKey.currentState?.push(
  //     MaterialPageRoute(
  //       builder: (context) => CallScreen(callData: callData),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'RiviumPush Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: HomeScreen(initialMessage: widget.initialMessage),
    );
  }
}
