import 'package:flutter_test/flutter_test.dart';
import 'package:tsync/tsync.dart';

import '../fake_local_db.dart';

void main() {
  late TSyncManager syncManager;
  late FakeLocalDb fakeDb;
  late FakeRemoteStream fakeStream;

  setUp(() {
    fakeDb = FakeLocalDb();
    fakeStream = FakeRemoteStream();
    syncManager = TSyncManager(
      localDb: fakeDb,
      remoteStream: fakeStream,
    );
  });

  tearDown(() async {
    await syncManager.dispose(); // Pastikan memory bersih setelah tiap test
  });

  group('1. TSyncManager - Data Core & Queue', () {
    test('Antrean (Queue) harus mencegah Race Condition', () async {
      syncManager.startSync('ledger_123');

      // Kita buat data PERTAMA sangat lemot diproses oleh local DB (50ms)
      fakeDb.simulatedDelay = const Duration(milliseconds: 50);
      fakeStream.emitData([
        RecordChange(id: 'trx_slow', type: ChangeType.added, data: {'val': 1})
      ]);

      // Kita buat data KEDUA sangat cepat diproses (0ms)
      // Jika TIDAK ADA queue, data kedua akan selesai duluan menimpa data pertama
      fakeDb.simulatedDelay = Duration.zero;
      fakeStream.emitData([
        RecordChange(id: 'trx_fast', type: ChangeType.added, data: {'val': 2})
      ]);

      // Tunggu sedikit agar semua Future di dalam _queue selesai
      await Future.delayed(const Duration(milliseconds: 100));

      // ASSERT: Pastikan urutan masuk ke database lokal tetap berurutan (Slow duluan, baru Fast)
      expect(fakeDb.upsertedRecords.length, 2);
      expect(fakeDb.upsertedRecords[0]['id'], 'trx_slow');
      expect(fakeDb.upsertedRecords[1]['id'], 'trx_fast');
    });

    test('Tidak boleh memancarkan status spam jika statusnya sama', () async {
      final statusHistory = <SyncStatus>[];

      // Dengarkan via Stream
      syncManager.statusStream.listen((status) {
        statusHistory.add(status);
      });

      syncManager.startSync('ledger_123');

      // Tembak data kosong (tidak akan memicu status idle karena tidak diproses)
      fakeStream.emitData([]);
      await Future.delayed(Duration.zero);

      // Status hanya boleh tercatat 1 kali yaitu syncing dari startSync
      expect(statusHistory, [SyncStatus.syncing]);
    });
  });

  group('2. TSyncManager - Lifecycle (Pause/Resume)', () {
    test('Pause harus memutuskan stream dan mengubah status ke idle', () async {
      final statusHistory = <SyncStatus>[];
      syncManager.statusStream.listen(statusHistory.add);

      syncManager.startSync('ledger_123');
      await Future.delayed(Duration.zero);

      // Simulasi layar HP dimatikan
      syncManager.pauseConnection();
      await Future.delayed(Duration.zero);

      // Pastikan status terakhir adalah idle
      expect(statusHistory.last, SyncStatus.idle);
      expect(fakeStream.controller.hasListener, false); // Stream harus putus
    });

    test('Resume harus menyambung ulang stream jika sebelumnya aktif', () async {
      syncManager.startSync('ledger_123');
      syncManager.pauseConnection();

      // Simulasi layar HP dinyalakan kembali
      syncManager.resumeConnection();
      await Future.delayed(Duration.zero);

      // Stream harus kembali didengarkan
      expect(fakeStream.controller.hasListener, true);
    });

    test('Resume TIDAK BOLEH menyambung stream jika user sudah stopSync (logout)', () async {
      syncManager.startSync('ledger_123');

      // User Logout
      await syncManager.stopSync();

      // Lifecycle trigger resume karena user buka app lagi di halaman login
      syncManager.resumeConnection();

      // Stream TIDAK BOLEH hidup
      expect(fakeStream.controller.hasListener, false);
    });
  });

  group('3. TSyncManager - Error Handling', () {
    test('Harus memancarkan status Error jika stream gagal', () async {
      final statusHistory = <SyncStatus>[];
      syncManager.statusStream.listen(statusHistory.add);

      syncManager.startSync('ledger_123');
      await Future.delayed(Duration.zero);

      // Tembakkan Error simulasi internet putus
      fakeStream.emitError(Exception('Internet Disconnected'));
      await Future.delayed(Duration.zero);

      // Status akhir harus error
      expect(statusHistory.last, SyncStatus.error);
    });

    // Catatan: Menguji Exponential Backoff (delay 2s, 4s, dst) secara murni
    // dalam Flutter Test membutuhkan package 'fake_async' agar test tidak berjalan
    // selama belasan detik. Namun, kita sudah memvalidasi bahwa stream error
    // mengubah status menjadi error.
  });
}