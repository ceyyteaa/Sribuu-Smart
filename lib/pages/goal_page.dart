import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:intl/intl.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 

// Import halaman lain (Pastikan file-file ini ada di project Anda)
import 'home_page.dart';
import 'grafik_page.dart';
import 'tips_keuangan_page.dart';
import 'laporan_keuangan_page.dart';
import 'leaderboard_page.dart'; 

// ================= MODEL GOAL =================
class Goal {
  String name;
  double target;

  Goal({required this.name, required this.target});

  Map<String, dynamic> toMap() {
    return {'name': name, 'target': target};
  }

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      name: map['name'] ?? 'Goal Tanpa Nama',
      target: map['target']?.toDouble() ?? 0.0,
    );
  }
}

// ================= HALAMAN GOAL SAVING =================
class GoalPage extends StatefulWidget {
  final int totalSaldo;
  final List<Map<String, dynamic>> transaksi;

  final Function(String name, double target, double progress) onGoalUpdate; 
  final double? currentGoalTarget;
  final double? currentGoalProgress;
  final String? currentGoalName; 

  const GoalPage({
    Key? key,
    required this.totalSaldo,
    required this.transaksi,
    required this.onGoalUpdate,
    this.currentGoalTarget,
    this.currentGoalProgress,
    this.currentGoalName,
  }) : super(key: key);

  @override
  State<GoalPage> createState() => _GoalPageState();
}

class _GoalPageState extends State<GoalPage> {
  // State untuk daftar goal lokal
  List<Goal> goals = [];
  final TextEditingController nameController = TextEditingController(); 
  final TextEditingController targetController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    // Mengatur locale format angka/tanggal ke Indonesia
    Intl.defaultLocale = 'id';
    loadGoals(); 
  }

  @override
  void dispose() {
    nameController.dispose();
    targetController.dispose();
    super.dispose();
  }

// --- LOGIKA PENYIMPANAN LOKAL & SINKRONISASI ---

  Future<void> saveGoalsAndSyncActive(Goal? activeGoal) async {
    final prefs = await SharedPreferences.getInstance();
    
    List<String> goalStrings =
        goals.map((goal) => jsonEncode(goal.toMap())).toList();
    await prefs.setStringList('goals', goalStrings);
    
    // Sinkronisasi ke halaman induk (Home)
    if (activeGoal != null) {
      double progress = widget.totalSaldo.toDouble(); 
      widget.onGoalUpdate(activeGoal.name, activeGoal.target, progress);
    } else {
      widget.onGoalUpdate("", 0.0, 0.0);
    }
  }

  Future<void> loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? goalStrings = prefs.getStringList('goals');
    if (goalStrings != null) {
      setState(() {
        goals = goalStrings.map((g) => Goal.fromMap(jsonDecode(g))).toList();
      });
    }
  }

