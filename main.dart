import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'lib/database/mongodb.dart';

Future<void> init(InternetAddress ip, int port) async {
  await MongoDatabase.connect();
  print('Database initialized.');
}

Future<HttpServer> run(
  Handler handler,
  InternetAddress ip,
  int port,
) {
  return serve(handler, ip, port);
}
