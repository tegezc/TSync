abstract class ILocalDatabase {
  /// Menyimpan atau memperbarui data ke storage lokal.
  /// [records] berisi data mentah dari server.
  Future<void> upsertRecords(List<Map<String, dynamic>> records);

  /// Menghapus data dari storage lokal berdasarkan ID.
  Future<void> deleteRecords(List<String> ids);
}