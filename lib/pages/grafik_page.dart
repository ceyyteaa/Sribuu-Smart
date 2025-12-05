import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 

import 'home_page.dart';
import 'tips_keuangan_page.dart';
import 'goal_page.dart';
import 'laporan_keuangan_page.dart';
import 'leaderboard_page.dart'; // 1. IMPORT FILE LEADERBOARD

class GrafikPage extends StatefulWidget {
  final List<Map<String, dynamic>> transaksi;
  final int saldo;
  // 💡 BARU: Tambahkan parameter goal untuk diteruskan
  final String? currentGoalName;
  final double? currentGoalTarget;
  final double? currentGoalProgress;

  const GrafikPage({
    Key? key,
    required this.transaksi,
    required this.saldo,
    this.currentGoalName, // Terima Nama Goal
    this.currentGoalTarget, // Terima Target
    this.currentGoalProgress, // Terima Progress
  }) : super(key: key);


  @override
  State<GrafikPage> createState() => _GrafikPageState();
}

class _GrafikPageState extends State<GrafikPage> {
  bool isBarChart = true;


  
  // 💡 Fungsi Helper: Mengambil DateTime dari data transaksi
  DateTime _getTanggal(Map<String, dynamic> item) {
    if (item['tanggal'] is Timestamp) {
      return (item['tanggal'] as Timestamp).toDate();
    } 
    if (item['tanggal'] is String) {
       return DateTime.parse(item['tanggal']);
    }
    return DateTime.now();
  }

  // Ambil dan urutkan tanggal
  List<String> _getSortedDates({bool hanyaYangAdaData = false}) {
    final semuaTanggal = widget.transaksi
        .map((item) => DateFormat('dd/MM/yyyy').format(_getTanggal(item)))
        .toSet()
        .toList();

    semuaTanggal.sort((a, b) =>
        DateFormat('dd/MM/yyyy').parse(a).compareTo(DateFormat('dd/MM/yyyy').parse(b)));

    if (!hanyaYangAdaData) return semuaTanggal;

    return semuaTanggal.where((tanggalStr) {
      final totalMasuk = widget.transaksi.where((item) =>
          item['jenis'] == 'masuk' &&
          DateFormat('dd/MM/yyyy').format(_getTanggal(item)) == tanggalStr);
      final totalKeluar = widget.transaksi.where((item) =>
          item['jenis'] == 'keluar' &&
          DateFormat('dd/MM/yyyy').format(_getTanggal(item)) == tanggalStr);
      return totalMasuk.isNotEmpty || totalKeluar.isNotEmpty;
    }).toList();
  }

  // Buat data campuran (masuk dan keluar) untuk Bar Chart (Grouped Bars)
  List<BarChartGroupData> _generateCampuranData() {
    final sortedDates = _getSortedDates(hanyaYangAdaData: true);
    List<BarChartGroupData> barGroups = [];

    for (int i = 0; i < sortedDates.length; i++) {
      final tanggal = sortedDates[i];
      final totalMasuk = widget.transaksi
          .where((item) =>
              item['jenis'] == 'masuk' &&
              DateFormat('dd/MM/yyyy').format(_getTanggal(item)) == tanggal)
          .fold(0, (sum, item) => sum + (item['jumlah'] as int));
      final totalKeluar = widget.transaksi
          .where((item) =>
              item['jenis'] == 'keluar' &&
              DateFormat('dd/MM/yyyy').format(_getTanggal(item)) == tanggal)
          .fold(0, (sum, item) => sum + (item['jumlah'] as int));

      if (totalMasuk > 0 || totalKeluar > 0) {
        barGroups.add(
          BarChartGroupData(
            x: i,
            // Rods akan otomatis dikelompokkan berdampingan
            barRods: [
              // Pemasukan
              BarChartRodData(
                toY: totalMasuk.toDouble(), 
                color: Colors.green, 
                width: 10,
              ),
              // Pengeluaran
              BarChartRodData(
                toY: totalKeluar.toDouble(), 
                color: Colors.red, 
                width: 10,
              ),
            ],
            barsSpace: 4,
          ),
        );
      }
    }
    return barGroups;
  }

  // Buat data tunggal (hanya masuk / keluar)
  List<BarChartGroupData> _generateSingleTypeData(String type) {
    final sortedDates = _getSortedDates(hanyaYangAdaData: true);
    List<BarChartGroupData> barGroups = [];

    for (int i = 0; i < sortedDates.length; i++) {
      final tanggal = sortedDates[i];
      final total = widget.transaksi
          .where((item) =>
              item['jenis'] == type &&
              DateFormat('dd/MM/yyyy').format(_getTanggal(item)) == tanggal)
          .fold(0, (sum, item) => sum + (item['jumlah'] as int));

      if (total > 0) {
        Color barColor = type == 'masuk' ? Colors.green : Colors.red;
        barGroups.add(
          BarChartGroupData(
            x: i,
            barRods: [BarChartRodData(toY: total.toDouble(), color: barColor, width: 14)],
          ),
        );
      }
    }
    return barGroups;
  }

