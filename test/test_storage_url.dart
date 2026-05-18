import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/widgets.dart';

void main() {
  test('Test Storage URL', () async {
    WidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(
        url: 'https://lswberciytrkxjftryei.supabase.co',
        anonKey: 'sb_publishable__oj8jDk8aa8fs9q7UGFkLg_1px6aaVN');

    final supabase = Supabase.instance.client;
    const path =
        'tenant_template/albums/album_template/track_template/TheBionicMan.mp3';

    try {
      final publicUrl = supabase.storage.from('audio').getPublicUrl(path);
      print('PUBLIC URL: $publicUrl');

      final signedUrl =
          await supabase.storage.from('audio').createSignedUrl(path, 3600);
      print('SIGNED URL: $signedUrl');
    } catch (e) {
      print('ERROR: $e');
    }
  });
}
