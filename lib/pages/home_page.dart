import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import untuk Notifikasi & Timezone
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// Import halaman lain (Pastikan file ini ada di project Anda)
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
  String filter = "Semua"; // Default filter

  String? goalName;
  double? goalTarget;
  double? goalProgress;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  User? _currentUser;

  StreamSubscription? _transactionSubscription;

  // Variabel Notifikasi
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isNotificationEnabled = false;
  String _notificationFrequency = 'Harian';

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    // Set locale format uang ke Indonesia
    Intl.defaultLocale = 'id_ID';

    tz.initializeTimeZones();
    _initNotifications();
    _loadNotificationPreferences();

    if (_currentUser != null) {
      _loadGoal();
      _startTransactionListener();
    } else {
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

  // --- HELPER MENGHITUNG SALDO REAL-TIME UNTUK VALIDASI ---
  int _hitungSaldoSaatIni() {
    int totalMasuk = transaksi
        .where((e) => e['jenis'] == 'masuk')
        .fold(0, (sum, item) => sum + (item['jumlah'] as int));
    int totalKeluar = transaksi
        .where((e) => e['jenis'] == 'keluar')
        .fold(0, (sum, item) => sum + (item['jumlah'] as int));
    return totalMasuk - totalKeluar;
  }

  // --- LOGIKA NOTIFIKASI ---

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
    _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }

  Future<void> _loadNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isNotificationEnabled = prefs.getBool('notif_enabled') ?? false;
      _notificationFrequency = prefs.getString('notif_freq') ?? 'Harian';
    });
  }

  Future<void> _saveNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_enabled', _isNotificationEnabled);
    await prefs.setString('notif_freq', _notificationFrequency);
    await _scheduleNotification();
  }

  double _hitungSaranTabungan() {
    final now = DateTime.now();
    final transBulanIni = transaksi.where((item) {
      final tgl = (item['tanggal'] as Timestamp).toDate();
      return tgl.year == now.year && tgl.month == now.month;
    }).toList();

    double masuk = transBulanIni.where((e) => e['jenis'] == 'masuk')
        .fold(0.0, (sum, item) => sum + (item['jumlah'] as int));
    double keluar = transBulanIni.where((e) => e['jenis'] == 'keluar')
        .fold(0.0, (sum, item) => sum + (item['jumlah'] as int));

    double surplus = masuk - keluar;
    return surplus > 0 ? surplus * 0.20 : 0;
  }

  Future<void> _scheduleNotification() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
    if (!_isNotificationEnabled) return;

    double saran = _hitungSaranTabungan();
    String bodyText = saran > 0
        ? "Yuk sisihkan Rp ${NumberFormat.compactSimpleCurrency(locale: 'id_ID').format(saran)} hari ini!"
        : "Jangan lupa cek keuanganmu dan sisihkan uang untuk menabung ya!";

    var now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 8, 0);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    DateTimeComponents? matchComponent;
    if (_notificationFrequency == 'Harian') {
      matchComponent = DateTimeComponents.time;
    } else if (_notificationFrequency == 'Mingguan') {
      matchComponent = DateTimeComponents.dayOfWeekAndTime;
    } else if (_notificationFrequency == 'Bulanan') {
      matchComponent = DateTimeComponents.dayOfMonthAndTime;
    }

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Waktunya Menabung! 💰',
      bodyText,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'channel_id_sribuu',
          'Pengingat Menabung',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: matchComponent,
    );
  }

  void _showNotificationSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Pengingat Menabung ⏰"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text("Aktifkan Notifikasi"),
                    value: _isNotificationEnabled,
                    onChanged: (val) {
                      setDialogState(() => _isNotificationEnabled = val);
                    },
                  ),
                  if (_isNotificationEnabled) ...[
                    const SizedBox(height: 10),
                    const Text("Frekuensi:"),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: _notificationFrequency,
                      items: ['Harian', 'Mingguan', 'Bulanan']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => _notificationFrequency = val);
                        }
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Batal"),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                    _saveNotificationPreferences();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Pengingat diatur: $_notificationFrequency")),
                    );
                  },
                  child: const Text("Simpan"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- FUNGSI FIREBASE ---

  Future<void> _updateSaldoKeFirestore() async {
    if (_currentUser == null) return;
    int saldoSaatIni = _hitungSaldoSaatIni();

    try {
      await _firestore.collection('users').doc(_currentUser!.uid).set({
        'saldo': saldoSaatIni,
        'nama': _currentUser!.displayName ?? _currentUser!.email ?? "User",
        'email': _currentUser!.email,
        'photoUrl': _currentUser!.photoURL,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Gagal update saldo: $e");
    }
  }

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
        _updateSaldoKeFirestore();
      });
    }, onError: (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data: $error')),
      );
    });
  }

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
            goalName = decoded?['name'];
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
      _scheduleNotification();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e')),
      );
    }
  }

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
      _scheduleNotification();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal edit: $e')),
      );
    }
  }

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
      _scheduleNotification();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal hapus: $e')),
      );
    }
  }

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
        SnackBar(content: Text('Gagal simpan goal: $e')),
      );
    }
  }

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

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("💡 Saran Menabung"),
          content: Text("Progres goal kamu sudah ${persenTercapai.toStringAsFixed(1)}%. Yuk tabung lagi!"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Oke"),
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
        title: const Text("⚠️ Peringatan"),
        content: Text(
            "Kamu baru keluar Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(jumlah)}. Jangan boros ya!"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Siap"),
          ),
        ],
      ),
    );
  }

  // --- 🔥 PERBAIKAN BOTTOM OVERFLOW & VALIDASI SALDO 🔥 ---
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
            scrollable: true,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Text(
              index == null
                  ? (jenis == 'masuk' ? 'Tambah Pemasukan' : 'Catat Pengeluaran')
                  : 'Edit Transaksi',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controllerKeterangan,
                    decoration: const InputDecoration(
                      labelText: 'Kategori / Keterangan', 
                      hintText: 'Contoh: Makanan, Transport, Gaji',
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

                    // --- 1. Validasi Angka Tidak Boleh <= 0 ---
                    if (jumlahInt <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("⚠️ Jumlah harus lebih dari 0!"),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return; // Batalkan
                    }

                    // --- 2. Validasi Saldo Tidak Boleh Minus (Khusus Pengeluaran) ---
                    if (jenis == 'keluar') {
                      int saldoSaatIni = _hitungSaldoSaatIni();
                      
                      // Jika sedang EDIT, kembalikan dulu nominal lama ke saldo 'bayangan'
                      // agar perbandingannya adil.
                      if (index != null) {
                         // Pastikan data lama memang pengeluaran sebelum dikembalikan
                         if (transaksi[index]['jenis'] == 'keluar') {
                            saldoSaatIni += (transaksi[index]['jumlah'] as int);
                         }
                      }

                      if (jumlahInt > saldoSaatIni) {
                        // Tampilkan DIALOG PEMBERITAHUAN sesuai permintaan
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("⚠️ Saldo Tidak Mencukupi"),
                            content: Text(
                                "Anda tidak bisa mencatat pengeluaran sebesar Rp ${NumberFormat('#,###', 'id_ID').format(jumlahInt)} karena saldo anda saat ini hanya Rp ${NumberFormat('#,###', 'id_ID').format(saldoSaatIni)}."),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text("Oke"),
                              )
                            ],
                          ),
                        );
                        return; // Batalkan penyimpanan
                      }
                    }
                    // --- Akhir Validasi Saldo ---

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

  // --- LOGIKA FILTER ---
  List<Map<String, dynamic>> _getFilteredTransaksi() {
    final now = DateTime.now();
    return transaksi.where((item) {
      final tgl = (item['tanggal'] as Timestamp).toDate();

      switch (filter) {
        case "Pemasukan":
          return item['jenis'] == 'masuk';
        case "Pengeluaran":
          return item['jenis'] == 'keluar';
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
                  'assets/Sribuu_Smart.png',
                  height: 80,
                  width: 80,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.account_balance_wallet,
                        size: 80, color: Colors.white);
                  },
                ),
                const SizedBox(height: 10),
                const Text("Sribuu Smart", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                MaterialPageRoute(
                    builder: (_) =>
                        GrafikPage(transaksi: transaksi, saldo: saldo)),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.lightbulb, color: Colors.orange),
            title: const Text("Tips Keuangan"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        TipsKeuanganPage(transaksi: transaksi, saldo: saldo)),
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
                    builder: (_) =>
                        LeaderboardPage(transaksi: transaksi, saldo: saldo)),
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

  Widget _buildSavingsAdviceCard(List<Map<String, dynamic>> allTransaksi) {
    final now = DateTime.now();
    final transBulanIni = allTransaksi.where((item) {
      final tgl = (item['tanggal'] as Timestamp).toDate();
      return tgl.year == now.year && tgl.month == now.month;
    }).toList();

    double masukBulanIni = transBulanIni
        .where((e) => e['jenis'] == 'masuk')
        .fold(0.0, (sum, item) => sum + (item['jumlah'] as int).toDouble());

    double keluarBulanIni = transBulanIni
        .where((e) => e['jenis'] == 'keluar')
        .fold(0.0, (sum, item) => sum + (item['jumlah'] as int).toDouble());

    double surplus = masukBulanIni - keluarBulanIni;
    double saranTabungan = surplus > 0 ? surplus * 0.20 : 0;

    bool isDefisit = surplus < 0;
    bool isBalanced = surplus == 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        color: isDefisit
            ? Colors.red.shade50
            : (isBalanced ? Colors.grey.shade50 : Colors.green.shade50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Detail Keuangan Bulan Ini"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Pemasukan: Rp ${NumberFormat('#,###', 'id_ID').format(masukBulanIni)}"),
                    Text("Pengeluaran: Rp ${NumberFormat('#,###', 'id_ID').format(keluarBulanIni)}"),
                    const Divider(),
                    Text(
                        "Sisa Dana (Cashflow): Rp ${NumberFormat('#,###', 'id_ID').format(surplus)}",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDefisit ? Colors.red : Colors.green)),
                    const SizedBox(height: 10),
                    if (surplus > 0)
                      const Text(
                          "Saran kami adalah menabung 20% dari sisa dana agar keuanganmu tetap sehat."),
                    if (isDefisit)
                      const Text(
                          "Saat ini pengeluaranmu lebih besar dari pemasukan. Fokuslah mengurangi pengeluaran."),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Tutup"))
                ],
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  isDefisit
                      ? Icons.warning_amber_rounded
                      : Icons.savings_outlined,
                  size: 30,
                  color: isDefisit ? Colors.red : Colors.green[800],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDefisit
                            ? "Peringatan Keuangan!"
                            : "Saran Tabungan Bulan Ini",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                isDefisit ? Colors.red[800] : Colors.green[900]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isDefisit
                            ? "Pengeluaranmu melebihi pemasukan bulan ini."
                            : isBalanced
                                ? "Belum ada sisa uang untuk ditabung."
                                : "Yuk, sisihkan Rp ${NumberFormat.compactSimpleCurrency(locale: 'id_ID').format(saranTabungan)} (20%)",
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: ["Pemasukan", "Pengeluaran", "Semua", "Harian", "Mingguan", "Bulanan", "Tahunan"]
            .map(
              (f) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(f),
                  selected: filter == f,
                  selectedColor: f == "Pemasukan"
                      ? Colors.green[100]
                      : f == "Pengeluaran"
                          ? Colors.red[100]
                          : Colors.blue[100],
                  labelStyle: TextStyle(
                    color: filter == f
                        ? (f == "Pemasukan" ? Colors.green[800] : f == "Pengeluaran" ? Colors.red[800] : Colors.blue[800])
                        : Colors.black,
                  ),
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
          final tanggal = DateFormat('EEE, dd MMM yyyy HH:mm', 'id_ID').format(parsedDate);

          return Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              onTap: () => _showInputDialog(index: globalIndex),
              leading: CircleAvatar(
                backgroundColor:
                    item['jenis'] == 'masuk' ? Colors.green : Colors.red,
                child: Icon(
                  item['jenis'] == 'masuk'
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  color: Colors.white,
                ),
              ),
              title: Text(item['keterangan']),
              subtitle: Text(tanggal),
              trailing: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format((item['jumlah'] as int).toDouble())}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: item['jenis'] == 'masuk' ? Colors.green : Colors.red,
                  ),
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

  Widget _buildSummaryCard(
      String title, int amount, Color color, IconData icon) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
                backgroundColor: color, child: Icon(icon, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(amount.toDouble())}",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color),
                    ),
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
    int saldo = _hitungSaldoSaatIni();
    int totalMasuk = transaksi
        .where((e) => e['jenis'] == 'masuk')
        .fold(0, (sum, item) => sum + (item['jumlah'] as int));
    int totalKeluar = transaksi
        .where((e) => e['jenis'] == 'keluar')
        .fold(0, (sum, item) => sum + (item['jumlah'] as int));

    final filtered = _getFilteredTransaksi();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sribuu_Smart"),
        actions: [
          IconButton(
            onPressed: _showNotificationSettingsDialog,
            icon: Icon(
              _isNotificationEnabled
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              color: _isNotificationEnabled ? Colors.yellowAccent : Colors.white,
            ),
            tooltip: 'Pengaturan Notifikasi',
          ),
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
          _buildSavingsAdviceCard(transaksi),
          _buildFilterChips(),
          const Divider(),
          _buildTransaksiList(filtered),
        ],
      ),
      floatingActionButton: _buildFloatingButtons(),
    );
  }
}