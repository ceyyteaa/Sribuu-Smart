import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'home_page.dart';
import 'tips_keuangan_page.dart';
import 'goal_page.dart';
import 'laporan_keuangan_page.dart';
import 'leaderboard_page.dart';

class GrafikPage extends StatefulWidget {
  final List<Map<String, dynamic>> transaksi;
  final int saldo;
  final String? currentGoalName;
  final double? currentGoalTarget;
  final double? currentGoalProgress;

  const GrafikPage({
    Key? key,
    required this.transaksi,
    required this.saldo,
    this.currentGoalName,
    this.currentGoalTarget,
    this.currentGoalProgress,
  }) : super(key: key);

  @override
  State<GrafikPage> createState() => _GrafikPageState();
}

class _GrafikPageState extends State<GrafikPage> {
  bool isBarChart = true;

  // 1. STATE UNTUK FILTER (AC: Grafik dapat difilter per bulan/tahun)
  late int selectedMonth;
  late int selectedYear;
  final List<int> availableYears = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedMonth = now.month;
    selectedYear = now.year;
    _generateAvailableYears();
  }

  // Helper: Generate tahun yang ada di data transaksi
  void _generateAvailableYears() {
    availableYears.clear();
    availableYears.add(DateTime.now().year); // Selalu masukkan tahun sekarang
    for (var item in widget.transaksi) {
      final date = _getTanggal(item);
      if (!availableYears.contains(date.year)) {
        availableYears.add(date.year);
      }
    }
    availableYears.sort(); // Urutkan tahun
  }

  // Helper: Ambil tanggal
  DateTime _getTanggal(Map<String, dynamic> item) {
    if (item['tanggal'] is Timestamp) {
      return (item['tanggal'] as Timestamp).toDate();
    }
    if (item['tanggal'] is String) {
      return DateTime.parse(item['tanggal']);
    }
    return DateTime.now();
  }

  // 2. LOGIKA FILTER DATA TRANSAKSI
  List<Map<String, dynamic>> get _filteredTransaksi {
    return widget.transaksi.where((item) {
      final date = _getTanggal(item);
      return date.month == selectedMonth && date.year == selectedYear;
    }).toList();
  }

  // Helper: Format Rupiah
  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  // --- LOGIKA CHART (Diperbarui menggunakan _filteredTransaksi) ---

  List<String> _getSortedDates({bool hanyaYangAdaData = false}) {
    // Gunakan _filteredTransaksi agar sumbu X sesuai filter bulan
    final dataSumber = _filteredTransaksi; 
    
    final semuaTanggal = dataSumber
        .map((item) => DateFormat('dd/MM/yyyy').format(_getTanggal(item)))
        .toSet()
        .toList();

    semuaTanggal.sort((a, b) =>
        DateFormat('dd/MM/yyyy').parse(a).compareTo(DateFormat('dd/MM/yyyy').parse(b)));

    return semuaTanggal;
  }

  List<BarChartGroupData> _generateCampuranData() {
    final sortedDates = _getSortedDates(hanyaYangAdaData: true);
    List<BarChartGroupData> barGroups = [];
    final dataSumber = _filteredTransaksi;

    for (int i = 0; i < sortedDates.length; i++) {
      final tanggal = sortedDates[i];
      final totalMasuk = dataSumber
          .where((item) =>
              item['jenis'] == 'masuk' &&
              DateFormat('dd/MM/yyyy').format(_getTanggal(item)) == tanggal)
          .fold(0, (sum, item) => sum + (item['jumlah'] as int));
      final totalKeluar = dataSumber
          .where((item) =>
              item['jenis'] == 'keluar' &&
              DateFormat('dd/MM/yyyy').format(_getTanggal(item)) == tanggal)
          .fold(0, (sum, item) => sum + (item['jumlah'] as int));

      if (totalMasuk > 0 || totalKeluar > 0) {
        barGroups.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: totalMasuk.toDouble(),
                color: Colors.green,
                width: 10,
                borderRadius: BorderRadius.circular(2),
              ),
              BarChartRodData(
                toY: totalKeluar.toDouble(),
                color: Colors.red,
                width: 10,
                borderRadius: BorderRadius.circular(2),
              ),
            ],
            barsSpace: 4,
          ),
        );
      }
    }
    return barGroups;
  }

  List<BarChartGroupData> _generateSingleTypeData(String type) {
    final sortedDates = _getSortedDates(hanyaYangAdaData: true);
    List<BarChartGroupData> barGroups = [];
    final dataSumber = _filteredTransaksi;

    for (int i = 0; i < sortedDates.length; i++) {
      final tanggal = sortedDates[i];
      final total = dataSumber
          .where((item) =>
              item['jenis'] == type &&
              DateFormat('dd/MM/yyyy').format(_getTanggal(item)) == tanggal)
          .fold(0, (sum, item) => sum + (item['jumlah'] as int));

      if (total > 0) {
        Color barColor = type == 'masuk' ? Colors.green : Colors.red;
        barGroups.add(
          BarChartGroupData(
            x: i,
            barRods: [BarChartRodData(toY: total.toDouble(), color: barColor, width: 14, borderRadius: BorderRadius.circular(2))],
          ),
        );
      }
    }
    return barGroups;
  }

  List<FlSpot> _generateLineSpots(String type) {
    final sortedDates = _getSortedDates(hanyaYangAdaData: true);
    List<FlSpot> spots = [];
    final dataSumber = _filteredTransaksi;

    for (int i = 0; i < sortedDates.length; i++) {
      final tanggal = sortedDates[i];
      final total = dataSumber
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

  // --- UI COMPONENTS ---

  ListTile _drawerItem(BuildContext context, IconData icon, String title, Widget page, Color color, {bool replace = false}) {
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

  @override
  Widget build(BuildContext context) {
    Intl.defaultLocale = 'id';

    // Hitung Ringkasan untuk ditampilkan di bawah grafik (AC: Total saldo ditampilkan di bawah grafik)
    double totalMasukBulanIni = _filteredTransaksi
        .where((e) => e['jenis'] == 'masuk')
        .fold(0, (sum, e) => sum + (e['jumlah'] as int));
    double totalKeluarBulanIni = _filteredTransaksi
        .where((e) => e['jenis'] == 'keluar')
        .fold(0, (sum, e) => sum + (e['jumlah'] as int));
    double selisihBulanIni = totalMasukBulanIni - totalKeluarBulanIni;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Grafik Keuangan'),
          centerTitle: true,
          elevation: 0,
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
              tooltip: "Ubah Tampilan Grafik",
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "Campuran"),
              Tab(text: "Menerima"),
              Tab(text: "Membayar"),
            ],
          ),
        ),
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
                      'assets/Sribuu_Smart.png',
                      height: 100,
                      width: 100,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.account_balance_wallet, size: 80, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
               _drawerItem(context, Icons.home, "Beranda", HomePage(transaksi: widget.transaksi, saldo: widget.saldo), Colors.blue, replace: true),
              ListTile(leading: const Icon(Icons.show_chart, color: Colors.blue), title: const Text("Grafik Keuangan"), onTap: () => Navigator.pop(context)),
              _drawerItem(context, Icons.lightbulb, "Tips Keuangan", TipsKeuanganPage(transaksi: widget.transaksi, saldo: widget.saldo, currentGoalName: widget.currentGoalName, currentGoalTarget: widget.currentGoalTarget, currentGoalProgress: widget.currentGoalProgress), Colors.orange, replace: true),
              _drawerItem(context, Icons.savings, "Goal Saving", GoalPage(totalSaldo: widget.saldo, transaksi: widget.transaksi, onGoalUpdate: (n, t, p) {}, currentGoalName: widget.currentGoalName, currentGoalTarget: widget.currentGoalTarget, currentGoalProgress: widget.currentGoalProgress), Colors.green, replace: true),
              _drawerItem(context, Icons.table_chart, "Laporan Keuangan", LaporanKeuanganPage(transaksi: widget.transaksi, currentGoalName: widget.currentGoalName, currentGoalTarget: widget.currentGoalTarget, currentGoalProgress: widget.currentGoalProgress), Colors.indigo, replace: true),
              _drawerItem(context, Icons.leaderboard, "Leaderboard", LeaderboardPage(transaksi: widget.transaksi, saldo: widget.saldo), Colors.red, replace: true),
            ],
          ),
        ),
        body: Column(
          children: [
            // 3. UI FILTER BULAN & TAHUN
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dropdown Bulan
                  DropdownButton<int>(
                    value: selectedMonth,
                    underline: Container(),
                    items: List.generate(12, (index) {
                      return DropdownMenuItem(
                        value: index + 1,
                        child: Text(DateFormat('MMMM', 'id_ID').format(DateTime(2023, index + 1))),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedMonth = val);
                    },
                  ),
                  // Dropdown Tahun
                  DropdownButton<int>(
                    value: selectedYear,
                    underline: Container(),
                    items: availableYears.map((year) {
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedYear = val);
                    },
                  ),
                ],
              ),
            ),
            
            // Legenda
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegend(Colors.green, "Pemasukan"),
                  const SizedBox(width: 20),
                  _buildLegend(Colors.red, "Pengeluaran"),
                ],
              ),
            ),

            // AREA GRAFIK
            Expanded(
              child: TabBarView(
                children: [
                  _buildGraphContainer(isBarChart ? _buildBarChartCampuran() : _buildLineChartCampuran()),
                  _buildGraphContainer(isBarChart ? _buildBarChartSingle('masuk') : _buildLineChartSingle('masuk')),
                  _buildGraphContainer(isBarChart ? _buildBarChartSingle('keluar') : _buildLineChartSingle('keluar')),
                ],
              ),
            ),

            // 4. SUMMARY TOTAL SALDO DI BAWAH GRAFIK (AC TERPENUHI)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 10, offset: const Offset(0, -3))],
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Ringkasan ${DateFormat('MMMM yyyy', 'id_ID').format(DateTime(selectedYear, selectedMonth))}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryItem("Masuk", totalMasukBulanIni, Colors.green),
                      _buildSummaryItem("Keluar", totalKeluarBulanIni, Colors.red),
                      // Total Saldo (Surplus/Defisit Periode Ini)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("Saldo Periode", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            _formatCurrency(selisihBulanIni),
                            style: TextStyle(
                              color: selisihBulanIni >= 0 ? Colors.blue : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          _formatCurrency(amount),
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildGraphContainer(Widget chart) {
    // Jika tidak ada data, tampilkan pesan
    if (_filteredTransaksi.isEmpty) {
       return Center(
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Icon(Icons.bar_chart_outlined, size: 60, color: Colors.grey[300]),
             const SizedBox(height: 10),
             Text("Tidak ada data di periode ini", style: TextStyle(color: Colors.grey[500])),
           ],
         ),
       );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.only(top: 24, right: 24, bottom: 12, left: 8),
          child: chart,
        ),
      ),
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // =================== CHART LOGIC (BAR & LINE) ===================

  Widget _buildBarChartCampuran() {
    final barData = _generateCampuranData();
    final sortedDates = _getSortedDates(hanyaYangAdaData: true);

    if (barData.isEmpty) return const SizedBox.shrink();

    double maxY = 0;
    try {
       maxY = barData
        .map((e) => e.barRods.map((r) => r.toY).reduce((a, b) => a > b ? a : b))
        .reduce((a, b) => a > b ? a : b) * 1.2;
    } catch (e) { maxY = 100000; } // Fallback jika error

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barGroups: barData,
        titlesData: _buildTitlesData(sortedDates),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1)),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String type = (rodIndex == 0) ? 'Pemasukan' : 'Pengeluaran';
              return BarTooltipItem(
                '$type\n',
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                children: <TextSpan>[
                  TextSpan(
                    text: _formatCurrency(rod.toY),
                    style: TextStyle(color: rodIndex == 0 ? Colors.greenAccent : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w500),
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

    if (masukSpots.isEmpty && keluarSpots.isEmpty) return const SizedBox.shrink();

    double maxY = 0;
    if (masukSpots.isNotEmpty) {
      double maxM = masukSpots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
      if (maxM > maxY) maxY = maxM;
    }
    if (keluarSpots.isNotEmpty) {
      double maxK = keluarSpots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
      if (maxK > maxY) maxY = maxK;
    }
    maxY = (maxY == 0 ? 100000 : maxY) * 1.2;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: sortedDates.isNotEmpty ? (sortedDates.length - 1).toDouble() : 0,
        maxY: maxY,
        titlesData: _buildTitlesData(sortedDates),
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(spots: masukSpots, isCurved: true, color: Colors.green, dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: false), barWidth: 3),
          LineChartBarData(spots: keluarSpots, isCurved: true, color: Colors.red, dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: false), barWidth: 3),
        ],
      ),
    );
  }

  Widget _buildBarChartSingle(String type) {
    final barData = _generateSingleTypeData(type);
    final sortedDates = _getSortedDates(hanyaYangAdaData: true);
    if (barData.isEmpty) return const SizedBox.shrink();

    final maxY = barData.map((e) => e.barRods[0].toY).reduce((a, b) => a > b ? a : b) * 1.2;
    final color = type == 'masuk' ? Colors.green : Colors.red;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barGroups: barData,
        titlesData: _buildTitlesData(sortedDates),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1)),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${type == 'masuk' ? 'Menerima' : 'Membayar'}\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                children: [TextSpan(text: _formatCurrency(rod.toY), style: TextStyle(color: color, fontSize: 12))],
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
    if (spots.isEmpty) return const SizedBox.shrink();

    final color = type == 'masuk' ? Colors.green : Colors.red;
    double maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.2;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: sortedDates.isNotEmpty ? (sortedDates.length - 1).toDouble() : 0,
        maxY: maxY,
        titlesData: _buildTitlesData(sortedDates),
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(spots: spots, isCurved: true, color: color, dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)), barWidth: 3),
        ],
      ),
    );
  }

  FlTitlesData _buildTitlesData(List<String> sortedDates) {
    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= sortedDates.length) return const SizedBox.shrink();
            final dateParts = sortedDates[index].split('/');
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text('${dateParts[0]}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), // Hide Left Titles for Cleaner Look
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }
}