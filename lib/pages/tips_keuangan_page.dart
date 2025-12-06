import 'package:flutter/material.dart';
import 'home_page.dart';
import 'grafik_page.dart';
import 'goal_page.dart';
import 'laporan_keuangan_page.dart';
import 'leaderboard_page.dart';

// --- MODEL DATA (Tetap dipertahankan agar struktur rapi) ---
class TipModel {
  final String content;
  final String category; // Investasi, Pengelolaan, Motivasi

  TipModel({required this.content, required this.category});
}

class TipsKeuanganPage extends StatefulWidget {
  final List<Map<String, dynamic>> transaksi;
  final int saldo;
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

  @override
  State<TipsKeuanganPage> createState() => _TipsKeuanganPageState();
}

class _TipsKeuanganPageState extends State<TipsKeuanganPage> {
  // State untuk Filter Kategori
  String _selectedCategory = "Semua";
  final List<String> _categories = ["Semua", "Pengelolaan", "Investasi", "Motivasi"];

  // Data Tips (Isi tetap dari yang saya berikan sebelumnya agar lengkap)
  late List<TipModel> _allData;

  @override
  void initState() {
    super.initState();
    _allData = [
      // === PENGELOLAAN ===
      TipModel(content: "Catat semua pengeluaran: Dengan mencatat, kamu tahu kemana uangmu pergi.", category: "Pengelolaan"),
      TipModel(content: "Buat anggaran bulanan: Pisahkan kebutuhan pokok, tabungan, dan hiburan.", category: "Pengelolaan"),
      TipModel(content: "Hidup sesuai kemampuan: Hindari gaya hidup yang membuat utang menumpuk.", category: "Pengelolaan"),
      TipModel(content: "Siapkan dana darurat: Minimal 3–6 bulan pengeluaran untuk berjaga-jaga.", category: "Pengelolaan"),
      TipModel(content: "Hindari hutang konsumtif: Utamakan utang produktif yang bisa menambah nilai.", category: "Pengelolaan"),
      TipModel(content: "Review keuangan secara berkala: Setiap bulan cek apakah pengeluaran sesuai rencana.", category: "Pengelolaan"),

      // === INVESTASI (Lengkap dengan 3 tambahan baru) ===
      TipModel(content: "Investasi sejak dini: Bahkan sedikit investasi rutin akan berkembang signifikan.", category: "Investasi"),
      TipModel(content: "Diversifikasi Aset: Jangan taruh semua telur dalam satu keranjang. Sebar uangmu di saham, reksadana, dan emas.", category: "Investasi"),
      TipModel(content: "Pahami Profil Risiko: Ketahui apakah kamu tipe agresif atau cari aman sebelum memilih instrumen investasi.", category: "Investasi"),
      TipModel(content: "Strategi Dollar Cost Averaging (DCA): Investasi rutin nominal sama setiap bulan lebih aman daripada menunggu pasar turun.", category: "Investasi"),

      // === MOTIVASI ===
      TipModel(content: "Jangan menabung apa yang tersisa setelah membelanjakan, tapi belanjakan apa yang tersisa setelah menabung. — Warren Buffett", category: "Motivasi"),
      TipModel(content: "Investasi dalam ilmu pengetahuan memberikan keuntungan terbaik. — Benjamin Franklin", category: "Motivasi"),
      TipModel(content: "Bukan seberapa banyak uang yang kamu hasilkan, tapi seberapa banyak yang kamu simpan. — Robert Kiyosaki", category: "Motivasi"),
      TipModel(content: "Sebagian besar kebebasan finansial adalah memiliki hati dan pikiran bebas dari kekhawatiran. — Suze Orman", category: "Motivasi"),
      TipModel(content: "Kamu harus mengendalikan uangmu, atau kekurangannya akan selalu mengendalikanmu. — Dave Ramsey", category: "Motivasi"),
      TipModel(content: "Bukan tentang gajimu, tapi tentang gaya hidupmu. — Tony Robbins", category: "Motivasi"),
    ];
  }

  // Helper Drawer Item
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

  // Helper Warna Icon
  Map<String, dynamic> _getCategoryStyle(String category) {
    if (category == "Motivasi") {
      return {'color': Colors.teal, 'icon': Icons.format_quote};
    } else if (category == "Investasi") {
      return {'color': Colors.green, 'icon': Icons.trending_up};
    } else {
      return {'color': Colors.blue, 'icon': Icons.lightbulb_outline};
    }
  }

  @override
  Widget build(BuildContext context) {
    // Logika Filter
    List<TipModel> filteredList = _selectedCategory == "Semua"
        ? _allData
        : _allData.where((item) => item.category == _selectedCategory).toList();

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

      // === DRAWER ===
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
                  // 💡 LOGO DISESUAIKAN DENGAN PERMINTAAN KAMU 💡
                  Image.asset(
                    'assets/Sribuu_Smart.png', // Sesuai path kamu
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

            // Navigasi Drawer
            _drawerItem(context, icon: Icons.home, title: "Beranda", color: Colors.blue, 
              page: HomePage(transaksi: widget.transaksi, saldo: widget.saldo)),
            
            _drawerItem(context, icon: Icons.show_chart, title: "Grafik Keuangan", color: Colors.blue, 
              page: GrafikPage(transaksi: widget.transaksi, saldo: widget.saldo)),
            
            // Item Aktif
            ListTile(
              leading: const Icon(Icons.lightbulb, color: Colors.orange),
              title: const Text("Tips Keuangan"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              onTap: () => Navigator.pop(context),
            ),
            
            _drawerItem(context, icon: Icons.savings, title: "Goal Saving", color: Colors.green, 
              page: GoalPage(
                totalSaldo: widget.saldo, 
                transaksi: widget.transaksi, 
                onGoalUpdate: (n, t, p) {}, 
                currentGoalName: widget.currentGoalName, 
                currentGoalTarget: widget.currentGoalTarget, 
                currentGoalProgress: widget.currentGoalProgress
              )),
            
            _drawerItem(context, icon: Icons.table_chart, title: "Laporan Keuangan", color: Colors.indigo, 
              page: LaporanKeuanganPage(transaksi: widget.transaksi)),
            
            _drawerItem(context, icon: Icons.leaderboard, title: "Leaderboard", color: Colors.red, 
              page: LeaderboardPage(transaksi: widget.transaksi, saldo: widget.saldo)),
          ],
        ),
      ),

      // === BODY (FILTER & LIST) ===
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((category) {
                  final bool isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10.0),
                    child: ChoiceChip(
                      label: Text(
                        category,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: Colors.purple,
                      backgroundColor: Colors.grey[100],
                      onSelected: (bool selected) {
                        if (selected) {
                          setState(() => _selectedCategory = category);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          const Divider(height: 1, thickness: 1),

          // List Data
          Expanded(
            child: filteredList.isEmpty 
              ? const Center(child: Text("Belum ada tips.")) 
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final item = filteredList[index];
                    final style = _getCategoryStyle(item.category);
                    
                    return Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: style['color'].withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(style['icon'], color: style['color'], size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.category.toUpperCase(),
                                    style: TextStyle(
                                      color: style['color'],
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.content,
                                    style: const TextStyle(fontSize: 14, height: 1.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}