import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class InviteFriendsScreen extends StatefulWidget {
  final String groupId;

  const InviteFriendsScreen({Key? key, required this.groupId}) : super(key: key);

  @override
  _InviteFriendsScreenState createState() => _InviteFriendsScreenState();
}

class _InviteFriendsScreenState extends State<InviteFriendsScreen> {
  final currentUser = FirebaseAuth.instance.currentUser!;
  List<DocumentSnapshot> allFriends = [];
  List<String> alreadyInGroup = [];
  List<String> selected = [];
  bool isLoading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    fetchFriendsAndParticipants();
  }

  Future<void> fetchFriendsAndParticipants() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    final friends = List<String>.from(userDoc.data()?['friends'] ?? []);

    final groupDoc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .get();

    alreadyInGroup = List<String>.from(groupDoc.data()?['participants'] ?? []);

    final friendsDocs = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: friends)
        .get();

    allFriends = friendsDocs.docs;
    setState(() => isLoading = false);
  }

  void toggleSelection(String uid) {
    setState(() {
      if (selected.contains(uid)) {
        selected.remove(uid);
      } else {
        selected.add(uid);
      }
    });
  }

  Future<void> inviteSelectedFriends() async {
    if (selected.isEmpty) return;

    final groupRef = FirebaseFirestore.instance.collection('groups').doc(widget.groupId);
    final groupDoc = await groupRef.get();
    final groupName = groupDoc.data()?['name'] ?? 'a group';


    for (String userId in selected) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'type': 'group_invite',
        'senderId': currentUser.uid,
        'groupId': widget.groupId,
        'message': 'You have been invited to join the group "$groupName"',
        'timestamp': FieldValue.serverTimestamp(),
        'seen': false,
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Friends invited successfully')),
    );

    Navigator.pop(context);
  }


  @override
  Widget build(BuildContext context) {
    final filteredFriends = allFriends.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final username = data['username']?.toString().toLowerCase() ?? '';
      return username.contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Invite Friends'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: TextField(
              onChanged: (val) => setState(() => searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search friends...',
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : filteredFriends.isEmpty
          ? Center(child: Text('No matching friends found'))
          : ListView.builder(
        itemCount: filteredFriends.length,
        itemBuilder: (context, index) {
          final user = filteredFriends[index].data() as Map<String, dynamic>;
          final uid = filteredFriends[index].id;
          final username = user['username'] ?? 'Unknown';
          final profileUrl = user['profileImage'] ?? '';

          final alreadyInvited = alreadyInGroup.contains(uid);

          return ListTile(
            leading: CircleAvatar(
              backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
              child: profileUrl.isEmpty ? Icon(Icons.person) : null,
            ),
            title: Text(username),
            subtitle: alreadyInvited
                ? Text('Already in group', style: TextStyle(color: Colors.grey))
                : null,
            trailing: alreadyInvited
                ? null
                : Checkbox(
              value: selected.contains(uid),
              onChanged: (_) => toggleSelection(uid),
            ),
            enabled: !alreadyInvited,
          );
        },
      ),
      floatingActionButton: selected.isNotEmpty
          ? FloatingActionButton.extended(
        onPressed: inviteSelectedFriends,
        icon: Icon(Icons.person_add),
        label: Text('Add (${selected.length})'),
      )
          : null,
    );
  }
}
