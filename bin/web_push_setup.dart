// Copies the Rivium Push service worker into a Flutter web app, for `RiviumPushConfig(webPush: true)`.
//
//   dart run rivium_push:web_push_setup          (in the app's folder, the one with pubspec.yaml and web/)
//
// Run it again after upgrading rivium_push, so the worker matches the package.
import 'dart:io';
import 'dart:isolate';

Future<void> main(List<String> args) async {
  final web = Directory('web');
  if (!web.existsSync()) {
    stderr.writeln('No web/ folder here. Run this in the Flutter app folder (add web with `flutter create --platforms=web .`).');
    exit(1);
  }
  final library = await Isolate.resolvePackageUri(Uri.parse('package:rivium_push/rivium_push.dart'));
  if (library == null) {
    stderr.writeln('rivium_push is not a dependency of this app.');
    exit(1);
  }
  final source = File.fromUri(library.resolve('../assets/web/rivium-push-sw.js'));
  if (!source.existsSync()) {
    stderr.writeln('The service worker is missing from the rivium_push package (${source.path}).');
    exit(1);
  }
  final target = File('web/rivium-push-sw.js');
  source.copySync(target.path);
  stdout.writeln('Copied rivium-push-sw.js to ${target.path}. Use RiviumPushConfig(webPush: true).');
}
