import '../config/app_config.dart';

class ImageHelper {
  static String resolve(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      if (url.contains('localhost') || url.contains('127.0.0.1')) {
        final uri = Uri.parse(url);
        final base = Uri.parse(AppConfig.instance.baseUrl);
        return Uri(
          scheme: base.scheme,
          host: base.host,
          port: base.port,
          path: uri.path,
          query: uri.query,
        ).toString();
      }
      return url;
    }
    final base = AppConfig.instance.baseUrl;
    return '$base${url.startsWith('/') ? '' : '/'}$url';
  }
}
