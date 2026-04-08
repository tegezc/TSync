import 'dart:async';
import '../contracts/i_local_database.dart';
import '../contracts/i_remote_stream.dart';
import '../models/record_change.dart';
import '../models/sync_status.dart';

class TSyncManager {
  final ILocalDatabase _localDb;
  final IRemoteStream _remoteStream;

  StreamSubscription<List<RecordChange>>? _subscription;

  // Queue (anti race condition)
  Future<void> _queue = Future.value();

  // Status
  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  SyncStatus _currentStatus = SyncStatus.idle;

  // Lifecycle & control
  String? _currentLedgerId;
  bool _isActive = false;

  // Retry
  int _retryCount = 0;
  static const int _maxRetry = 3;

  TSyncManager({
    required ILocalDatabase localDb,
    required IRemoteStream remoteStream,
  })  : _localDb = localDb,
        _remoteStream = remoteStream;

  // =========================
  // PUBLIC API
  // =========================

  void startSync(String ledgerId) {
    _currentLedgerId = ledgerId;
    _isActive = true;
    _retryCount = 0;

    _startListening();
  }

  Future<void> stopSync() async {
    _isActive = false;
    _retryCount = 0;

    await _subscription?.cancel();
    _subscription = null;

    _updateStatus(SyncStatus.idle);
  }

  Future<void> dispose() async {
    await stopSync();
    await _statusController.close();
  }

  /// PENGGANTI LIFECYCLE: Dipanggil oleh UI/App saat HP kembali menyala (Resumed)
  void resumeConnection() {
    if (!_isActive || _currentLedgerId == null) return;
    _startListening();
  }

  /// PENGGANTI LIFECYCLE: Dipanggil oleh UI/App saat HP dimatikan layarnya (Paused)
  void pauseConnection() {
    // Opsional: Untuk hemat baterai, matikan stream saat aplikasi di-background
    // Jika tidak ingin dimatikan, biarkan kosong.
    _subscription?.cancel();
    _subscription = null;
    _updateStatus(SyncStatus.idle);
  }

  // =========================
  // INTERNAL: STREAM HANDLING
  // =========================

  void _startListening() {
    if (_currentLedgerId == null) return;

    _subscription?.cancel();
    _subscription = null;

    _updateStatus(SyncStatus.syncing);

    _subscription = _remoteStream
        .getLedgerStream(_currentLedgerId!)
        .listen(
      _enqueueChanges,
      onError: _handleError,
    );
  }

  void _enqueueChanges(List<RecordChange> changes) {
    _queue = _queue.then((_) => _onDataReceived(changes));
  }

  Future<void> _onDataReceived(List<RecordChange> changes) async {
    if (changes.isEmpty) return;

    _updateStatus(SyncStatus.syncing);

    final recordsToUpsert = <Map<String, dynamic>>[];
    final idsToDelete = <String>[];

    for (final change in changes) {
      if (change.type == ChangeType.deleted) {
        idsToDelete.add(change.id);
      } else {
        if (change.data != null) {
          final payload = Map<String, dynamic>.from(change.data!);
          payload['id'] = change.id;
          recordsToUpsert.add(payload);
        }
      }
    }

    try {
      if (recordsToUpsert.isNotEmpty) {
        await _localDb.upsertRecords(recordsToUpsert);
      }

      if (idsToDelete.isNotEmpty) {
        await _localDb.deleteRecords(idsToDelete);
      }

      _retryCount = 0; // reset retry jika sukses
      _updateStatus(SyncStatus.idle);
    } catch (_) {
      _updateStatus(SyncStatus.error);
    }
  }

  // =========================
  // INTERNAL: ERROR & RETRY
  // =========================

  void _handleError(Object error) {
    _updateStatus(SyncStatus.error);

    if (!_isActive) return;

    if (_retryCount >= _maxRetry) return;

    _retryCount++;

    final delay = Duration(seconds: 2 * _retryCount);

    Future.delayed(delay, () {
      if (_isActive) {
        _startListening();
      }
    });
  }

  // =========================
  // STATUS
  // =========================

  void _updateStatus(SyncStatus status) {
    if (_currentStatus == status) return;

    _currentStatus = status;

    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }
}