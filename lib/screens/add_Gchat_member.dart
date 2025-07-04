import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddMemberScreen extends StatefulWidget {
  final String conversationId;
  final List<String> existingParticipants;

  AddMemberScreen({
    required this.conversationId,
    required this.existingParticipants,
  });

  @override
  _AddMemberScreenState createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  List<Map<String, dynamic>> allUsers = [];
  List<Map<String, dynamic>> filteredUsers = [];
  Set<String> selectedUserIds = {};
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    fetchAllUsers();
  }

  Future<void> fetchAllUsers() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();

      final users = snapshot.docs.map((doc) {
        final data = doc.data();

        return {
          'uid': doc.id,
          'username': data['username'] ?? '',
          'profileImage': data.containsKey('profileImage') ? data['profileImage'] ?? '' : '',
        };
      }).where((user) =>
      !widget.existingParticipants.contains(user['uid']) &&
          (user['username'] ?? '').toString().isNotEmpty
      ).toList();

      setState(() {
        allUsers = users;
        filteredUsers = users;
      });

      print('Fetched users: ${users.map((u) => u['username']).toList()}');
    } catch (e) {
      print('Error fetching users: $e');
    }
  }


  void filterUsers(String query) {
    final lowerQuery = query.toLowerCase().trim();
    setState(() {
      searchQuery = query;
      filteredUsers = allUsers.where((user) {
        final username = (user['username'] ?? '').toLowerCase();
        return username.contains(lowerQuery);
      }).toList();
    });
  }

  Future<void> addSelectedMembers() async {
    if (selectedUserIds.isEmpty) return;

    final updatedParticipants = List<String>.from(widget.existingParticipants)
      ..addAll(selectedUserIds);

    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .update({'participants': updatedParticipants});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Members added successfully')),
    );

    Navigator.pop(context, true); // Return to GroupInfoScreen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Members'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: addSelectedMembers,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(10),
            child: TextField(
              onChanged: (value) {
                print("Searching: $value");
                filterUsers(value);
              },
              decoration: InputDecoration(
                hintText: 'Search users',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Expanded(
            child: filteredUsers.isEmpty
                ? Center(child: Text('No users found'))
                : ListView.builder(
              itemCount: filteredUsers.length,
              itemBuilder: (_, i) {
                final user = filteredUsers[i];
                final uid = user['uid'];
                final isSelected = selectedUserIds.contains(uid);

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user['profileImage'].isNotEmpty
                        ? NetworkImage(user['profileImage'])
                        : null,
                    child: user['profileImage'].isEmpty ? Icon(Icons.person) : null,
                  ),
                  title: Text(user['username']),
                  trailing: Checkbox(
                    value: isSelected,
                    onChanged: (_) {
                      setState(() {
                        if (isSelected) {
                          selectedUserIds.remove(uid);
                        } else {
                          selectedUserIds.add(uid);
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
