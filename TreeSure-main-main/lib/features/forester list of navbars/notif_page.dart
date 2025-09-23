import 'package:flutter/material.dart';
import 'package:treesure_app/features/forester/applicant_detail_page.dart';
class NotifPage_Forester extends StatefulWidget {
  const NotifPage_Forester({super.key});

  @override
  State<NotifPage_Forester> createState() => _NotifPageState();
}

class _NotifPageState extends State<NotifPage_Forester> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Notifications",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(width: 5),
            Icon(Icons.notifications, color: Colors.green, size: 24),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            // Search Bar
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: "Search",
                  border: InputBorder.none,
                  icon: Icon(Icons.search),
                ),
              ),
            ),
            // Notifications List
            Expanded(
              child: ListView.builder(
                itemCount: 5, // Adjust the count as needed
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.notifications_active, color: Colors.white),
                    ),
                    title: const Text("Notification Title"),
                    subtitle: const Text("Applicant's requirement details here"),
                    trailing: const Text("12:00 PM"),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ApplicantDetailPage(
                            applicantName: "Applicant",
                            requirementDetails: "Details about the applicant's requirements.",
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
