import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ⬅️ Wajib untuk Registrasi Firebase
import 'home_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  // Ganti _usernameController menjadi _emailController untuk Firebase Auth
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  final FirebaseAuth _auth = FirebaseAuth.instance; 
  bool _isLoading = false; 

  // Fungsi Registrasi yang terhubung dengan Firebase
  Future<void> _signUp() async {
    // 0. Cek validasi Form lokal
    if (!_formKey.currentState!.validate()) {
      return; 
    }

    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      // 1. Panggil metode registrasi Firebase Authentication
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Jika registrasi berhasil: Simpan status login lokal
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true); // Simpan status 'isLoggedIn'
      
      // 3. Navigasi ke HomePage (dan hapus semua rute sebelumnya)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
        (route) => false,
      );

    } on FirebaseAuthException catch (e) {
      // 4. Tangani error dari Firebase
      String message;
      if (e.code == 'weak-password') {
        message = 'Password terlalu lemah. Minimal 6 karakter.';
      } else if (e.code == 'email-already-in-use') {
        message = 'Email ini sudah terdaftar. Silakan login atau gunakan Email lain.';
      } else if (e.code == 'invalid-email') {
        message = 'Format Email tidak valid.';
      } else {
        message = 'Gagal Registrasi: ${e.message}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Terjadi kesalahan tak terduga: ${e.toString()}")),
      );
    } finally {
      // 5. Matikan loading state terlepas dari berhasil atau gagal
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Daftar Akun Baru",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white), // Ubah ikon kembali menjadi putih
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Buat Akun",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),

                // Input Email menggunakan TextFormField
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Email",
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) { 
                    if (value == null || value.isEmpty) {
                      return 'Email tidak boleh kosong';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                        return 'Masukkan format email yang valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // Input Password menggunakan TextFormField
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Password (Min. 6 karakter)",
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) { 
                    if (value == null || value.isEmpty) {
                      return 'Password tidak boleh kosong';
                    }
                    if (value.length < 6) {
                      return 'Password harus minimal 6 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),
                
                // Tombol Daftar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isLoading ? null : _signUp,
                    child: _isLoading 
                      ? const SizedBox(
                        height: 20, 
                        width: 20, 
                        child: CircularProgressIndicator(
                          color: Colors.white, 
                          strokeWidth: 2
                        ))
                      : const Text(
                        "Daftar & Masuk",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                  ),
                ),
                const SizedBox(height: 15),
                
                // Teks untuk kembali ke Login (sudah ada di AppBar, ini opsional)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Sudah punya akun? Kembali ke Login"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}