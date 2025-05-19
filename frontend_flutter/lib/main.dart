import 'package:flutter/material.dart';
import 'package:frontend_flutter/home_screen.dart'; // Assuming home_screen.dart is in lib
import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv;
import 'package:provider/provider.dart';
import 'controllers/sign_animation_controller.dart';
import 'screens/profile_screen.dart';
import 'screens/speech_screen.dart';
import 'screens/debug_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.dotenv.load(fileName: ".env");
    print("Environment variables loaded successfully");
  } catch (e) {
    print("Failed to load environment variables: $e");
    // Continue without env file - will use defaults
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SignAnimationController()),
      ],
      child: MaterialApp(
        title: 'Signosi',
        theme: ThemeData(
          // This is the theme of your application.
          //
          // TRY THIS: Try running your application with "flutter run". You'll see
          // the application has a purple toolbar. Then, without quitting the app,
          // try changing the seedColor in the colorScheme below to Colors.green
          // and then invoke "hot reload" (save your changes or press the "hot
          // reload" button in a Flutter-supported IDE, or press "r" if you used
          // the command line to start the app).
          //
          // Notice that the counter didn't reset back to zero; the application
          // state is not lost during the reload. To reset the state, use hot
          // restart instead.
          //
          // This works for code too, not just values: Most code changes can be
          // tested with just a hot reload.
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
          useMaterial3: true,
          // Further Material 3 specific theme customizations can be added here
          // For example, to match the UI image more closely:
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.white, // Or a light surface color from M3
            foregroundColor: Colors.black87, // For icons and text
            elevation: 0,
            titleTextStyle: const TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            )
          ),
          // You might want to define textTheme, cardTheme, elevatedButtonTheme, etc.
        ),
        initialRoute: '/home',
        routes: {
          '/home': (context) => const HomeScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/speech': (context) => const SpeechScreen(),
          '/debug': (context) => const DebugScreen(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
