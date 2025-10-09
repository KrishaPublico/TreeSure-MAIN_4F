import 'package:flutter/material.dart';

class NotifPage extends StatefulWidget {
  const NotifPage({super.key});

  @override
  State<NotifPage> createState() => _NotifPageState();
}

class _NotifPageState extends State<NotifPage> {
  // Example notifications data
  final List<Map<String, String>> notifications = [
      {
      "title": "Tree Tagging Update",
      "message": "Your tree tagging has been approved.",
      "time": "11:00 AM",
    },
    {
      "title": "Applicant Requirements",
      "message": "Please complete your pending requirements.",
      "time": "10:30 AM",
    },
  
    {
      "title": "System Notice",
      "message": "Maintenance scheduled at 5:00 PM.",
      "time": "03:30 PM",
    },
  ];

  void _handleNotificationTap(String title) {
    // If the notification is "Applicant Requirements", do nothing
    if (title == "Applicant Requirements") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This notification doesn’t open any page."),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Otherwise, navigate to a sample page or show info
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationDetailPage(title: title),
      ),
    );
  }

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
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notif = notifications[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.green,
                      child:
                          Icon(Icons.notifications_active, color: Colors.white),
                    ),
                    title: Text(notif["title"]!),
                    subtitle: Text(notif["message"]!),
                    trailing: Text(notif["time"]!),
                    onTap: () => _handleNotificationTap(notif["title"]!),
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

class NotificationDetailPage extends StatelessWidget {
  final String title;
  const NotificationDetailPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Text(
          'This is the detail page for "$title"',
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
