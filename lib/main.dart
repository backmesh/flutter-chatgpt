import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nimbus/gemini.dart';
import 'package:nimbus/user_store.dart';
import 'package:nimbus/firebase_options.dart';
import 'package:nimbus/widgets/chat.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseFirestore.instance.settings = Settings(
    persistenceEnabled: true,
  );
  FirebaseUIAuth.configureProviders([
    EmailAuthProvider(),
  ]);
  runApp(Main());
}

class Main extends StatefulWidget {
  @override
  _MainState createState() => _MainState();
}

class _MainState extends State<Main> with WidgetsBindingObserver {
  @override
  Widget build(BuildContext context) {
    const primary = Color.fromRGBO(23, 89, 115, 1);
    return MaterialApp(
      navigatorObservers: [PosthogObserver()],
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: primary),
        // used by Firebase SignInScreen
        // https://github.com/firebase/FirebaseUI-Flutter/blob/main/docs/firebase-ui-auth/theming.md
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: TextStyle(fontSize: 20.0),
            splashFactory: NoSplash.splashFactory,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(5)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 20),
            backgroundColor: primary,
            foregroundColor: Colors.white,
          ),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      supportedLocales: [
        const Locale('en', 'US'),
      ],
      home: _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  final _posthogFlutterPlugin = Posthog();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _Login();
        }
        final user = snapshot.data;
        if (user != null) {
          UserStore(user);
          _posthogFlutterPlugin.identify(userId: user.uid);
          user.getIdToken().then((jwt) {
            // print(jwt);
            GeminiClient(jwt!, UserStore.instance.model);
          });
        }

        if (user != null && !user.emailVerified) {
          final emailProvider = user.providerData
              .any((provider) => provider.providerId == 'password');
          if (emailProvider) {
            user.sendEmailVerification().then((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Verification email sent to ${user.email}. Please verify your email.'),
                ),
              );
              FirebaseAuth.instance.signOut();
            });
          }
        }

        return ChatPage();
      },
    );
  }
}

class _Login extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SignInScreen(
      resizeToAvoidBottomInset: false,
      providers: [
        EmailAuthProvider(),
      ],
      sideBuilder: (context, constraints) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 100,
              width: 100,
            ),
            const SizedBox(
              height: 30,
            ),
            const Text(
              'ChatGPT-like Flutter App',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            )
          ],
        );
      },
      headerBuilder: (context, constraints, _) {
        return Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  height: 80,
                ),
                Image.asset(
                  'assets/images/logo.png',
                  height: 60,
                  width: 60,
                ),
                const SizedBox(
                  height: 10,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
