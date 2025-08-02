import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailsScreen({super.key, required this.groupId});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  Map<String, dynamic>? groupData;
  List<Map<String, dynamic>> memberDataList = [];
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid;
    fetchGroupDetails();
  }

  Future<void> fetchGroupDetails() async {
    final groupDoc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .get();

    if (groupDoc.exists) {
      final data = groupDoc.data();
      setState(() {
        groupData = data;
      });

      final List<dynamic> participantIds = data?['participantIds'] ?? [];

      // Fetch user data of all members
      final memberSnapshots = await Future.wait(participantIds.map((uid) {
        return FirebaseFirestore.instance.collection('users').doc(uid).get();
      }));

      final members = memberSnapshots
          .where((doc) => doc.exists)
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      setState(() {
        memberDataList = members;
      });
    }
  }

  Future<void> deleteGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Group"),
        content: const Text("Are you sure you want to delete this group?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .delete();

      if (mounted) {
        Navigator.pop(context); // Go back after deleting
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Group deleted successfully")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (groupData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isAdmin = currentUserId == groupData!['adminId'];

    return Scaffold(
      appBar: AppBar(
        title: Text(groupData!['groupName'] ?? 'Group Details'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: deleteGroup,
            ),
        ],
      ),
      body: ListView.builder(
        itemCount: memberDataList.length,
        itemBuilder: (context, index) {
          final member = memberDataList[index];
          return ListTile(
            leading: const Icon(Icons.person),
            title: Text(member['name'] ?? 'No name'),
            subtitle: Text(member['email'] ?? ''),
          );
        },
      ),
    );
  }
}