  // Buat titik data untuk line chart
  List<FlSpot> _generateLineSpots(String type) {
    final sortedDates = _getSortedDates(hanyaYangAdaData: true);
    List<FlSpot> spots = [];

    for (int i = 0; i < sortedDates.length; i++) {
      final tanggal = sortedDates[i];
      final total = widget.transaksi
          .where((item) =>
              item['jenis'] == type &&
              DateFormat('dd/MM/yyyy').format(_getTanggal(item)) == tanggal)
          .fold(0, (sum, item) => sum + (item['jumlah'] as int));
      if (total > 0) {
        spots.add(FlSpot(i.toDouble(), total.toDouble()));
      }
    }
    return spots;
  }
  
  // 💡 Penyesuaian Drawer Item: Tambahkan opsi replace
  ListTile _drawerItem(
      BuildContext context, IconData icon, String title, Widget page, Color color, {bool replace = false}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: () {
        Navigator.pop(context);
        if (replace) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => page));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (context) => page));
        }
      },
    );
  }

  // =================== UI ===================
  @override
  Widget build(BuildContext context) {
    Intl.defaultLocale = 'id';
    final tanggalSekarang =
        DateFormat('EEEE, dd MMM yyyy HH:mm').format(DateTime.now());

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Grafik Keuangan'),
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
          actions: [
            IconButton(
              icon: Icon(isBarChart ? Icons.show_chart : Icons.bar_chart),
              onPressed: () => setState(() => isBarChart = !isBarChart),
              tooltip: "Ubah tampilan grafik",
            ),
        
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: "Campuran"),
              Tab(text: "Menerima"),
              Tab(text: "Membayar"),
            ],
          ),
        ),

        // 💡 Drawer dengan Navigasi GoalPage Langsung
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
                      'assets/Sribuu Smart.png',
                      height: 126,
                      width: 126,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.account_balance_wallet, size: 80, color: Colors.white);
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),

              // 🔹 BERANDA
              _drawerItem(
                context,
                Icons.home,
                "Beranda",
                HomePage(
                    transaksi: widget.transaksi,
                    saldo: widget.saldo), 
                Colors.blue,
                replace: true,
              ),

              // 🔹 GRAFIK KEUANGAN (tetap di halaman ini)
              ListTile(
                leading: const Icon(Icons.show_chart, color: Colors.blue),
                title: const Text("Grafik Keuangan"),
                onTap: () => Navigator.pop(context), // Tutup drawer
              ),

              // 🔹 TIPS KEUANGAN
              _drawerItem(
                context,
                Icons.lightbulb,
                "Tips Keuangan",
                TipsKeuanganPage(
                  transaksi: widget.transaksi,
                  saldo: widget.saldo,
                  // Kirimkan data goal
                  currentGoalName: widget.currentGoalName, 
                  currentGoalTarget: widget.currentGoalTarget, 
                  currentGoalProgress: widget.currentGoalProgress, 
                ),
                Colors.orange,
                replace: true,
              ),

              // 🔹 GOAL SAVING (Menuju GoalPage secara langsung)
              _drawerItem(
                context,
                Icons.savings,
                "Goal Saving",
                GoalPage(
                  totalSaldo: widget.saldo,
                  transaksi: widget.transaksi,
                  // Kirimkan fungsi placeholder yang sekarang menerima Nama, Target, Progress
                  onGoalUpdate: (name, target, progress) {
                    // Fungsi kosong.
                  },
                  currentGoalName: widget.currentGoalName,
                  currentGoalTarget: widget.currentGoalTarget,
                  currentGoalProgress: widget.currentGoalProgress,
                ),
                Colors.green,
                replace: true,
              ),

              // 🔹 LAPORAN KEUANGAN
              _drawerItem(
                context,
                Icons.table_chart,
                "Laporan Keuangan",
                LaporanKeuanganPage(
                  transaksi: widget.transaksi,
                  // Kirimkan data goal
                  currentGoalName: widget.currentGoalName, 
                  currentGoalTarget: widget.currentGoalTarget, 
                  currentGoalProgress: widget.currentGoalProgress, 
                ),
                Colors.indigo,
                replace: true,
              ),

              // 🔹 LEADERBOARD (Ditambahkan di sini)
              _drawerItem(
                context,
                Icons.leaderboard,
                "Leaderboard",
                LeaderboardPage(
                  transaksi: widget.transaksi,
                  saldo: widget.saldo,
                ),
                Colors.red,
                replace: true,
              ),
            ],
          ),
        ),

        // Body
        body: Column(
          children: [
            // 💡 Legenda
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegend(Colors.green, "Pemasukan"),
                  const SizedBox(width: 20),
                  _buildLegend(Colors.red, "Pengeluaran"),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildGraphContainer(isBarChart ? _buildBarChartCampuran() : _buildLineChartCampuran()),
                  _buildGraphContainer(isBarChart ? _buildBarChartSingle('masuk') : _buildLineChartSingle('masuk')),
                  _buildGraphContainer(isBarChart ? _buildBarChartSingle('keluar') : _buildLineChartSingle('keluar')),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey.shade100,
              width: double.infinity,
              child: Text(
                "Diperbarui: $tanggalSekarang",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphContainer(Widget chart) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.only(top: 16, right: 16, bottom: 8, left: 4),
          child: chart,
        ),
      ),
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 13)),
      ],
    );
  }


  // =================== CHART LOGIC ===================

  Widget _buildBarChartCampuran() {
    final barData = _generateCampuranData();
    final sortedDates = _getSortedDates(hanyaYangAdaData: true);

    if (barData.isEmpty) return const Center(child: Text("Belum ada data transaksi"));

    final maxY = barData
        .map((e) => e.barRods.map((r) => r.toY).reduce((a, b) => a > b ? a : b))
        .reduce((a, b) => a > b ? a : b) * 1.2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        maxY: maxY,
        barGroups: barData,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= sortedDates.length) return const SizedBox.shrink();
                final dateParts = sortedDates[index].split('/');
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 4,
                  child: Text(
                    '${dateParts[0]}/${dateParts[1]}',
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  NumberFormat.compact(locale: 'id_ID').format(value),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: const Color(0xff37434d), width: 1)),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String type = (rodIndex == 0) ? 'Pemasukan' : 'Pengeluaran';
              return BarTooltipItem(
                '$type\n',
                TextStyle(color: rod.color, fontWeight: FontWeight.bold, fontSize: 12),
                children: <TextSpan>[
                  TextSpan(
                    text: NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(rod.toY),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLineChartCampuran() {
    final masukSpots = _generateLineSpots('masuk');
    final keluarSpots = _generateLineSpots('keluar');
    final sortedDates = _getSortedDates(hanyaYangAdaData: true);

    if (sortedDates.isEmpty) {
      return const Center(child: Text("Belum ada data transaksi"));
    }
    
    double maxY = 0;
    if (masukSpots.isNotEmpty) maxY = masukSpots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    if (keluarSpots.isNotEmpty) {
      final maxKeluar = keluarSpots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
      if (maxKeluar > maxY) maxY = maxKeluar;
    }
    maxY *= 1.2;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: sortedDates.length > 0 ? (sortedDates.length - 1).toDouble() : 0,
        maxY: maxY,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= sortedDates.length) return const SizedBox.shrink();
                final dateParts = sortedDates[index].split('/');
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 4,
                  child: Text(
                    '${dateParts[0]}/${dateParts[1]}',
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  NumberFormat.compact(locale: 'id_ID').format(value),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: true, border: Border.all(color: const Color(0xff37434d), width: 1)),
        lineBarsData: [
          LineChartBarData(
            spots: masukSpots, 
            isCurved: true, 
            color: Colors.green, 
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
            ),
          LineChartBarData(
            spots: keluarSpots, 
            isCurved: true, 
            color: Colors.red, 
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
            ),
        ],
      ),
    );
  }

  Widget _buildBarChartSingle(String type) {
    final barData = _generateSingleTypeData(type);
    final sortedDates = _getSortedDates(hanyaYangAdaData: true);

    if (barData.isEmpty) return const Center(child: Text("Belum ada data transaksi"));

    final maxY =
        barData.map((e) => e.barRods[0].toY).reduce((a, b) => a > b ? a : b) * 1.2;
    final color = type == 'masuk' ? Colors.green : Colors.red;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        maxY: maxY,
        barGroups: barData,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= sortedDates.length) return const SizedBox.shrink();
                final dateParts = sortedDates[index].split('/');
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 4,
                  child: Text(
                    '${dateParts[0]}/${dateParts[1]}',
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  NumberFormat.compact(locale: 'id_ID').format(value),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: const Color(0xff37434d), width: 1)),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
         barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${type == 'masuk' ? 'Menerima' : 'Membayar'}\n',
                TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                children: <TextSpan>[
                  TextSpan(
                    text: NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(rod.toY),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
  
  Widget _buildLineChartSingle(String type) {
    final spots = _generateLineSpots(type);
    final sortedDates = _getSortedDates(hanyaYangAdaData: true);

    if (spots.isEmpty) return const Center(child: Text("Belum ada data transaksi"));

    final color = type == 'masuk' ? Colors.green : Colors.red;
    
    double maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.2;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: sortedDates.length > 0 ? (sortedDates.length - 1).toDouble() : 0,
        maxY: maxY,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= sortedDates.length) return const SizedBox.shrink();
                final dateParts = sortedDates[index].split('/');
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 4,
                  child: Text(
                    '${dateParts[0]}/${dateParts[1]}',
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  NumberFormat.compact(locale: 'id_ID').format(value),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: true, border: Border.all(color: const Color(0xff37434d), width: 1)),
        lineBarsData: [
          LineChartBarData(
            spots: spots, 
            isCurved: true, 
            color: color,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}