// --- FUNGSI CRUD GOAL ---

  void addGoal() {
    String name = nameController.text.trim();
    // Membersihkan input angka dari titik/koma format ribuan jika ada
    double target = double.tryParse(targetController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
    
    if (name.isEmpty || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nama dan Target harus diisi dengan benar."), backgroundColor: Colors.red),
      );
      return;
    }

    final newGoal = Goal(name: name, target: target);

    setState(() {
      goals.add(newGoal);
    });
    
    // Simpan goal baru dan set sebagai aktif otomatis (opsional, tergantung logika yang diinginkan)
    saveGoalsAndSyncActive(newGoal);

    nameController.clear();
    targetController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Goal '$name' berhasil ditambahkan."), backgroundColor: Colors.green),
    );
  }
  
  void editGoal(int index, Goal currentGoal) {
    if (index < 0 || index >= goals.length) return;
    
    nameController.text = currentGoal.name;
    targetController.text = currentGoal.target.toStringAsFixed(0);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // scrollable: true mencegah overflow di dalam dialog saat keyboard muncul
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Edit Goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nama Goal'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: targetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target Nominal'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              double target = double.tryParse(targetController.text.replaceAll('.', '').replaceAll(',', '')) ?? currentGoal.target;
              String newName = nameController.text.trim();

              if (target <= 0 || newName.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Nama dan Target harus valid."), backgroundColor: Colors.red),
                );
                return;
              }

              setState(() {
                goals[index].name = newName;
                goals[index].target = target;
              });
              
              // Cek apakah goal yang diedit adalah goal yang sedang aktif
              bool wasActive = currentGoal.name == widget.currentGoalName && currentGoal.target == widget.currentGoalTarget;

              if (wasActive) {
                  saveGoalsAndSyncActive(goals[index]);
              } else {
                  // Hanya simpan list, jangan ubah goal aktif
                  saveGoalsAndSyncActive(widget.currentGoalName != null ? Goal(name: widget.currentGoalName!, target: widget.currentGoalTarget ?? 0) : null); 
              }

              nameController.clear();
              targetController.clear();
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void deleteGoal(int index) async {
    if (index < 0 || index >= goals.length) return;
    
    final deletedGoal = goals[index];

    setState(() {
      goals.removeAt(index);
    });
    
    bool wasActive = deletedGoal.name == widget.currentGoalName && deletedGoal.target == widget.currentGoalTarget;
    
    // Jika goal yang dihapus adalah goal aktif, reset goal aktif
    if (wasActive) {
      await saveGoalsAndSyncActive(null);
    } else {
      // Jika bukan, update list saja
      final prefs = await SharedPreferences.getInstance();
      List<String> goalStrings = goals.map((goal) => jsonEncode(goal.toMap())).toList();
      await prefs.setStringList('goals', goalStrings);
    }

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Goal '${deletedGoal.name}' berhasil dihapus."), backgroundColor: Colors.orange),
    );
  }
  
  void deleteActiveGoal() {
    // Reset goal aktif di Home tanpa menghapus dari list (kecuali jika logika bisnis mengharuskan)
    widget.onGoalUpdate("", 0.0, 0.0);
    
    targetController.clear();
    nameController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Goal aktif berhasil direset."),
        backgroundColor: Colors.orange,
      ),
    );
  }
  
  void setGoalAsActive(Goal goal) {
    saveGoalsAndSyncActive(goal);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Goal '${goal.name}' diatur sebagai Goal Aktif."), backgroundColor: Colors.blue),
    );
  }

  double calculatePercentage(double target) {
    if (target <= 0) return 0;
    double percent = (widget.totalSaldo / target);
    if (percent > 1.0) percent = 1.0;
    return percent;
  }
  
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

