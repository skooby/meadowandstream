import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/widgets.dart';

void main() {
  test('List buckets', () async {
    WidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(
        url: 'https://lswberciytrkxjftryei.supabase.co',
        anonKey: 'sb_publishable__oj8jDk8aa8fs9q7UGFkLg_1px6aaVN');

    final buckets = await Supabase.instance.client.storage.listBuckets();
    for (final b in buckets) {
      print('FOUND BUCKET: ${b.name}');
    }
  });
}
