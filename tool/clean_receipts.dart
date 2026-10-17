import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Standalone CLI tool to purge rejected receipts and clean old screenshots
/// via the official Supabase Storage REST API.
void main(List<String> args) async {
  print('====================================================');
  print(' MatricMate Admin - Receipt Storage Cleanup CLI Tool');
  print('====================================================\n');

  // Load .env
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    print('Error: .env file not found.');
    exit(1);
  }

  final env = <String, String>{};
  for (final line in envFile.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final idx = trimmed.indexOf('=');
    if (idx != -1) {
      env[trimmed.substring(0, idx).trim()] = trimmed.substring(idx + 1).trim();
    }
  }

  final supabaseUrl = env['SUPABASE_URL'] ?? '';
  final apiKey = env['SUPABASE_API_KEY'] ?? '';
  final adminEmail = env['MOCK_ADMIN_EMAIL'] ?? '';
  final adminPassword = env['MOCK_ADMIN_PASSWORD'] ?? '';

  if (supabaseUrl.isEmpty || apiKey.isEmpty) {
    print('Error: SUPABASE_URL or SUPABASE_API_KEY is missing in .env');
    exit(1);
  }

  print('Authenticating as admin ($adminEmail)...');
  final authRes = await http.post(
    Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password'),
    headers: {
      'apikey': apiKey,
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'email': adminEmail,
      'password': adminPassword,
    }),
  );

  if (authRes.statusCode != 200) {
    print('Failed to authenticate: ${authRes.statusCode} - ${authRes.body}');
    exit(1);
  }

  final authData = jsonDecode(authRes.body) as Map<String, dynamic>;
  final accessToken = authData['access_token'] as String;
  print('Authenticated successfully.\n');

  final headers = {
    'apikey': apiKey,
    'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
  };

  // 1. Fetch rejected receipts
  print('Checking for rejected receipts in database...');
  final rejectedRes = await http.get(
    Uri.parse('$supabaseUrl/rest/v1/payment_receipts?status=eq.rejected&select=id,receipt_path'),
    headers: headers,
  );

  if (rejectedRes.statusCode == 200) {
    final rejectedList = jsonDecode(rejectedRes.body) as List<dynamic>;
    print('Found ${rejectedList.length} rejected receipt(s).');

    if (rejectedList.isNotEmpty) {
      final pathsToDelete = <String>[];
      for (final item in rejectedList) {
        final path = item['receipt_path']?.toString();
        if (path != null && path.isNotEmpty) {
          pathsToDelete.add(path);
        }
      }

      if (pathsToDelete.isNotEmpty) {
        print('Deleting ${pathsToDelete.length} screenshot(s) from Supabase Storage bucket "receipts"...');
        final storageRes = await http.delete(
          Uri.parse('$supabaseUrl/storage/v1/object/receipts'),
          headers: headers,
          body: jsonEncode({'prefixes': pathsToDelete}),
        );
        print('Storage delete status: ${storageRes.statusCode}');
      }

      print('Deleting ${rejectedList.length} rejected receipt row(s) from database...');
      final dbDelRes = await http.delete(
        Uri.parse('$supabaseUrl/rest/v1/payment_receipts?status=eq.rejected'),
        headers: headers,
      );
      print('Database delete status: ${dbDelRes.statusCode}');
      print('Rejected receipts purged successfully!\n');
    }
  } else {
    print('Error querying rejected receipts: ${rejectedRes.body}');
  }

  // 2. Fetch active receipts older than 7 days
  final oneWeekAgo = DateTime.now().toUtc().subtract(const Duration(days: 7)).toIso8601String();
  print('Checking for active receipts older than 7 days (before $oneWeekAgo)...');

  final activeOldRes = await http.get(
    Uri.parse('$supabaseUrl/rest/v1/payment_receipts?status=eq.approved&receipt_path=not.is.null&created_at=lt.$oneWeekAgo&select=id,receipt_path'),
    headers: headers,
  );

  if (activeOldRes.statusCode == 200) {
    final activeOldList = jsonDecode(activeOldRes.body) as List<dynamic>;
    print('Found ${activeOldList.length} active screenshot(s) older than 7 days.');

    if (activeOldList.isNotEmpty) {
      final oldPaths = <String>[];
      for (final item in activeOldList) {
        final path = item['receipt_path']?.toString();
        if (path != null && path.isNotEmpty) {
          oldPaths.add(path);
        }
      }

      if (oldPaths.isNotEmpty) {
        print('Deleting ${oldPaths.length} old screenshot(s) from storage...');
        final delStorageRes = await http.delete(
          Uri.parse('$supabaseUrl/storage/v1/object/receipts'),
          headers: headers,
          body: jsonEncode({'prefixes': oldPaths}),
        );
        print('Storage delete status: ${delStorageRes.statusCode}');
      }

      print('Clearing receipt_path and receipt_url on ${activeOldList.length} approved row(s)...');
      final updateDbRes = await http.patch(
        Uri.parse('$supabaseUrl/rest/v1/payment_receipts?status=eq.approved&receipt_path=not.is.null&created_at=lt.$oneWeekAgo'),
        headers: {
          ...headers,
          'Prefer': 'return=minimal',
        },
        body: jsonEncode({
          'receipt_path': null,
          'receipt_url': null,
        }),
      );
      print('Database update status: ${updateDbRes.statusCode}');
      print('Old active screenshots cleaned successfully!\n');
    }
  } else {
    print('Error querying active receipts: ${activeOldRes.body}');
  }

  print('====================================================');
  print(' Cleanup Finished!');
  print('====================================================');
}
