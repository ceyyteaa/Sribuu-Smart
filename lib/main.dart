import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart'; 
import 'package:firebase_core/firebase_core.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; // ⬅️ IMPORT YANG HILANG DITAMBAHKAN!

// Import file konfigurasi Firebase yang dihasilkan oleh FlutterFire CLI
import 'firebase_options.dart'; 

// Pastikan jalur ini benar
import 'pages/login_page.dart';
import 'pages/home_page.dart'; 

void main() async {
  // 1. Pastikan binding widget sudah siap sebelum memanggil native code
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inisialisasi Firebase
  try {
    await Firebase.initializeApp(
      // Menggunakan konfigurasi platform-spesifik
      options: DefaultFirebaseOptions.currentPlatform, 
    );
    print("✅ Firebase berhasil diinisialisasi.");
  } catch (e) {
    print("❌ Gagal menginisialisasi Firebase: $e");
    // Penanganan error bisa ditambahkan di sini
  }

  // 3. Inisialisasi data format tanggal (intl package)
  await initializeDateFormatting('id_ID', null); 

  runApp(const MyApp());
}

// ----------------------------------------------------

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Fungsi untuk mengecek status login dari SharedPreferences dan Firebase Auth
  Future<Widget> _getInitialPage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Ambil status login dari penyimpanan lokal (SharedPreferences)
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

      // Cek apakah ada pengguna yang sedang login di Firebase Auth
      final user = FirebaseAuth.instance.currentUser; 

      // Jika SharedPreferences menyatakan sudah login AND ada user aktif di Firebase
      if (isLoggedIn && user != null) {
        return const HomePage();
      } else {
        // Jika belum login atau sesi Firebase sudah berakhir
        return const LoginPage();
      }
    } catch (e) {
      // Jika terjadi kesalahan saat mengakses SharedPreferences atau Firebase, default ke LoginPage
      print("Error saat mengecek sesi: $e");
      return const LoginPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sribuu Smart',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      // FutureBuilder untuk menentukan halaman awal (LoginPage atau HomePage)
      home: FutureBuilder<Widget>(
        future: _getInitialPage(), // Panggil fungsi pengecekan sesi
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Tampilkan loading screen/splash screen saat menunggu data sesi
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: Colors.blue)),
            );
          }
          // Tampilkan halaman yang ditentukan
          return snapshot.data ?? const LoginPage(); 
        },
      ),
    );
  }
}