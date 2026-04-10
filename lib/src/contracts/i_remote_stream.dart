import '../models/record_change.dart';

abstract class IRemoteStream {
  /// Membuka aliran data untuk ledger tertentu.
  /// Menghasilkan list of [RecordChange] setiap kali ada perubahan di server.
  Stream<List<RecordChange>> getLedgerStream(String ledgerId,DateTime? since,);

  /// Mengambil riwayat perubahan untuk ledger tertentu dalam rentang waktu yang ditentukan.
  Future<List<RecordChange>> fetchHistory(
    String ledgerId, 
    DateTime start, 
    DateTime end
  );
}