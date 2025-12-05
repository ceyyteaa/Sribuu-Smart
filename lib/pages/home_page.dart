import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import halaman lain (Pastikan file-file ini ada di project Anda)
import 'login_page.dart';
import 'grafik_page.dart';
import 'tips_keuangan_page.dart';
import 'goal_page.dart';
import 'laporan_keuangan_page.dart';
import 'leaderboard_page.dart';

class HomePage extends StatefulWidget {
  final List<Map<String, dynamic>> transaksi;
  final int saldo;

  const HomePage({
    super.key,
    this.transaksi = const [],
    this.saldo = 0,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  List<Map<String, dynamic>> transaksi = [];
  String filter = "Semua";
  
  String? goalName; 
  double? goalTarget;
  double? goalProgress;
  
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  
  StreamSubscription? _transactionSubscription; 

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    Intl.defaultLocale = 'id';
    
    if (_currentUser != null) {
      _loadGoal();
      _startTransactionListener(); 
    } else {
      // Delay sedikit agar aman saat build pertama
      Future.delayed(Duration.zero, () {
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
      });
    }
  }

  @override
  void dispose() {
    _transactionSubscription?.cancel(); 
    super.dispose();
  }

  // --- FUNGSI FIREBASE (PERSISTENSI DATA) ---

  // 🔥 Fungsi untuk menyimpan Saldo ke Database Utama agar terbaca Leaderboard
  Future<void> _updateSaldoKeFirestore() async {
    if (_currentUser == null) return;

    // 1. Hitung ulang saldo dari data lokal yang baru saja diambil
    int totalMasuk = transaksi
        .where((e) => e['jenis'] == 'masuk')
        .fold(0, (sum, item) => sum + (item['jumlah'] as int));
    int totalKeluar = transaksi
        .where((e) => e['jenis'] == 'keluar')
        .fold(0, (sum, item) => sum + (item['jumlah'] as int));
    int saldoSaatIni = totalMasuk - totalKeluar;

    try {
      // 2. Simpan ke Collection 'users'
      await _firestore.collection('users').doc(_currentUser!.uid).set({
        'saldo': saldoSaatIni, // Data ini yang diambil Leaderboard
        'nama': _currentUser!.displayName ?? _currentUser!.email ?? "User Tanpa Nama",
        'email': _currentUser!.email,
        'photoUrl': _currentUser!.photoURL,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // merge: true supaya data lain tidak hilang
      
      print("✅ Saldo berhasil diupdate ke Firestore: $saldoSaatIni");
    } catch (e) {
      print("❌ Gagal update saldo: $e");
    }
  }

  // 1. Memulai listener real-time untuk transaksi
  void _startTransactionListener() {
    if (_currentUser == null) return;
    
    final transaksiCollection = _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('transactions')
        .orderBy('tanggal', descending: true); 

    _transactionSubscription = transaksiCollection.snapshots().listen((snapshot) {
      if (!mounted) return;
      setState(() {
        transaksi = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id; 
          return data;
        }).toList();
        
        // 🔥 PENTING: Panggil update saldo setiap kali ada perubahan data
        _updateSaldoKeFirestore();
      });
    }, onError: (error) {
      print("Error fetching transactions: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data transaksi: $error')),
      );
    });
  }

  // 2. Memuat goal dari Firestore
  Future<void> _loadGoal() async {
    if (_currentUser == null) return;

    try {
      final goalDoc = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('goals')
          .doc('current_goal') 
          .get();

      if (goalDoc.exists) {
        final decoded = goalDoc.data();
        if (mounted) {
          setState(() {
            goalName = decoded?['name'] as String?;
            goalTarget = decoded?['target']?.toDouble();
            goalProgress = decoded?['progress']?.toDouble() ?? 0;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            goalName = null;
            goalTarget = null;
            goalProgress = null;
          });
        }
      }
    } catch (e) {
      print("Error loading goal: $e");
    }
  }

  // 3. Menambah Transaksi ke Firestore
  void _tambahTransaksi(String jenis, String keterangan, int jumlah,
      [DateTime? tanggal]) async {
    if (_currentUser == null) return;

    final data = {
      'jenis': jenis,
      'keterangan': keterangan,
      'jumlah': jumlah,
      'tanggal': (tanggal ?? DateTime.now()), 
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('transactions')
          .add(data);
      
      if (jenis == 'masuk') {
        _tampilkanSaranMenabung(jumlah);
      } else if (jenis == 'keluar' && jumlah > 100000) {
        _tampilkanPeringatanBoros(jumlah);
      }

    } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan transaksi: $e')),
      );
    }
  }

  // 4. Mengedit Transaksi di Firestore
  void _editTransaksi(int index, String keterangan, int jumlah, DateTime tanggal) async {
    if (_currentUser == null) return;
    
    final docId = transaksi[index]['id'] as String;

    final updatedData = {
      'keterangan': keterangan,
      'jumlah': jumlah,
      'tanggal': tanggal,
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('transactions')
          .doc(docId)
          .update(updatedData);
          
    } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengedit transaksi: $e')),
      );
    }
  }

  // 5. Menghapus Transaksi di Firestore
  void _hapusTransaksi(int index) async {
    if (_currentUser == null) return;

    final docId = transaksi[index]['id'] as String;

    try {
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('transactions')
          .doc(docId)
          .delete();
          
    } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus transaksi: $e')),
      );
    }
  }
  
  // 6. Menyimpan atau memperbarui Goal di Firestore
  Future<void> _updateGoal(String name, double target, double progress) async {
    if (_currentUser == null) return;

    final goalData = {
      'name': name,
      'target': target,
      'progress': progress,
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('goals')
          .doc('current_goal') 
          .set(goalData, SetOptions(merge: true));

      _loadGoal(); 
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan goal: $e')),
      );
    }
  }

  // 7. Logout dari Firebase
  Future<void> _logout() async {
    _transactionSubscription?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    await _auth.signOut();
    
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  // --- UI & LOGIKA PENDUKUNG ---

  void _tampilkanSaranMenabung(int jumlahMasuk) {
    if (goalTarget != null && goalTarget! > 0) {
      double totalProgress = (goalProgress ?? 0) + jumlahMasuk;
      double persenTercapai = (totalProgress / goalTarget!) * 100;
      if (persenTercapai > 100) persenTercapai = 100;
      final currentGoalName = goalName ?? "Tabungan Anda";

      double sisaGoal = goalTarget! - totalProgress;
      if (sisaGoal < 0) sisaGoal = 0;
      double saranTabung = sisaGoal / 3;

      String pesan;
      if (sisaGoal > 0) {
        pesan =
            "Kamu baru menerima Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(jumlahMasuk)}.\n\n"
            "✨ Progres goal **$currentGoalName** kamu sudah mencapai ${persenTercapai.toStringAsFixed(1)}% dari total Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(goalTarget)}.\n"
            "Untuk mempercepat pencapaian goal, pertimbangkan menabung sekitar Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(saranTabung)} lagi.";
      } else {
        pesan =
            "🎉 Selamat! Goal **$currentGoalName** kamu telah tercapai 100%.\nKamu bisa membuat goal baru untuk target selanjutnya.";
      }

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("💡 Saran Menabung"),
          content: Text(pesan, style: const TextStyle(fontSize: 16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Oke, Terima Kasih 💰"),
            ),
          ],
        ),
      );
    }
  }

  void _tampilkanPeringatanBoros(int jumlah) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("⚠️ Peringatan Keuangan"),
        content: Text(
          "Kamu baru saja membayar sebesar Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(jumlah)}.\n\n"
          "💸 Jangan boros ya!\nDan jangan lupa untuk tetap menyisihkan sebagian uangmu untuk tabungan.",
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Oke, Siap 👍"),
          ),
        ],
      ),
    );
  }

  // --- 🔥 PERBAIKAN DI SINI: MENAMBAHKAN scrollable: true ---
  void _showInputDialog({String jenis = 'masuk', int? index}) {
    final transactionItem = index != null && index < transaksi.length ? transaksi[index] : null;
    
    final controllerKeterangan = TextEditingController(
        text: transactionItem != null ? transactionItem['keterangan'] : "");
    final controllerJumlah = TextEditingController(
        text: transactionItem != null ? (transactionItem['jumlah'] as int).toString() : "");
    
    DateTime selectedDate = transactionItem != null
        ? (transactionItem['tanggal'] as Timestamp).toDate()
        : DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            // ✅ INI SOLUSINYA: scrollable: true
            // Membuat dialog otomatis bisa di-scroll ketika keyboard muncul
            scrollable: true, 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Text(
              index == null
                  ? (jenis == 'masuk' ? 'Tambah Pemasukan' : 'Tambah Pengeluaran')
                  : 'Edit Transaksi',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min, // Pastikan min agar tidak memakan seluruh layar
              children: [
                TextField(
                  controller: controllerKeterangan,
                  decoration: const InputDecoration(
                    labelText: 'Keterangan',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controllerJumlah,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Jumlah (Rp)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text("Tanggal: "),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Text(
                        DateFormat('dd MMM yyyy').format(selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              if (index != null)
                TextButton(
                  onPressed: () {
                    _hapusTransaksi(index);
                    Navigator.pop(context);
                  },
                  child: const Text("Hapus", style: TextStyle(color: Colors.red)),
                ),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Batal")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: jenis == 'masuk' ? Colors.green : Colors.red,
                ),
                onPressed: () {
                  if (controllerKeterangan.text.isNotEmpty &&
                      controllerJumlah.text.isNotEmpty) {
                    int jumlahInt = int.tryParse(controllerJumlah.text) ?? 0;
                    if (index == null) {
                      _tambahTransaksi(
                        jenis,
                        controllerKeterangan.text,
                        jumlahInt,
                        selectedDate,
                      );
                    } else {
                      _editTransaksi(
                        index,
                        controllerKeterangan.text,
                        jumlahInt,
                        selectedDate,
                      );
                    }
                  }
                  Navigator.pop(context);
                },
                child: const Text("Simpan"),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredTransaksi() {
    final now = DateTime.now();
    return transaksi.where((item) {
      final tgl = (item['tanggal'] as Timestamp).toDate(); 
      
      switch (filter) {
        case "Harian":
          return tgl.year == now.year && tgl.month == now.month && tgl.day == now.day;
        case "Mingguan":
          final sevenDaysAgo = now.subtract(const Duration(days: 7));
          return tgl.isAfter(sevenDaysAgo) || tgl.isAtSameMomentAs(sevenDaysAgo);
        case "Bulanan":
          return tgl.year == now.year && tgl.month == now.month;
        case "Tahunan":
          return tgl.year == now.year;
        default:
          return true;
      }
    }).toList();
  }

  // --- WIDGET UI ---
  
  Widget _buildDrawer(BuildContext context, int saldo) {
    return Drawer(
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
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text("Beranda"),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.show_chart, color: Colors.blue),
            title: const Text("Grafik Keuangan"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => GrafikPage(transaksi: transaksi, saldo: saldo)),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.lightbulb, color: Colors.orange),
            title: const Text("Tips Keuangan"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TipsKeuanganPage(transaksi: transaksi, saldo: saldo)),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.savings, color: Colors.green),
            title: const Text("Goal Saving"),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GoalPage(
                    totalSaldo: saldo,
                    transaksi: transaksi,
                    onGoalUpdate: _updateGoal, 
                    currentGoalTarget: goalTarget,
                    currentGoalProgress: goalProgress,
                    currentGoalName: goalName,
                  ),
                ),
              );
              _loadGoal(); 
            },
          ),

          ListTile(
            leading: const Icon(Icons.table_chart, color: Colors.indigo),
            title: const Text("Laporan Keuangan"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => LaporanKeuanganPage(transaksi: transaksi)),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.leaderboard, color: Colors.red),
            title: const Text("Leaderboard"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => LeaderboardPage(transaksi: transaksi, saldo: saldo)),
              );
            },
          ),
          
          const Divider(),
          
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout"),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(int saldo, int totalMasuk, int totalKeluar) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          _buildSummaryCard("Saldo", saldo, Colors.blue, Icons.account_balance_wallet),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                    "Telah Menerima", totalMasuk, Colors.green, Icons.arrow_downward),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                    "Telah Membayar", totalKeluar, Colors.red, Icons.arrow_upward),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {  
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: ["Semua", "Harian", "Mingguan", "Bulanan", "Tahunan"]
            .map(
              (f) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(f),
                  selected: filter == f,
                  onSelected: (_) => setState(() => filter = f),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTransaksiList(List<Map<String, dynamic>> filtered) {
    if (filtered.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text("Belum ada transaksi",
              style: TextStyle(fontSize: 16, color: Colors.grey)),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final item = filtered[index];
          final globalIndex = transaksi.indexOf(item); 
          
          final parsedDate = (item['tanggal'] as Timestamp).toDate(); 
          final tanggal = DateFormat('EEE, dd MMM yyyy HH:mm').format(parsedDate);
          
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              onTap: () => _showInputDialog(index: globalIndex),
              leading: CircleAvatar(
                backgroundColor: item['jenis'] == 'masuk' ? Colors.green : Colors.red,
                child: Icon(
                  item['jenis'] == 'masuk'
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  color: Colors.white,
                ),
              ),
              title: Text(item['keterangan']),
              subtitle: Text(tanggal),
              trailing: Text(
                "Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format((item['jumlah'] as int).toDouble())}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: item['jenis'] == 'masuk' ? Colors.green : Colors.red,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFloatingButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.extended(
          heroTag: "btn1",
          backgroundColor: Colors.green,
          onPressed: () => _showInputDialog(jenis: 'masuk'),
          label: const Text("Menerima"),
          icon: const Icon(Icons.add),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.extended(
          heroTag: "btn2",
          backgroundColor: Colors.red,
          onPressed: () => _showInputDialog(jenis: 'keluar'),
          label: const Text("Membayar"),
          icon: const Icon(Icons.remove),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, int amount, Color color, IconData icon) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color, child: Icon(icon, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(
                    "Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(amount.toDouble())}",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    int totalMasuk = transaksi
        .where((e) => e['jenis'] == 'masuk')
        .fold(0, (sum, item) => sum + (item['jumlah'] as int));
    int totalKeluar = transaksi
        .where((e) => e['jenis'] == 'keluar')
        .fold(0, (sum, item) => sum + (item['jumlah'] as int));
    int saldo = totalMasuk - totalKeluar;

    final filtered = _getFilteredTransaksi();

    return Scaffold(
      // Tambahkan resizeToAvoidBottomInset: false jika Anda tidak ingin floating button ikut naik
      // Tapi biasanya dibiarkan default (true)
      appBar: AppBar(
        title: const Text("Sribuu Smart"),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
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
      drawer: _buildDrawer(context, saldo),
      body: Column(
        children: [
          _buildSummarySection(saldo, totalMasuk, totalKeluar),
          _buildFilterChips(),
          const Divider(),
          _buildTransaksiList(filtered),
        ],
      ),
      floatingActionButton: _buildFloatingButtons(),
    );
  } 
}