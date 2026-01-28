import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/team.dart';
import 'user_preferences.dart';

/// Service for managing teams via Firebase Realtime Database REST API
class TeamService {
  static const String _databaseUrl = 'https://allin-d0e2d-default-rtdb.firebaseio.com';
  static const int createTeamCost = 1000000; // 1 million chips
  static const int joinTeamCost = 1000; // 1 thousand chips

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Get current user display name
  String get currentUserName {
    final user = _auth.currentUser;
    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        return user.displayName!;
      }
      if (user.email != null && user.email!.isNotEmpty) {
        return user.email!.split('@').first;
      }
      return 'Player${user.uid.substring(0, 4).toUpperCase()}';
    }
    return UserPreferences.username;
  }

  /// Get auth token for authenticated requests
  Future<String?> _getAuthToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  // ============================================================================
  // TEAM CRUD OPERATIONS
  // ============================================================================

  /// Create a new team (costs 1,000,000 chips)
  Future<Team> createTeam({
    required String name,
    String description = '',
    int emblemIndex = 0,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Must be logged in to create a team');

    // Check if user has enough chips
    final currentChips = UserPreferences.chips;
    if (currentChips < createTeamCost) {
      throw Exception(
          'Need ${_formatChips(createTeamCost)} chips to create a team (you have ${_formatChips(currentChips)})');
    }

    // Check if user is already in a team
    final existingTeam = await getUserTeam();
    if (existingTeam != null) {
      throw Exception('You must leave your current team before creating a new one');
    }

    // Validate team name
    if (name.trim().isEmpty) throw Exception('Team name cannot be empty');
    if (name.length > 20) throw Exception('Team name must be 20 characters or less');

    // Check if team name is taken
    final nameTaken = await isTeamNameTaken(name.trim());
    if (nameTaken) throw Exception('Team name is already taken');

    final token = await _getAuthToken();
    final teamId = _generateTeamId();

    final captain = TeamMember(
      odeid: userId,
      displayName: currentUserName,
      rank: 'captain',
      joinedAt: DateTime.now(),
    );

    final team = Team(
      id: teamId,
      name: name.trim(),
      description: description.trim(),
      emblemIndex: emblemIndex,
      captainId: userId,
      members: [captain],
      createdAt: DateTime.now(),
    );

    final response = await http.put(
      Uri.parse('$_databaseUrl/teams/$teamId.json?auth=$token'),
      body: jsonEncode(team.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create team: ${response.body}');
    }

    // Deduct chips
    await UserPreferences.spendChips(createTeamCost);

    // Save team ID to user's profile
    await _saveUserTeamId(teamId);

    return team;
  }

  /// Join an existing team (costs 1,000 chips)
  Future<void> joinTeam(String teamId) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Must be logged in to join a team');

    // Check if user has enough chips
    final currentChips = UserPreferences.chips;
    if (currentChips < joinTeamCost) {
      throw Exception(
          'Need ${_formatChips(joinTeamCost)} chips to join a team (you have ${_formatChips(currentChips)})');
    }

    // Check if user is already in a team
    final existingTeam = await getUserTeam();
    if (existingTeam != null) {
      throw Exception('You must leave your current team first');
    }

    final token = await _getAuthToken();
    final team = await getTeam(teamId);
    if (team == null) throw Exception('Team not found');
    if (team.isFull) throw Exception('Team is full');
    if (team.isMember(userId)) throw Exception('You are already in this team');

    final newMember = TeamMember(
      odeid: userId,
      displayName: currentUserName,
      rank: 'member',
      joinedAt: DateTime.now(),
    );

    final updatedMembers = [...team.members, newMember];

    await http.patch(
      Uri.parse('$_databaseUrl/teams/$teamId.json?auth=$token'),
      body: jsonEncode({'members': updatedMembers.map((m) => m.toJson()).toList()}),
    );

    // Deduct chips
    await UserPreferences.spendChips(joinTeamCost);

    // Save team ID to user's profile
    await _saveUserTeamId(teamId);
  }

  /// Leave a team
  Future<void> leaveTeam(String teamId) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Must be logged in');

    final token = await _getAuthToken();
    final team = await getTeam(teamId);
    if (team == null) throw Exception('Team not found');
    if (!team.isMember(userId)) throw Exception('You are not in this team');

    // Captain cannot leave - must transfer or disband
    if (team.isCaptain(userId)) {
      if (team.members.length > 1) {
        throw Exception('Captain must transfer leadership before leaving');
      } else {
        // Last member, delete team
        await http.delete(Uri.parse('$_databaseUrl/teams/$teamId.json?auth=$token'));
        await _clearUserTeamId();
        return;
      }
    }

    final updatedMembers = team.members.where((m) => m.odeid != userId).toList();

    await http.patch(
      Uri.parse('$_databaseUrl/teams/$teamId.json?auth=$token'),
      body: jsonEncode({'members': updatedMembers.map((m) => m.toJson()).toList()}),
    );

    await _clearUserTeamId();
  }

  /// Get a team by ID
  Future<Team?> getTeam(String teamId) async {
    final token = await _getAuthToken();

    final response = await http.get(Uri.parse('$_databaseUrl/teams/$teamId.json?auth=$token'));

    if (response.statusCode != 200 || response.body == 'null') {
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return Team.fromJson(data, teamId);
  }

  /// Get current user's team
  Future<Team?> getUserTeam() async {
    final teamId = await _getUserTeamId();
    if (teamId == null) return null;
    return getTeam(teamId);
  }

  /// Check if team name is taken
  Future<bool> isTeamNameTaken(String name) async {
    final teams = await searchTeams(name);
    return teams.any((t) => t.name.toLowerCase() == name.toLowerCase());
  }

  /// Search for teams by name
  Future<List<Team>> searchTeams(String query) async {
    final token = await _getAuthToken();

    final response = await http.get(Uri.parse('$_databaseUrl/teams.json?auth=$token'));

    if (response.statusCode != 200 || response.body == 'null') {
      return [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final teams = data.entries
        .map((e) => Team.fromJson(Map<String, dynamic>.from(e.value as Map), e.key))
        .where((t) => t.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    teams.sort((a, b) => b.memberCount.compareTo(a.memberCount));
    return teams;
  }

  /// Get all teams (for browsing)
  Future<List<Team>> getAllTeams() async {
    final token = await _getAuthToken();

    final response = await http.get(Uri.parse('$_databaseUrl/teams.json?auth=$token'));

    if (response.statusCode != 200 || response.body == 'null') {
      return [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final teams = data.entries.map((e) => Team.fromJson(Map<String, dynamic>.from(e.value as Map), e.key)).toList();

    teams.sort((a, b) => b.memberCount.compareTo(a.memberCount));
    return teams;
  }

  /// Stream team updates (polling-based)
  Stream<Team?> watchTeam(String teamId) {
    return Stream.periodic(const Duration(seconds: 2)).asyncMap((_) => getTeam(teamId));
  }

  // ============================================================================
  // TEAM MANAGEMENT (Captain/Officer only)
  // ============================================================================

  /// Update team description
  Future<void> updateDescription(String teamId, String description) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Must be logged in');

    final team = await getTeam(teamId);
    if (team == null) throw Exception('Team not found');
    if (!team.isOfficer(userId)) throw Exception('Only officers and captain can update description');

    if (description.length > 200) throw Exception('Description must be 200 characters or less');

    final token = await _getAuthToken();
    await http.patch(
      Uri.parse('$_databaseUrl/teams/$teamId.json?auth=$token'),
      body: jsonEncode({'description': description.trim()}),
    );
  }

  /// Update team emblem
  Future<void> updateEmblem(String teamId, int emblemIndex) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Must be logged in');

    final team = await getTeam(teamId);
    if (team == null) throw Exception('Team not found');
    if (!team.isOfficer(userId)) throw Exception('Only officers and captain can update emblem');

    final token = await _getAuthToken();
    await http.patch(
      Uri.parse('$_databaseUrl/teams/$teamId.json?auth=$token'),
      body: jsonEncode({'emblemIndex': emblemIndex}),
    );
  }

  /// Promote member to officer (Captain only)
  Future<void> promoteMember(String teamId, String memberuid) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Must be logged in');

    final team = await getTeam(teamId);
    if (team == null) throw Exception('Team not found');
    if (!team.isCaptain(userId)) throw Exception('Only captain can promote members');

    final memberIndex = team.members.indexWhere((m) => m.odeid == memberuid);
    if (memberIndex == -1) throw Exception('Member not found');
    if (team.members[memberIndex].rank != 'member') throw Exception('Member is already an officer');

    final updatedMembers = List<TeamMember>.from(team.members);
    updatedMembers[memberIndex] = updatedMembers[memberIndex].copyWith(rank: 'officer');

    final token = await _getAuthToken();
    await http.patch(
      Uri.parse('$_databaseUrl/teams/$teamId.json?auth=$token'),
      body: jsonEncode({'members': updatedMembers.map((m) => m.toJson()).toList()}),
    );
  }

  /// Demote officer to member (Captain only)
  Future<void> demoteMember(String teamId, String memberuid) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Must be logged in');

    final team = await getTeam(teamId);
    if (team == null) throw Exception('Team not found');
    if (!team.isCaptain(userId)) throw Exception('Only captain can demote members');

    final memberIndex = team.members.indexWhere((m) => m.odeid == memberuid);
    if (memberIndex == -1) throw Exception('Member not found');
    if (team.members[memberIndex].rank != 'officer') throw Exception('Member is not an officer');

    final updatedMembers = List<TeamMember>.from(team.members);
    updatedMembers[memberIndex] = updatedMembers[memberIndex].copyWith(rank: 'member');

    final token = await _getAuthToken();
    await http.patch(
      Uri.parse('$_databaseUrl/teams/$teamId.json?auth=$token'),
      body: jsonEncode({'members': updatedMembers.map((m) => m.toJson()).toList()}),
    );
  }

  /// Kick a member (Captain/Officer only, cannot kick officers unless captain)
  Future<void> kickMember(String teamId, String memberuid) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Must be logged in');

    final team = await getTeam(teamId);
    if (team == null) throw Exception('Team not found');
    if (!team.isOfficer(userId)) throw Exception('Only officers and captain can kick members');

    final member =
        team.members.firstWhere((m) => m.odeid == memberuid, orElse: () => throw Exception('Member not found'));

    // Cannot kick captain
    if (member.rank == 'captain') throw Exception('Cannot kick the captain');

    // Officers can only kick members, not other officers
    if (member.rank == 'officer' && !team.isCaptain(userId)) {
      throw Exception('Only captain can kick officers');
    }

    final updatedMembers = team.members.where((m) => m.odeid != memberuid).toList();

    final token = await _getAuthToken();
    await http.patch(
      Uri.parse('$_databaseUrl/teams/$teamId.json?auth=$token'),
      body: jsonEncode({'members': updatedMembers.map((m) => m.toJson()).toList()}),
    );

    // Clear kicked user's team ID
    await http.delete(Uri.parse('$_databaseUrl/user_teams/$memberuid.json?auth=$token'));
  }

  /// Transfer captaincy (Captain only)
  Future<void> transferCaptaincy(String teamId, String newCaptainuid) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Must be logged in');

    final team = await getTeam(teamId);
    if (team == null) throw Exception('Team not found');
    if (!team.isCaptain(userId)) throw Exception('Only captain can transfer leadership');

    final newCaptainIndex = team.members.indexWhere((m) => m.odeid == newCaptainuid);
    if (newCaptainIndex == -1) throw Exception('Member not found');

    final updatedMembers = team.members.map((m) {
      if (m.odeid == userId) {
        return m.copyWith(rank: 'officer'); // Old captain becomes officer
      } else if (m.odeid == newCaptainuid) {
        return m.copyWith(rank: 'captain');
      }
      return m;
    }).toList();

    final token = await _getAuthToken();
    await http.patch(
      Uri.parse('$_databaseUrl/teams/$teamId.json?auth=$token'),
      body: jsonEncode({
        'captainId': newCaptainuid,
        'members': updatedMembers.map((m) => m.toJson()).toList(),
      }),
    );
  }

  // ============================================================================
  // TEAM CHAT
  // ============================================================================

  /// Send a chat message
  Future<void> sendChatMessage(String teamId, String message) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Must be logged in');

    if (message.trim().isEmpty) return;
    if (message.length > 500) throw Exception('Message too long');

    final team = await getTeam(teamId);
    if (team == null) throw Exception('Team not found');
    if (!team.isMember(userId)) throw Exception('You are not in this team');

    final token = await _getAuthToken();
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();

    final chatMessage = TeamChatMessage(
      id: messageId,
      senderuid: userId,
      senderName: currentUserName,
      message: message.trim(),
      timestamp: DateTime.now(),
    );

    await http.put(
      Uri.parse('$_databaseUrl/team_chats/$teamId/$messageId.json?auth=$token'),
      body: jsonEncode(chatMessage.toJson()),
    );
  }

  /// Get chat messages (last 100)
  Future<List<TeamChatMessage>> getChatMessages(String teamId) async {
    final token = await _getAuthToken();

    final response = await http.get(
      Uri.parse('$_databaseUrl/team_chats/$teamId.json?auth=$token&orderBy="\$key"&limitToLast=100'),
    );

    if (response.statusCode != 200 || response.body == 'null') {
      return [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final messages =
        data.entries.map((e) => TeamChatMessage.fromJson(Map<String, dynamic>.from(e.value as Map))).toList();

    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }

  /// Stream chat messages (polling-based)
  Stream<List<TeamChatMessage>> watchChatMessages(String teamId) {
    return Stream.periodic(const Duration(seconds: 2)).asyncMap((_) => getChatMessages(teamId));
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  String _generateTeamId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String _formatChips(int amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toString();
  }

  Future<void> _saveUserTeamId(String teamId) async {
    final userId = currentUserId;
    if (userId == null) return;

    final token = await _getAuthToken();
    await http.put(
      Uri.parse('$_databaseUrl/user_teams/$userId.json?auth=$token'),
      body: jsonEncode({'teamId': teamId}),
    );
  }

  Future<void> _clearUserTeamId() async {
    final userId = currentUserId;
    if (userId == null) return;

    final token = await _getAuthToken();
    await http.delete(Uri.parse('$_databaseUrl/user_teams/$userId.json?auth=$token'));
  }

  Future<String?> _getUserTeamId() async {
    final userId = currentUserId;
    if (userId == null) return null;

    final token = await _getAuthToken();
    final response = await http.get(Uri.parse('$_databaseUrl/user_teams/$userId.json?auth=$token'));

    if (response.statusCode != 200 || response.body == 'null') {
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['teamId'] as String?;
  }
}
