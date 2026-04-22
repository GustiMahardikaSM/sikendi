class HierarchyData {
  static const Map<String, List<String>> fakultasDepartemen = {
    'Fakultas Teknik (FT)': [
      'Teknik Sipil',
      'Arsitektur',
      'Teknik Mesin',
      'Teknik Kimia',
      'Teknik Elektro',
      'Perencanaan Wilayah dan Kota (PWK)',
      'Teknik Industri',
      'Teknik Lingkungan',
      'Teknik Perkapalan',
      'Teknik Geologi',
      'Teknik Geodesi',
      'Teknik Komputer',
    ],
    'Fakultas Ekonomika dan Bisnis (FEB)': [
      'Manajemen',
      'Akuntansi',
      'Ilmu Ekonomi',
      'Ekonomi Islam',
      'Bisnis Digital',
    ],
    'Fakultas Hukum (FH)': [
      'Ilmu Hukum',
    ],
    'Fakultas Kedokteran (FK)': [
      'Kedokteran',
      'Keperawatan',
      'Ilmu Gizi',
      'Kedokteran Gigi',
      'Farmasi',
    ],
    'Fakultas Ilmu Sosial dan Ilmu Politik (FISIP)': [
      'Administrasi Bisnis',
      'Administrasi Publik',
      'Ilmu Komunikasi',
      'Ilmu Pemerintahan',
      'Hubungan Internasional',
    ],
    'Fakultas Ilmu Budaya (FIB)': [
      'Sastra Indonesia',
      'Sastra Inggris',
      'Bahasa dan Kebudayaan Jepang',
      'Ilmu Sejarah',
      'Ilmu Perpustakaan',
      'Antropologi Sosial',
    ],
    'Fakultas Sains dan Matematika (FSM)': [
      'Matematika',
      'Fisika',
      'Biologi',
      'Kimia',
      'Statistika',
      'Informatika',
      'Bioteknologi',
    ],
    'Fakultas Peternakan dan Pertanian (FPP)': [
      'Peternakan',
      'Teknologi Pangan',
      'Agribisnis',
      'Agroekoteknologi',
    ],
    'Fakultas Perikanan dan Ilmu Kelautan (FPIK)': [
      'Akuakultur',
      'Manajemen Sumber Daya Perairan',
      'Perikanan Tangkap',
      'Ilmu Kelautan',
      'Oseanografi',
      'Teknologi Hasil Perikanan',
    ],
    'Fakultas Kesehatan Masyarakat (FKM)': [
      'Kesehatan Masyarakat',
    ],
    'Fakultas Psikologi (FPsi)': [
      'Psikologi',
    ],
    'Sekolah Vokasi (SV)': [
      'Teknologi Rekayasa Kimia Industri',
      'Rekayasa Perancangan Mekanik',
      'Teknologi Rekayasa Otomasi',
      'Teknologi Rekayasa Konstruksi Perkapalan',
      'Teknik Listrik Industri',
      'Teknik Infrastruktur Sipil dan Perancangan Arsitektur',
      'Perencanaan Tata Ruang dan Pertanahan',
      'Akuntansi Perpajakan',
      'Manajemen dan Administrasi Logistik',
      'Bahasa Asing Terapan',
      'Informasi dan Hubungan Masyarakat',
    ],
  };

  static List<String> get listFakultas => fakultasDepartemen.keys.toList();

  static List<String> getDepartemen(String fakultas) {
    return fakultasDepartemen[fakultas] ?? [];
  }
}
