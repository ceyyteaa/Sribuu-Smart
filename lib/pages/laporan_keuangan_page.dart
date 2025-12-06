import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'home_page.dart';
import 'grafik_page.dart';
import 'tips_keuangan_page.dart';
import 'goal_page.dart';
import 'leaderboard_page.dart';

class LaporanKeuanganPage extends StatefulWidget {
  final List<Map<String, dynamic>> transaksi;
  final String? currentGoalName;
  final double? currentGoalTarget;
  final double? currentGoalProgress;

  const LaporanKeuanganPage({
    super.key,
    required this.transaksi,
    this.currentGoalName,
    this.currentGoalTarget,
    this.currentGoalProgress,
  });

  @override
  State<LaporanKeuanganPage> createState() => _LaporanKeuanganPageState();
}

class _LaporanKeuanganPageState extends State<LaporanKeuanganPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {}); 
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- HELPER FUNCTIONS ---

  DateTime _getTanggal(Map<String, dynamic> item) {
    if (item['tanggal'] is Timestamp) return (item['tanggal'] as Timestamp).toDate();
    try {
      if (item['tanggal'] is String) return DateTime.parse(item['tanggal']);
    } catch (_) {}
    return DateTime.now();
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + offset);
    });
  }

  // --- LOGIC DATA FILTERING ---
  Map<String, dynamic> _getFilteredData() {
    final allSorted = List<Map<String, dynamic>>.from(widget.transaksi)
      ..sort((a, b) => _getTanggal(a).compareTo(_getTanggal(b)));

    // Hitung Saldo Awal (Tetap dihitung untuk ketepatan matematika saldo berjalan)
    int saldoAwal = 0;
    for (var item in allSorted) {
      DateTime tgl = _getTanggal(item);
      if (tgl.isBefore(DateTime(_selectedMonth.year, _selectedMonth.month, 1))) {
        int d = item['jenis'] == 'masuk' ? item['jumlah'] as int : 0;
        int k = item['jenis'] == 'keluar' ? item['jumlah'] as int : 0;
        saldoAwal += (d - k);
      }
    }

    List<Map<String, dynamic>> resultList = [];
    int runningSaldo = saldoAwal;
    int totalDebit = 0;
    int totalKredit = 0;

    String? filterJenis; 
    if (_tabController.index == 1) filterJenis = 'masuk'; // Tab Pemasukan
    if (_tabController.index == 2) filterJenis = 'keluar'; // Tab Pengeluaran

    for (var item in allSorted) {
      DateTime tgl = _getTanggal(item);
      String jenis = item['jenis'];

      bool isMonthMatch = tgl.year == _selectedMonth.year && tgl.month == _selectedMonth.month;
      bool isTypeMatch = filterJenis == null || jenis == filterJenis;

      if (isMonthMatch) {
        int debit = jenis == 'masuk' ? item['jumlah'] as int : 0;
        int kredit = jenis == 'keluar' ? item['jumlah'] as int : 0;
        
        runningSaldo += (debit - kredit);

        if (isTypeMatch) {
          totalDebit += debit;
          totalKredit += kredit;

          resultList.add({
            'tanggal': tgl,
            'keterangan': item['keterangan'],
            'kategori': item['kategori'] ?? 'Umum', 
            'debit': debit,
            'kredit': kredit,
            'saldo': runningSaldo 
          });
        }
      }
    }

    return {
      'data': resultList,
      'saldoAwal': saldoAwal,
      'totalDebit': totalDebit,
      'totalKredit': totalKredit,
      'saldoAkhir': runningSaldo
    };
  }

  // ================= FUNGSI EXPORT PDF =================
  Future<void> _exportPdf(BuildContext context) async {
    final processedData = _getFilteredData();
    List<Map<String, dynamic>> dataList = processedData['data'];
    int tDebit = processedData['totalDebit'];
    int tKredit = processedData['totalKredit'];
    int saldoAkhir = processedData['saldoAkhir'];
    String periode = DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth).toUpperCase();
    
    int tabIndex = _tabController.index; 

    try {
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.poppinsRegular();
      final fontBold = await PdfGoogleFonts.poppinsBold();
      final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
      
      // Update format tanggal di PDF juga agar konsisten
      final dateFormat = DateFormat('dd/MM/yyyy'); 

      List<String> headers = [];
      List<List<String>> rows = [];
      List<String> footer = [];
      Map<int, pw.Alignment> alignments = {};

      if (tabIndex == 0) { // SEMUA
        // Update header PDF
        headers = ['No', 'Tanggal', 'Keterangan', 'Debit', 'Kredit', 'Saldo'];
        alignments = {0: pw.Alignment.center, 3: pw.Alignment.centerRight, 4: pw.Alignment.centerRight, 5: pw.Alignment.centerRight};
        rows = dataList.asMap().entries.map((e) {
           return [
             (e.key + 1).toString(),
             dateFormat.format(e.value['tanggal']),
             (e.value['keterangan'] ?? '').toString(),
             e.value['debit'] == 0 ? "" : currency.format(e.value['debit']), 
             e.value['kredit'] == 0 ? "" : currency.format(e.value['kredit']), 
             currency.format(e.value['saldo'])
           ];
        }).toList();
        footer = ['', '', 'TOTAL', currency.format(tDebit), currency.format(tKredit), currency.format(saldoAkhir)];
      } 
      else if (tabIndex == 1) { // PEMASUKAN
        headers = ['No', 'Tanggal', 'Keterangan', 'Nominal'];
        alignments = {0: pw.Alignment.center, 3: pw.Alignment.centerRight};
        rows = dataList.asMap().entries.map((e) {
           return [
             (e.key + 1).toString(),
             dateFormat.format(e.value['tanggal']),
             (e.value['keterangan'] ?? '').toString(),
             currency.format(e.value['debit']),
           ];
        }).toList();
        footer = ['', '', 'TOTAL', currency.format(tDebit)];
      } 
      else { // PENGELUARAN
        headers = ['No', 'Tanggal', 'Keterangan', 'Nominal'];
        alignments = {0: pw.Alignment.center, 3: pw.Alignment.centerRight};
        rows = dataList.asMap().entries.map((e) {
           return [
             (e.key + 1).toString(),
             dateFormat.format(e.value['tanggal']),
             (e.value['keterangan'] ?? '').toString(),
             currency.format(e.value['kredit']),
           ];
        }).toList();
        footer = ['', '', 'TOTAL', currency.format(tKredit)];
      }

      rows.add(footer);

      String judulLaporan = tabIndex == 0 ? "LAPORAN BULANAN" : (tabIndex == 1 ? "LAPORAN PEMASUKAN" : "LAPORAN PENGELUARAN");

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Header(
                    level: 0,
                    child: pw.Column(children: [
                      pw.Text("$judulLaporan - SRIBUU SMART", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: fontBold, fontSize: 16)),
                      pw.Text("Periode: $periode", style: pw.TextStyle(font: font, fontSize: 12)),
                    ])),
                pw.SizedBox(height: 10),
                pw.Table.fromTextArray(
                  headers: headers,
                  data: rows,
                  cellStyle: pw.TextStyle(fontSize: 8, font: font),
                  headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white, font: fontBold),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellAlignments: alignments,
                ),
              ],
            );
          },
        ),
      );

      await Printing.sharePdf(bytes: await pdf.save(), filename: 'Laporan_${judulLaporan}_$periode.pdf');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal mencetak: $e")));
    }
  }

  // --- WIDGET BUILDER ---

  Widget _drawerItem(BuildContext context, {required IconData icon, required String title, required Color color, required Widget page}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page)),
    );
  }

  Widget _header(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 1),
    child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
  );

  Widget _cell(String text, {bool isBold = false, TextAlign align = TextAlign.left, Color? color, double fontSize = 10}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Text(text, textAlign: align, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? Colors.black87)),
    );
  }

  Widget _moneyCell(int amount, NumberFormat fmt, Color? color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(amount == 0 ? "" : fmt.format(amount), textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
      ),
    );
  }

  // Builder Tabel Utama
  Widget _buildTableContent(Map<String, dynamic> processedData) {
    List<Map<String, dynamic>> data = processedData['data'];
    int tDebit = processedData['totalDebit'];
    int tKredit = processedData['totalKredit'];
    int saldoAkhir = processedData['saldoAkhir'];
    
    final numberFormat = NumberFormat.decimalPattern('id');
    int tabIndex = _tabController.index;

    // KONFIGURASI LEBAR KOLOM (Disesuaikan agar muat Tanggal dd/MM/yyyy)
    Map<int, TableColumnWidth> columnWidths;
    if (tabIndex == 0) { // SEMUA (6 Kolom: No, Tanggal, Ket, Deb, Kre, Sal)
       columnWidths = const {
         0: FixedColumnWidth(25), 
         1: FixedColumnWidth(70), // Diperlebar
         2: FlexColumnWidth(2), 
         3: FlexColumnWidth(1.2), 
         4: FlexColumnWidth(1.2), 
         5: FlexColumnWidth(1.2)
       };
    } else { // DEBIT/KREDIT (4 Kolom: No, Tanggal, Ket, Nominal)
       columnWidths = const {
         0: FixedColumnWidth(30), 
         1: FixedColumnWidth(70), // Diperlebar
         2: FlexColumnWidth(2), 
         3: FlexColumnWidth(1.5)
       };
    }

    if (data.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 60, color: Colors.grey[300]),
          Text("Tidak ada data", style: TextStyle(color: Colors.grey[500])),
        ],
      ));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
        child: Table(
          border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
          columnWidths: columnWidths,
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            // HEADER (Diubah: Tgl -> Tanggal, Ket -> Keterangan)
            TableRow(
              decoration: BoxDecoration(color: Colors.blue[100]),
              children: [
                _header("No"),
                _header("Tanggal"),
                _header("Keterangan"),
                if (tabIndex == 0) ...[_header("Debit"), _header("Kredit"), _header("Saldo")],
                if (tabIndex == 1) _header("Nominal"), 
                if (tabIndex == 2) _header("Nominal"), 
              ],
            ),

            // DATA ROW
            ...data.asMap().entries.map((entry) {
              int index = entry.key + 1;
              var item = entry.value;
              return TableRow(
                decoration: BoxDecoration(color: index % 2 == 0 ? Colors.white : Colors.grey[50]),
                children: [
                  _cell(index.toString(), align: TextAlign.center),
                  // Diubah: Format tanggal ada tahunnya
                  _cell(DateFormat('dd/MM/yyyy').format(item['tanggal']), align: TextAlign.center, fontSize: 10),
                  _cell(item['keterangan']?.toString() ?? '', align: TextAlign.left),
                  
                  if (tabIndex == 0) ...[
                    _moneyCell(item['debit'], numberFormat, Colors.green[800]),
                    _moneyCell(item['kredit'], numberFormat, Colors.red[800]),
                    _moneyCell(item['saldo'], numberFormat, Colors.blue[900], isBold: true),
                  ],
                  if (tabIndex == 1) _moneyCell(item['debit'], numberFormat, Colors.green[800]),
                  if (tabIndex == 2) _moneyCell(item['kredit'], numberFormat, Colors.red[800]),
                ],
              );
            }),

            // TOTAL ROW
            TableRow(
              decoration: BoxDecoration(color: Colors.yellow[100]),
              children: [
                _cell(""), _cell(""), 
                _cell("TOTAL", isBold: true, align: TextAlign.center, fontSize: 10),
                if (tabIndex == 0) ...[
                   _moneyCell(tDebit, numberFormat, Colors.green[900], isBold: true),
                   _moneyCell(tKredit, numberFormat, Colors.red[900], isBold: true),
                   _moneyCell(saldoAkhir, numberFormat, Colors.blue[900], isBold: true),
                ],
                if (tabIndex == 1) _moneyCell(tDebit, numberFormat, Colors.green[900], isBold: true),
                if (tabIndex == 2) _moneyCell(tKredit, numberFormat, Colors.red[900], isBold: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String namaBulan = DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth).toUpperCase();
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Laporan Keuangan', style: TextStyle(fontSize: 18)),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.blue, Colors.purple]))),
        actions: [
          IconButton(
            onPressed: () => _exportPdf(context),
            icon: const Icon(Icons.print, color: Colors.white),
            tooltip: 'Cetak Laporan Aktif',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "Semua"),
            Tab(text: "Pemasukan"),
            Tab(text: "Pengeluaran"),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.blue, Colors.purple])),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Image.asset('assets/Sribuu_Smart.png', height: 126, width: 126, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.table_chart, size: 60, color: Colors.white)),
                const SizedBox(height: 8),

              ]),
            ),
            _drawerItem(context, icon: Icons.home, title: "Beranda", color: Colors.blue, page: HomePage(transaksi: widget.transaksi, saldo: 0)), 
            _drawerItem(context, icon: Icons.show_chart, title: "Grafik Keuangan", color: Colors.green, page: GrafikPage(transaksi: widget.transaksi, saldo: 0)),
            _drawerItem(context, icon: Icons.lightbulb, title: "Tips Keuangan", color: Colors.orange, page: TipsKeuanganPage(transaksi: widget.transaksi, saldo: 0)),
            _drawerItem(context, icon: Icons.savings, title: "Goal Saving", color: Colors.teal, page: GoalPage(totalSaldo: 0, transaksi: widget.transaksi, onGoalUpdate: (_, __, ___) {}, currentGoalName: widget.currentGoalName, currentGoalTarget: widget.currentGoalTarget, currentGoalProgress: widget.currentGoalProgress)),
            ListTile(leading: const Icon(Icons.table_chart, color: Colors.indigo), title: const Text("Laporan Keuangan"), tileColor: Colors.indigo.withOpacity(0.1), onTap: () => Navigator.pop(context)),
            _drawerItem(context, icon: Icons.leaderboard, title: "Leaderboard", color: Colors.red, page: LeaderboardPage(transaksi: widget.transaksi, saldo: 0)),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[50],
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.arrow_back_ios, size: 16), onPressed: () => _changeMonth(-1)),
                Column(
                  children: [
                    Text("PERIODE", style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    Text(namaBulan, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 16), onPressed: () => _changeMonth(1)),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTableContent(_getFilteredData()), 
                _buildTableContent(_getFilteredData()), 
                _buildTableContent(_getFilteredData()), 
              ],
            ),
          ),
        ],
      ),
    );
  }
}