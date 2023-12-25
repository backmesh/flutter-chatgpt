import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_apple/firebase_ui_oauth_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:journal/user_store.dart';
import 'package:journal/firebase_options.dart';

import 'widgets/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseFirestore.instance.settings = Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  FirebaseUIAuth.configureProviders([
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS)
      AppleProvider()
  ]);
  runApp(Main());
}

class Main extends StatefulWidget {
  // This widget is the root of your application.

  @override
  _MainState createState() => _MainState();
}

class _MainState extends State<Main> with WidgetsBindingObserver {
  late StreamSubscription<User?> userStream;
  User? user = FirebaseAuth.instance.currentUser;
  // ios only
  bool isHidden = true;
  bool isAuthing = false;

  void initState() {
    super.initState();
    userStream = FirebaseAuth.instance.authStateChanges().listen((fbUser) {
      if (fbUser != null) UserStore(fbUser.uid);
      setState(() {
        user = fbUser;
      });
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    userStream.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      if (user != null && state == AppLifecycleState.resumed) {
        _showAuthenticationScreen();
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (!isAuthing && user != null && state != AppLifecycleState.resumed) {
        isHidden = true;
      } else if (!isAuthing &&
          user != null &&
          isHidden &&
          state == AppLifecycleState.resumed) {
        isAuthing = true;
        isHidden = false;
        _showAuthenticationScreen();
      }
    }
  }

  Future<void> _showAuthenticationScreen() async {
    try {
      await FirebaseAuth.instance.signInWithProvider(AppleAuthProvider());
    } catch (e) {
      FirebaseAuth.instance.signOut();
    } finally {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        isAuthing = false;
      }
    }
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    const primary = Color.fromRGBO(23, 89, 115, 1);
    //const secondary = Color.fromRGBO(140, 184, 159, 1);
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Journal',
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
        ],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: primary),
          visualDensity: VisualDensity.adaptivePlatformDensity,
          useMaterial3: true,
        ),
        supportedLocales: [
          const Locale('en', 'US'),
        ],
        home: user == null ? ContinueWithApple() : HomeScreen());
  }
}

class ContinueWithApple extends StatelessWidget {
  // TODO modify to say continue instead of sign in
  @override
  Widget build(BuildContext context) {
    return SignInScreen(
      showAuthActionSwitch: false,
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Tag>>(
        stream: UserStore.instance.tagsRef.snapshots(),
        builder:
            (BuildContext context, AsyncSnapshot<QuerySnapshot<Tag>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              !snapshot.hasData) {
            return Center(
                child:
                    CircularProgressIndicator()); // Show a loading indicator while waiting
          }
          if (snapshot.hasError) {
            return Text(snapshot.error
                .toString()); // Show error or a placeholder when no data
          }
          final docs = snapshot.data!.docs;
          Map<String, Tag> tags = {for (var doc in docs) doc.id: doc.data()};
          return HomePage(tags);
        });
  }
}
