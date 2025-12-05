import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'signup_page.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isEmailLoading = false;
  bool _isGoogleLoading = false;

  // --- 1. LOGIN MANUAL (EMAIL & PASSWORD) ---
  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Isi Email dan Password"), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isEmailLoading = true);

    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      _goToHome(); 
    } on FirebaseAuthException catch (e) {
      String msg = "Login Gagal";
      if (e.code == 'user-not-found') msg = "Email tidak ditemukan.";
      else if (e.code == 'wrong-password') msg = "Password salah.";
      else if (e.code == 'invalid-credential') msg = "Email/Password salah.";

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isEmailLoading = false);
    }
  }

  // --- 2. LOGIN GOOGLE (SELALU TAMPIL PILIHAN AKUN) ---
  Future<void> _loginWithGoogle() async {
    if (_isGoogleLoading) return;
    setState(() => _isGoogleLoading = true);

    try {
      // 🔥 KUNCI UTAMA:
      // Kita memaksa logout dari plugin GoogleSignIn terlebih dahulu.
      // Ini membuat aplikasi 'lupa' akun sebelumnya, jadi popup pilih akun akan muncul lagi.
      await GoogleSignIn().signOut();

      // Sekarang mulai proses sign in (Dialog akan muncul)
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      
      // Jika user membatalkan (klik area kosong/back)
      if (googleUser == null) {
        setState(() => _isGoogleLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Masuk ke Firebase
      await _auth.signInWithCredential(credential);

      // Berhasil
      _goToHome();

    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal Google: ${e.message}"), backgroundColor: Colors.red),
        );
      }
      setState(() => _isGoogleLoading = false);
    } catch (e) {
      setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _goToHome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              margin: const EdgeInsets.all(20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 10,
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Selamat Datang 👋", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blue)),
                    const SizedBox(height: 10),
                    const Text("Masuk dengan Email atau Google", style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 25),

                    // Input Email
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "Email", prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Input Password
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Password", prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    
                    const SizedBox(height: 20),

                    // Tombol Login Manual
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: Colors.blue, foregroundColor: Colors.white,
                        ),
                        onPressed: (_isEmailLoading || _isGoogleLoading) ? null : _login,
                        child: _isEmailLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("Login", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    
                    const SizedBox(height: 15),
                    const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("ATAU")), Expanded(child: Divider())]),
                    const SizedBox(height: 15),

                    // --- TOMBOL LOGIN GOOGLE ---
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: _isGoogleLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Image.network(
                                // Menggunakan Link Online Logo Google
                                'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/240px-Google_%22G%22_logo.svg.png',
                                height: 24,
                                width: 24,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, color: Colors.red, size: 28),
                              ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Colors.grey),
                          backgroundColor: Colors.white,
                        ),
                        onPressed: (_isEmailLoading || _isGoogleLoading) ? null : _loginWithGoogle,
                        label: Text(
                          _isGoogleLoading ? "Sedang memproses..." : "Masuk dengan Google",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpPage())),
                      child: const Text("Belum punya akun? Daftar"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}