// --- UI ---
  @override
  Widget build(BuildContext context) {
    int saldo = widget.totalSaldo;
    final transaksi = widget.transaksi;
    
    final double currentTarget = widget.currentGoalTarget ?? 0.0;
    final String currentName = widget.currentGoalName ?? "Belum Ditetapkan"; 
    
    final double percent = calculatePercentage(currentTarget); 

    return Scaffold(
      // Pastikan resizeToAvoidBottomInset true agar layout menyesuaikan keyboard
      resizeToAvoidBottomInset: true, 

      appBar: AppBar(
        title: const Text('Goal Saving'),
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

      // ================= DRAWER =================
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
                  Image.asset(
                    'assets/Sribuu Smart.png',
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
            
            _drawerItem(context, icon: Icons.home, title: "Beranda", color: Colors.blue, page: HomePage(transaksi: transaksi, saldo: saldo)),
            _drawerItem(context, icon: Icons.show_chart, title: "Grafik Keuangan", color: Colors.blue, page: GrafikPage(transaksi: transaksi, saldo: saldo)),
            _drawerItem(context, icon: Icons.lightbulb, title: "Tips Keuangan", color: Colors.orange, page: TipsKeuanganPage(transaksi: transaksi, saldo: saldo)),
            
            ListTile(leading: const Icon(Icons.savings, color: Colors.green), title: const Text("Goal Saving"), onTap: () => Navigator.pop(context)),
            
            _drawerItem(context, icon: Icons.table_chart, title: "Laporan Keuangan", color: Colors.indigo, page: LaporanKeuanganPage(transaksi: transaksi)),
            
            _drawerItem(context, icon: Icons.leaderboard, title: "Leaderboard", color: Colors.red, page: LeaderboardPage(transaksi: transaksi, saldo: saldo)),
          ],
        ),
      ),

      // ================= BODY =================
      // SAFEAREA + SINGLECHILDSCROLLVIEW ADALAH SOLUSI UTAMA OVERFLOW
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 1. Input Goal Baru
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Nama Goal Baru',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.flag),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: targetController,
                      decoration: InputDecoration(
                        labelText: 'Target Nominal (Rp)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: addGoal,
                      label: const Text('Tambah Goal Baru', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 2. Goal Aktif Saat Ini
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Card(
                  color: Colors.blue.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Goal Aktif (Tersinkronisasi ke Beranda)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
                        const Divider(),
                        if (currentTarget > 0) ...[
                          Text("Nama: $currentName", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          LinearPercentIndicator(
                            animation: true,
                            lineHeight: 18.0,
                            percent: percent,
                            center: Text("${(percent * 100).toStringAsFixed(1)}%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            linearStrokeCap: LinearStrokeCap.roundAll,
                            progressColor: Colors.blue.shade700,
                            backgroundColor: Colors.blue.shade200,
                          ),
                          const SizedBox(height: 5),
                          Text("Target: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(currentTarget)}"),
                        ] else ...[
                          const Center(child: Text("Tidak ada goal aktif."))
                        ],
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton.icon(
                              onPressed: deleteActiveGoal, 
                              icon: const Icon(Icons.delete_forever, size: 18, color: Colors.red),
                              label: const Text("Hapus Goal Aktif", style: TextStyle(color: Colors.red)),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
              
              // 3. Daftar Semua Goal
              const Padding(
                padding: EdgeInsets.only(top: 8, left: 16, right: 16),
                child: Text("Daftar Semua Goal", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              ),
              const Divider(indent: 16, endIndent: 16),

              // LISTVIEW YANG AMAN DARI ERROR SCROLL
              goals.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text('Belum ada goal yang tersimpan.', textAlign: TextAlign.center),
                    )
                  : ListView.builder(
                      shrinkWrap: true, // Penting: Agar ListView tidak memakan tinggi tak terbatas
                      physics: const NeverScrollableScrollPhysics(), // Penting: Agar scroll ikut induk (SingleChildScrollView)
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      itemCount: goals.length,
                      itemBuilder: (context, index) {
                        final goal = goals[index];
                        final isCurrentlyActive = goal.name == currentName && goal.target == currentTarget;
                        final percentValue = calculatePercentage(goal.target);

                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: isCurrentlyActive ? Colors.yellow.shade100 : Colors.white,
                          child: ListTile(
                            leading: Icon(Icons.flag, color: isCurrentlyActive ? Colors.green.shade800 : Colors.teal),
                            title: Text(goal.name, style: TextStyle(fontWeight: isCurrentlyActive ? FontWeight.bold : FontWeight.normal)),
                            subtitle: Text("Target: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(goal.target)} | Progres: ${(percentValue * 100).toStringAsFixed(0)}%"),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  editGoal(index, goal);
                                } else if (value == 'delete') {
                                  deleteGoal(index);
                                } else if (value == 'activate') {
                                  setGoalAsActive(goal);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Text("Edit Goal")),
                                if (!isCurrentlyActive)
                                  const PopupMenuItem(value: 'activate', child: Text("Jadikan Aktif")),
                                const PopupMenuItem(value: 'delete', child: Text("Hapus Goal")),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                // Padding tambahan di bawah agar tidak tertutup floating button atau keyboard
                const SizedBox(height: 20),
            ],
          ),
        ), 
      ),
    );
  }
}