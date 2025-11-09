import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ForesterSummaryReports extends StatelessWidget {
  const ForesterSummaryReports({super.key});

  @override

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[800],
        title: const Text(
          "Summary Reports",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.normal,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance.collection('tree_inventory').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No tree data found.",
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          // Group by forester
          Map<String, List<QueryDocumentSnapshot>> summary = {};
          for (var doc in docs) {
            String forester = doc.get('forester') ?? 'Unknown';
            if (!summary.containsKey(forester)) summary[forester] = [];
            summary[forester]!.add(doc);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: summary.entries.map((entry) {
              String forester = entry.key;
              List<QueryDocumentSnapshot> trees = entry.value;

              // Aggregate stats
              double totalVolume =
                  trees.fold(0.0, (sum, t) => sum + (t.get('volume') ?? 0.0));
              int totalTrees = trees.length;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                child: ExpansionTile(
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(
                    forester,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                      "$totalTrees Trees | Total Volume: ${totalVolume.toStringAsFixed(2)} CU m"),
                  children: trees.map((t) {
                    return ListTile(
                      leading: const Icon(Icons.park, color: Colors.green),
                      title: Text("${t.get('tree_no')} - ${t.get('specie')}"),
                      subtitle: Text(
                          "Diameter: ${t.get('diameter')} cm | Height: ${t.get('height')} m | Volume: ${t.get('volume')} CU m"),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
