import 'package:flutter/material.dart';
import 'home_page.dart';
import 'grafik_page.dart';
import 'goal_page.dart';
import 'laporan_keuangan_page.dart';
import 'leaderboard_page.dart';

class TipsKeuanganPage extends StatelessWidget {
  // parameter agar data tetap terhubung
  final List<Map<String, dynamic>> transaksi;
  final int saldo;
  // 💡 Tambahkan parameter Goal Name, Target, dan Progress
  final String? currentGoalName;
  final double? currentGoalTarget;
  final double? currentGoalProgress;

  const TipsKeuanganPage({
    Key? key,
    this.transaksi = const <Map<String, dynamic>>[],
    this.saldo = 0,
    this.currentGoalName,
    this.currentGoalTarget,
    this.currentGoalProgress,
  }) : super(key: key);

  final List<String> motivasi = const [
    "Jangan menabung apa yang tersisa setelah membelanjakan, tapi belanjakan apa yang tersisa setelah menabung. — Warren Buffett",
    "Investasi dalam ilmu pengetahuan memberikan keuntungan terbaik. — Benjamin Franklin",
    "Bukan seberapa banyak uang yang kamu hasilkan, tapi seberapa banyak yang kamu simpan. — Robert Kiyosaki",
    "Sebagian besar kebebasan finansial adalah memiliki hati dan pikiran bebas dari kekhawatiran. — Suze Orman",
    "Kamu harus mengendalikan uangmu, atau kekurangannya akan selalu mengendalikanmu. — Dave Ramsey",
    "Bukan tentang gajimu, tapi tentang gaya hidupmu. — Tony Robbins",
  ];

  final List<String> tips = const [
    "Catat semua pengeluaran: Dengan mencatat, kamu tahu kemana uangmu pergi.",
    "Buat anggaran bulanan: Pisahkan kebutuhan pokok, tabungan, dan hiburan.",
    "Hidup sesuai kemampuan: Hindari gaya hidup yang membuat utang menumpuk.",
    "Siapkan dana darurat: Minimal 3–6 bulan pengeluaran untuk berjaga-jaga.",
    "Investasi sejak dini: Bahkan sedikit investasi rutin akan berkembang signifikan.",
    "Hindari hutang konsumtif: Utamakan utang produktif yang bisa menambah nilai.",
    "Review keuangan secara berkala: Setiap bulan cek apakah pengeluaran sesuai rencana.",
  ];

  // Helper untuk membuat ListTile navigasi yang rapi
  Widget _drawerItem(BuildContext context,
      {required IconData icon,
      required String title,
      required Color color,
      required Widget page}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => page),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tips & Motivasi Keuangan"),
        centerTitle: true,
        elevation: 4,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),

      // === Drawer Navigasi ===
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue, Colors.purple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 💡 Menggunakan Gambar Aset Lokal
                  Image.asset(
                    'assets/Sribuu Smart.png', // Pastikan file ada di folder assets
                    height: 126,
                    width: 126,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.account_balance_wallet, size: 100, color: Colors.white);
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),

            // === Navigasi ke halaman lain ===
            _drawerItem(
              context,
              icon: Icons.home,
              title: "Beranda",
              color: Colors.blue,
              page: HomePage(transaksi: transaksi, saldo: saldo),
            ),
            _drawerItem(
              context,
              icon: Icons.show_chart,
              title: "Grafik Keuangan",
              color: Colors.blue,
              page: GrafikPage(transaksi: transaksi, saldo: saldo),
            ),
            
            // Item Tips Keuangan (Halaman Saat Ini)
            ListTile(
              leading: const Icon(Icons.lightbulb, color: Colors.orange),
              title: const Text("Tips Keuangan"),
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.grey),
              onTap: () {
                Navigator.pop(context); // tetap di halaman ini
              },
            ),
            
            _drawerItem(
              context,
              icon: Icons.savings,
              title: "Goal Saving",
              color: Colors.green,
              page: GoalPage(
                totalSaldo: saldo,
                transaksi: transaksi,
                onGoalUpdate: (name, target, progress) {},
                currentGoalName: currentGoalName,
                currentGoalTarget: currentGoalTarget,
                currentGoalProgress: currentGoalProgress,
              ),
            ),
            _drawerItem(
              context,
              icon: Icons.table_chart,
              title: "Laporan Keuangan",
              color: Colors.indigo,
              page: LaporanKeuanganPage(transaksi: transaksi),
            ),

            // 💡 Leaderboard
            _drawerItem(
              context,
              icon: Icons.leaderboard,
              title: "Leaderboard",
              color: Colors.red,
              page: LeaderboardPage(transaksi: transaksi, saldo: saldo),
            ),
          ],
        ),
      ),

      // === Isi Halaman Tips & Motivasi ===
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "📌 Tips Keuangan Sederhana tapi Efektif",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 12),
            ...tips.map(
              (t) => Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.orange),
                  title: Text(
                    t,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "💡 Kata-kata Motivasi Keuangan",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 12),
            ...motivasi.map(
              (m) => Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 4,
                margin:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                child: ListTile(
                  leading: const Icon(Icons.lightbulb, color: Colors.teal),
                  title: Text(
                    m,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}