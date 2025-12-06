import 'package:flutter/material.dart';
// 1. TAMBAHAN PENTING: Import untuk memperbaiki Date Picker Error
import 'package:flutter_localizations/flutter_localizations.dart'; 

import 'package:intl/date_symbol_data_local.dart'; 
import 'package:firebase_core/firebase_core.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 

// Import file konfigurasi Firebase
import 'firebase_options.dart'; 

// Import Halaman
import 'pages/login_page.dart';
import 'pages/home_page.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inisialisasi Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform, 
    );
    print("✅ Firebase berhasil diinisialisasi.");
  } catch (e) {
    print("❌ Gagal menginisialisasi Firebase: $e");
  }

  // 3. Inisialisasi format tanggal Indonesia
  await initializeDateFormatting('id_ID', null); 

  runApp(const MyApp());
}

// ----------------------------------------------------

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Fungsi Cek Status Login (Tetap menggunakan logika Anda)
  Future<Widget> _getInitialPage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Cek Local Storage
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

      // Cek Firebase Auth
      final user = FirebaseAuth.instance.currentUser; 

      // Validasi Ganda
      if (isLoggedIn && user != null) {
        return const HomePage();
      } else {
        return const LoginPage();
      }
    } catch (e) {
      print("Error saat mengecek sesi: $e");
      return const LoginPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sribuu Smart',
      
      // Tema Aplikasi
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[100],
      ),

      // ============================================================
      // 4. BAGIAN INI WAJIB DITAMBAHKAN AGAR DATE PICKER TIDAK EROR
      // ============================================================
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'), // Bahasa Indonesia
        Locale('en', 'US'), // Bahasa Inggris
      ],
      // ============================================================

      // Logic Halaman Awal
      home: FutureBuilder<Widget>(
        future: _getInitialPage(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Loading Screen
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: Colors.blue)),
            );
          }
          // Tampilkan HomePage atau LoginPage
          return snapshot.data ?? const LoginPage(); 
        },
      ),
    );
  }
}