import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Import halaman lain untuk navigasi Drawer
import 'home_page.dart';
import 'grafik_page.dart';
import 'tips_keuangan_page.dart';
import 'goal_page.dart';
import 'laporan_keuangan_page.dart';

// ================= MODEL DATA =================
class UserScore {
  final String id;
  final String displayName;
  final String email;
  final int saldo;
  final String? avatarUrl;

  UserScore({
    required this.id,
    required this.displayName,
    required this.email,
    required this.saldo,
    this.avatarUrl,
  });

  // 🔹 Logika Konversi: 1.000 Rupiah = 1 Poin
  int get points => (saldo / 1000).floor();

  // 🔹 Gelar Berdasarkan Poin
  String get rankTitle {
    if (points >= 100000) return "👑 Sultan Supreme"; // > 100 Juta
    if (points >= 50000) return "💎 Crazy Rich";      // > 50 Juta
    if (points >= 10000) return "🔥 Bos Besar";       // > 10 Juta
    if (points >= 5000) return "💼 Juragan Muda";     // > 5 Juta
    if (points >= 1000) return "💰 Pedagang Sukses";  // > 1 Juta
    if (points >= 500) return "🚀 Perintis";          // > 500rb
    return "🌱 Pejuang Rupiah";                       // < 500rb
  }

  factory UserScore.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Parsing aman untuk Saldo (menangani integer atau double dari firebase)
    num rawSaldoVal = data['saldo'] ?? data['score'] ?? 0;
    int rawSaldo = rawSaldoVal.toInt();

    return UserScore(
      id: doc.id,
      displayName: data['nama'] ?? data['name'] ?? data['email'] ?? 'User Tanpa Nama',
      email: data['email'] ?? '-',
      saldo: rawSaldo,
      avatarUrl: data['photoUrl'] ?? data['avatarUrl'],
    );
  }
}

// ================= HALAMAN LEADERBOARD =================
class LeaderboardPage extends StatelessWidget {
  final List<Map<String, dynamic>> transaksi;
  final int saldo;

  const LeaderboardPage({
    super.key,
    this.transaksi = const <Map<String, dynamic>>[],
    this.saldo = 0,
  });

