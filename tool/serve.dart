import 'dart:io';

/// Простой статический сервер для локального просмотра веб-сборки.
/// Запуск: dart tool/serve.dart build/web 8080
Future<void> main(List<String> args) async {
  final root = args.isNotEmpty ? args[0] : 'build/web';
  final port = args.length > 1 ? int.parse(args[1]) : 8080;

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('Сервер: http://localhost:$port (папка $root)');

  const mime = {
    '.html': 'text/html; charset=utf-8',
    '.js': 'text/javascript; charset=utf-8',
    '.mjs': 'text/javascript; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.wasm': 'application/wasm',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
    '.otf': 'font/otf',
    '.ttf': 'font/ttf',
    '.woff': 'font/woff',
    '.woff2': 'font/woff2',
    '.map': 'application/json; charset=utf-8',
    '.frag': 'application/octet-stream',
    '.apk': 'application/vnd.android.package-archive',
  };

  await for (final request in server) {
    try {
      var path = request.uri.path;
      if (path.isEmpty || path == '/') path = '/index.html';

      // APK лежит отдельно от build/web, чтобы пересборка веба его не удаляла.
      var baseDir = root;
      var relative = path.replaceFirst('/', '');
      if (path.startsWith('/download/')) {
        baseDir = 'build/download';
        relative = path.substring('/download/'.length);
      }

      final file = File('$baseDir${Platform.pathSeparator}'
          '${relative.replaceAll('/', Platform.pathSeparator)}');

      if (await file.exists()) {
        final extension = path.contains('.')
            ? '.${path.split('.').last.toLowerCase()}'
            : '';
        request.response.headers.contentType =
            ContentType.parse(mime[extension] ?? 'application/octet-stream');
        request.response.headers.set('Cache-Control', 'no-store');
        await request.response.addStream(file.openRead());
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Not found: $path');
      }
    } catch (error) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('$error');
    } finally {
      await request.response.close();
    }
  }
}
