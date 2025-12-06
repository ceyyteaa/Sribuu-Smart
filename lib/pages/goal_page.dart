import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Penting untuk format tanggal Indonesia
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
  DateTime? deadline;

  Goal({
    required this.name,
    required this.target,
    this.deadline,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'target': target,
      'deadline': deadline?.toIso8601String(),
    };
  }

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      name: map['name'] ?? 'Goal Tanpa Nama',
      target: (map['target'] is int) 
          ? (map['target'] as int).toDouble() 
          : (map['target'] as double? ?? 0.0),
      deadline: map['deadline'] != null 
          ? DateTime.tryParse(map['deadline'].toString()) 
          : null,
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
  List<Goal> goals = [];
  
  // Controller Form
  final TextEditingController addNameController = TextEditingController();
  final TextEditingController addTargetController = TextEditingController();
  final TextEditingController addDateController = TextEditingController();
  
  DateTime? selectedDate; 

  // --- STATE LOKAL UNTUK UPDATE INSTAN ---
  String? _localActiveName;
  double? _localActiveTarget;

  @override
  void initState() {
    super.initState();
    // 1. Inisialisasi State Lokal dari Widget Parent
    _localActiveName = widget.currentGoalName;
    _localActiveTarget = widget.currentGoalTarget;

    initializeDateFormatting('id_ID', null).then((_) {
      if (mounted) {
        setState(() {
           Intl.defaultLocale = 'id';
        });
      }
    });
    loadGoals();
  }

  // 2. Pastikan State Lokal tetap sinkron jika Widget Parent berubah
  @override
  void didUpdateWidget(GoalPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentGoalName != oldWidget.currentGoalName || 
        widget.currentGoalTarget != oldWidget.currentGoalTarget) {
      setState(() {
        _localActiveName = widget.currentGoalName;
        _localActiveTarget = widget.currentGoalTarget;
      });
    }
  }

  @override
  void dispose() {
    addNameController.dispose();
    addTargetController.dispose();
    addDateController.dispose();
    super.dispose();
  }

  // --- LOGIKA PENYIMPANAN ---

  Future<void> saveGoalsAndSyncActive(Goal? activeGoal) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> goalStrings = goals.map((goal) => jsonEncode(goal.toMap())).toList();
    await prefs.setStringList('goals', goalStrings);

    // Sync ke Home (Parent)
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

  Future<void> _selectDate(BuildContext context, {required Function(DateTime) onPicked, DateTime? initialDate}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      locale: const Locale('id', 'ID'), 
    );
    if (picked != null) {
      onPicked(picked);
    }
  }

  // --- CRUD & ACTIONS ---

  void addGoal() async {
    String name = addNameController.text.trim();
    double target = double.tryParse(addTargetController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;

    if (name.isEmpty || target <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nama dan Target harus diisi."), backgroundColor: Colors.red),
      );
      return;
    }

    final newGoal = Goal(name: name, target: target, deadline: selectedDate);

    setState(() {
      goals.add(newGoal);
    });

    // Otomatis jadikan aktif saat ditambah (Opsional, sesuai preferensi)
    // setGoalAsActive(newGoal); <-- Aktifkan baris ini jika ingin langsung aktif setelah tambah
    
    // Hanya simpan ke list
    await saveGoalsAndSyncActive(_localActiveName != null ? Goal(name: _localActiveName!, target: _localActiveTarget ?? 0) : null);

    addNameController.clear();
    addTargetController.clear();
    addDateController.clear();
    setState(() {
      selectedDate = null;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Goal '$name' berhasil ditambahkan."), backgroundColor: Colors.green),
    );
  }

  void editGoal(int index, Goal currentGoal) {
    if (index < 0 || index >= goals.length) return;

    final TextEditingController editNameCtrl = TextEditingController(text: currentGoal.name);
    final TextEditingController editTargetCtrl = TextEditingController(text: currentGoal.target.toStringAsFixed(0));
    DateTime? tempDate = currentGoal.deadline;
    final TextEditingController editDateCtrl = TextEditingController(
      text: tempDate != null ? DateFormat('dd MMMM yyyy', 'id_ID').format(tempDate) : ''
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              scrollable: true,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Text('Edit Goal'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: editNameCtrl, decoration: const InputDecoration(labelText: 'Nama Goal')),
                  const SizedBox(height: 10),
                  TextField(controller: editTargetCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target Nominal')),
                  const SizedBox(height: 10),
                  TextField(
                    controller: editDateCtrl, readOnly: true,
                    decoration: const InputDecoration(labelText: 'Deadline', suffixIcon: Icon(Icons.calendar_today)),
                    onTap: () async {
                      FocusScope.of(context).requestFocus(FocusNode());
                      await _selectDate(context, initialDate: tempDate, onPicked: (picked) {
                         setDialogState(() {
                           tempDate = picked;
                           editDateCtrl.text = DateFormat('dd MMMM yyyy', 'id_ID').format(picked);
                         });
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                ElevatedButton(
                  onPressed: () async {
                    double target = double.tryParse(editTargetCtrl.text.replaceAll('.', '').replaceAll(',', '')) ?? currentGoal.target;
                    String newName = editNameCtrl.text.trim();
                    if (target <= 0 || newName.isEmpty) return; 

                    setState(() {
                      goals[index].name = newName;
                      goals[index].target = target;
                      goals[index].deadline = tempDate;
                    });

                    // Cek apakah yang diedit adalah goal yang sedang aktif
                    bool wasActive = currentGoal.name == _localActiveName && currentGoal.target == _localActiveTarget;
                    
                    if (wasActive) {
                      // UPDATE UI INSTAN
                      setState(() {
                        _localActiveName = newName;
                        _localActiveTarget = target;
                      });
                      await saveGoalsAndSyncActive(goals[index]);
                    } else {
                      // Simpan list saja, pertahankan active goal yang lama
                      await saveGoalsAndSyncActive(_localActiveName != null 
                        ? Goal(name: _localActiveName!, target: _localActiveTarget ?? 0) : null);
                    }

                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void deleteGoal(int index) async {
    if (index < 0 || index >= goals.length) return;
    final deletedGoal = goals[index];

    bool wasActive = deletedGoal.name == _localActiveName && deletedGoal.target == _localActiveTarget;

    if (wasActive) {
       // UPDATE UI INSTAN: Reset Active Goal
       setState(() {
         _localActiveName = null;
         _localActiveTarget = 0.0;
       });
       await saveGoalsAndSyncActive(null);
    } else {
       // Hanya hapus dari list
       await saveGoalsAndSyncActive(_localActiveName != null 
          ? Goal(name: _localActiveName!, target: _localActiveTarget ?? 0) : null);
    }

    setState(() {
      goals.removeAt(index);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Goal '${deletedGoal.name}' dihapus."), backgroundColor: Colors.orange),
    );
  }

  // --- FUNGSI UPDATE UI SECARA INSTAN ---

  void deleteActiveGoal() {
    // 1. Update UI Lokal Terlebih Dahulu (Agar langsung menghilang)
    setState(() {
      _localActiveName = null;
      _localActiveTarget = 0.0;
    });

    // 2. Kirim update ke Parent/Storage
    widget.onGoalUpdate("", 0.0, 0.0);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Goal aktif direset."), backgroundColor: Colors.orange),
    );
  }

  void setGoalAsActive(Goal goal) {
    // 1. Update UI Lokal Terlebih Dahulu (Agar langsung muncul)
    setState(() {
      _localActiveName = goal.name;
      _localActiveTarget = goal.target;
    });

    // 2. Kirim update ke Parent/Storage
    saveGoalsAndSyncActive(goal);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("'${goal.name}' sekarang aktif."), backgroundColor: Colors.blue),
    );
  }

  double calculatePercentage(double target) {
    if (target <= 0) return 0;
    double percent = (widget.totalSaldo / target);
    if (percent > 1.0) percent = 1.0;
    return percent;
  }

  Widget _drawerItem(BuildContext context, {required IconData icon, required String title, required Color color, required Widget page}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: () {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
      },
    );
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    // GANTI: Gunakan Variabel Lokal (_local...) agar update instan
    final double currentTarget = _localActiveTarget ?? 0.0;
    final String currentName = _localActiveName ?? "Belum Ditetapkan";

    final double percent = calculatePercentage(currentTarget);
    final bool isCompleted = percent >= 1.0;

    // Cari deadline goal aktif untuk ditampilkan
    DateTime? activeDeadline;
    try {
      if (goals.isNotEmpty) {
        final activeGoalObj = goals.firstWhere(
            (g) => g.name == currentName && g.target == currentTarget,
            orElse: () => Goal(name: '', target: 0));
        if (activeGoalObj.target != 0) activeDeadline = activeGoalObj.deadline;
      }
    } catch (e) { activeDeadline = null; }

    return Scaffold(
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
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.blue, Colors.purple])),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/Sribuu_Smart.png', height: 126, width: 126, fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.account_balance_wallet, size: 100, color: Colors.white),
                  ),
                ],
              ),
            ),
            _drawerItem(context, icon: Icons.home, title: "Beranda", color: Colors.blue, page: HomePage(transaksi: widget.transaksi, saldo: widget.totalSaldo)),
            _drawerItem(context, icon: Icons.show_chart, title: "Grafik Keuangan", color: Colors.blue, page: GrafikPage(transaksi: widget.transaksi, saldo: widget.totalSaldo)),
            _drawerItem(context, icon: Icons.lightbulb, title: "Tips Keuangan", color: Colors.orange, page: TipsKeuanganPage(transaksi: widget.transaksi, saldo: widget.totalSaldo)),
            ListTile(leading: const Icon(Icons.savings, color: Colors.green), title: const Text("Goal Saving"), onTap: () => Navigator.pop(context)),
            _drawerItem(context, icon: Icons.table_chart, title: "Laporan Keuangan", color: Colors.indigo, page: LaporanKeuanganPage(transaksi: widget.transaksi)),
            _drawerItem(context, icon: Icons.leaderboard, title: "Leaderboard", color: Colors.red, page: LeaderboardPage(transaksi: widget.transaksi, saldo: widget.totalSaldo)),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 1. INPUT FORM
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: addNameController,
                      decoration: InputDecoration(labelText: 'Nama Goal Baru', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.flag)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addTargetController,
                      decoration: InputDecoration(labelText: 'Target Nominal (Rp)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.attach_money)),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addDateController, readOnly: true,
                      decoration: InputDecoration(labelText: 'Deadline', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.calendar_today)),
                      onTap: () => _selectDate(context, onPicked: (picked) {
                        setState(() { selectedDate = picked; addDateController.text = DateFormat('dd MMMM yyyy', 'id_ID').format(picked); });
                      }),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: addGoal,
                      label: const Text('Tambah Goal Baru', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ],
                ),
              ),

              // 2. KARTU GOAL AKTIF (Menggunakan State Lokal agar Update Instan)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Card(
                  color: isCompleted ? Colors.green.shade50 : Colors.blue.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Goal Aktif", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
                            if (isCompleted)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
                                child: const Text("SELESAI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                              )
                          ],
                        ),
                        const Divider(),
                        // LOGIKA DISPLAY: Jika currentTarget > 0 maka TAMPILKAN, jika tidak HILANGKAN
                        if (currentTarget > 0) ...[
                          Text("Nama: $currentName", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          if (activeDeadline != null)
                             Text("Deadline: ${DateFormat('dd MMM yyyy', 'id_ID').format(activeDeadline)}", style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                          const SizedBox(height: 8),
                          LinearPercentIndicator(
                            animation: true, lineHeight: 18.0, percent: percent,
                            center: Text("${(percent * 100).toStringAsFixed(1)}%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            linearStrokeCap: LinearStrokeCap.roundAll,
                            progressColor: isCompleted ? Colors.green.shade700 : Colors.blue.shade700, backgroundColor: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 5),
                          Text("Target: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(currentTarget)}"),
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton.icon(
                                onPressed: deleteActiveGoal, // Fungsi ini sekarang update UI seketika
                                icon: const Icon(Icons.close, size: 18, color: Colors.red),
                                label: const Text("Reset Goal Aktif", style: TextStyle(color: Colors.red)),
                            ),
                          )
                        ] else ...[
                          const Center(child: Text("Tidak ada goal aktif."))
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // 3. DAFTAR GOAL
              const Padding(
                padding: EdgeInsets.only(top: 8, left: 16, right: 16),
                child: Text("Daftar Semua Goal", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              ),
              const Divider(indent: 16, endIndent: 16),
              goals.isEmpty
                  ? const Padding(padding: EdgeInsets.all(20.0), child: Text('Belum ada goal yang tersimpan.', textAlign: TextAlign.center))
                  : ListView.builder(
                      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      itemCount: goals.length,
                      itemBuilder: (context, index) {
                        final goal = goals[index];
                        final isCurrentlyActive = goal.name == currentName && goal.target == currentTarget;
                        final percentValue = calculatePercentage(goal.target);
                        final bool goalCompleted = percentValue >= 1.0;

                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 2, margin: const EdgeInsets.symmetric(vertical: 4),
                          color: isCurrentlyActive ? (goalCompleted ? Colors.green.shade100 : Colors.yellow.shade100) : Colors.white,
                          child: ListTile(
                            leading: Icon(goalCompleted ? Icons.check_circle : Icons.flag, color: goalCompleted ? Colors.green : (isCurrentlyActive ? Colors.orange : Colors.teal)),
                            title: Text(goal.name, style: TextStyle(fontWeight: isCurrentlyActive ? FontWeight.bold : FontWeight.normal)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Target: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(goal.target)}"),
                                if (goal.deadline != null) Text("Deadline: ${DateFormat('dd MMM yyyy', 'id_ID').format(goal.deadline!)}", style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') editGoal(index, goal);
                                else if (value == 'delete') deleteGoal(index);
                                else if (value == 'activate') setGoalAsActive(goal);
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Text("Edit Goal")),
                                if (!isCurrentlyActive) const PopupMenuItem(value: 'activate', child: Text("Jadikan Aktif")),
                                const PopupMenuItem(value: 'delete', child: Text("Hapus Goal")),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}