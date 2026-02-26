import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class MlServerClient {
  MlServerClient({this.baseUrl = 'http://127.0.0.1:8000'});

  final String baseUrl;

  Future<Map<String, dynamic>> status() async {
    final res = await http.get(Uri.parse('$baseUrl/status'));
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> train() async {
    final res = await http.post(Uri.parse('$baseUrl/train'));
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> extractLandmarks(File imageFile) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/landmarks'));
    req.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    _ensureOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final count = body['landmark_count'];
    if (count != 468) {
      throw Exception('Landmark count invalid: expected 468 got $count');
    }
    return body;
  }

  Future<Map<String, dynamic>> analyzeSession({
    required List<List<double>> neutral,
    required List<List<double>> smile,
    required List<List<double>> anger,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/analyze_session'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'neutral': neutral, 'smile': smile, 'anger': anger}),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  void _ensureOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Server error ${res.statusCode}: ${res.body}');
    }
  }
}
