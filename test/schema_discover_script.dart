import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

void main() async {
  dotenv.testLoad(fileInput: File('.env').readAsStringSync());
  final client = SupabaseClient(
      dotenv.env['SUPABASE_URL']!, dotenv.env['SUPABASE_ANON_KEY']!);

  final buf = StringBuffer();
  Future<void> fetchRow(String table) async {
    try {
      final res = await client.from(table).select().limit(1);
      buf.writeln('=== $table ===');
      if ((res as List).isNotEmpty) {
        buf.writeln((res).first.keys.toList());
        buf.writeln((res).first);
      } else {
        buf.writeln('Empty but exists');
      }
    } catch (e) {
      buf.writeln('=== $table ===');
      buf.writeln('ERROR: $e');
    }
  }

  await fetchRow('tags');
  await fetchRow('track_tags');
  await fetchRow('album_tags');

  File('schema_output.txt').writeAsStringSync(buf.toString());
}
