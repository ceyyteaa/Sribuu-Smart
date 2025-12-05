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

class LaporanKeuanganPage extends StatelessWidget {
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

  DateTime _getTanggal(Map<String, dynamic> item) {
    if (item['tanggal'] is Timestamp) return (item['tanggal'] as Timestamp).toDate();
    try {
      if (item['tanggal'] is String) return DateTime.parse(item['tanggal']);
    } catch (_) {}
    return DateTime.now();
  }

  // ================= FUNGSI EXPORT PDF =================
  Future<void> _exportPdf(BuildContext context, List<Map<String, dynamic>> laporanData, int totalDebit, int totalKredit, int saldoAkhir) async {
    try {
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.poppinsRegular();
      final fontBold = await PdfGoogleFonts.poppinsBold();
      final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
      final dateFormat = DateFormat('dd/MM/yyyy');

      final headers = ['No', 'Tanggal', 'Keterangan', 'Debit', 'Kredit', 'Saldo'];

      final data = laporanData.asMap().entries.map((entry) {
        final item = entry.value;
        String tanggalFormatted = item['tanggal'] is DateTime 
            ? dateFormat.format(item['tanggal']) 
            : item['tanggal'].toString();

        return [
          (entry.key + 1).toString(),
          tanggalFormatted,
          item['keterangan'] as String,
          item['debit'] == 0 ? "-" : currency.format(item['debit']),
          item['kredit'] == 0 ? "-" : currency.format(item['kredit']),
          currency.format(item['saldo']),
        ];
      }).toList();

      data.add(['', '', 'TOTAL', currency.format(totalDebit), currency.format(totalKredit), currency.format(saldoAkhir)]);
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Header(level: 0, child: pw.Center(child: pw.Text("LAPORAN KEUANGAN SRIBUU SMART", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: fontBold, fontSize: 16)))),
                pw.SizedBox(height: 10),
                pw.Table.fromTextArray(
                  headers: headers,
                  data: data,
                  cellStyle: pw.TextStyle(fontSize: 8, font: font),
                  headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white, font: fontBold),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellAlignments: {0: pw.Alignment.center, 3: pw.Alignment.centerRight, 4: pw.Alignment.centerRight, 5: pw.Alignment.centerRight},
                ),
              ],
            );
          },
        ),
      );

      await Printing.sharePdf(bytes: await pdf.save(), filename: 'Laporan_SribuuSmart.pdf');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal mencetak: $e")));
    }
  }

  Widget _drawerItem(BuildContext context, {required IconData icon, required String title, required Color color, required Widget page}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page)),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> laporan = [];
    int saldo = 0;
    final sorted = List<Map<String, dynamic>>.from(transaksi)..sort((a, b) => _getTanggal(a).compareTo(_getTanggal(b)));
    
    for (var item in sorted) {
      int debit = item['jenis'] == 'masuk' ? item['jumlah'] as int : 0;
      int kredit = item['jenis'] == 'keluar' ? item['jumlah'] as int : 0;
      saldo += debit - kredit;
      laporan.add({'tanggal': _getTanggal(item), 'keterangan': item['keterangan'], 'debit': debit, 'kredit': kredit, 'saldo': saldo});
    }

    int totalDebit = laporan.fold(0, (sum, item) => sum + (item['debit'] as int));
    int totalKredit = laporan.fold(0, (sum, item) => sum + (item['kredit'] as int));
    
    // 🔥 Format Angka Tanpa "Rp" agar hemat tempat di tabel (Rp ditaruh di header)
    final numberFormat = NumberFormat.decimalPattern('id'); 

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Laporan Keuangan', style: TextStyle(fontSize: 18)),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.blue, Colors.purple]))),
        actions: [
          IconButton(
            onPressed: () => _exportPdf(context, laporan, totalDebit, totalKredit, saldo),
            icon: const Icon(Icons.print, color: Colors.white),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.blue, Colors.purple])),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                 Image.asset('assets/Sribuu Smart.png', height: 80, width: 80, fit: BoxFit.contain, errorBuilder: (_,__,___) => const Icon(Icons.table_chart, size: 60, color: Colors.white)),
                 const SizedBox(height: 8),
                 const Text("Sribuu Smart", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ]),
            ),
            _drawerItem(context, icon: Icons.home, title: "Beranda", color: Colors.blue, page: HomePage(transaksi: transaksi, saldo: saldo)),
            _drawerItem(context, icon: Icons.show_chart, title: "Grafik Keuangan", color: Colors.green, page: GrafikPage(transaksi: transaksi, saldo: saldo)),
            _drawerItem(context, icon: Icons.lightbulb, title: "Tips Keuangan", color: Colors.orange, page: TipsKeuanganPage(transaksi: transaksi, saldo: saldo)),
            _drawerItem(context, icon: Icons.savings, title: "Goal Saving", color: Colors.teal, page: GoalPage(totalSaldo: saldo, transaksi: transaksi, onGoalUpdate: (_,__,___){}, currentGoalName: currentGoalName, currentGoalTarget: currentGoalTarget, currentGoalProgress: currentGoalProgress)),
            ListTile(leading: const Icon(Icons.table_chart, color: Colors.indigo), title: const Text("Laporan Keuangan"), tileColor: Colors.indigo.withOpacity(0.1), onTap: () => Navigator.pop(context)),
            _drawerItem(context, icon: Icons.leaderboard, title: "Leaderboard", color: Colors.red, page: LeaderboardPage(transaksi: transaksi, saldo: saldo)),
          ],
        ),
      ),
      
      // ================= BODY =================
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[50],
            width: double.infinity,
            child: Column(
              children: [
                Text("LAPORAN BULAN ${DateFormat('MMMM yyyy', 'id_ID').format(DateTime.now()).toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                // Legend Kecil
                const Text("(Satuan dalam Rupiah)", style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical, // Hanya scroll ke bawah
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0), // Padding kiri kanan tipis
                child: Table(
                  border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
                  // 🔥 PENGATURAN KOLOM RESPONSIF LAYAR HP 🔥
                  columnWidths: const {
                    0: FixedColumnWidth(22),  // No: Sangat kecil
                    1: FixedColumnWidth(45),  // Tgl: Kecil (format dd/MM)
                    2: FlexColumnWidth(1.8),  // Ket: Paling Lebar
                    3: FlexColumnWidth(1.2),  // Debit
                    4: FlexColumnWidth(1.2),  // Kredit
                    5: FlexColumnWidth(1.2),  // Saldo
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    // --- HEADER ---
                    TableRow(
                      decoration: BoxDecoration(color: Colors.blue[100]),
                      children: [
                        _header("No"),
                        _header("Tanggal"),
                        _header("Keterangan"),
                        _header("Debit"),
                        _header("Kredit"),
                        _header("Saldo"), 
                      ],
                    ),
                    
                    // --- DATA ---
                    ...laporan.asMap().entries.map((entry) {
                      int index = entry.key + 1;
                      var item = entry.value;
                      return TableRow(
                        decoration: BoxDecoration(color: index % 2 == 0 ? Colors.white : Colors.grey[50]),
                        children: [
                          _cell(index.toString(), align: TextAlign.center),
                          _cell(DateFormat('dd/MM').format(item['tanggal']), align: TextAlign.center, fontSize: 10), // Hanya Tgl/Bulan
                          _cell(item['keterangan'], align: TextAlign.left), // Teks akan wrap ke bawah
                          _moneyCell(item['debit'], numberFormat, Colors.green[800]),
                          _moneyCell(item['kredit'], numberFormat, Colors.red[800]),
                          _moneyCell(item['saldo'], numberFormat, Colors.blue[900], isBold: true),
                        ],
                      );
                    }),

                    // --- TOTAL ---
                    TableRow(
                      decoration: BoxDecoration(color: Colors.yellow[100]),
                      children: [
                        _cell(""), _cell(""),
                        _cell("TOTAL", isBold: true, align: TextAlign.center, fontSize: 10),
                        _moneyCell(totalDebit, numberFormat, Colors.green[900], isBold: true),
                        _moneyCell(totalKredit, numberFormat, Colors.red[900], isBold: true),
                        _moneyCell(saldo, numberFormat, Colors.blue[900], isBold: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET HELPER KHUSUS TABEL COMPACT

  Widget _header(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 1),
    child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
  );

  Widget _cell(String text, {bool isBold = false, TextAlign align = TextAlign.left, Color? color, double fontSize = 10}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? Colors.black87),
      ),
    );
  }

  // Helper Khusus Angka agar mengecil jika tidak muat (FittedBox)
  Widget _moneyCell(int amount, NumberFormat fmt, Color? color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: FittedBox( // 🔥 Fitur Penting: Mengecilkan font jika angka jutaan
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(
          amount == 0 ? "-" : fmt.format(amount),
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 10, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color),
        ),
      ),
    );
  }
}