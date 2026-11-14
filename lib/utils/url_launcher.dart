import 'url_launcher_stub.dart' if (dart.library.html) 'url_launcher_web.dart' as launcher;

void launchUrlString(String url) {
  launcher.openExternalUrl(url);
}

