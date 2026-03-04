import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:swachh_mobile/services/storage_service.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late StorageService storageService;
  late MockHttpClient mockHttpClient;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    storageService = StorageService(client: mockHttpClient);
  });

  group('StorageService ImgBB', () {
    test('uploads image and returns url', () async {
      await Directory('test_resources').create();
      final fakeFile = File('test_resources/fake_image.jpg');
      await fakeFile.writeAsBytes([1, 2, 3]);

      final fakeResponse = http.Response(
        jsonEncode({
          'data': {'url': 'https://i.ibb.co/123/fake_image.jpg'},
        }),
        200,
      );

      when(
        () => mockHttpClient.post(any(), body: any(named: 'body')),
      ).thenAnswer((_) async => fakeResponse);

      final resultUrl = await storageService.uploadIssuePhoto(fakeFile);

      expect(resultUrl, 'https://i.ibb.co/123/fake_image.jpg');

      await fakeFile.delete();
    });

    test('throws error when upload fails', () async {
      await Directory('test_resources').create();
      final fakeFile = File('test_resources/fake_image.jpg');
      await fakeFile.writeAsBytes([1, 2, 3]);

      final fakeResponse = http.Response('Unauthorized', 400);

      when(
        () => mockHttpClient.post(any(), body: any(named: 'body')),
      ).thenAnswer((_) async => fakeResponse);

      expect(
        () => storageService.uploadIssuePhoto(fakeFile),
        throwsA(isA<Exception>()),
      );

      await fakeFile.delete();
    });
  });
}
