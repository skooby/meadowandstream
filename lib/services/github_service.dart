import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'version_control_service.dart';

class GithubService {
  static final GithubService instance = GithubService._internal();

  GithubService._internal();

  Future<Map<String, String>> getRequestHeaders({String? acceptOverride}) async {
    final token = await VersionControlService.instance.getGithubToken();
    final headers = {
      'Accept': acceptOverride ?? 'application/vnd.github.v3+json',
      'User-Agent': 'Antigravity-Visual-Editor',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'token $token';
    }
    return headers;
  }

  Future<String?> getRemoteUrl() async {
    final path = await VersionControlService.instance.getLocalRepositoryPath();
    if (path == null || path.isEmpty) return null;
    final result = await Process.run('git', ['remote', 'get-url', 'origin'], workingDirectory: path, runInShell: true);
    if (result.exitCode == 0) {
      return result.stdout.toString().trim();
    }
    return null;
  }

  Map<String, String>? parseGithubUrl(String url) {
    String cleanUrl = url.trim();
    if (cleanUrl.endsWith('.git')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 4);
    }
    
    // Handle SSH format: git@github.com:owner/repo
    if (cleanUrl.contains('git@github.com:')) {
      final index = cleanUrl.indexOf('git@github.com:');
      final parts = cleanUrl.substring(index + 15).split('/');
      if (parts.length >= 2) {
        return {
          'owner': parts[0],
          'repo': parts[1],
        };
      }
    }
    
    // Try parsing as standard URI (handles http, https, tokens, credentials)
    try {
      final uri = Uri.parse(cleanUrl);
      if (uri.host == 'github.com' || uri.host.endsWith('.github.com')) {
        final pathSegments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (pathSegments.length >= 2) {
          return {
            'owner': pathSegments[0],
            'repo': pathSegments[1],
          };
        }
      }
    } catch (_) {
      // Fallback if Uri.parse fails
    }

    // Fallback substring matching for safety (e.g. cleanUrl might contain github.com/owner/repo)
    if (cleanUrl.contains('github.com/')) {
      final index = cleanUrl.indexOf('github.com/');
      final parts = cleanUrl.substring(index + 11).split('/');
      if (parts.length >= 2) {
        return {
          'owner': parts[0],
          'repo': parts[1],
        };
      }
    }
    
    return null;
  }

  /// Fetches the commit history of a specific file from GitHub API.
  /// Returns a list of maps containing: sha, date, author, message.
  Future<List<Map<String, String>>> fetchCommits(String filePath) async {
    final remoteUrl = await getRemoteUrl();
    if (remoteUrl == null) throw Exception('No remote URL configured.');

    final parsed = parseGithubUrl(remoteUrl);
    if (parsed == null) throw Exception('Failed to parse owner and repo from remote URL: $remoteUrl');

    final owner = parsed['owner']!;
    final repo = parsed['repo']!;
    
    final apiUrl = Uri.parse('https://api.github.com/repos/$owner/$repo/commits?path=$filePath');
    final headers = await getRequestHeaders();

    final response = await http.get(apiUrl, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch commits from GitHub API: ${response.statusCode} - ${response.body}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((item) {
      final commit = item['commit'] ?? {};
      final authorObj = commit['author'] ?? {};
      return {
        'sha': (item['sha'] ?? '').toString(),
        'hash': (item['sha'] ?? '').toString(),
        'date': (authorObj['date'] ?? '').toString(),
        'author': (authorObj['name'] ?? '').toString(),
        'message': (commit['message'] ?? '').toString(),
      };
    }).toList();
  }

  /// Fetches the commit history of the repository/branch from GitHub API.
  Future<List<Map<String, String>>> fetchRepositoryCommits(String branch) async {
    final remoteUrl = await getRemoteUrl();
    if (remoteUrl == null) throw Exception('No remote URL configured.');

    final parsed = parseGithubUrl(remoteUrl);
    if (parsed == null) throw Exception('Failed to parse owner and repo from remote URL: $remoteUrl');

    final owner = parsed['owner']!;
    final repo = parsed['repo']!;
    
    final apiUrl = Uri.parse('https://api.github.com/repos/$owner/$repo/commits?sha=$branch');
    final headers = await getRequestHeaders();

    final response = await http.get(apiUrl, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch commits from GitHub API: ${response.statusCode} - ${response.body}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((item) {
      final commit = item['commit'] ?? {};
      final authorObj = commit['author'] ?? {};
      return {
        'sha': (item['sha'] ?? '').toString(),
        'hash': (item['sha'] ?? '').toString(),
        'date': (authorObj['date'] ?? '').toString(),
        'author': (authorObj['name'] ?? '').toString(),
        'message': (commit['message'] ?? '').toString(),
      };
    }).toList();
  }

  /// Pulls the raw text of the file at the specified commit SHA.
  Future<String> fetchFileContent(String filePath, String commitSha) async {
    final remoteUrl = await getRemoteUrl();
    if (remoteUrl == null) throw Exception('No remote URL configured.');

    final parsed = parseGithubUrl(remoteUrl);
    if (parsed == null) throw Exception('Failed to parse owner and repo from remote URL: $remoteUrl');

    final owner = parsed['owner']!;
    final repo = parsed['repo']!;
    
    final apiUrl = Uri.parse('https://api.github.com/repos/$owner/$repo/contents/$filePath?ref=$commitSha');
    final headers = await getRequestHeaders(acceptOverride: 'application/vnd.github.v3.raw');

    final response = await http.get(apiUrl, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch file content from GitHub API: ${response.statusCode} - ${response.body}');
    }

    return response.body;
  }
}
