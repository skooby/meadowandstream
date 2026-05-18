import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

void main() async {
  dotenv.testLoad(fileInput: File('.env').readAsStringSync());
  final client = SupabaseClient(
      dotenv.env['SUPABASE_URL']!, dotenv.env['SUPABASE_ANON_KEY']!);

  final buf = StringBuffer();
  Future<void> fetchSchema(String table) async {
    try {
      final res =
          await client.rpc('get_columns', params: {'table_name': table});
      buf.writeln('=== $table ===');
      buf.writeln(res);
    } catch (e) {
      // Fallback to trying to query 0 limit using raw postgrest
      try {
        final res = await client.from(table).select().limit(0);
        buf.writeln('=== $table Columns ===');
        buf.writeln('Failed to get keys because empty list returns nothing.');
        // Insert a row and roll back? Cannot easily do that.
        // Let's just catch the error and do nothing.
      } catch (e) {}
    }
  }

  // Use postgrest to query 1 row, but we already saw it was empty.
  // Maybe we can insert a fake row or just guess the schema.

  File('schema_output2.txt').writeAsStringSync(buf.toString());
}
