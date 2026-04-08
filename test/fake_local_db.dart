import 'dart:async';
import 'package:tsync/tsync.dart'; // Sesuaikan path

// --- FAKE LOCAL DATABASE ---
class FakeLocalDb implements ILocalDatabase {
  final List<Map<String, dynamic>> upsertedRecords = [];
  final List<String> deletedIds = [];

  // Fitur baru untuk test: Simulasi database lemot
  Duration? simulatedDelay;

  @override
  Future<void> upsertRecords(List<Map<String, dynamic>> records) async {
    if (simulatedDelay != null) await Future.delayed(simulatedDelay!);
    upsertedRecords.addAll(records);
  }

  @override
  Future<void> deleteRecords(List<String> ids) async {
    if (simulatedDelay != null) await Future.delayed(simulatedDelay!);
    deletedIds.addAll(ids);
  }
}

// --- FAKE REMOTE STREAM ---
class FakeRemoteStream implements IRemoteStream {
  // Gunakan broadcast agar bisa di-listen ulang saat reconnect/resume
  StreamController<List<RecordChange>> controller = StreamController.broadcast();

  @override
  Stream<List<RecordChange>> getLedgerStream(String ledgerId) {
    // Jika stream lama tertutup, buat yang baru (simulasi reconnect)
    if (controller.isClosed) {
      controller = StreamController.broadcast();
    }
    return controller.stream;
  }

  void emitData(List<RecordChange> data) {
    controller.add(data);
  }

  void emitError(Object error) {
    controller.addError(error);
  }
}