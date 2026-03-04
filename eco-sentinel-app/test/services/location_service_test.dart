// ignore_for_file: subtype_of_sealed_class
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swachh_mobile/services/location_service.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late LocationService locationService;
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollectionReference;
  late MockQuery mockQuery1;
  late MockQuery mockQuery2;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockCollectionReference = MockCollectionReference();
    mockQuery1 = MockQuery();
    mockQuery2 = MockQuery();

    when(
      () => mockFirestore.collection('locations'),
    ).thenReturn(mockCollectionReference);

    locationService = LocationService(firestore: mockFirestore);
  });

  test('getLocationByQrCodeId returns CampusLocation when found', () async {
    final mockSnapshot = MockQuerySnapshot();
    final mockDoc = MockQueryDocumentSnapshot();

    when(
      () => mockCollectionReference.where('qr_code_id', isEqualTo: 'QR123'),
    ).thenReturn(mockQuery1);
    when(() => mockQuery1.limit(1)).thenReturn(mockQuery2);
    when(() => mockQuery2.get()).thenAnswer((_) async => mockSnapshot);

    when(() => mockSnapshot.docs).thenReturn([mockDoc]);
    when(() => mockDoc.id).thenReturn('location_1');
    when(() => mockDoc.data()).thenReturn({
      'qr_code_id': 'QR123',
      'name': 'Library',
      'description': 'Main Library',
      'coordinates': const GeoPoint(12.0, 34.0),
      'restricted': false,
    });

    final result = await locationService.getLocationByQrCodeId('QR123');

    expect(result, isNotNull);
    expect(result!.id, 'location_1');
    expect(result.qrCodeId, 'QR123');
    expect(result.name, 'Library');
  });

  test('getLocationByQrCodeId returns null when not found', () async {
    final mockSnapshot = MockQuerySnapshot();

    when(
      () => mockCollectionReference.where('qr_code_id', isEqualTo: 'UNKNOWN'),
    ).thenReturn(mockQuery1);
    when(() => mockQuery1.limit(1)).thenReturn(mockQuery2);
    when(() => mockQuery2.get()).thenAnswer((_) async => mockSnapshot);

    when(() => mockSnapshot.docs).thenReturn([]);

    final result = await locationService.getLocationByQrCodeId('UNKNOWN');

    expect(result, isNull);
  });

  test('getLocationByQrCodeId throws exception on error', () async {
    when(
      () => mockCollectionReference.where('qr_code_id', isEqualTo: 'ERROR'),
    ).thenThrow(Exception('Firestore error'));

    expect(
      () => locationService.getLocationByQrCodeId('ERROR'),
      throwsException,
    );
  });

  test('getLocations returns a list of CampusLocation', () async {
    final mockSnapshot = MockQuerySnapshot();
    final mockDoc = MockQueryDocumentSnapshot();

    when(
      () => mockCollectionReference.get(),
    ).thenAnswer((_) async => mockSnapshot);
    when(() => mockSnapshot.docs).thenReturn([mockDoc]);
    when(() => mockDoc.id).thenReturn('loc_1');
    when(() => mockDoc.data()).thenReturn({
      'qr_code_id': 'QR1',
      'name': 'Loc 1',
      'description': 'Desc 1',
      'coordinates': const GeoPoint(0, 0),
      'restricted': false,
    });

    final result = await locationService.getLocations();

    expect(result.length, 1);
    expect(result[0].id, 'loc_1');
    expect(result[0].name, 'Loc 1');
  });

  test('getLocations throws exception on error', () async {
    when(
      () => mockCollectionReference.get(),
    ).thenThrow(Exception('Firestore error'));

    expect(() => locationService.getLocations(), throwsException);
  });
}