  Widget _drawerItem(BuildContext context, {
    required IconData icon,
    required String title,
    required Widget page,
    required Color color
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: () {
        Navigator.pop(context); // Tutup drawer
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => page));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      
      // --- APP BAR ---
      appBar: AppBar(
        title: const Text('🏆 Top Sultan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)], // Gradasi Biru Neon
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
                    'assets/Sribuu_Smart.png',
                    height: 126,
                    width: 126,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => 
                        const Icon(Icons.emoji_events, size: 80, color: Colors.white),
                  ),
                  const SizedBox(height: 10),

                ],
              ),
            ),
            
            _drawerItem(context, icon: Icons.home, title: "Beranda", color: Colors.blue, page: HomePage(transaksi: transaksi, saldo: saldo)),
            _drawerItem(context, icon: Icons.show_chart, title: "Grafik Keuangan", color: Colors.green, page: GrafikPage(transaksi: transaksi, saldo: saldo)),
            _drawerItem(context, icon: Icons.lightbulb, title: "Tips Keuangan", color: Colors.orange, page: TipsKeuanganPage(transaksi: transaksi, saldo: saldo)),
            
            _drawerItem(
              context, 
              icon: Icons.savings, 
              title: "Goal Saving", 
              color: Colors.teal, 
              page: GoalPage(
                totalSaldo: saldo, 
                transaksi: transaksi,
                onGoalUpdate: (name, target, progress) {},
                currentGoalName: null,
                currentGoalTarget: null,
                currentGoalProgress: null,
              )
            ),
            
            _drawerItem(context, icon: Icons.table_chart, title: "Laporan Keuangan", color: Colors.indigo, page: LaporanKeuanganPage(transaksi: transaksi)),
            
            ListTile(
              leading: const Icon(Icons.leaderboard, color: Colors.red),
              title: const Text("Leaderboard"),
              tileColor: Colors.red.withOpacity(0.1),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),

      // ================= BODY: STREAM BUILDER =================
      // Ini bagian penting agar data Realtime
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('saldo', descending: true) // KUNCI: Urutkan berdasarkan saldo
            .limit(50) 
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  const Text("Belum ada data kompetitor.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // Konversi data
          final List<UserScore> leaderboards = snapshot.data!.docs
              .map((doc) => UserScore.fromFirestore(doc))
              .toList();

          // Cari data user yang login
          UserScore? myUserScore;
          int myRank = -1;
          try {
            final index = leaderboards.indexWhere((u) => u.id == currentUserUid);
            if (index != -1) {
              myUserScore = leaderboards[index];
              myRank = index + 1;
            }
          } catch (e) {
            // ignore
          }

          return Column(
            children: [
              // 1. KARTU USER SAYA (Top Section)
              if (myUserScore != null)
                Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))
                    ],
                    gradient: const LinearGradient(
                      colors: [Color(0xFF141E30), Color(0xFF243B55)], 
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.amber, width: 2),
                        ),
                        child: CircleAvatar(
                          backgroundColor: Colors.grey[800],
                          radius: 30,
                          backgroundImage: myUserScore.avatarUrl != null ? NetworkImage(myUserScore.avatarUrl!) : null,
                          child: myUserScore.avatarUrl == null 
                              ? const Icon(Icons.person, color: Colors.white, size: 30) 
                              : null,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Rank Anda Saat Ini", style: TextStyle(fontSize: 12, color: Colors.white70)),
                            const SizedBox(height: 4),
                            Text(
                              myUserScore.displayName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                myUserScore.rankTitle,
                                style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            )
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("#$myRank", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 28, color: Colors.white)),
                          Text(
                            "${NumberFormat.decimalPattern('id').format(myUserScore.points)} Poin",
                            style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // 2. LIST TOP RANK
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: leaderboards.length,
                  itemBuilder: (context, index) {
                    final user = leaderboards[index];
                    final rank = index + 1;
                    final isMe = user.id == currentUserUid;

                    // Logika Warna Kartu (Gold, Silver, Bronze)
                    Color? cardColor;
                    Color textColor = const Color(0xFF2D3436);
                    LinearGradient? gradient;
                    
                    if (rank == 1) {
                      gradient = const LinearGradient(colors: [Color(0xFFFFF200), Color(0xFFFFB302)]); // Gold
                      textColor = Colors.brown.shade900;
                    } else if (rank == 2) {
                      gradient = const LinearGradient(colors: [Color(0xFFE0E0E0), Color(0xFFBDBDBD)]); // Silver
                    } else if (rank == 3) {
                      gradient = const LinearGradient(colors: [Color(0xFFFFCCBC), Color(0xFFD7CCC8)]); // Bronze
                    } else {
                      cardColor = Colors.white;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: cardColor,
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: isMe ? Border.all(color: Colors.blueAccent, width: 2) : null,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        
                        // Icon Ranking
                        leading: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: rank <= 3 ? Colors.white.withOpacity(0.5) : Colors.transparent,
                              ),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                                child: user.avatarUrl == null 
                                    ? Text("$rank", style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 18)) 
                                    : null,
                              ),
                            ),
                            if (rank == 1) 
                              Transform.translate(
                                offset: const Offset(8, -8),
                                child: const Text("👑", style: TextStyle(fontSize: 20)), 
                              ),
                          ],
                        ),
                        
                        // Nama User
                        title: Text(
                          user.displayName,
                          style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  user.rankTitle, 
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.7)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Total Poin
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              NumberFormat.decimalPattern('id').format(user.points),
                              style: TextStyle(
                                fontWeight: FontWeight.w900, 
                                fontSize: 18, 
                                color: rank == 1 ? Colors.red.shade900 : const Color(0xFF0984E3)
                              ),
                            ),
                            Text("Poin", style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.7))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}