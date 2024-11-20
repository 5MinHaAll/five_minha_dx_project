import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'testFirebaseDB.dart';
import 'login_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Firestore 인스턴스를 전역으로 선언
late FirebaseFirestore db;

void main() async{
  // Flutter 프레임워크 초기화
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Firestore 인스턴스 초기화
  db = FirebaseFirestore.instance;
  // 앱 실행
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const LoginPage(), // 최초 페이지를 LoginPage로 설정
      // home: ForDB(userId: '', title: '',), // 최초 페이지를 LoginPage로 설정
    );
  }






}
