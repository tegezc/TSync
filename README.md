# 🔄 TSync (TExm Synchronization Engine)

**TSync** adalah *package* inti untuk menangani sinkronisasi data satu arah (One-Way Down-Sync) dari server (*Remote*) ke penyimpanan lokal (*Local DB*). Dibuat khusus untuk mendukung infrastruktur aplikasi **TExm** (Expense Management).

Package ini dibangun dengan prinsip **Clean Architecture** (100% Pure Dart), sehingga tidak bergantung pada implementasi spesifik seperti Firebase, Supabase, SQLite, atau Isar.

---

## ✨ Fitur Utama

- 🚀 **One-Way Down-Sync:** Otomatis menarik data dari *cloud* dan menimpanya ke *local storage* untuk performa UI dengan *zero-latency* (bisa dibaca saat *offline*).
- 🧩 **100% Framework Agnostic (Clean Architecture):** Berkomunikasi secara eksklusif melalui *Interface* (`ILocalDatabase` & `IRemoteStream`). Bebas polusi UI Flutter.
- 🚦 **Smart Queue System (Anti Race Condition):** Menjamin integritas *database* lokal saat *server* menembakkan banyak perubahan data dalam rentang waktu milidetik.
- 🔄 **Auto-Retry (Exponential Backoff):** Menangani koneksi internet yang *flaky* (putus-nyambung) dengan *delay* percobaan ulang yang cerdas (2s, 4s, 6s) untuk mencegah *spamming* ke server.
- 🔋 **Lifecycle Aware:** Menghemat baterai dengan fitur *Pause/Resume* saat aplikasi masuk ke *background* atau layar dimatikan.
- 📡 **Reactive Status:** Menyediakan `Stream<SyncStatus>` untuk memudahkan *binding* ke UI (misal: ikon *loading*).

---

## 📂 Struktur Direktori

```text
tsync/
├── lib/
│   ├── tsync.dart                  # Barrel file (Entry point)
│   └── src/
│       ├── contracts/              # Interface penghubung eksternal
│       ├── models/                 # DTO (Data Transfer Objects) universal
│       └── manager/                # Core logic & queue system
└── test/                           # Unit tests (100% Coverage pada Core Logic)
```

## Cara Penggunaan
### 1. Implementasi Kontrak (Di Aplikasi TExm)
Buat class yang mengimplementasikan ILocalDatabase (misal menggunakan package TData) dan IRemoteStream (misal menggunakan Firebase Firestore).

```dart
// Contoh Implementasi Remote
class FirestoreStreamImpl implements IRemoteStream {
  @override
  Stream<List<RecordChange>> getLedgerStream(String ledgerId) {
    // Return stream dari Firestore
  }
}

// Contoh Implementasi Local
class LocalDbImpl implements ILocalDatabase {
  @override
  Future<void> upsertRecords(List<Map<String, dynamic>> records) async {
    // Simpan ke Isar/SQLite via TData
  }
  // ... implementasi deleteRecords
}
```

### 2. Inisialisasi TSyncManager
Suntikkan (inject) implementasi Anda ke dalam TSyncManager. Direkomendasikan menggunakan Dependency Injection (seperti get_it atau Riverpod).

```dart
final syncManager = TSyncManager(
  localDb: LocalDbImpl(),
  remoteStream: FirestoreStreamImpl(),
);
```

### 3. Mulai Sinkronisasi & Integrasi UI Flutter
Gunakan WidgetsBindingObserver di layer presentasi Anda (Flutter) untuk memberi tahu TSyncManager kapan harus hidup dan mati.

```dart
class _DashboardState extends State<Dashboard> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Mulai sync saat masuk halaman
    syncManager.startSync('family_ledger_123');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      syncManager.resumeConnection(); // Nyalakan stream saat buka app
    } else if (state == AppLifecycleState.paused) {
      syncManager.pauseConnection();  // Matikan stream saat background
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    syncManager.dispose(); // Wajib dipanggil saat logout/tutup app
    super.dispose();
  }
}
```

### 4. Mendengarkan Status Sinkronisasi
Anda bisa mendengarkan stream status untuk memperbarui UI (misalnya memunculkan indikator loading).
```dart
StreamBuilder<SyncStatus>(
  stream: syncManager.statusStream,
  builder: (context, snapshot) {
    final status = snapshot.data ?? SyncStatus.idle;
    if (status == SyncStatus.syncing) return CircularProgressIndicator();
    if (status == SyncStatus.error) return Icon(Icons.cloud_off, color: Colors.red);
    return Icon(Icons.cloud_done, color: Colors.green);
  },
)
```

## Testing
Modul ini dilengkapi dengan Unit Test murni tanpa memerlukan emulator Firebase. Untuk menjalankan tes:

```bash
flutter test
```