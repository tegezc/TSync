enum SyncStatus {
  idle,       // Tidak ada proses, stanby
  syncing,    // Sedang menarik/menyimpan data
  error       // Terjadi kesalahan (misal: koneksi putus)
}