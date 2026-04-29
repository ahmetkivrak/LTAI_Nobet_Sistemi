import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const LtaiApp());

class TrafikVerisi {
  final int gelen;    
  final int giden;    
  final int vfrGelen; 
  final int vfrGiden; 
  
  TrafikVerisi(this.gelen, this.giden, {this.vfrGelen = 0, this.vfrGiden = 0});
  
  int get ifrToplam => gelen + giden;
  int get vfrToplam => vfrGelen + vfrGiden;
  int get genelToplam => ifrToplam + vfrToplam;
}

class HavaDurumu {
  final String rwy; 
  final bool yagmur;
  final bool oraj;
  final bool bulutlu;
  final bool gunesli;
  final bool siddetliRuzgar; 

  HavaDurumu({
    this.rwy = "36", 
    this.yagmur = false, 
    this.oraj = false, 
    this.bulutlu = false,
    this.gunesli = false,
    this.siddetliRuzgar = false,
  });

  HavaDurumu copyWith({String? rwy, bool? yagmur, bool? oraj, bool? bulutlu, bool? gunesli, bool? siddetliRuzgar}) {
    return HavaDurumu(
      rwy: rwy ?? this.rwy, yagmur: yagmur ?? this.yagmur, oraj: oraj ?? this.oraj,
      bulutlu: bulutlu ?? this.bulutlu, gunesli: gunesli ?? this.gunesli, siddetliRuzgar: siddetliRuzgar ?? this.siddetliRuzgar,
    );
  }
}

class AirgramVerisi {
  final String saat, yon, hiz, hamle, gorus, hadise, bulut, sicaklik, isba, nem, qnh;
  AirgramVerisi({required this.saat, required this.yon, required this.hiz, required this.hamle, required this.gorus, required this.hadise, required this.bulut, required this.sicaklik, required this.isba, required this.nem, required this.qnh});
}

class BordArsivi {
  final DateTime tarih;
  final String tarihMetni;
  final List<String> basliklar;
  final List<List<String>> satirlar;
  final List<TrafikVerisi> satirlarTrafik; 
  final List<TrafikVerisi> satirlarGercekciTrafik; 
  final List<HavaDurumu> satirlarHava; 
  final Map<String, Map<String, dynamic>> istatistik;
  final List<String> izinliler; 
  final String bizimleKal; 
  BordArsivi(this.tarih, this.tarihMetni, this.basliklar, this.satirlar, this.satirlarTrafik, this.satirlarGercekciTrafik, this.satirlarHava, this.istatistik, this.izinliler, this.bizimleKal);
}

class PersonelKarnesi {
  int geceCore = 0;
  int araCore = 0;
  int sabahCore = 0;
  int parcali = 0;
  int offCount = 0;
  String sonGeceRolu = '';
  int gunduzGorev = 0;
  int gunduzShift = 0;
  int gunduzToplamSlotIndeksi = 0;
  
  int get toplamGeceGorev => geceCore + araCore + sabahCore + parcali;
  
  double get oranAra => toplamGeceGorev > 0 ? araCore / toplamGeceGorev : 0;
  double get oranGece => toplamGeceGorev > 0 ? geceCore / toplamGeceGorev : 0;
  double get oranSabah => toplamGeceGorev > 0 ? sabahCore / toplamGeceGorev : 0;
  double get oranGunduz => gunduzShift > 0 ? gunduzGorev / gunduzShift : 0;
  double get gunduzGecGirisOrani => gunduzGorev > 0 ? gunduzToplamSlotIndeksi / gunduzGorev : 0;
}

// ═══════════════════════════════════════════════════
// EKİP VERİLERİ
// ═══════════════════════════════════════════════════
class EkipVerisi {
  static const Map<String, List<String>> kadro = {
    'A': ['IU', 'OK', 'OZ', 'GB', 'MS', 'RI', 'II', 'AL', 'IK', 'OG', 'TY', 'MB', 'EE', 'FU'],
    'B': ['EA', 'BK', 'FK', 'NO', 'BC', 'FI', 'IB', 'BB', 'EP', 'FD', 'AS', 'AR', 'ZH'],
    'C': ['OO', 'AV', 'AY', 'AT', 'BS', 'UY', 'SG', 'HU', 'UE', 'BN', 'NA', 'ME'],
    'D': ['GP', 'AI', 'AK', 'BE', 'MK', 'AN', 'BA', 'BL', 'DE', 'MI', 'FL', 'YT', 'GI', 'AP', 'DO'],
    'E': ['EL', 'HB', 'SE', 'EK', 'IA', 'RC', 'IG', 'KU', 'HM', 'YZ'],
  };

  static const Map<String, String> sifreler = {
    'A': 'a2026',
    'B': 'b2026',
    'C': 'c2026',
    'D': 'd2026',
    'E': 'e2026',
  };

  static const Map<String, Color> renkler = {
    'A': Color(0xFF4CAF50),
    'B': Color(0xFF2196F3),
    'C': Color(0xFFFF9800),
    'D': Color(0xFFE91E63),
    'E': Color(0xFF9C27B0),
  };

  // Ekip rotasyon sırası: D → E → A → B → C → D → ...
  static const List<String> rotasyon = ['D', 'E', 'A', 'B', 'C'];
  // Referans tarih: 29 Nisan 2026 Gündüz = D Ekibi
  static final DateTime gunduzReferans = DateTime(2026, 4, 29);
  // Referans tarih: 30 Nisan 2026 Gece = D Ekibi
  static final DateTime geceReferans = DateTime(2026, 4, 30);

  /// Verilen tarih için gündüz ekibini döndürür
  static String gunduzEkibi(DateTime tarih) {
    int fark = tarih.difference(gunduzReferans).inDays % 5;
    if (fark < 0) fark += 5;
    return rotasyon[fark];
  }

  /// Verilen tarih için gece ekibini döndürür
  static String geceEkibi(DateTime tarih) {
    int fark = tarih.difference(geceReferans).inDays % 5;
    if (fark < 0) fark += 5;
    return rotasyon[fark];
  }
}

// ═══════════════════════════════════════════════════
// EKİP SEÇİM SAYFASI
// ═══════════════════════════════════════════════════
class EkipSecimSayfasi extends StatefulWidget {
  const EkipSecimSayfasi({super.key});
  @override
  State<EkipSecimSayfasi> createState() => _EkipSecimSayfasiState();
}

class _EkipSecimSayfasiState extends State<EkipSecimSayfasi> {
  String? _secilenEkip;
  final TextEditingController _sifreController = TextEditingController();
  String _hata = '';

  void _ekipSec(String ekip) {
    setState(() {
      _secilenEkip = ekip;
      _sifreController.clear();
      _hata = '';
    });
  }

  void _girisYap() {
    if (_secilenEkip == null) return;
    String sifre = _sifreController.text.trim();
    if (sifre == EkipVerisi.sifreler[_secilenEkip]) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AnaSayfa(ekip: _secilenEkip!)),
      );
    } else {
      setState(() => _hata = 'Şifre yanlış');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo / Başlık
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.orangeAccent.withOpacity(0.5), width: 2),
                  boxShadow: [BoxShadow(color: Colors.orangeAccent.withOpacity(0.15), blurRadius: 30, spreadRadius: 5)],
                ),
                child: const Icon(Icons.flight, size: 56, color: Colors.orangeAccent),
              ),
              
              const SizedBox(height: 40),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: ['A', 'B', 'C', 'D', 'E'].map((ekip) {
                  bool secili = _secilenEkip == ekip;
                  Color renk = EkipVerisi.renkler[ekip]!;
                  return GestureDetector(
                    onTap: () => _ekipSec(ekip),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: secili ? renk.withOpacity(0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: secili ? renk : renk.withOpacity(0.3),
                          width: secili ? 2.5 : 1,
                        ),
                        boxShadow: secili
                            ? [BoxShadow(color: renk.withOpacity(0.3), blurRadius: 12, spreadRadius: 2)]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            ekip,
                            style: TextStyle(
                              color: secili ? renk : renk.withOpacity(0.7),
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${EkipVerisi.kadro[ekip]!.length} kişi',
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Şifre Alanı (ekip seçilince görünür)
              if (_secilenEkip != null) ...[
                const SizedBox(height: 32),
                Container(
                  width: 280,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: EkipVerisi.renkler[_secilenEkip]!.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$_secilenEkip Ekibi Girişi',
                        style: TextStyle(
                          color: EkipVerisi.renkler[_secilenEkip]!,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _sifreController,
                        obscureText: true,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 4),
                        decoration: InputDecoration(
                          hintText: 'Şifre',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onSubmitted: (_) => _girisYap(),
                      ),
                      if (_hata.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(_hata, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _girisYap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EkipVerisi.renkler[_secilenEkip]!,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('GİRİŞ', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],


            ],
          ),
        ),
      ),
    );
  }
}

class LtaiApp extends StatelessWidget {
  const LtaiApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF111111),
        primaryColor: Colors.orangeAccent,
      ),
      home: const EkipSecimSayfasi(),
    );
  }
}

class AnaSayfa extends StatefulWidget {
  final String ekip;
  const AnaSayfa({super.key, required this.ekip});
  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  bool isGunduzVardiyasi = true;
  int saatSenaryosu = 1; 
  
  List<String> gunduzKlasik = ["09:00 - 10:40", "10:40 - 12:20", "12:20 - 14:00", "14:00 - 15:40", "15:40 - 17:20", "17:20 - 19:00"];
  List<String> gunduzAlengirli = ["09:00 - 10:40", "10:40 - 12:20", "12:20 - 14:00", "14:00 - 15:20", "15:20 - 16:40", "16:40 - 17:50", "17:50 - 19:00"];
  
  List<String> geceKlasik = ["19:00 - 20:40", "20:40 - 22:20", "22:20 - 00:00", "00:00 - 03:00", "03:00 - 05:30", "05:30 - 08:00", "08:00 - 09:00"];
  List<String> geceAlengirli = ["19:00 - 21:15", "21:15 - 23:30", "23:30 - 03:00", "03:00 - 05:30", "05:30 - 08:00", "08:00 - 09:00"];

  List<String> get saatler {
    if (isGunduzVardiyasi) return saatSenaryosu == 1 ? gunduzKlasik : gunduzAlengirli;
    return saatSenaryosu == 1 ? geceKlasik : geceAlengirli;
  }

  int t3to4 = 25; int t4to5 = 36; int t5to6 = 50; int t6to7 = 70;
  
  Map<String, List<TrafikVerisi>> _haftalikTrafikKasa = {};
  
  List<TrafikVerisi> anlikTrafik24 = []; 
  List<TrafikVerisi> anlikTrafik = []; 
  List<TrafikVerisi> anlikGercekciTrafik = []; 
  
  Map<int, HavaDurumu> anlikHava24 = {};
  List<HavaDurumu> anlikHava = [];
  
  Map<String, dynamic>? hamSaatlikHavaVerisi;
  List<AirgramVerisi> canliAirgram24 = [];

  bool _veriCekiliyor = false;
  List<dynamic> ltaiNotamlari = [];
  String notamGuncelleme = "";
  String trafikGuncelleme = "";
  String metGuncelleme = "";
  
  final String gasUrl = "https://script.google.com/macros/s/AKfycbwbwRw2XQTpnX9MgN4zJM6QDUg5JX_q4mqJ84B_ODPmkZAM00eDA4iUHDOuVzcPNIfr4A/exec";

  late List<String> tumPersonelHavuzu;
  late final String _aktifEkip;
  
  Map<String, Set<String>> _gunlukDurumGunduz = {};
  Map<String, Set<String>> _gunlukDurumGece = {};
  Map<String, Set<String>> get gunlukDurum => isGunduzVardiyasi ? _gunlukDurumGunduz : _gunlukDurumGece;

  Map<String, Set<String>> yetkiler = {}; 
  
  Set<String> _ilkSecilenlerGunduz = {};
  Set<String> _ilkSecilenlerGece = {};
  Set<String> get ilkSecilenler => isGunduzVardiyasi ? _ilkSecilenlerGunduz : _ilkSecilenlerGece;


  Set<String> _sonSecilenlerGunduz = {};
  Set<String> _sonSecilenlerGece = {};
  Set<String> get sonSecilenler => isGunduzVardiyasi ? _sonSecilenlerGunduz : _sonSecilenlerGece;

  Set<String> _bizimleKalSecilenlerGunduz = {};
  Set<String> _bizimleKalSecilenlerGece = {};
  Set<String> get bizimleKalSecilenler => isGunduzVardiyasi ? _bizimleKalSecilenlerGunduz : _bizimleKalSecilenlerGece;

  Set<String> _supOnlySecilenlerGunduz = {};
  Set<String> _supOnlySecilenlerGece = {};
  Set<String> get supOnlySecilenler => isGunduzVardiyasi ? _supOnlySecilenlerGunduz : _supOnlySecilenlerGece;

  Set<String> gece1203Secilenler = {};
  Set<String> geceAraSecilenler = {};
  Set<String> gece0508Secilenler = {};
  Set<String> gece0809Secilenler = {};
  Set<String> geceOffSecilenler = {};
  // NOT: Karınca (HAMAL) ve Aguştos Böceği (ENSECİ) bayrakları gunlukDurum içinde tutulur.
  // Ayrı Set yoktur — gunlukDurum tek gerçek kaynağıdır.

  /// Aktif kadro içinde herhangi biri manuel Karınca seçilmiş mi?
  bool get _herhangiManuelKarinca => tumPersonelHavuzu.any((p) =>
      !(gunlukDurum[p]?.contains('OFF') ?? false) &&
      !(gunlukDurum[p]?.contains('KAZANDIŞI') ?? false) &&
      (gunlukDurum[p]?.contains('HAMAL') ?? false));

  /// Aktif kadro içinde herhangi biri manuel Aguştos Böceği seçilmiş mi?
  bool get _herhangiManuelEnseci => tumPersonelHavuzu.any((p) =>
      !(gunlukDurum[p]?.contains('OFF') ?? false) &&
      !(gunlukDurum[p]?.contains('KAZANDIŞI') ?? false) &&
      (gunlukDurum[p]?.contains('ENSECİ') ?? false));

  bool tamOtomatikDagitim = true;
  double gunlukSeviye = 4.0;
  double get hakimSeviye {
    if (anlikTrafik24.isEmpty || anlikTrafik.isEmpty) return 4.0;
    Map<double, int> counts = {};
    for (var t in anlikTrafik) { double lvl = _getIdealLevel(t.genelToplam); counts[lvl] = (counts[lvl] ?? 0) + 1; }
    int maxCount = 0; double mode = 4.0;
    counts.forEach((lvl, count) { if (count > maxCount) { maxCount = count; mode = lvl; } });
    return mode;
  }

  Map<String, Map<int, Map<String, String>>> _kilitliSaatlerTarihli = {}; // Pin: sadece görünen saat notu, algoritmayı etkilemez
  Map<String, Map<int, Map<String, String>>> _manuelAtananKisiler = {}; // Hangi slota ve pozisyona manuel kilitlendiği (Algoritmayı zorlar)
  String get _aktifTarihVeMod => "${_aktifTarihStr}_${isGunduzVardiyasi ? 'G' : 'N'}";


  Map<String, int> turSayisi = {}; 
  Map<String, int> supSayisi = {}; Map<String, int> twrSayisi = {}; Map<String, int> gndSayisi = {}; Map<String, int> delSayisi = {};

  Map<int, Map<String, String>> _pozOtoNotlar = {}; // slot → {pozisyon: " (14:00)"}
  /// İsimden oto-notu ayırır: "BE (14:00)" → "BE"
  String _yalnIsim(String s) => s.contains(' (') ? s.split(' (')[0] : s;

  List<BordArsivi> tamArsiv = [];


  DateTime _seciliTakvimTarihi = DateTime.now();
  String get _aktifTarihStr => "${_seciliTakvimTarihi.day.toString().padLeft(2, '0')}.${_seciliTakvimTarihi.month.toString().padLeft(2, '0')}.${_seciliTakvimTarihi.year}";
  DateTime get _aktifTarih => _seciliTakvimTarihi;

  // Sektör Sıralaması: TWR -> DEL -> GND -> SUP
  List<String> getSektorlerByLevel(double level) {
    if (level <= 3.0) return ["TWR", "DEL", "SUP"]; 
    if (level <= 4.0) return ["TWR", "DEL", "GND", "SUP"]; 
    if (level <= 5.0) return ["TWR_W", "DEL", "GND", "TWR_E", "SUP"]; 
    if (level <= 6.0) return ["TWR_W", "DEL", "GND_S", "TWR_E", "GND_N", "SUP"]; 
    return ["TWR_W", "DEL", "GND_S", "TWR_E", "GND_N", "GND_C", "SUP"]; 
  }

  double _getIdealLevel(int trafik, {int? l34, int? l45, int? l56, int? l67}) {
    int b34 = l34 ?? t3to4; // 3.0 -> 3.5 sınırı
    int b45 = l45 ?? t4to5; // 3.5 -> 4.0 sınırı
    int b56 = l56 ?? t5to6; // 4.0 -> 4.5 sınırı
    int b67 = l67 ?? t6to7; // 4.5 -> 5.0 sınırı

    if (trafik <= b34) return 3.0;
    if (trafik <= b45) return 3.5;
    if (trafik <= b56) return 4.0;
    if (trafik <= b67) return 4.5;
    return 5.0;
  }

  @override
  void initState() {
    super.initState();
    _aktifEkip = widget.ekip;
    tumPersonelHavuzu = List<String>.from(EkipVerisi.kadro[_aktifEkip] ?? []);
    _tabController = TabController(length: 2, vsync: this);
    for (var k in tumPersonelHavuzu) {
      _gunlukDurumGunduz[k] = {'A'};
      _gunlukDurumGece[k] = {'A'};
      yetkiler[k] = {}; 
    }
    
    anlikTrafik24 = List.generate(24, (i) => TrafikVerisi(0, 0, vfrGelen: 0, vfrGiden: 0));
    _varsayilanAirgramYarat();

    for (int i = 0; i < 24; i++) {
      anlikHava24[i] = HavaDurumu(gunesli: true); 
    }
    
    _meteorolojiVerisiniCek();
    _trafikVerisiniCek();
    _sadeceNotamVerisiniCek(); // Açılışta taze NOTAM'ları otomatik çek
    _trafikSlotlariniHesapla();
    gunlukSeviye = hakimSeviye;
    _gruplariGuncelle(arsiveKaydet: false);
    _loadNotamPrefs(); // Rozet tercihlerini yükle
    _loadPersonelPrefs(); // Kişi listesi hafızadan yükle
    _loadTakvimIzinler(); // Takvim izinlerini yükle

    // Otomatik gunduz/gece algilama
    DateTime simdi = DateTime.now();
    String gunduzEkip = EkipVerisi.gunduzEkibi(simdi);
    String geceEkip = EkipVerisi.geceEkibi(simdi);
    if (geceEkip == _aktifEkip) {
      isGunduzVardiyasi = false;
      // Sezon bazli saat grubu: 1 May - 31 Eki = 21:15 (senaryo 2), diger = 20:40 (senaryo 1)
      bool yaz = (simdi.month >= 5 && simdi.month <= 10);
      saatSenaryosu = yaz ? 2 : 1;
      _modGecisiTemizle(false);
      _gruplariGuncelle(arsiveKaydet: false);
    } else if (gunduzEkip == _aktifEkip) {
      isGunduzVardiyasi = true;
      saatSenaryosu = 1;
    }
    // OFF gunu ise varsayilan gunduz kalsin
  }

  void _tariheGoreVerileriGuncelle() {
    if (_haftalikTrafikKasa.containsKey(_aktifTarihStr)) {
      anlikTrafik24 = _haftalikTrafikKasa[_aktifTarihStr]!;
    } else {
      anlikTrafik24 = List.generate(24, (i) => TrafikVerisi(0, 0, vfrGelen: 0, vfrGiden: 0));
    }
    _havayiTariheGoreFiltrele(); 
    _trafikSlotlariniHesapla();
    gunlukSeviye = hakimSeviye;
    _gruplariGuncelle(arsiveKaydet: false);
  }

  Future<void> _trafikVerisiniCek() async {
    setState(() { _veriCekiliyor = true; });
    try {
      final response = await http.get(Uri.parse(gasUrl)).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['durum'] == 'BAŞARILI') {
          _haftalikTrafikKasa.clear();
          Map<String, dynamic> haftalik = decoded['haftalikVeri'];
          haftalik.forEach((tarihStr, saatlerObj) {
            List<TrafikVerisi> gunlukTrafik = List.generate(24, (i) => TrafikVerisi(0, 0));
            saatlerObj.forEach((saatStr, veri) {
              int saat = int.parse(saatStr.split(':')[0]);
              if (saat >= 0 && saat < 24) {
                gunlukTrafik[saat] = TrafikVerisi(
                  veri['gelen'] ?? 0, veri['giden'] ?? 0,
                  vfrGelen: veri['vfrGelen'] ?? 0, vfrGiden: veri['vfrGiden'] ?? 0
                );
              }
            });
            _haftalikTrafikKasa[tarihStr] = gunlukTrafik;
          });
          setState(() {
            ltaiNotamlari = decoded['notamlar'] ?? [];
            notamGuncelleme = decoded['notamGuncelleme'] ?? "";
            trafikGuncelleme = decoded['guncelleme'] ?? DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());
          });
          _tariheGoreVerileriGuncelle();
        }
      }
    } catch (e) {
      debugPrint("Canlı Veri Çekim Hatası (Bulut): $e");
    } finally {
      if (mounted) setState(() { _veriCekiliyor = false; });
    }
  }

  void _varsayilanAirgramYarat() {
    canliAirgram24.clear();
    for (int i = 0; i < 24; i++) {
      canliAirgram24.add(AirgramVerisi(
        saat: "${i.toString().padLeft(2, '0')}:00", yon: "360", hiz: "10", hamle: "-", 
        gorus: "9999", hadise: "-", bulut: "NSC", sicaklik: "15", isba: "10", nem: "75", qnh: "1018"
      ));
    }
  }

  Future<void> _meteorolojiVerisiniCek() async {
    try {
      final url = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=36.90&longitude=30.80&hourly=temperature_2m,dewpoint_2m,relative_humidity_2m,surface_pressure,visibility,windspeed_10m,winddirection_10m,windgusts_10m,weathercode,cloudcover&timezone=Europe%2FIstanbul&forecast_days=7&past_days=7');
      final response = await http.get(url).timeout(const Duration(seconds: 25));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        hamSaatlikHavaVerisi = data['hourly']; 
        metGuncelleme = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());
        _havayiTariheGoreFiltrele(); 
      }
    } catch (e) { debugPrint("Canlı Veri Çekim Hatası: $e"); }
  }

  List<AirgramVerisi> _havaGetir(DateTime hedefTarih) {
    if (hamSaatlikHavaVerisi == null) {
      return List.generate(24, (i) => AirgramVerisi(
        saat: "${i.toString().padLeft(2, '0')}:00", yon: "360", hiz: "10", hamle: "-", 
        gorus: "9999", hadise: "-", bulut: "NSC", sicaklik: "15", isba: "10", nem: "75", qnh: "1018"
      ));
    }
    String hedefTarihStr = "${hedefTarih.year}-${hedefTarih.month.toString().padLeft(2, '0')}-${hedefTarih.day.toString().padLeft(2, '0')}";
    List<AirgramVerisi> yeniVeri = [];
    var hourly = hamSaatlikHavaVerisi!;
    int totalHours = (hourly['time'] as List).length;
    for (int i = 0; i < totalHours; i++) {
      String timeStr = hourly['time'][i]; 
      if (timeStr.startsWith(hedefTarihStr)) {
        String hourStr = timeStr.substring(11, 16); 
        double wspdKmh = (hourly['windspeed_10m'][i] ?? 0).toDouble();
        double wgstKmh = (hourly['windgusts_10m'][i] ?? 0).toDouble();
        int dir = (hourly['winddirection_10m'][i] ?? 0).round();
        int lastDigit = dir % 10;
        int roundedDir = (lastDigit <= 5) ? (dir ~/ 10) * 10 : ((dir ~/ 10) + 1) * 10;
        if (roundedDir == 0) roundedDir = 360;
        int wspdKt = (wspdKmh / 1.852).round();
        int wgstKt = (wgstKmh / 1.852).round();
        String hamleYazisi = (wgstKt >= wspdKt + 10 && wgstKt >= 15) ? wgstKt.toString() : "-";
        int weatherCode = hourly['weathercode'][i] ?? 0;
        String hadise = _wmoToMetarCode(weatherCode);
        int cloudCover = hourly['cloudcover'][i] ?? 0;
        String bulut = _cloudToAviationCode(cloudCover);
        double rawGorus = (hourly['visibility'][i] ?? 9999).toDouble();
        String gorusStr;
        if (rawGorus >= 10000) { gorusStr = "9999"; } 
        else if (rawGorus >= 5000) { gorusStr = ((rawGorus ~/ 1000) * 1000).toString().padLeft(4, '0'); } 
        else { gorusStr = ((rawGorus ~/ 1000) * 1000).toString().padLeft(4, '0'); }
        String isbaStr = (hourly['dewpoint_2m'][i] ?? 0).round().toString();
        String nemStr = (hourly['relative_humidity_2m'][i] ?? 0).round().toString();
        yeniVeri.add(AirgramVerisi(
          saat: hourStr, yon: roundedDir.toString().padLeft(3, '0'),
          hiz: wspdKt.toString().padLeft(2, '0'), hamle: hamleYazisi,
          gorus: gorusStr, hadise: hadise, bulut: bulut,
          sicaklik: (hourly['temperature_2m'][i] ?? 0).round().toString(),
          isba: isbaStr, nem: nemStr,
          qnh: (hourly['surface_pressure'][i] ?? 1013).round().toString(),
        ));
      }
    }
    if (yeniVeri.length == 24) return yeniVeri;
    return List.generate(24, (i) => AirgramVerisi(
      saat: "${i.toString().padLeft(2, '0')}:00", yon: "360", hiz: "10", hamle: "-", 
      gorus: "9999", hadise: "-", bulut: "NSC", sicaklik: "15", isba: "10", nem: "75", qnh: "1018"
    ));
  }

  void _havayiTariheGoreFiltrele() {
    canliAirgram24 = _havaGetir(_aktifTarih);
    _anaEkraniGercekVeriyleGuncelle();
  }

  String _wmoToMetarCode(int code) {
    if (code == 0 || code == 1 || code == 2 || code == 3) return "-";
    if (code == 45 || code == 48) return "BR";
    if (code >= 51 && code <= 55) return "DZ";
    if (code == 61) return "-RA";
    if (code == 63) return "RA";
    if (code == 65) return "+RA";
    if (code >= 71 && code <= 75) return "SN";
    if (code >= 80 && code <= 82) return "SHRA";
    if (code == 95) return "TS";
    if (code == 96 || code == 99) return "TSRA";
    return "-";
  }

  String _cloudToAviationCode(int percentage) {
    if (percentage < 10) return "NSC";
    if (percentage < 25) return "FEW030";
    if (percentage < 50) return "SCT030";
    if (percentage < 85) return "BKN025";
    return "OVC015";
  }

  void _anaEkraniGercekVeriyleGuncelle() {
    for(int i=0; i<24; i++) {
        var aData = canliAirgram24.firstWhere((element) => element.saat.startsWith(i.toString().padLeft(2, '0')), orElse: () => canliAirgram24.first);
        bool sRuz = aData.hamle != "-" && int.tryParse(aData.hamle) != null && int.parse(aData.hamle) >= 20;
        bool yag = aData.hadise.contains("RA") || aData.hadise.contains("DZ");
        bool oraj = aData.hadise.contains("TS") || aData.bulut.contains("CB");
        bool bCloud = aData.bulut.contains("BKN") || aData.bulut.contains("OVC");
        String pYon = "36";
        if (aData.yon != "VRB") {
          int deg = int.tryParse(aData.yon) ?? 360;
          if (deg > 100 && deg < 260) pYon = "18";
        }
        anlikHava24[i] = HavaDurumu(
          rwy: pYon, yagmur: yag && !oraj, oraj: oraj, 
          bulutlu: bCloud && !yag && !oraj, gunesli: !bCloud && !yag && !oraj, siddetliRuzgar: sRuz
        );
    }
    setState(() { _trafikSlotlariniHesapla(); gunlukSeviye = hakimSeviye; _gruplariGuncelle(); });
  }

  void _trafikSlotlariniHesapla() {
    anlikTrafik.clear();
    anlikGercekciTrafik.clear();
    anlikHava.clear();
    
    DateTime yarin = _aktifTarih.add(const Duration(days: 1));
    String yarinStr = "${yarin.day.toString().padLeft(2, '0')}.${yarin.month.toString().padLeft(2, '0')}.${yarin.year}";
    List<TrafikVerisi> yarinTrafik24 = _haftalikTrafikKasa[yarinStr] ?? List.generate(24, (i) => TrafikVerisi(0, 0));

    for (int i = 0; i < saatler.length; i++) {
      String aralik = saatler[i];
      int startH = int.parse(aralik.split(' - ')[0].split(':')[0]);
      int startM = int.parse(aralik.split(' - ')[0].split(':')[1]);
      int endH = int.parse(aralik.split(' - ')[1].split(':')[0]);
      int endM = int.parse(aralik.split(' - ')[1].split(':')[1]); 
      
      TrafikVerisi maxTrf = TrafikVerisi(0, 0);
      int h = startH;
      while(true) {
        if (h == endH && endM == 0) break; 
        bool isYarin = !isGunduzVardiyasi && (h < 12); 
        TrafikVerisi curTrf = isYarin ? yarinTrafik24[h] : anlikTrafik24[h];
        if (curTrf.genelToplam > maxTrf.genelToplam) maxTrf = curTrf;
        if (h == endH) break; 
        h = (h + 1) % 24; 
      }
      anlikTrafik.add(maxTrf);
      
      double toplamGelen = 0; double toplamGiden = 0; double toplamVfrGelen = 0; double toplamVfrGiden = 0;
      int currentH = startH; int currentM = startM; int remainingMins = _dakikaCoz(aralik);

      while (remainingMins > 0) {
        int minsInThisHour = 60 - currentM;
        if (minsInThisHour > remainingMins) minsInThisHour = remainingMins;
        bool isYarin = !isGunduzVardiyasi && (currentH < 12);
        TrafikVerisi curTrf = isYarin ? yarinTrafik24[currentH] : anlikTrafik24[currentH];
        double ratio = minsInThisHour / 60.0;
        toplamGelen += curTrf.gelen * ratio; toplamGiden += curTrf.giden * ratio;
        toplamVfrGelen += curTrf.vfrGelen * ratio; toplamVfrGiden += curTrf.vfrGiden * ratio;
        remainingMins -= minsInThisHour; currentH = (currentH + 1) % 24; currentM = 0;
      }
      anlikGercekciTrafik.add(TrafikVerisi(toplamGelen.ceil(), toplamGiden.ceil(), vfrGelen: toplamVfrGelen.ceil(), vfrGiden: toplamVfrGiden.ceil()));
      
      bool has36 = false; bool has18 = false; bool hasRain = false; bool hasStorm = false; bool hasCloud = false; bool hasWind = false;
      String baseRwy = anlikHava24[startH]?.rwy ?? "36";
      int hw = startH;
      while(true) {
        if (hw == endH && endM == 0) break;
        HavaDurumu hwDurum = anlikHava24[hw] ?? HavaDurumu();
        if (hwDurum.rwy.contains("36")) has36 = true; if (hwDurum.rwy.contains("18")) has18 = true;
        if (hwDurum.yagmur) hasRain = true; if (hwDurum.oraj) hasStorm = true;
        if (hwDurum.bulutlu) hasCloud = true; if (hwDurum.siddetliRuzgar) hasWind = true;
        if (hw == endH) break; hw = (hw + 1) % 24;
      }

      String finalRwy = baseRwy;
      if (has36 && has18) finalRwy = (baseRwy.contains("36")) ? "36 🔄 18" : "18 🔄 36";
      else finalRwy = has18 ? "18" : "36";

      anlikHava.add(HavaDurumu(rwy: finalRwy, oraj: hasStorm, yagmur: hasRain && !hasStorm, bulutlu: hasCloud && !hasStorm && !hasRain, gunesli: !hasStorm && !hasRain && !hasCloud, siddetliRuzgar: hasWind));
    }
  }

  void _gruplariGuncelle({bool arsiveKaydet = true, bool pinleriTemizle = true}) {
    setState(() { 
      // Takvim izinlerini otomatik uygula
      String bugunKey = _tarihKey(DateTime.now());
      Map<String, String> takvimIzinliler = _takvimIzinler[bugunKey] ?? {};
      for (var k in takvimIzinliler.keys) {
        if (tumPersonelHavuzu.contains(k) && !(gunlukDurum[k]?.contains('OFF') ?? false)) {
          gunlukDurum[k] = {'OFF'};
        }
      }

      // Manuel pin korumasi: pinleriTemizle=false ise mevcut pinler silinmez
      if (pinleriTemizle) {
        _manuelAtananKisiler.remove(_aktifTarihVeMod);
        _kilitliSaatlerTarihli.remove(_aktifTarihVeMod);
      }
      _trafikSlotlariniHesapla(); 
      _arsiveOtomatikKaydet(kaydet: arsiveKaydet); 
    });
  }

  void _hafizayiSifirla() {
    for (var k in tumPersonelHavuzu) {
      turSayisi[k] = 0;
      supSayisi[k] = 0; twrSayisi[k] = 0; gndSayisi[k] = 0; delSayisi[k] = 0;
      // Önceki turdan kalan oto-etiketleri temizle (her üretimde taze hesaplansın)
      gunlukDurum[k]?.remove('HAMAL_OTO');
      gunlukDurum[k]?.remove('ENSECİ_OTO');
    }
  }

  int _dakikaCoz(String aralik) {
    try {
      var parts = aralik.split(' - ');
      int startMins = int.parse(parts[0].split(':')[0]) * 60 + int.parse(parts[0].split(':')[1]);
      int endMins = int.parse(parts[1].split(':')[0]) * 60 + int.parse(parts[1].split(':')[1]);
      if (endMins < startMins) endMins += 24 * 60; 
      return endMins - startMins;
    } catch(e) { return 100; }
  }

  bool _vizeKontrol(String kisi, String pozisyon, String core, {bool acilDurum = false, List<String>? aktifPersonelHavuzu}) {
    if (core == 'SUP') {
      bool isAnyActiveSup = false;
      if (aktifPersonelHavuzu != null) {
         isAnyActiveSup = aktifPersonelHavuzu.any((k) => (yetkiler[k] ?? <String>{}).contains('SUP'));
      } else {
         isAnyActiveSup = tumPersonelHavuzu.any((k) => !gunlukDurum[k]!.contains('OFF') && !gunlukDurum[k]!.contains('KAZANDIŞI') && (yetkiler[k] ?? <String>{}).contains('SUP'));
      }
      if (!isAnyActiveSup) return true; 
      if (supOnlySecilenler.contains(kisi)) return true; 
      return (yetkiler[kisi] ?? <String>{}).contains('SUP');
    } else {
      if (supOnlySecilenler.contains(kisi)) return false; 
      if ((yetkiler[kisi] ?? <String>{}).isEmpty) return true; 
      if ((yetkiler[kisi] ?? <String>{}).contains(pozisyon) || (yetkiler[kisi] ?? <String>{}).contains(core)) return true; 
      if (acilDurum && (yetkiler[kisi] ?? <String>{}).length == 1 && (yetkiler[kisi] ?? <String>{}).contains('SUP')) return true; 
      return false;
    }
  }

  // 18 nöbetlik otonom hafıza (izinlileri ezmez)
  PersonelKarnesi _getPersonelKarnesi(String k) {
    PersonelKarnesi karne = PersonelKarnesi();
    int countLimit = 0;
    
    for (var a in tamArsiv.reversed) {
      if (a.satirlar.isEmpty) continue;
      String ilkSaat = a.satirlar.first.first;
      bool isGeceBordro = ilkSaat.startsWith("18:") || ilkSaat.startsWith("19:") || ilkSaat.startsWith("20:");
      
      if (a.izinliler.contains(k)) continue;

      if (isGeceBordro) {
        bool oGeceCalisti = false;
        bool isParcali = false;
        String rol = 'OFF';
        
        for (var satir in a.satirlar) {
          String s = satir.first;
          bool oSaatMevcut = false;
          bool localParcali = false;
          for (int i = 1; i < satir.length; i++) {
             if (_yalnIsim(satir[i]) == k) {
                oSaatMevcut = true;
                if (satir[i].contains('(') || satir[i].contains(')')) {
                  localParcali = true;
                }
                break;
             }
          }
          if (oSaatMevcut) {
             oGeceCalisti = true;
             if (localParcali) isParcali = true;
             
             if (s.startsWith('00:00') || s.startsWith('23:30')) {
                rol = 'GECE';
             } else if (s.startsWith('03:00')) {
                rol = 'ARA';
             } else if (s.startsWith('05:30') || s.startsWith('08:00')) {
                if (rol != 'GECE' && rol != 'ARA') rol = 'SABAH';
             }
          }
        }
        
        if (karne.sonGeceRolu.isEmpty) karne.sonGeceRolu = rol;

        if (rol == 'GECE') karne.geceCore++;
        else if (rol == 'ARA') karne.araCore++;
        else if (rol == 'SABAH') karne.sabahCore++;
        else if (rol == 'OFF') karne.offCount++;
        
        if (isParcali) karne.parcali++; // Parçalı her halükarda ek destek olarak sayılır
        
      } else {
        karne.gunduzShift++;
        for (int slotIdx = 0; slotIdx < a.satirlar.length; slotIdx++) {
           var satir = a.satirlar[slotIdx];
           for (int i = 1; i < satir.length; i++) {
              if (_yalnIsim(satir[i]) == k) {
                 karne.gunduzGorev++;
                 karne.gunduzToplamSlotIndeksi += slotIdx;
                 break; // Bu saat diliminde pozisyonda oturmuş
              }
           }
        }
      }
      
      countLimit++;
      if (countLimit > 60) break; // Son 60 nöbet arşivi dengeli oran için yeterlidir
    }
    
    if (karne.sonGeceRolu.isEmpty) karne.sonGeceRolu = 'OFF';
    return karne;
  }

  double _getArsivYorgunlukOrtalamasi(String k) {
    var k1 = _getPersonelKarnesi(k);
    if (isGunduzVardiyasi) {
      return k1.oranGunduz;
    } else {
      // Akşamın zikzagsız nöbetleri vs. sıralanırken "en az nöbet tutan" en üste çıksın diye:
      int gCount = k1.toplamGeceGorev;
      return gCount.toDouble(); 
    }
  }

  // ════════════════════════════════════════════════
  // ALGORİTMA v3 — NUMARALI ZİGZAG DÖNGÜ
  //   Adım 1: Zigzag numaralı şablon oluştur
  //   Adım 2: Kişileri numaralara ata (SUP havuzu öncelikli)
  //   Adım 3: İnce ayar (aynı pozisyon tekrarını grup içi swap ile çöz)
  // ════════════════════════════════════════════════

  /// Phase 1: Her kişi hangi slot(lar)da çalışacak?
  /// NUMARA ŞABLONU yaklaşımı:
  ///   Adım 1: Zigzag numara şablonu oluştur (hangi numara, hangi slotlarda)
  ///   Adım 2: KARINCA → en çok turlu numara, AĞUSTOS BÖCEĞİ → en az turlu numara
  ///   Adım 3: İLK → erken slotlu numara, SON → geç slotlu numara
  Map<int, List<String>> _phase1SlotAtama(List<String> aktifPersonel) {
    int slotCount = saatler.length;
    int aCount = aktifPersonel.length;
    if (aCount == 0) return {for (int i = 0; i < slotCount; i++) i: []};
    
    // Slot kapasiteleri
    List<int> slotKap = [];
    for (int i = 0; i < slotCount; i++) {
      double sLvl = tamOtomatikDagitim 
          ? _getIdealLevel(anlikTrafik[i % anlikTrafik.length].genelToplam) 
          : gunlukSeviye;
      int kap = getSektorlerByLevel(sLvl).length;
      slotKap.add(kap);
    }
    
    // ═══════════════════════════════════════════════════
    // ADIM 1: ZİGZAG NUMARA ŞABLONU
    // Round-robin ile numara → slot eşlemesi
    // Örnek: 14 kişi, 7 slot → Numara 0: [slot0, slot3], Numara 13: [slot3]
    // ═══════════════════════════════════════════════════
    Map<int, List<int>> numaraSlotlari = {};
    int idx = 0;
    for (int slot = 0; slot < slotCount; slot++) {
      for (int j = 0; j < slotKap[slot]; j++) {
        int num = idx % aCount;
        numaraSlotlari.putIfAbsent(num, () => []);
        numaraSlotlari[num]!.add(slot);
        idx++;
      }
    }
    
    // Numaranın ortalama slot pozisyonu (erken mi geç mi?)
    double _numAvg(int n) {
      var s = numaraSlotlari[n] ?? [];
      if (s.isEmpty) return slotCount / 2.0;
      return s.reduce((a, b) => a + b) / s.length;
    }
    
    // ═══════════════════════════════════════════════════
    // ADIM 2: KİŞİLERİ NUMARALARA EŞLE
    // Öncelik: KARINCA → çok tur, AĞUSTOS BÖCEĞİ → az tur
    // Sonra: İLK → erken slot, SON → geç slot
    // ═══════════════════════════════════════════════════

    // ─── OTOMATİK BÖCEK/KARINCA HESAPLA ───
    // Kaç böcek/karinca gerekli ama eksik seçilmiş ise otomatik tamamla
    {
      int totalSLocal = 0;
      for (int i = 0; i < saatler.length; i++) {
        totalSLocal += getSektorlerByLevel(tamOtomatikDagitim ? _getIdealLevel(anlikTrafik[i % anlikTrafik.length].genelToplam) : gunlukSeviye).length;
      }
      int bCount = aktifPersonel.length;
      if (bCount > 0) {
        int baseT = totalSLocal ~/ bCount;
        int remT  = totalSLocal % bCount;
        int majTLocal = remT <= bCount / 2 ? baseT : baseT + 1;
        int hGerekLocal = remT <= bCount / 2 ? remT : 0;
        int eGerekLocal = remT > bCount / 2 ? (bCount - remT) : 0;

        int manuelH = aktifPersonel.where((k) => gunlukDurum[k]!.contains('HAMAL')).length;
        int manuelE = aktifPersonel.where((k) => gunlukDurum[k]!.contains('ENSECİ')).toList().length;

        // Eksik KARINCA varsa en yorgun kişileri otomatik karınca yap
        int bockEksiH = hGerekLocal - manuelH;
        if (bockEksiH > 0) {
          List<String> adayH = aktifPersonel.where((k) =>
            !gunlukDurum[k]!.contains('HAMAL') &&
            !gunlukDurum[k]!.contains('ENSECİ') &&
            !gunlukDurum[k]!.contains('OFF') &&
            !gunlukDurum[k]!.contains('KAZANDIŞI')
          ).toList();
          adayH.sort((a, b) => _getArsivYorgunlukOrtalamasi(b).compareTo(_getArsivYorgunlukOrtalamasi(a)));
          for (int i = 0; i < bockEksiH && i < adayH.length; i++) {
            gunlukDurum[adayH[i]]!.add('HAMAL_OTO');
          }
        }

        // Eksik BÖCEK varsa en az yorgun kişileri otomatik böcek yap
        int bockEksiE = eGerekLocal - manuelE;
        if (bockEksiE > 0) {
          List<String> adayE = aktifPersonel.where((k) =>
            !gunlukDurum[k]!.contains('ENSECİ') &&
            !gunlukDurum[k]!.contains('HAMAL') &&
            !gunlukDurum[k]!.contains('HAMAL_OTO') &&
            !gunlukDurum[k]!.contains('OFF') &&
            !gunlukDurum[k]!.contains('KAZANDIŞI')
          ).toList();
          adayE.sort((a, b) => _getArsivYorgunlukOrtalamasi(a).compareTo(_getArsivYorgunlukOrtalamasi(b)));
          for (int i = 0; i < bockEksiE && i < adayE.length; i++) {
            gunlukDurum[adayE[i]]!.add('ENSECİ_OTO');
          }
        }
      }
    }

    // Kişileri grupla (manuel + otomatik etiketler birlikte)
    List<String> karincalar = aktifPersonel.where((k) => gunlukDurum[k]!.contains('HAMAL') || gunlukDurum[k]!.contains('HAMAL_OTO')).toList();
    List<String> agustoslar = aktifPersonel.where((k) => gunlukDurum[k]!.contains('ENSECİ') || gunlukDurum[k]!.contains('ENSECİ_OTO')).toList();
    
    Set<String> aktifIlkSecilenler = this.ilkSecilenler.where((k) => aktifPersonel.contains(k)).toSet();
    Set<String> aktifSonSecilenler = this.sonSecilenler.where((k) => aktifPersonel.contains(k)).toSet();

    Map<String, int> kisiNumara = {};
    Set<int> kullanilanlar = {};
    
    // Uygunluk kontrolü (BK burada yok — BK mikro seçim değil, Phase 2'de yönetilir)
    bool _numaraUygun(String k, int num) {
      return true; // ORTA kısıtı kaldırıldı — sadece İLK/SON yönlendirme yapar
    }
    
    // Numaraları tur sayısına göre sırala (çoktan aza)
    List<int> tumNumaralar = List.generate(aCount, (i) => i);
    tumNumaralar.sort((a, b) {
      int diff = (numaraSlotlari[b]?.length ?? 0).compareTo(numaraSlotlari[a]?.length ?? 0);
      if (diff != 0) return diff;
      return _numAvg(a).compareTo(_numAvg(b));
    });
    
    // ─── BİZİMLE KAL (BK) ATAMASI ───
    // BK kişisinin son slottan (slotCount - 1) otomatik silineceği için 
    // eksik kadro ("-") bırakmaması adına son slotu içermeyen numaralar verilir.
    Set<String> aktifBKPersonel = this.bizimleKalSecilenler.where((k) => aktifPersonel.contains(k)).toSet();
    for (var k in aktifBKPersonel) {
      if (kisiNumara.containsKey(k)) continue;
      
      List<int> bkIcinUygun = tumNumaralar.where((n) {
        if (kullanilanlar.contains(n)) return false;
        return !(numaraSlotlari[n]?.contains(slotCount - 1) ?? false);
      }).toList();

      if (bkIcinUygun.isNotEmpty) {
        kisiNumara[k] = bkIcinUygun.first;
        kullanilanlar.add(bkIcinUygun.first);
      } else {
        int mecburi = tumNumaralar.firstWhere((n) => !kullanilanlar.contains(n));
        kisiNumara[k] = mecburi;
        kullanilanlar.add(mecburi);
      }
    }
    
    // ─── KARINCA → en çok tur çalışan numaraya ───
    karincalar.sort((a, b) => _getArsivYorgunlukOrtalamasi(a).compareTo(_getArsivYorgunlukOrtalamasi(b)));
    for (var k in karincalar) {
      // SON+KARINCA → yüksek tur + geç slot numarası tercih
      // İLK+KARINCA → yüksek tur + erken slot numarası tercih
      bool isSon = aktifSonSecilenler.contains(k);
      
      int? bestNum; int bestScore = -999999;
      for (var num in tumNumaralar) {
        if (kullanilanlar.contains(num)) continue;
        if (!_numaraUygun(k, num)) continue;
        int tur = numaraSlotlari[num]?.length ?? 0;
        int score = tur * 10000; // Çok tur en önemli
        if (isSon) score += (_numAvg(num) * 100).toInt(); // Geç slot bonus
        else score -= (_numAvg(num) * 100).toInt(); // Erken slot bonus
        if (score > bestScore) { bestScore = score; bestNum = num; }
      }
      if (bestNum != null) { kisiNumara[k] = bestNum; kullanilanlar.add(bestNum); }
    }
    
    // ─── AĞUSTOS BÖCEĞİ → en az tur çalışan numaraya ───
    agustoslar.sort((a, b) => _getArsivYorgunlukOrtalamasi(b).compareTo(_getArsivYorgunlukOrtalamasi(a)));
    for (var k in agustoslar) {
      int? bestNum; int bestScore = 999999;
      for (var num in tumNumaralar) {
        if (kullanilanlar.contains(num)) continue;
        if (!_numaraUygun(k, num)) continue;
        int tur = numaraSlotlari[num]?.length ?? 0;
        if (tur < bestScore) { bestScore = tur; bestNum = num; }
      }
      if (bestNum != null) { kisiNumara[k] = bestNum; kullanilanlar.add(bestNum); }
    }
    
    // ─── SUP ONLY kişileri farklı slotlara dağıt ───
    Map<int, int> slotSupOnlySayisi = {for (int i = 0; i < slotCount; i++) i: 0};
    // Zaten atanmış (BK, Karınca, Ağustos) SUP ONLY kişileri say
    for (var entry in kisiNumara.entries) {
      if (supOnlySecilenler.contains(entry.key)) {
        for (int s in numaraSlotlari[entry.value] ?? []) {
          slotSupOnlySayisi[s] = (slotSupOnlySayisi[s] ?? 0) + 1;
        }
      }
    }

    List<String> supOnlykisiler = aktifPersonel.where((k) => supOnlySecilenler.contains(k) && !kisiNumara.containsKey(k)).toList();
    supOnlykisiler.sort((a,b) => _getArsivYorgunlukOrtalamasi(a).compareTo(_getArsivYorgunlukOrtalamasi(b)));
    for (var k in supOnlykisiler) {
      int? bestNum; int bestScore = -999999;
      for (var num in tumNumaralar) {
        if (kullanilanlar.contains(num)) continue;
        if (!_numaraUygun(k, num)) continue;
        List<int> slots = numaraSlotlari[num] ?? [];
        int score = 0;
        int cakisma = 0;
        for (int s in slots) cakisma += slotSupOnlySayisi[s] ?? 0;
        score -= cakisma * 200000; // ASLA ÇAKIŞTIRMA
        if (score > bestScore) { bestScore = score; bestNum = num; }
      }
      if (bestNum != null) {
        kisiNumara[k] = bestNum;
        kullanilanlar.add(bestNum);
        for (int s in numaraSlotlari[bestNum] ?? []) {
          slotSupOnlySayisi[s] = (slotSupOnlySayisi[s] ?? 0) + 1;
        }
      }
    }

    // ─── SUP kişileri farklı slotlara dağıt ───
    // 4 SUP kişi varsa her biri farklı slotun SUP'u olmalı
    // Hangi slotlarda zaten SUP kişi var?
    Set<String> supHavuzu = aktifPersonel.where((k) => (yetkiler[k] ?? <String>{}).contains('SUP')).toSet();
    Map<int, int> slotSupSayisi = {for (int i = 0; i < slotCount; i++) i: 0};
    
    // Zaten atanmış SUP kişilerin slotlarını say
    for (var entry in kisiNumara.entries) {
      if (supHavuzu.contains(entry.key)) {
        for (int slot in numaraSlotlari[entry.value] ?? []) {
          slotSupSayisi[slot] = (slotSupSayisi[slot] ?? 0) + 1;
        }
      }
    }
    
    // Henüz atanmamış SUP kişiler (KARINCA/AĞUSTOS olmayan)
    List<String> kalanSuplar = aktifPersonel.where((k) => 
        supHavuzu.contains(k) && !kisiNumara.containsKey(k)).toList();
    kalanSuplar.sort((a, b) => _getArsivYorgunlukOrtalamasi(a).compareTo(_getArsivYorgunlukOrtalamasi(b)));
    
    for (var k in kalanSuplar) {
      bool isSon = aktifSonSecilenler.contains(k);
      bool isIlk = aktifIlkSecilenler.contains(k);
      
      int? bestNum; int bestScore = -999999;
      for (var num in tumNumaralar) {
        if (kullanilanlar.contains(num)) continue;
        if (!_numaraUygun(k, num)) continue;
        List<int> slots = numaraSlotlari[num] ?? [];
        
        int score = 0;
        // En önemli: slotlarında en az SUP çakışması olan numara
        int supCakisma = 0;
        for (int s in slots) supCakisma += slotSupSayisi[s] ?? 0;
        score -= supCakisma * 10000;
        
        // İLK/SON tercihi
        if (isSon) score += (_numAvg(num) * 100).toInt();
        else if (isIlk) score -= (_numAvg(num) * 100).toInt();
        
        // Tur sayısı bonusu
        score += (slots.length * 500);
        
        if (score > bestScore) { bestScore = score; bestNum = num; }
      }
      
      if (bestNum != null) {
        kisiNumara[k] = bestNum;
        kullanilanlar.add(bestNum);
        // SUP sayısını güncelle
        for (int s in numaraSlotlari[bestNum] ?? []) {
          slotSupSayisi[s] = (slotSupSayisi[s] ?? 0) + 1;
        }
      }
    }
    
    // ─── Kalan kişiler: İLK → erken, SON → geç, ORTA → orta, Normal → kalan ───
    List<String> kalanKisiler = aktifPersonel.where((k) => !kisiNumara.containsKey(k)).toList();
    kalanKisiler.sort((a, b) => _getArsivYorgunlukOrtalamasi(a).compareTo(_getArsivYorgunlukOrtalamasi(b)));
    
    List<String> ilkler = kalanKisiler.where((k) => aktifIlkSecilenler.contains(k)).toList();
    List<String> sonlar = kalanKisiler.where((k) => aktifSonSecilenler.contains(k)).toList();
    List<String> duznormal = kalanKisiler.where((k) => !aktifIlkSecilenler.contains(k) && !aktifSonSecilenler.contains(k)).toList();
    
    // Gündüz Arşivi - Ters Dağıtım Döngüsü (Negative Feedback Loop):
    // İnsanlar sürekli aynı turlarda çalışmasın diye, tarihsel olarak yüksek indeksli 
    // (sürekli SON'lara kalmış) kişileri EN BAŞA koyuyoruz.
    // Çünkü aşağıda `kalanNumaralar` sıralanırken en erken numaralar başa geliyor, 
    // böylece "Geçmişte Geç Kalan Adam -> Şimdi Erken Numara" eşleşmesi yaşanıyor.
    duznormal.sort((a, b) {
       double avgA = _getPersonelKarnesi(a).gunduzGecGirisOrani;
       double avgB = _getPersonelKarnesi(b).gunduzGecGirisOrani;
       return avgB.compareTo(avgA); // Yüksek olan (historically late) başa geçer
    });
    
    int ny = duznormal.length ~/ 2;
    List<String> eslemeListesi = [...ilkler, ...duznormal.sublist(0, ny), ...duznormal.sublist(ny), ...sonlar];
    
    // Kalan numaraları ortalama slot pozisyonuna göre sırala (erken → geç)
    List<int> kalanNumaralar = tumNumaralar.where((n) => !kullanilanlar.contains(n)).toList();
    kalanNumaralar.sort((a, b) => _numAvg(a).compareTo(_numAvg(b)));
    
    for (var k in eslemeListesi) {
      int? assignedNum;
      // Önce kısıtlamaya uyan numara bulmaya çalış
      for (int i = 0; i < kalanNumaralar.length; i++) {
        int num = kalanNumaralar[i];
        if (_numaraUygun(k, num)) {
          assignedNum = num;
          kalanNumaralar.removeAt(i);
          break;
        }
      }
      // Kısıtlamaya uyan numara bulunamadıysa ORTA kısıtını göz ardı ederek zorla ata
      // (Kişiyi tamamen bord dışında bırakmak yerine)
      if (assignedNum == null && kalanNumaralar.isNotEmpty) {
        assignedNum = kalanNumaralar.first;
        kalanNumaralar.removeAt(0);
      }
      // Tüm numaralar dolmuşsa bile kisiNumara'ya ekleme — fallback olarak tüm listeden al
      if (assignedNum == null) {
        // Hiç numara kalmadı ama kişiyi bırakma: en az kullananı bul
        int? minNum;
        int minCount = 999999;
        for (int n = 0; n < aCount; n++) {
          int cnt = kisiNumara.values.where((v) => v == n).length;
          if (cnt < minCount) { minCount = cnt; minNum = n; }
        }
        assignedNum = minNum;
      }
      if (assignedNum != null) {
        kisiNumara[k] = assignedNum;
        kullanilanlar.add(assignedNum);
      }
    }
    
    // (SUP ONLY doğrulaması Phase 2 tarafından yapılır — ölü kod temizlendi)
    
    // ═══════════════════════════════════════════════════
    // ADIM 3: NUMARA → SLOT ATAMASINA ÇEVİR
    // ═══════════════════════════════════════════════════
    Map<int, List<String>> slotAtamalari = {for (int i = 0; i < slotCount; i++) i: []};
    
    for (var entry in kisiNumara.entries) {
      for (int slot in numaraSlotlari[entry.value] ?? []) {
        slotAtamalari[slot]!.add(entry.key);
      }
    }
    
    // Atanmamış kişi varsa (çakışmadan değil, sayılar uyumsuzsa vb.) → fallback
    for (var k in aktifPersonel) {
      if (!kisiNumara.containsKey(k)) {
        // En boş numarayı veya ilk rastgele numarayı zorla vererek boş kalmasını engelle
        for (int slot = 0; slot < slotCount; slot++) {
          if (slotAtamalari[slot]!.length < slotKap[slot]) {
            slotAtamalari[slot]!.add(k);
            break;
          }
        }
      }
    }
    
    return slotAtamalari;
  }

  // ════════════════════════════════════════════════
  // GECE MODE — NUMARA SİSTEMLİ TERS ATAMA ALGORİTMASI
  // ════════════════════════════════════════════════
  Map<int, Map<String, String>> _geceAtama(List<String> aktifPersonel) {
    int slotCount = saatler.length;
    Map<int, Map<String, String>> gunlukPlan = {for (int i = 0; i < slotCount; i++) i: {}};
    if (aktifPersonel.isEmpty) return gunlukPlan;

    // Gündüz motorundaki bugunkuPozisyonlar'ın gece karşılığı — zigzag ve swap için
    Map<String, List<String>> bugunkuPozisyonlar = {for (var k in aktifPersonel) k: []};

    // ─────────────────────────────────────────────
    // ADIM 1: Slot Öncelik Sıralaması
    // ─────────────────────────────────────────────
    List<int> siralama = [];
    String _slotBaslangic(int s) => saatler[s].split(' - ')[0];

    int sabahSlotIdx   = List.generate(slotCount, (i) => i).firstWhere((s) => _slotBaslangic(s) == '05:30', orElse: () => -1);
    int araSlotIdx     = List.generate(slotCount, (i) => i).firstWhere((s) => _slotBaslangic(s) == '03:00', orElse: () => -1);
    int geceSlotIdx    = List.generate(slotCount, (i) => i).firstWhere((s) => _slotBaslangic(s) == '00:00' || _slotBaslangic(s) == '23:30', orElse: () => -1);
    int sonSaatSlotIdx = List.generate(slotCount, (i) => i).firstWhere((s) => _slotBaslangic(s) == '08:00', orElse: () => -1);

    List<int> aksamSlotIdxs = [];
    for (int i = 0; i < slotCount; i++) {
      if (i == sabahSlotIdx || i == araSlotIdx || i == geceSlotIdx || i == sonSaatSlotIdx) continue;
      if (geceSlotIdx == -1 || i < geceSlotIdx) {
        aksamSlotIdxs.add(i);
      }
    }

    if (sabahSlotIdx != -1) siralama.add(sabahSlotIdx);
    if (araSlotIdx != -1) siralama.add(araSlotIdx);
    if (geceSlotIdx != -1) siralama.add(geceSlotIdx);
    siralama.addAll(aksamSlotIdxs);
    if (sonSaatSlotIdx != -1 && sonSaatSlotIdx > sabahSlotIdx) siralama.add(sonSaatSlotIdx);

    // ─────────────────────────────────────────────
    // ADIM 2: Kişilere Numara Ata
    // ─────────────────────────────────────────────
    List<String> siraliKisiler = [];
    List<String> kalanlar = List.from(aktifPersonel);
    kalanlar.removeWhere((k) => geceOffSecilenler.contains(k));
    
    // Yeni sarmal için sıralama: gece1203 ilk (gece (00:00) pozisyonuna denk gelir),
    // sonra geceAra, sonra gece0508 (sabah pozisyonuna denk gelir)
    for (var k in gece1203Secilenler) { if (kalanlar.contains(k)) { siraliKisiler.add(k); kalanlar.remove(k); } }
    for (var k in geceAraSecilenler)  { if (kalanlar.contains(k)) { siraliKisiler.add(k); kalanlar.remove(k); } }
    for (var k in gece0508Secilenler) { if (kalanlar.contains(k)) { siraliKisiler.add(k); kalanlar.remove(k); } }
    kalanlar.sort((a, b) => _getArsivYorgunlukOrtalamasi(a).compareTo(_getArsivYorgunlukOrtalamasi(b)));
    siraliKisiler.addAll(kalanlar);
    
    if (siraliKisiler.isEmpty) return gunlukPlan;

    // ─────────────────────────────────────────────
    // ADIM 3: Slot Kapasitelerini ve OtoNotları Belirle
    // ─────────────────────────────────────────────
    Map<int, List<String>> slotPozisyonlari = {};
    DateTime yarin = _aktifTarih.add(const Duration(days: 1));
    String yarinStr = "${yarin.day.toString().padLeft(2, '0')}.${yarin.month.toString().padLeft(2, '0')}.${yarin.year}";
    List<TrafikVerisi> yarinT24 = _haftalikTrafikKasa[yarinStr] ?? List.generate(24, (i) => TrafikVerisi(0, 0));

    for (int slotIdx = 0; slotIdx < slotCount; slotIdx++) {
      String slotSaat = saatler[slotIdx];
      bool isAra = (slotIdx == araSlotIdx);
      bool isGece = (slotIdx == geceSlotIdx);
      bool isSabah = (slotIdx == sabahSlotIdx); // 05:30-08:00 — SUP yok
      
      int startH = int.parse(slotSaat.split(' - ')[0].split(':')[0]);
      int endH = int.parse(slotSaat.split(' - ')[1].split(':')[0]);
      
      List<int> sTaramasi = [];
      int h = startH;
      while (h != endH) {
        sTaramasi.add(h);
        h = (h + 1) % 24;
      }
      if (sTaramasi.isEmpty) sTaramasi.add(startH);

      Map<int, List<String>> hPozisyonlar = {};
      for (int ah in sTaramasi) {
        bool isYarin = (ah < 12);
        TrafikVerisi trf = isYarin ? yarinT24[ah] : anlikTrafik24[ah];
        double sLvlLocal = tamOtomatikDagitim ? _getIdealLevel(trf.genelToplam) : gunlukSeviye;
        hPozisyonlar[ah] = getSektorlerByLevel(sLvlLocal);
      }

      List<String> pozlar = [];
      Map<String, String> pozOtoNot = {};

      if (isAra) {
        pozlar = ['TWR', 'DEL'];
      } else if (isGece) {
        pozlar = ['TWR', 'DEL'];
        if (sTaramasi.isNotEmpty) {
           int ilkSaat = sTaramasi.first;
           for (var p in hPozisyonlar[ilkSaat]!) {
              if (!p.startsWith('SUP') && !pozlar.contains(p)) {
                 pozlar.add(p);
                 int bitisH = (ilkSaat + 1) % 24;
                 pozOtoNot[p] = " (-${bitisH.toString().padLeft(2, '0')}:00)";
              }
           }
        }
      } else {
        for (int ah in sTaramasi) {
          if (hPozisyonlar[ah]!.length > pozlar.length) pozlar = List.from(hPozisyonlar[ah]!);
        }
        // Sabah slotunda (05:30-08:00) SUP yok — gerekirse manuel yazılır
        if (isSabah) pozlar.removeWhere((p) => p.startsWith('SUP'));
        for (String p in pozlar) {
           if (p.startsWith('SUP')) continue;
           int firstH = -1;
           int lastH = -1;
           for (int i = 0; i < sTaramasi.length; i++) {
              if (hPozisyonlar[sTaramasi[i]]!.contains(p)) {
                 if (firstH == -1) firstH = i;
                 lastH = i;
              }
           }
           if (firstH > 0) pozOtoNot[p] = " (${sTaramasi[firstH].toString().padLeft(2, '0')}:00)";
           else if (lastH >= 0 && lastH < sTaramasi.length - 1) pozOtoNot[p] = " (-${sTaramasi[lastH + 1].toString().padLeft(2, '0')}:00)";
        }
      }
      slotPozisyonlari[slotIdx] = pozlar;
      _pozOtoNotlar[slotIdx] = Map.from(pozOtoNot);
    }

    // ─────────────────────────────────────────────
    // ADIM 4: Deterministik Havuz Sistemi
    //
    //  Her kişi TAM OLARAK 1 akşam + 1 gece slotunda yer alır.
    //  Havuz-A: gece1 seçilenler → Gece1 + akşam erken
    //  Havuz-B: ARA seçilenler   → ARA + akşam erken
    //  Havuz-C: sabah/son seçilenler → Sabah/Son + akşam son
    //  Havuz-D: seçilmemiş kalanlar → boş pozisyonlara dağıtılır
    // ─────────────────────────────────────────────

    // Akşam slotları kronolojik sırala
    List<int> aksamSiralanmis = List.from(aksamSlotIdxs);
    aksamSiralanmis.sort((a, b) {
      int aH = int.parse(saatler[a].split(' - ')[0].split(':')[0]);
      int bH = int.parse(saatler[b].split(' - ')[0].split(':')[0]);
      return aH.compareTo(bH);
    });

    // Gece slotları kronolojik sıra
    List<int> geceSirali = [];
    if (geceSlotIdx   != -1) geceSirali.add(geceSlotIdx);
    if (araSlotIdx    != -1) geceSirali.add(araSlotIdx);
    if (sabahSlotIdx  != -1) geceSirali.add(sabahSlotIdx);
    if (sonSaatSlotIdx != -1) geceSirali.add(sonSaatSlotIdx);

    // Akşam listesi: tüm siraliKisiler + geceOff kişileri
    List<String> aksamListe = List.from(siraliKisiler);
    for (var k in geceOffSecilenler) {
      if (aktifPersonel.contains(k) && !aksamListe.contains(k)) aksamListe.add(k);
    }

    // Gece listesi: siraliKisiler (geceOff zaten yok)
    List<String> geceListe = List.from(siraliKisiler);

    Map<int, List<String>> slotTakiKisiler = {};
    for (int i = 0; i < slotCount; i++) slotTakiKisiler[i] = [];

    // Her kişinin akşam ve gece ataması (çift yazımı önler)
    Map<String, int> kisiAksamSlot = {};  // kişi → akşam slot idx
    Map<String, int> kisiGeceSlot = {};   // kişi → gece slot idx

    // Yardımcı: Kişiyi slota yaz (kapasite kontrolü ile)
    bool ataSlot(int slotIdx, String kisi) {
      int kap = slotPozisyonlari[slotIdx]?.length ?? 0;
      if (slotTakiKisiler[slotIdx]!.length < kap && !slotTakiKisiler[slotIdx]!.contains(kisi)) {
        slotTakiKisiler[slotIdx]!.add(kisi);
        return true;
      }
      return false;
    }

    // ── HAVUZ-A: Gece1 (00:00-03:00) Seçilenler ──
    for (var k in gece1203Secilenler) {
      if (!geceListe.contains(k)) continue;
      // Gece slotuna sabitle
      if (geceSlotIdx != -1 && ataSlot(geceSlotIdx, k)) {
        kisiGeceSlot[k] = geceSlotIdx;
      }
      // Akşam karşılığı: EN ERKEN akşam slotu
      for (int asi in aksamSiralanmis) {
        if (ataSlot(asi, k)) { kisiAksamSlot[k] = asi; break; }
      }
    }

    // ── HAVUZ-B: ARA (03:00-05:30) Seçilenler ──
    for (var k in geceAraSecilenler) {
      if (!geceListe.contains(k)) continue;
      // ARA slotuna sabitle
      if (araSlotIdx != -1 && ataSlot(araSlotIdx, k)) {
        kisiGeceSlot[k] = araSlotIdx;
      }
      // Akşam karşılığı: erken akşam slotu (gece1 ile aynı olabilir)
      for (int asi in aksamSiralanmis) {
        if (ataSlot(asi, k)) { kisiAksamSlot[k] = asi; break; }
      }
    }

    // ── HAVUZ-C: Sabah (05:30-08:00) + Son Saat (08:00-09:00) Seçilenler ──
    for (var k in gece0508Secilenler) {
      if (!geceListe.contains(k)) continue;
      if (sabahSlotIdx != -1 && ataSlot(sabahSlotIdx, k)) {
        kisiGeceSlot[k] = sabahSlotIdx;
      }
      // Akşam karşılığı: EN SON akşam slotu
      for (int asi in aksamSiralanmis.reversed) {
        if (ataSlot(asi, k)) { kisiAksamSlot[k] = asi; break; }
      }
    }
    for (var k in gece0809Secilenler) {
      if (!geceListe.contains(k)) continue;
      if (sonSaatSlotIdx != -1 && ataSlot(sonSaatSlotIdx, k)) {
        kisiGeceSlot[k] = sonSaatSlotIdx;
      }
      for (int asi in aksamSiralanmis.reversed) {
        if (ataSlot(asi, k)) { kisiAksamSlot[k] = asi; break; }
      }
    }

    // ── HAVUZ-D: Seçilmemiş Kalanlar ──
    // geceOff kişileri: sadece akşam slotlarında
    for (var k in geceOffSecilenler) {
      if (!aksamListe.contains(k) || kisiAksamSlot.containsKey(k)) continue;
      for (int asi in aksamSiralanmis) {
        if (ataSlot(asi, k)) { kisiAksamSlot[k] = asi; break; }
      }
    }

    // Kalan gece personeli: önce akşam boşluklarını doldur, sonra gece boşluklarını
    List<String> geceKalanHavuz = geceListe.where((k) => !kisiGeceSlot.containsKey(k)).toList();
    // Yorgunluk sırasına göre sırala
    geceKalanHavuz.sort((a, b) => _getArsivYorgunlukOrtalamasi(a).compareTo(_getArsivYorgunlukOrtalamasi(b)));

    // Kalanlar için akşam ataması
    for (var k in geceKalanHavuz) {
      if (kisiAksamSlot.containsKey(k)) continue;
      for (int asi in aksamSiralanmis) {
        if (ataSlot(asi, k)) { kisiAksamSlot[k] = asi; break; }
      }
    }

    // Kalanlar için gece ataması
    for (var k in geceKalanHavuz) {
      if (kisiGeceSlot.containsKey(k)) continue;
      for (int gsi in geceSirali) {
        if (ataSlot(gsi, k)) { kisiGeceSlot[k] = gsi; break; }
      }
    }

    // ─────────────────────────────────────────────
    // ADIM 5: Kronolojik Pozisyon Ataması (Zigzag)
    // ─────────────────────────────────────────────
    Set<String> supHavuzu = tumPersonelHavuzu.where((k) => (yetkiler[k] ?? <String>{}).contains('SUP')).toSet();

    for (int slotIdx = 0; slotIdx < slotCount; slotIdx++) {
      if (!slotTakiKisiler.containsKey(slotIdx)) continue;
      
      List<String> pozList = slotPozisyonlari[slotIdx]!;
      List<String> kList = slotTakiKisiler[slotIdx]!;
      Map<String, String> atama = {for (var p in pozList) p: "-"};
      Set<String> atanmislar = {};
      
      String? supPos = pozList.firstWhere((p) => p.split('_')[0].split('/')[0] == 'SUP', orElse: () => '');
      if (supPos.isNotEmpty) {
        String? supKisi;
        for (var k in kList) {
          if (supOnlySecilenler.contains(k)) { supKisi = k; break; }
        }
        if (supKisi == null) {
          int minSupOturma = 9999;
          for (var k in kList) {
            if (supHavuzu.contains(k)) {
              int s = bugunkuPozisyonlar[k]!.where((p) => p.startsWith('SUP')).length;
              if (s < minSupOturma) {
                minSupOturma = s;
                supKisi = k;
              }
            }
          }
        }
        if (supKisi != null) {
          atama[supPos] = supKisi;
          atanmislar.add(supKisi);
          bugunkuPozisyonlar[supKisi]!.add(supPos);
        }
      }

      for (var pos in pozList) {
        if (atama[pos] != "-") continue;
        
        String core = pos.split('_')[0].split('/')[0];
        String? bestK;
        int bestScore = -999999;
        
        for (var k in kList) {
          if (atanmislar.contains(k)) continue;
          // In night mode, we ignore supOnly restriction because there are no SUP positions.
          // Everyone assigned to the slot must work the available TWR/DEL/GND chairs.
          // if (supOnlySecilenler.contains(k)) continue; 
          
          int score = 0;
          var kYetki = yetkiler[k] ?? <String>{};
          bool yetkili = kYetki.isEmpty || kYetki.contains(pos) || kYetki.contains(core);
          if (!yetkili) score -= 10000;
          if (kYetki.isNotEmpty && (kYetki.contains(pos) || kYetki.contains(core))) score += 5000;
          
          int oSayi = bugunkuPozisyonlar[k]!.where((p) => p.split('_')[0].split('/')[0] == core).length;
          score -= oSayi * 2000;
          
          if (bugunkuPozisyonlar[k]!.isNotEmpty) {
            String lastCore = bugunkuPozisyonlar[k]!.last.split('_')[0].split('/')[0];
            if (lastCore != core) score += 500;
          }
          
          if (score > bestScore) {
            bestScore = score;
            bestK = k;
          }
        }
        
        if (bestK != null) {
          atama[pos] = bestK;
          atanmislar.add(bestK);
          bugunkuPozisyonlar[bestK]!.add(pos);
        }
      }
      gunlukPlan[slotIdx] = atama;
    }

    // ─────────────────────────────────────────────
    // ADIM 6: Swap / İnce Ayar
    // ─────────────────────────────────────────────
    for (int slotIdx = 0; slotIdx < slotCount; slotIdx++) {
      if (!gunlukPlan.containsKey(slotIdx)) continue;
      Map<String, String> atama = gunlukPlan[slotIdx]!;
      
      for (var entry in atama.entries.toList()) {
        String pos = entry.key;
        String kisi = entry.value;
        if (kisi == "-") continue;
        
        String core = pos.split('_')[0].split('/')[0];
        List<String> oncekiPozlar = bugunkuPozisyonlar[kisi]!
            .sublist(0, bugunkuPozisyonlar[kisi]!.indexOf(pos) >= 0 ? bugunkuPozisyonlar[kisi]!.indexOf(pos) : 0);
            
        bool tekrarVar = oncekiPozlar.any((p) => p.split('_')[0].split('/')[0] == core);
        if (!tekrarVar) continue;
        
        if (supOnlySecilenler.contains(kisi)) continue;
        if (core == 'SUP' && supHavuzu.contains(kisi)) continue;
        
        for (var entry2 in atama.entries.toList()) {
          String pos2 = entry2.key;
          String kisi2 = entry2.value;
          if (kisi2 == "-" || kisi2 == kisi) continue;
          if (supOnlySecilenler.contains(kisi2)) continue;
          
          String core2 = pos2.split('_')[0].split('/')[0];
          
          int posIdx2 = bugunkuPozisyonlar[kisi2]!.indexOf(pos2);
          List<String> prev2Poslar = bugunkuPozisyonlar[kisi2]!
              .sublist(0, posIdx2 >= 0 ? posIdx2 : 0);
          bool kisi2TekrarPos = prev2Poslar.any((p) => p.split('_')[0].split('/')[0] == core);
          bool kisi1TekrarPos2 = oncekiPozlar.any((p) => p.split('_')[0].split('/')[0] == core2);
          
          if (core == 'SUP' && !supHavuzu.contains(kisi2)) continue;
          if (core2 == 'SUP' && !supHavuzu.contains(kisi)) continue;
          
          if (!kisi2TekrarPos && !kisi1TekrarPos2) {
            atama[pos] = kisi2;
            atama[pos2] = kisi;
            bugunkuPozisyonlar[kisi]!.remove(pos);
            bugunkuPozisyonlar[kisi]!.add(pos2);
            bugunkuPozisyonlar[kisi2]!.remove(pos2);
            bugunkuPozisyonlar[kisi2]!.add(pos);
            break;
          }
        }
      }
    }

    // ─────────────────────────────────────────────
    // ADIM 7: MANUEL PİN KİŞİ ATAMALARI
    // ─────────────────────────────────────────────
    _manuelAtananKisiler[_aktifTarihVeMod]?.removeWhere((slot, pinMap) {
      if (slot >= slotCount) return true;
      pinMap.removeWhere((pos, kisi) => kisi != "-" && !aktifPersonel.contains(kisi));
      return pinMap.isEmpty;
    });
    
    for (int slot = 0; slot < slotCount; slot++) {
      Map<String, String>? manuelPinler = _manuelAtananKisiler[_aktifTarihVeMod]?[slot];
      if (manuelPinler != null && gunlukPlan.containsKey(slot)) {
        manuelPinler.forEach((pos, kisi) {
           if (!gunlukPlan[slot]!.containsKey(pos)) return;
           
           String? eskiKisi = gunlukPlan[slot]![pos];
           if (eskiKisi != null && eskiKisi != "-") {
              bugunkuPozisyonlar[eskiKisi]?.remove(pos);
           }
           gunlukPlan[slot]![pos] = kisi;
           if (kisi != "-" && bugunkuPozisyonlar.containsKey(kisi)) {
              bugunkuPozisyonlar[kisi]!.add(pos);
           }
        });
      }
    }

    return gunlukPlan;
  }
  /// Phase 2: Zigzag pozisyon atama + SUP havuzu + ince ayar
  /// Döndürür: {slotIndex: {pozisyon: kişi, ...}, ...}
  Map<int, Map<String, String>> _phase2PozisyonAtama(
    Map<int, List<String>> slotAtamalari, 
    List<String> aktifPersonel,
    Set<String> aktifBK
  ) {
    int slotCount = saatler.length;
    Map<int, Map<String, String>> gunlukPlan = {};
    _pozOtoNotlar = {}; // Her hesaplamada oto-notları sıfırla
    
    // Kişinin bugün hangi pozisyonlarda oturduğunu takip et
    Map<String, List<String>> bugunkuPozisyonlar = {for (var k in aktifPersonel) k: []};
    
    Set<String> supHavuzu = aktifPersonel.where((k) => (yetkiler[k] ?? <String>{}).contains('SUP')).toSet();
    Set<String> supYazmislar = {};
    
    for (int slot = 0; slot < slotCount; slot++) {
      int startH = int.parse(saatler[slot].split(' - ')[0].split(':')[0]);
      int endH = int.parse(saatler[slot].split(' - ')[1].split(':')[0]);

      Map<String, String> pozOtoNot = {};
      List<String> pozisyonlar = [];

      List<int> sTaramasi = [];
         int h = startH;
         while(h != endH) {
            sTaramasi.add(h);
            h = (h + 1) % 24;
         }
         if (sTaramasi.isEmpty) sTaramasi.add(startH);
         
         Map<int, List<String>> hPozisyonlar = {};
         for (int ah in sTaramasi) {
            TrafikVerisi trf = anlikTrafik24[ah];
            double sLvlLocal = tamOtomatikDagitim ? _getIdealLevel(trf.genelToplam) : gunlukSeviye;
            hPozisyonlar[ah] = getSektorlerByLevel(sLvlLocal);
         }
         
         for (int ah in sTaramasi) {
            if (hPozisyonlar[ah]!.length > pozisyonlar.length) {
               pozisyonlar = List.from(hPozisyonlar[ah]!);
            }
         }
         
         for (String p in pozisyonlar) {
            if (p.startsWith('SUP')) continue;
            
            int firstH = -1;
            int lastH = -1;
            for(int i = 0; i < sTaramasi.length; i++) {
               if(hPozisyonlar[sTaramasi[i]]!.contains(p)) {
                  if (firstH == -1) firstH = i;
                  lastH = i;
               }
            }
            if (firstH > 0) {
               pozOtoNot[p] = " (${sTaramasi[firstH].toString().padLeft(2, '0')}:00)";
            } else if (lastH >= 0 && lastH < sTaramasi.length - 1) {
               int bitisSaat = sTaramasi[lastH + 1];
               pozOtoNot[p] = " (-${bitisSaat.toString().padLeft(2, '0')}:00)";
            }
         }

      _pozOtoNotlar[slot] = Map.from(pozOtoNot); // Oto-notları ayrı sakla (isimle karıştırma)

      List<String> kisiler = List.from(slotAtamalari[slot] ?? []);
      
      // BK kişisi son slotta pozisyona oturmaz (tek BK kuralı)
      if (slot == slotCount - 1) {
        kisiler.removeWhere((k) => aktifBK.contains(k));
      }
      
      // Personel eksik olduğunda TWR yerine GND'nin boş kalması için 
      // öncelik sırası korunmalıdır. (tersine çevrilmez - score sistemi rotasyonu yapıyor zaten)
      List<String> pozSirasi = List.from(pozisyonlar);
      
      Map<String, String> atama = {for (var p in pozisyonlar) p: "-"};
      Set<String> atanmislar = {};
      
      // ─────────────────────────────────────────────
      // ADIM 1: SUP koltuğunu önce doldur
      // ─────────────────────────────────────────────
      String? supPos = pozisyonlar.firstWhere(
        (p) => p.split('_')[0].split('/')[0] == 'SUP', orElse: () => '');
      
      if (supPos.isNotEmpty && atama[supPos] == "-") {
        String? supKisi;
        
        for (var k in kisiler) {
          if (atanmislar.contains(k)) continue;
          if (supOnlySecilenler.contains(k)) { supKisi = k; break; }
        }
        
        if (supKisi == null) {
          // Öncelik 0: SUP-only kişi (sadece SUP yetkisi — başka koltuğa atanamaz)
          for (var k in kisiler) {
            if (atanmislar.contains(k)) continue;
            if (supHavuzu.contains(k)) {
              var y = yetkiler[k] ?? <String>{};
              bool supOnly = y.length == 1 && y.contains('SUP');
              if (supOnly) { supKisi = k; break; }
            }
          }
        }
        // Öncelik 1: SUP havuzunda olup henüz SUP yazmamış
        if (supKisi == null) {
          for (var k in kisiler) {
            if (atanmislar.contains(k)) continue;
            if (supHavuzu.contains(k) && !supYazmislar.contains(k)) {
              supKisi = k;
              break;
            }
          }
        }
        // Öncelik 2: Grup içinden Joker SUP (Gerçek SUP'lar dinlensin diye)
        if (supKisi == null) {
          String? bestSup;
          int bestV = -9999;
          for (var k in kisiler) {
            if (atanmislar.contains(k)) continue;
            int score = 0;
            // Gerçek SUP ise ve buraya kadar geldiyse (yani zaten SUP yapmışsa), onu seçmekten KAÇIN (dinlensin)
            if (supHavuzu.contains(k)) score -= 1000;
            // Gruptaki diğer kişiler arasında da henüz SUP "Jokerliği" yapmamış olanı tercih et
            if (supYazmislar.contains(k)) score -= 500;
            
            if (score > bestV) { bestV = score; bestSup = k; }
          }
          supKisi = bestSup;
        }
        
        if (supKisi != null) {
          atama[supPos] = supKisi; // Yalın isim sakla (oto-not ayrı haritada)
          atanmislar.add(supKisi);
          supYazmislar.add(supKisi);
          bugunkuPozisyonlar[supKisi]!.add(supPos);
        }
      }
      
      // ─────────────────────────────────────────────
      // ADIM 2: Kalan pozisyonları zigzag sırasıyla ata
      // ─────────────────────────────────────────────
      for (var pos in pozSirasi) {
        if (atama[pos] != "-") continue; // SUP zaten dolu
        
        String? bestK;
        int bestScore = -999999;
        
        for (var k in kisiler) {
          if (atanmislar.contains(k)) continue;
          // FIX 2: SUP ONLY kişi zaten ADIM 1'de SUP koltuğuna atandı;
          // eğer bu slotta SUP pozisyonu yoksa veya SUP zaten doluysa bu kişiyi ASLA başka koltuğa atma
          if (supOnlySecilenler.contains(k)) continue; // SUP ONLY başka koltuğa atanamaz
          
          int score = 0;
          String core = pos.split('_')[0].split('/')[0];

          // Pozisyon çeşitliliği: daha önce bu pozisyonda oturmamış tercih et
          if (bugunkuPozisyonlar[k]!.contains(pos)) score -= 5000;
          bool ayniCoreVar = bugunkuPozisyonlar[k]!.any(
            (p) => p.split('_')[0].split('/')[0] == core);
          if (ayniCoreVar) score -= 3000;
          
          // Gündüz Zigzag rotasyonu
          if (bugunkuPozisyonlar[k]!.isNotEmpty) {
            String lastCore = bugunkuPozisyonlar[k]!.last.split('_')[0].split('/')[0];
            if (lastCore != core) score += 2000;
          }
          
          if (score > bestScore) { bestScore = score; bestK = k; }
        }
        
        if (bestK != null) {
          atama[pos] = bestK; // Yalın isim sakla (oto-not ayrı haritada)
          atanmislar.add(bestK);
          bugunkuPozisyonlar[bestK]!.add(pos);
        }
      }
      
      gunlukPlan[slot] = atama;
    }
    
    // ─────────────────────────────────────────────
    // ADIM 3: İnce ayar — aynı pozisyonda tekrar eden kişileri swap et
    // ─────────────────────────────────────────────
    for (int slot = 0; slot < slotCount; slot++) {
      Map<String, String> atama = gunlukPlan[slot]!;
      List<String> kisiler = slotAtamalari[slot] ?? [];
      
      // Bu slottaki her kişinin önceki turlarını kontrol et
      for (var entry in atama.entries.toList()) {
        String pos = entry.key;
        String kisi = entry.value;
        if (kisi == "-") continue;
        
        String core = pos.split('_')[0].split('/')[0];
        
        // Bu kişi bu core pozisyonunda daha önce oturmuş mu?
        List<String> oncekiPozlar = [];
        for (int prev = 0; prev < slot; prev++) {
          String? prevPos = gunlukPlan[prev]!.entries
            .where((e) => e.value == kisi)
            .map((e) => e.key)
            .firstOrNull;
          if (prevPos != null) oncekiPozlar.add(prevPos);
        }
        
        bool tekrarVar = oncekiPozlar.any(
          (p) => p.split('_')[0].split('/')[0] == core);
        
        if (!tekrarVar) continue; // Tekrar yok, swap gerekmez
        if (supOnlySecilenler.contains(kisi)) continue; // SUP ONLY ASLA TAKAS EDİLMEZ
        if (core == 'SUP' && supHavuzu.contains(kisi)) continue; // SUP havuzu tekrar yapabilir
        
        // Aynı gruptaki başka biriyle swap et
        for (var entry2 in atama.entries.toList()) {
          String pos2 = entry2.key;
          String kisi2 = entry2.value;
          if (kisi2 == "-" || kisi2 == kisi) continue;
          if (supOnlySecilenler.contains(kisi2)) continue; // SUP ONLY ASLA TAKAS EDİLMEZ
          
          String core2 = pos2.split('_')[0].split('/')[0];
          
          // kisi2 pos'a geçerse tekrar oluyor mu?
          bool kisi2TekrarPos = false;
          for (int prev = 0; prev < slot; prev++) {
            String? prev2Pos = gunlukPlan[prev]!.entries
              .where((e) => e.value == kisi2)
              .map((e) => e.key)
              .firstOrNull;
            if (prev2Pos != null && prev2Pos.split('_')[0].split('/')[0] == core) {
              kisi2TekrarPos = true;
            }
          }
          
          // kisi pos2'ye geçerse tekrar oluyor mu?
          bool kisi1TekrarPos2 = oncekiPozlar.any(
            (p) => p.split('_')[0].split('/')[0] == core2);
          
          // SUP pozisyonlarını SUP havuzu dışındakilerle swap etme
          if (core == 'SUP' && !supHavuzu.contains(kisi2)) continue;
          if (core2 == 'SUP' && !supHavuzu.contains(kisi)) continue;
          
          // Swap her iki taraf için de iyileşme sağlıyorsa yap
          if (!kisi2TekrarPos && !kisi1TekrarPos2) {
            // Swap!
            atama[pos] = kisi2;
            atama[pos2] = kisi;
            // bugunkuPozisyonlar güncelle
            bugunkuPozisyonlar[kisi]!.remove(pos);
            bugunkuPozisyonlar[kisi]!.add(pos2);
            bugunkuPozisyonlar[kisi2]!.remove(pos2);
            bugunkuPozisyonlar[kisi2]!.add(pos);
            break;
          }
        }
      }
    }
    
    // ─────────────────────────────────────────────
    // ADIM 4: MANUEL PİN KİŞİ ATAMALARI UYGULA (POST-PROCESS OVERRIDE)
    // ─────────────────────────────────────────────
    
    // Güvenlik Filtresi: Eski bordlardan kalan geçersiz pinleri temizle
    // (farklı slot sayısından kaynaklanan out-of-range pinler ve güncel aktif olmayan kişiler)
    _manuelAtananKisiler[_aktifTarihVeMod]?.removeWhere((slot, pinMap) {
      // Mevcut senaryo slot sayısını aşan pinleri sil
      if (slot >= slotCount) return true;
      // Slot içindeki geçersiz kişileri temizle
      pinMap.removeWhere((pos, kisi) => kisi != "-" && !aktifPersonel.contains(kisi));
      return pinMap.isEmpty;
    });
    
    for (int slot = 0; slot < slotCount; slot++) {
      Map<String, String>? manuelPinler = _manuelAtananKisiler[_aktifTarihVeMod]?[slot];
      if (manuelPinler != null) {
        manuelPinler.forEach((pos, kisi) {
           // Pozisyon mevcut slot'ta yoksa (seviye değişmiş olabilir), pinleme yapma
           if (!gunlukPlan[slot]!.containsKey(pos)) return;
           
           // Eski kişiyi bul ve pozisyon kaydından düş (istatistiği düzeltmek için)
           String? eskiKisi = gunlukPlan[slot]![pos];
           if (eskiKisi != null && eskiKisi != "-") {
              bugunkuPozisyonlar[eskiKisi]?.remove(pos);
           }
           
           // Manuel pini zorla yaz ('-' olsa bile)
           gunlukPlan[slot]![pos] = kisi;
           
           // Eğer manuel kişi gerçek bir insansa, istatistiğe ekle
           if (kisi != "-" && bugunkuPozisyonlar.containsKey(kisi)) {
              bugunkuPozisyonlar[kisi]!.add(pos);
           }
        });
      }
    }

    
    return gunlukPlan;
  }

  void _istatistikleriYenidenHesapla(Map<int, Map<String, String>> plan) {
    _hafizayiSifirla();
    for (int i = 0; i < saatler.length; i++) {
      if (plan[i] == null) continue;
      plan[i]!.forEach((pos, kisi) {
        if (kisi != "-") {
          String core = pos.split('_')[0].split('/')[0];
          turSayisi[kisi] = (turSayisi[kisi] ?? 0) + 1;
          if(core == "DEL") delSayisi[kisi] = (delSayisi[kisi] ?? 0) + 1;
          else if(core == "TWR") twrSayisi[kisi] = (twrSayisi[kisi] ?? 0) + 1;
          else if(core == "GND") gndSayisi[kisi] = (gndSayisi[kisi] ?? 0) + 1;
          else if(core == "SUP") supSayisi[kisi] = (supSayisi[kisi] ?? 0) + 1;
        }
      });
    }
  }

  void _arsiveOtomatikKaydet({bool kaydet = true}) {
    if (anlikTrafik.isEmpty) return;
    
    Set<String> aktifBK = isGunduzVardiyasi ? Set.from(bizimleKalSecilenler) : {};
    var aktifPersonel = tumPersonelHavuzu.where((k) => !gunlukDurum[k]!.contains('OFF') && !gunlukDurum[k]!.contains('KAZANDIŞI')).toList();

    if (isGunduzVardiyasi && aktifBK.isEmpty && tamOtomatikDagitim) {
      List<BordArsivi> ayniTipArsiv = tamArsiv.where((a) {
        if (a.satirlar.isEmpty) return false;
        String ilkSaat = a.satirlar.first.first;
        bool arsivGunduz = ilkSaat.startsWith("08:") || ilkSaat.startsWith("09:") || ilkSaat.startsWith("10:");
        return arsivGunduz == isGunduzVardiyasi;
      }).toList();

      Set<String> son4BK = {};
      int count = 0;
      for (int i = ayniTipArsiv.length - 1; i >= 0 && count < 4; i--) {
        String bk = ayniTipArsiv[i].bizimleKal;
        if (bk != "-") son4BK.addAll(bk.split(', ').map((e) => e.trim()));
        count++;
      }

      Map<String, int> totalBK = {for (var k in tumPersonelHavuzu) k: 0};
      for (var a in tamArsiv) {
        if (a.bizimleKal != "-") {
          for (var p in a.bizimleKal.split(', ').map((e) => e.trim())) {
            if (totalBK.containsKey(p)) totalBK[p] = totalBK[p]! + 1;
          }
        }
      }

      var adaylar = aktifPersonel.where((p) => !son4BK.contains(p)).toList();
      if (adaylar.isNotEmpty) {
        adaylar.sort((a, b) => totalBK[a]!.compareTo(totalBK[b]!));
        aktifBK.add(adaylar.first);
      } else if (aktifPersonel.isNotEmpty) {
        // Tüm aktif personel son 4'te BK görmüş — en az toplam BK olan seçilir
        List<String> hepsi = List.from(aktifPersonel);
        hepsi.sort((a, b) => totalBK[a]!.compareTo(totalBK[b]!));
        aktifBK.add(hepsi.first);
      }
    }

    // BK kişisi aktif kadroda KALIR (shift çalışır, sadece son slota atanamaz)

    double tGLvl = gunlukSeviye;
    // Tablo başlık sektörleri: tamOtomatik modda hakim seviyeye göre,
    // ama minimum 4 pozisyon göster (DEL, TWR, GND, SUP)
    List<String> tabloBaslikSektorleri = getSektorlerByLevel(tGLvl.clamp(4.0, 7.0));
    
    int totalS = 0;
    for (int i = 0; i < saatler.length; i++) {
      totalS += getSektorlerByLevel(tamOtomatikDagitim ? _getIdealLevel(anlikTrafik[i % anlikTrafik.length].genelToplam) : gunlukSeviye).length;
    }
    
    int aCount = aktifPersonel.length;
    int baseTur = aCount > 0 ? (totalS ~/ aCount) : 0;
    int rem = aCount > 0 ? (totalS % aCount) : 0;
    int majT = aCount > 0 ? (rem <= aCount / 2 ? baseTur : baseTur + 1) : 0;

    _hafizayiSifirla();
    List<List<String>> tempRows = [];
    List<TrafikVerisi> tempTrf = []; 
    List<TrafikVerisi> tempGercekciTrf = []; 
    List<HavaDurumu> tempHava = [];
    
    Map<int, Map<String, String>> gunlukPlan = {};
    if (isGunduzVardiyasi) {
      // GÜNDÜZ: Phase 1 (Slotlara dağılım) + Phase 2 (Pozisyonlara dağılım)
      Map<int, List<String>> slotAtamalari = _phase1SlotAtama(aktifPersonel);
      gunlukPlan = _phase2PozisyonAtama(slotAtamalari, aktifPersonel, aktifBK);
    } else {
      // GECE: Bağımsız Motor (Numara tabanlı tam atama)
      gunlukPlan = _geceAtama(aktifPersonel);
    }
    
    // İstatistikleri hesapla (post-process sonrası doğru veriler)
    _istatistikleriYenidenHesapla(gunlukPlan);

    for (int i = 0; i < saatler.length; i++) {
      TrafikVerisi tObj = anlikTrafik[i % anlikTrafik.length];
      tempTrf.add(tObj);
      tempGercekciTrf.add(anlikGercekciTrafik[i % anlikGercekciTrafik.length]); 
      tempHava.add(anlikHava[i % anlikHava.length]);

      Map<String, String> atamalar = gunlukPlan[i]!;
      List<String> row = [];
      for (String header in tabloBaslikSektorleri) {
        String cellText = "-";
        String headerCore = header.split('_')[0].split('/')[0];
        String notKey = header; // Oto-not anahtarı
        
        if (atamalar.containsKey(header)) {
          cellText = atamalar[header]!;
          notKey = header;
        }
        // Seviye farkı eşleme: atamada TWR varsa → TWR_W'ye yaz
        else if (headerCore == 'TWR' && atamalar.containsKey('TWR')) {
          cellText = (header == tabloBaslikSektorleri.firstWhere((h) => h.startsWith('TWR'), orElse: () => '')) ? atamalar['TWR']! : '-';
          notKey = 'TWR';
        }
        else if (headerCore == 'GND' && atamalar.containsKey('GND')) {
          cellText = (header == tabloBaslikSektorleri.firstWhere((h) => h.startsWith('GND'), orElse: () => '')) ? atamalar['GND']! : '-';
          notKey = 'GND';
        }
        // Seviye farkı: atamada TWR_W var ama tabloda TWR → ilk TWR varyantını yaz
        else if (header == 'TWR') {
          cellText = atamalar['TWR_W'] ?? atamalar['TWR_E'] ?? '-';
          notKey = atamalar.containsKey('TWR_W') ? 'TWR_W' : 'TWR_E';
        }
        else if (header == 'GND') {
          cellText = atamalar['GND_S'] ?? atamalar['GND_N'] ?? atamalar['GND_C'] ?? '-';
          notKey = atamalar.containsKey('GND_S') ? 'GND_S' : (atamalar.containsKey('GND_N') ? 'GND_N' : 'GND_C');
        }
        
        // Oto-notu sadece UI gösterimi için ekle (istatistik/swap yalın isimle çalışır)
        if (cellText != '-') {
          String otoNot = _pozOtoNotlar[i]?[notKey] ?? '';
          if (otoNot.isNotEmpty) cellText += otoNot;
        }
        
        row.add(cellText);
      }
      tempRows.add([saatler[i], ...row]);
    }
    
    Map<String, Map<String, dynamic>> bugunIstat = {};
    bool herhangiManuelKarinca = _herhangiManuelKarinca;
    bool herhangiManuelEnseci  = _herhangiManuelEnseci;
    for(var k in tumPersonelHavuzu) {
      int ts = turSayisi[k] ?? 0;
      bool isHamal  = isGunduzVardiyasi && ((gunlukDurum[k]?.contains('HAMAL') ?? false) || (gunlukDurum[k]?.contains('HAMAL_OTO') ?? false) || (ts > majT));
      bool isEnseci = isGunduzVardiyasi && ((gunlukDurum[k]?.contains('ENSECİ') ?? false) || (gunlukDurum[k]?.contains('ENSECİ_OTO') ?? false) || (ts < majT && ts > 0));
      bugunIstat[k] = { 
        'DEL': delSayisi[k] ?? 0, 'TWR': twrSayisi[k] ?? 0, 'GND': gndSayisi[k] ?? 0, 'SUP': supSayisi[k] ?? 0, 
        'TUR': ts, 
        'IS_HAMAL': isHamal, 'IS_ENSECI': isEnseci,
        'H_SAYI': ts > majT ? (ts - majT) : 0, 'E_SAYI': ts < majT && ts > 0 ? (majT - ts) : 0,
        'ILK_S': ilkSecilenler.contains(k),
        'ORTA_S': false,
        'SON_S': sonSecilenler.contains(k),
        'BK_S': aktifBK.contains(k),
        '1203_S': gece1203Secilenler.contains(k),
        'ARA_S': geceAraSecilenler.contains(k),
        '0508_S': gece0508Secilenler.contains(k),
        '0809_S': gece0809Secilenler.contains(k),
        'OFF_S': geceOffSecilenler.contains(k)
      };
    }

    String guncelBK = aktifBK.isEmpty ? "-" : aktifBK.join(', ');

    DateTime recordDate = _aktifTarih; 
    String recordDateStr = "$_aktifTarihStr (${isGunduzVardiyasi ? 'Gündüz' : 'Gece'})";
    
    var yeniBord = BordArsivi(recordDate, recordDateStr, [...tabloBaslikSektorleri], tempRows, tempTrf, tempGercekciTrf, tempHava, bugunIstat, tumPersonelHavuzu.where((k) => gunlukDurum[k]!.contains('OFF')).toList(), guncelBK);
    
    int varOlanIndex = tamArsiv.indexWhere((b) => b.tarihMetni == recordDateStr);
    if (varOlanIndex != -1) {
      tamArsiv[varOlanIndex] = yeniBord;
    } else {
      // Her zaman ekle: mod/tarih kombinasyonu ilk kez oluşturuluyorsa UI çökmemeli
      tamArsiv.add(yeniBord);
    }
  }

  void _isiHaritasiniAc() {
    String _zamanFiltresi = isGunduzVardiyasi ? "GÜNDÜZ" : "GECE"; 
    String _turFiltresi = "TÜM";

    int tempT3to4 = t3to4;
    int tempT4to5 = t4to5;
    int tempT5to6 = t5to6;
    int tempT6to7 = t6to7;

    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setST) {
      
      int getListItemCount() { 
        if (_zamanFiltresi == "GÜNDÜZ") return 10; 
        if (_zamanFiltresi == "GECE") return 14;   
        return 24; 
      }
      
      int getActualHour(int index) { 
        if (_zamanFiltresi == "GÜNDÜZ") return index + 9; 
        if (_zamanFiltresi == "GECE") return index < 5 ? index + 19 : index - 5; 
        return index; 
      }
      
      String formatliTakvimTarihi = "${_seciliTakvimTarihi.day.toString().padLeft(2, '0')}.${_seciliTakvimTarihi.month.toString().padLeft(2, '0')}.${_seciliTakvimTarihi.year}";
      
      Widget _circleBtn(IconData i, Color c, VoidCallback onTap, {bool disabled = false}) => GestureDetector(
        onTap: disabled ? null : onTap, 
        child: Container(
          padding: const EdgeInsets.all(2), 
          decoration: BoxDecoration(shape: BoxShape.circle, color: disabled ? Colors.grey.withOpacity(0.5) : c), 
          child: Icon(i, size: 14, color: disabled ? Colors.white54 : Colors.white)
        ),
      );
      
      Widget _boxBtn(IconData i, VoidCallback onTap, {Color color = Colors.grey}) => GestureDetector(
        onTap: onTap, child: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade700), borderRadius: BorderRadius.circular(6)), child: Icon(i, size: 18, color: color)),
      );
      
      int gIfrG = 0, gIfrC = 0, gVfrG = 0, gVfrC = 0;
      int nIfrG = 0, nIfrC = 0, nVfrG = 0, nVfrC = 0;
      int tIfrG = 0, tIfrC = 0, tVfrG = 0, tVfrC = 0;

      for (int i = 0; i < 24; i++) {
        int ig = anlikTrafik24[i].gelen;
        int ic = anlikTrafik24[i].giden;
        int vg = anlikTrafik24[i].vfrGelen;
        int vc = anlikTrafik24[i].vfrGiden;

        tIfrG += ig; tIfrC += ic; tVfrG += vg; tVfrC += vc;
        if (i >= 8 && i <= 18) { gIfrG += ig; gIfrC += ic; gVfrG += vg; gVfrC += vc; }
        else { nIfrG += ig; nIfrC += ic; nVfrG += vg; nVfrC += vc; }
      }

      Widget _zamanBtn(String l, bool a, Function(String) onSet, int ig, int ic, int vg, int vc) {
        int inisIfr = (_turFiltresi == "VFR") ? 0 : ig;
        int inisVfr = (_turFiltresi == "IFR") ? 0 : vg;
        int kalkisIfr = (_turFiltresi == "VFR") ? 0 : ic;
        int kalkisVfr = (_turFiltresi == "IFR") ? 0 : vc;

        int totalInis = inisIfr + inisVfr;
        int totalKalkis = kalkisIfr + kalkisVfr;

        // Her kartın sabit rengi
        Color cardColor = l == "GÜNDÜZ"
            ? Colors.amber
            : l == "GECE"
                ? const Color(0xFF4A90D9) // gece mavisi
                : Colors.greenAccent;    // TÜM GÜN

        Widget _buildPart(IconData icon, int ifrV, int vfrV, int tot, Color baseC) {
          Color fg = a ? baseC : baseC.withOpacity(0.45);
          if (_turFiltresi == "TÜM") {
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 12, color: a ? Colors.white60 : Colors.white24),
              const SizedBox(width: 2),
              Text("$ifrV", style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
              Text("+", style: TextStyle(color: a ? Colors.white30 : Colors.white12, fontSize: 10)),
              Text("$vfrV", style: TextStyle(color: fg.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.bold)),
              Text("=$tot", style: TextStyle(color: a ? Colors.white : Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
            ]);
          }
          return Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 12, color: a ? Colors.white60 : Colors.white24),
            const SizedBox(width: 4),
            Text("$tot", style: TextStyle(color: a ? Colors.white : Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
          ]);
        }

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => onSet(l),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(
                    color: a ? cardColor : cardColor.withOpacity(0.25),
                    width: a ? 1.8 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l, style: TextStyle(
                      color: a ? cardColor : cardColor.withOpacity(0.35),
                      fontSize: 12,
                      fontWeight: a ? FontWeight.bold : FontWeight.normal,
                    )),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildPart(Icons.arrow_downward, inisIfr, inisVfr, totalInis, Colors.amberAccent),
                          const SizedBox(width: 8),
                          _buildPart(Icons.arrow_upward, kalkisIfr, kalkisVfr, totalKalkis, Colors.lightBlueAccent),
                          const SizedBox(width: 8),
                          Text("= ${totalInis + totalKalkis}", style: TextStyle(
                            color: a ? cardColor : cardColor.withOpacity(0.3),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          )),
                        ],
                      ),
                    )
                  ],
                )
              ),
            ),
          ),
        );
      }

      Widget _toggleBtn(String l, bool a, Function(String) onSet) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GestureDetector(
          onTap: () => onSet(l),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: a ? Colors.blueAccent : Colors.transparent, border: Border.all(color: a ? Colors.blueAccent : Colors.grey.shade700), borderRadius: BorderRadius.circular(6)),
            child: Text(l, style: TextStyle(color: a ? Colors.white : Colors.grey, fontSize: 11, fontWeight: a ? FontWeight.bold : FontWeight.normal)),
          ),
        ),
      );

      return Dialog(
        backgroundColor: const Color(0xFF2D2D30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 750, 
          height: 680,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Row(children: [_circleBtn(Icons.remove, Colors.redAccent, () { setST(() => tempT3to4--); }, disabled: _veriCekiliyor), const SizedBox(width: 10), Text("$tempT3to4", style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 10), _circleBtn(Icons.add, Colors.greenAccent, () { setST(() => tempT3to4++); }, disabled: _veriCekiliyor)])),
                      Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Row(children: [_circleBtn(Icons.remove, Colors.redAccent, () { setST(() => tempT4to5--); }, disabled: _veriCekiliyor), const SizedBox(width: 10), Text("$tempT4to5", style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 10), _circleBtn(Icons.add, Colors.greenAccent, () { setST(() => tempT4to5++); }, disabled: _veriCekiliyor)])),
                      Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Row(children: [_circleBtn(Icons.remove, Colors.redAccent, () { setST(() => tempT5to6--); }, disabled: _veriCekiliyor), const SizedBox(width: 10), Text("$tempT5to6", style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 10), _circleBtn(Icons.add, Colors.greenAccent, () { setST(() => tempT5to6++); }, disabled: _veriCekiliyor)])),
                      Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Row(children: [_circleBtn(Icons.remove, Colors.redAccent, () { setST(() => tempT6to7--); }, disabled: _veriCekiliyor), const SizedBox(width: 10), Text("$tempT6to7", style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 10), _circleBtn(Icons.add, Colors.greenAccent, () { setST(() => tempT6to7++); }, disabled: _veriCekiliyor)])),
                      const SizedBox(height: 10),
                      // YENİ: ŞIK ONAY TİKİ (Zarif Tasarım)
                      GestureDetector(
                        onTap: () {
                           setState(() { t3to4 = tempT3to4; t4to5 = tempT4to5; t5to6 = tempT5to6; t6to7 = tempT6to7; });
                           _gruplariGuncelle(); Navigator.pop(context);
                        },
                        child: Container(
                          width: 40,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.15),
                            border: Border.all(color: Colors.greenAccent.withOpacity(0.8), width: 1.5),
                            borderRadius: BorderRadius.circular(4)
                          ),
                          child: const Center(child: Icon(Icons.check, color: Colors.greenAccent, size: 16)),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(width: 25),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _boxBtn(Icons.chevron_left, () { 
                                setST(() { 
                                  _seciliTakvimTarihi = _seciliTakvimTarihi.subtract(const Duration(days: 1)); 
                                  _tariheGoreVerileriGuncelle(); 
                                }); 
                            }),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade700), borderRadius: BorderRadius.circular(6)),
                              child: Text(formatliTakvimTarihi, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            _boxBtn(Icons.chevron_right, () { 
                                setST(() { 
                                  _seciliTakvimTarihi = _seciliTakvimTarihi.add(const Duration(days: 1)); 
                                  _tariheGoreVerileriGuncelle(); 
                                }); 
                            }),
                            const SizedBox(width: 8),
                            _veriCekiliyor
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.lightBlueAccent, strokeWidth: 2))
                                : _boxBtn(Icons.sync, () async {
                                    setST(() => _veriCekiliyor = true);
                                    await _trafikVerisiniCek();
                                    setST(() => _veriCekiliyor = false);
                                  }, color: Colors.lightBlueAccent),
                            if (trafikGuncelleme.isNotEmpty) ...[                              const SizedBox(width: 8),
                              Text(trafikGuncelleme, style: const TextStyle(color: Colors.white24, fontSize: 9)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: ["IFR", "VFR", "TÜM"].map((f) => _toggleBtn(f, _turFiltresi == f, (val) => setST(() => _turFiltresi = val))).toList(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _zamanBtn("GÜNDÜZ", _zamanFiltresi == "GÜNDÜZ", (val) => setST(() => _zamanFiltresi = val), gIfrG, gIfrC, gVfrG, gVfrC),
                            _zamanBtn("GECE", _zamanFiltresi == "GECE", (val) => setST(() => _zamanFiltresi = val), nIfrG, nIfrC, nVfrG, nVfrC),
                            _zamanBtn("TÜM GÜN", _zamanFiltresi == "TÜM GÜN", (val) => setST(() => _zamanFiltresi = val), tIfrG, tIfrC, tVfrG, tVfrC),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              
              Expanded(
                child: ListView.builder(
                  physics: getListItemCount() <= 14 ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
                  itemCount: getListItemCount(),
                  itemBuilder: (context, i) {
                    int h = getActualHour(i); 
                    
                    bool isYarin = (_zamanFiltresi == "GECE" || _zamanFiltresi == "TÜM GÜN") && (!isGunduzVardiyasi && h < 12); 
                    DateTime yarin = _aktifTarih.add(const Duration(days: 1));
                    String yarinStr = "${yarin.day.toString().padLeft(2, '0')}.${yarin.month.toString().padLeft(2, '0')}.${yarin.year}";
                    
                    TrafikVerisi t = isYarin 
                        ? (_haftalikTrafikKasa[yarinStr] != null ? _haftalikTrafikKasa[yarinStr]![h] : TrafikVerisi(0,0)) 
                        : anlikTrafik24[h];
                    
                    int barTotal = (_turFiltresi == "IFR") ? t.ifrToplam : ((_turFiltresi == "VFR") ? t.vfrToplam : t.genelToplam);
                    
                    double ideal = _getIdealLevel(barTotal, l34: tempT3to4, l45: tempT4to5, l56: tempT5to6, l67: tempT6to7);
                    Color c = ideal <= 3.0 ? Colors.green : (ideal <= 4.5 ? Colors.orange : Colors.redAccent);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        children: [
                          SizedBox(width: 80, child: Text("${h.toString().padLeft(2, '0')}:00 - ${h.toString().padLeft(2, '0')}:59", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70))),
                          Expanded(
                            child: Container(
                              height: 28,
                              decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                              child: Stack(
                                children: [
                                  FractionallySizedBox(
                                    widthFactor: (barTotal / 100).clamp(0.01, 1.0),
                                    child: Container(decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)))
                                  ),
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        children: [
                                          if (_turFiltresi != "VFR" && t.ifrToplam > 0) Container(
                                            margin: const EdgeInsets.only(right: 14),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.blue.shade900.withOpacity(0.8), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white24)),
                                            child: Row(children: [
                                              const Icon(Icons.arrow_downward, size: 10, color: Colors.white), const SizedBox(width: 4), Text("${t.gelen}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(width: 8), 
                                              const Icon(Icons.arrow_upward, size: 10, color: Colors.white), const SizedBox(width: 4), Text("${t.giden}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                              const SizedBox(width: 8), Text("= $barTotal", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                                            ]),
                                          ),
                                          if (_turFiltresi != "IFR" && t.vfrToplam > 0) Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.teal.shade900.withOpacity(0.8), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.cyanAccent.withOpacity(0.3))),
                                            child: Row(children: [
                                              const Icon(Icons.south_east, size: 10, color: Colors.cyanAccent), const SizedBox(width: 4), Text("${t.vfrGelen}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.cyanAccent)), const SizedBox(width: 14), 
                                              const Icon(Icons.north_east, size: 10, color: Colors.cyanAccent), const SizedBox(width: 4), Text("${t.vfrGiden}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                                              const SizedBox(width: 8), Text("= $barTotal", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                                            ]),
                                          ),
                                        ]
                                      )
                                    )
                                  )
                                ]
                              )
                            )
                          ),
                          SizedBox(width: 55, child: Padding(padding: const EdgeInsets.only(left: 12), child: Text("S$ideal", style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)))),
                        ]
                      )
                    );
                  }
                ),
              ),
            ],
          ),
        ),
      );
    }));
  }

  void _airgramEkraniAc() {
    bool _modalIciVeriCekiliyor = false;
    DateTime lokalMetTarih = _aktifTarih;
    
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setModalState) {
      String lokalMetTarihStr = "${lokalMetTarih.day.toString().padLeft(2, '0')}.${lokalMetTarih.month.toString().padLeft(2, '0')}.${lokalMetTarih.year}";
      List<AirgramVerisi> lokalAirgram = _havaGetir(lokalMetTarih);

      return DefaultTabController(
        length: 2,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(color: Colors.black, borderRadius: BorderRadius.vertical(top: Radius.circular(4))),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                const Text("🌦️", style: TextStyle(fontSize: 22)), 
                const SizedBox(width: 10), 
                const Text("MET INFO ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 15),
                Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(Icons.chevron_left, size: 18), onPressed: () => setModalState(() => lokalMetTarih = lokalMetTarih.subtract(const Duration(days: 1)))),
                      Text(lokalMetTarihStr, style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                      IconButton(icon: const Icon(Icons.chevron_right, size: 18), onPressed: () => setModalState(() => lokalMetTarih = lokalMetTarih.add(const Duration(days: 1)))),
                    ]
                  )
                ),
                const SizedBox(width: 15),
                _modalIciVeriCekiliyor 
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.lightBlueAccent, strokeWidth: 2))
                  : IconButton(
                      padding: EdgeInsets.zero, 
                      constraints: const BoxConstraints(), 
                      icon: const Icon(Icons.sync, color: Colors.lightBlueAccent), 
                      tooltip: "Küresel Meteoroloji Ağından Canlı Çek",
                      onPressed: () async {
                        setModalState(() => _modalIciVeriCekiliyor = true);
                        await _meteorolojiVerisiniCek();
                        setModalState(() => _modalIciVeriCekiliyor = false);
                      }
                    ),
                if (metGuncelleme.isNotEmpty) ...[                  const SizedBox(width: 8),
                  Text(metGuncelleme, style: const TextStyle(color: Colors.white24, fontSize: 9)),
                ],
              ]),
              IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context))
            ]),
          ),
          content: Container(
            width: 1050, 
            height: 680, 
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
            child: Column(
              children: [
                const TabBar(
                  indicatorColor: Colors.orangeAccent,
                  labelColor: Colors.orangeAccent,
                  unselectedLabelColor: Colors.white54,
                  tabs: [
                    Tab(child: Text("☀️ GÜNDÜZ (09:00 - 19:00)", style: TextStyle(fontWeight: FontWeight.bold))),
                    Tab(child: Text("🌙 GECE (19:00 - 09:00)", style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(scrollDirection: Axis.horizontal, child: _buildAirgramTable(true, lokalAirgram)),
                      SingleChildScrollView(scrollDirection: Axis.horizontal, child: _buildAirgramTable(false, lokalAirgram)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }));
  }

  Widget _buildAirgramTable(bool isDay, List<AirgramVerisi> lokalAirgram) {
    double rowH = isDay ? 45.0 : 34.0; 
    double fontS = 12.0; 

    List<DataRow> rows = [];
    if (isDay) {
      for(var veri in lokalAirgram) {
        int h = int.parse(veri.saat.split(':')[0]);
        if (h >= 9 && h <= 18) {
          rows.add(_airgramRow(veri.saat, veri.yon, veri.hiz, veri.hamle, veri.gorus, veri.hadise, veri.bulut, veri.sicaklik, veri.isba, veri.nem, veri.qnh, fontS));
        }
      }
    } else {
      List<int> geceSira = [19, 20, 21, 22, 23, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
      for (int h in geceSira) {
        if (lokalAirgram.any((e) => int.parse(e.saat.split(':')[0]) == h)) {
          var veri = lokalAirgram.firstWhere((e) => int.parse(e.saat.split(':')[0]) == h);
          rows.add(_airgramRow(veri.saat, veri.yon, veri.hiz, veri.hamle, veri.gorus, veri.hadise, veri.bulut, veri.sicaklik, veri.isba, veri.nem, veri.qnh, fontS));
        }
      }
    }

    return DataTable(
        headingRowHeight: 40.0, 
        dataRowHeight: rowH,
        headingRowColor: MaterialStateProperty.all(Colors.blueAccent.withOpacity(0.15)),
        headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.lightBlueAccent, fontSize: fontS),
        dataTextStyle: TextStyle(color: Colors.white, fontSize: fontS),
        columnSpacing: 25,
        border: TableBorder(horizontalInside: BorderSide(color: Colors.white.withOpacity(0.05))),
        columns: const [
          DataColumn(label: Text("Saat (L)")),
          DataColumn(label: Text("Rüzgar Yön")),
          DataColumn(label: Text("Yer Rüzgarı\n(Knot)")),
          DataColumn(label: Text("Hamle\n(Gust)")),
          DataColumn(label: Text("Görüş (m)")),
          DataColumn(label: Text("Hadise")),
          DataColumn(label: Text("Bulutluluk")),
          DataColumn(label: Text("Sıc. / İşba\n(Nem)", textAlign: TextAlign.center)),
          DataColumn(label: Text("Basınç\n(QNH)")),
        ],
        rows: rows,
      );
  }

  DataRow _airgramRow(String saat, String yon, String hiz, String hamle, String gorus, String hadise, String bulut, String sicaklik, String isba, String nem, String qnh, double fSize) {
    bool isRain = hadise != "-";
    bool isGust = hamle != "-";
    return DataRow(cells: [
      DataCell(Text(saat, style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: fSize))),
      DataCell(Text(yon)),
      DataCell(Text(hiz)),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: isGust ? BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)) : null,
        child: Text(hamle, style: TextStyle(color: isGust ? Colors.redAccent : Colors.white, fontWeight: isGust ? FontWeight.bold : FontWeight.normal, fontSize: fSize)),
      )),
      DataCell(Text(gorus)),
      DataCell(Text(hadise, style: TextStyle(color: isRain ? Colors.lightBlueAccent : Colors.white, fontWeight: isRain ? FontWeight.bold : FontWeight.normal, fontSize: fSize))),
      DataCell(Text(bulut)),
      DataCell(Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("$sicaklik / $isba", style: TextStyle(color: Colors.white, fontSize: fSize, fontWeight: FontWeight.bold)),
            Text("%$nem Nem", style: TextStyle(color: Colors.white54, fontSize: fSize - 3)),
          ],
        ),
      )),
      DataCell(Text(qnh, style: TextStyle(color: Colors.greenAccent, fontSize: fSize))),
    ]);
  }

  void _arsivVeIstatistikPenceresiniAc({int hedefSekme = 0}) {
    DateTimeRange? seciliAralik;
    bool isGunduzSecili = isGunduzVardiyasi;

    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setP) {
      List<BordArsivi> gosterilecek = tamArsiv.where((a) => a.tarihMetni.contains(isGunduzSecili ? '(Gündüz)' : '(Gece)')).toList();
      if (seciliAralik != null) gosterilecek = gosterilecek.where((b) => b.tarih.isAfter(seciliAralik!.start.subtract(const Duration(days: 1))) && b.tarih.isBefore(seciliAralik!.end.add(const Duration(days: 1)))).toList();
      
      Map<String, Map<String, dynamic>> aggIstat = {};
      for (String k in tumPersonelHavuzu) aggIstat[k] = {
        'DEL': 0, 'TWR': 0, 'GND': 0, 'SUP': 0, 
        'H_SAYI': 0, 'E_SAYI': 0,
        'ILK_S': 0, 'ORTA_S': 0, 'SON_S': 0, 'BK_S': 0,
        '1203_S': 0, 'ARA_S': 0, '0508_S': 0, '0809_S': 0, 'OFF_S': 0
      };
      
      for (var b in gosterilecek) {
        b.istatistik.forEach((k, v) {
          if (aggIstat.containsKey(k)) {
            aggIstat[k]!['H_SAYI'] = (aggIstat[k]!['H_SAYI'] as int) + (v['H_SAYI'] as int);
            aggIstat[k]!['E_SAYI'] = (aggIstat[k]!['E_SAYI'] as int) + (v['E_SAYI'] as int);
            aggIstat[k]!['ILK_S'] = (aggIstat[k]!['ILK_S'] as int) + ((v['ILK_S'] == true) ? 1 : 0);
            aggIstat[k]!['ORTA_S'] = (aggIstat[k]!['ORTA_S'] as int) + ((v['ORTA_S'] == true) ? 1 : 0);
            aggIstat[k]!['SON_S'] = (aggIstat[k]!['SON_S'] as int) + ((v['SON_S'] == true) ? 1 : 0);
            aggIstat[k]!['BK_S'] = (aggIstat[k]!['BK_S'] as int) + ((v['BK_S'] == true) ? 1 : 0);
            aggIstat[k]!['1203_S'] = (aggIstat[k]!['1203_S'] as int) + ((v['1203_S'] == true) ? 1 : 0);
            aggIstat[k]!['ARA_S'] = (aggIstat[k]!['ARA_S'] as int) + ((v['ARA_S'] == true) ? 1 : 0);
            aggIstat[k]!['0508_S'] = (aggIstat[k]!['0508_S'] as int) + ((v['0508_S'] == true) ? 1 : 0);
            aggIstat[k]!['0809_S'] = (aggIstat[k]!['0809_S'] as int) + ((v['0809_S'] == true) ? 1 : 0);
            aggIstat[k]!['OFF_S'] = (aggIstat[k]!['OFF_S'] as int) + ((v['OFF_S'] == true) ? 1 : 0);
          }
        });
        for (var row in b.satirlar) {
           for (int i=1; i<row.length; i++) {
              String worker = _yalnIsim(row[i]);
              if (worker == "-" || !aggIstat.containsKey(worker)) continue;
              String header = b.basliklar[i-1];
              if (header.contains("TWR")) aggIstat[worker]!['TWR'] = (aggIstat[worker]!['TWR'] as int) + 1;
              else if (header.contains("GND")) aggIstat[worker]!['GND'] = (aggIstat[worker]!['GND'] as int) + 1;
              else if (header.contains("DEL")) aggIstat[worker]!['DEL'] = (aggIstat[worker]!['DEL'] as int) + 1;
              else if (header.contains("SUP")) aggIstat[worker]!['SUP'] = (aggIstat[worker]!['SUP'] as int) + 1;
           }
        }
      }

      Widget contentWidget;
      if (hedefSekme == 0) {
        contentWidget = gosterilecek.isEmpty ? const Center(child: Text("Arşiv kaydı bulunamadı.", style: TextStyle(color: Colors.white54))) : ListView.builder(itemCount: gosterilecek.length, itemBuilder: (context, i) {
            var siraliArsiv = List<BordArsivi>.from(gosterilecek)..sort((a, b) => b.tarih.compareTo(a.tarih));
            var arsiv = siraliArsiv[i];
            return Card(color: Colors.white.withOpacity(0.05), margin: const EdgeInsets.only(bottom: 8), child: ExpansionTile(
              iconColor: Colors.orangeAccent, collapsedIconColor: Colors.white54, title: Text("Tarih: ${arsiv.tarihMetni}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              children: [ Padding(padding: const EdgeInsets.all(12.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 8),
                  SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
                    columnSpacing: 15, headingRowHeight: 36, dataRowHeight: 56, border: TableBorder.all(color: Colors.white12),
                    columns: [ 
                      const DataColumn(label: SizedBox(width: 40, child: Center(child: Text("")))),
                      DataColumn(label: Text(arsiv.tarihMetni, style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold))), 
                      ...arsiv.basliklar.map((b) => DataColumn(label: Text(b, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)))) 
                    ],
                    rows: arsiv.satirlar.asMap().entries.map((entry) {
                      int rIdx = entry.key; List<String> cells = entry.value;
                      TrafikVerisi tVeriGercekci = arsiv.satirlarGercekciTrafik[rIdx];
                      List<DataCell> rCells = [];
                      rCells.add(DataCell(_buildMetInfoCell(arsiv.satirlarHava[rIdx])));
                      Widget trfWidget = Row(mainAxisSize: MainAxisSize.min, children: [
                          const Text("🛬 ", style: TextStyle(fontSize: 10)),
                          Text("${tVeriGercekci.gelen}", style: const TextStyle(fontSize: 10, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          const Text("🛫 ", style: TextStyle(fontSize: 10)),
                          Text("${tVeriGercekci.giden}", style: const TextStyle(fontSize: 10, color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          Text("= ${tVeriGercekci.genelToplam}", style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                      ]);
                      rCells.add(DataCell(Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [ Text(cells[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)), Row(mainAxisSize: MainAxisSize.min, children: [ trfWidget ]) ]), )));
                      for(int c = 1; c < cells.length; c++) {
                        String text = cells[c];
                        if (text == "-") rCells.add(const DataCell(Center(child: Text("-", style: TextStyle(color: Colors.white12)))));
                        else rCells.add(DataCell(Container(margin: const EdgeInsets.all(4), padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)), borderRadius: BorderRadius.circular(4)), child: Center(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))))));
                      }
                      return DataRow(cells: rCells);
                    }).toList(),
                  )),
                  Padding(padding: const EdgeInsets.only(top: 12.0), child: Row(children: [
                    Container(width: ((arsiv.basliklar.length + 2) * 90.0) * (2/3), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), border: Border.all(color: Colors.redAccent.withOpacity(0.5)), borderRadius: BorderRadius.circular(8)), child: Text("❌ İZİNLİLER: ${arsiv.izinliler.isEmpty ? 'Yok' : arsiv.izinliler.join(', ')}", style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 10),
                    Container(width: ((arsiv.basliklar.length + 2) * 90.0) * (1/3) - 10, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.1), border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)), borderRadius: BorderRadius.circular(8)), child: Center(child: Text("☕ BİZİMLE KAL: ${arsiv.bizimleKal}", style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 11), overflow: TextOverflow.ellipsis))),
                  ])),
              ]))]
            ));
        });
      } else {
        contentWidget = gosterilecek.isEmpty ? const Center(child: Text("Kayıt yok.", style: TextStyle(color: Colors.white54))) : SingleChildScrollView(child: DataTable(
            columnSpacing: 10, headingRowHeight: 40, dataRowHeight: 45, border: TableBorder.all(color: Colors.white12),
            columns: [ 
              const DataColumn(label: SizedBox(width: 60, child: Text(""))), 
              const DataColumn(label: Text("DEL", style: TextStyle(fontSize: 10))), 
              const DataColumn(label: Text("TWR", style: TextStyle(fontSize: 10))), 
              const DataColumn(label: Text("GND", style: TextStyle(fontSize: 10))), 
              const DataColumn(label: Text("SUP", style: TextStyle(fontSize: 10))), 
              if (isGunduzSecili) ...[
                 const DataColumn(label: Text("İLK", style: TextStyle(fontSize: 10, color: Colors.purpleAccent))),
                 const DataColumn(label: Text("ORTA", style: TextStyle(fontSize: 10, color: Colors.blue))),
                 const DataColumn(label: Text("SON", style: TextStyle(fontSize: 10, color: Colors.tealAccent))),
                 const DataColumn(label: Text("B.KAL", style: TextStyle(fontSize: 10, color: Colors.amberAccent))),
                 const DataColumn(label: Text("KARINCA", style: TextStyle(fontSize: 10))), 
                 const DataColumn(label: Text("A.BÖC", style: TextStyle(fontSize: 10))), 
              ] else ...[
                 const DataColumn(label: Text("00⁰⁰-03⁰⁰", style: TextStyle(fontSize: 10, color: Colors.deepPurpleAccent))),
                 const DataColumn(label: Text("ARA", style: TextStyle(fontSize: 10, color: Colors.indigoAccent))),
                 const DataColumn(label: Text("05³⁰-08⁰⁰", style: TextStyle(fontSize: 10, color: Colors.teal))),
                 const DataColumn(label: Text("08⁰⁰-09⁰⁰", style: TextStyle(fontSize: 10, color: Colors.blueGrey))),
                 const DataColumn(label: Text("OFF", style: TextStyle(fontSize: 10, color: Colors.redAccent))),
              ]
            ],
            rows: aggIstat.entries.map((e) => DataRow(cells: [ 
              DataCell(Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))), 
              DataCell(Text("${e.value['DEL']}", style: const TextStyle(fontSize: 11))), 
              DataCell(Text("${e.value['TWR']}", style: const TextStyle(fontSize: 11))), 
              DataCell(Text("${e.value['GND']}", style: const TextStyle(fontSize: 11))), 
              DataCell(Text("${e.value['SUP']}", style: const TextStyle(fontSize: 11))), 
              if (isGunduzSecili) ...[
                 DataCell(Text("${e.value['ILK_S'] > 0 ? e.value['ILK_S'] : '-'}", style: const TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold))), 
                 DataCell(Text("${e.value['ORTA_S'] > 0 ? e.value['ORTA_S'] : '-'}", style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold))), 
                 DataCell(Text("${e.value['SON_S'] > 0 ? e.value['SON_S'] : '-'}", style: const TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold))), 
                 DataCell(Text("${e.value['BK_S'] > 0 ? e.value['BK_S'] : '-'}", style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold))), 
                 DataCell(Text("${e.value['H_SAYI']}", style: TextStyle(color: e.value['H_SAYI'] > 0 ? Colors.pinkAccent : Colors.white24, fontSize: 11))), 
                 DataCell(Text("${e.value['E_SAYI']}", style: TextStyle(color: e.value['E_SAYI'] > 0 ? Colors.lightBlueAccent : Colors.white24, fontSize: 11))), 
              ] else ...[
                 DataCell(Text("${e.value['1203_S'] > 0 ? e.value['1203_S'] : '-'}", style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 11, fontWeight: FontWeight.bold))), 
                 DataCell(Text("${e.value['ARA_S'] > 0 ? e.value['ARA_S'] : '-'}", style: const TextStyle(color: Colors.indigoAccent, fontSize: 11, fontWeight: FontWeight.bold))), 
                 DataCell(Text("${e.value['0508_S'] > 0 ? e.value['0508_S'] : '-'}", style: const TextStyle(color: Colors.teal, fontSize: 11, fontWeight: FontWeight.bold))), 
                 DataCell(Text("${e.value['0809_S'] > 0 ? e.value['0809_S'] : '-'}", style: const TextStyle(color: Colors.blueGrey, fontSize: 11, fontWeight: FontWeight.bold))), 
                 DataCell(Text("${e.value['OFF_S'] > 0 ? e.value['OFF_S'] : '-'}", style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold))), 
              ]
            ])).toList(),
        ));
      }

      return AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
             Icon(hedefSekme == 0 ? Icons.archive : Icons.bar_chart, color: isGunduzSecili ? Colors.orangeAccent : Colors.indigoAccent), 
             const SizedBox(width: 10), 
             Text(hedefSekme == 0 ? "BORD ARŞİVİ (${isGunduzSecili ? 'Gündüz' : 'Gece'})" : "İSTATİSTİKLER (${isGunduzSecili ? 'Gündüz' : 'Gece'})", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))
          ]),
          Row(children: [
             IconButton(
               icon: Icon(isGunduzSecili ? Icons.wb_sunny : Icons.nightlight_round, color: isGunduzSecili ? Colors.orangeAccent : Colors.indigoAccent, size: 28),
               onPressed: () => setP(() => isGunduzSecili = !isGunduzSecili),
             ),
             if (hedefSekme == 1) TextButton.icon(icon: const Icon(Icons.calendar_month, color: Colors.orangeAccent, size: 16), label: Text(seciliAralik == null ? "TARİH SEÇ" : "${seciliAralik!.start.day}.${seciliAralik!.start.month} - ${seciliAralik!.end.day}.${seciliAralik!.end.month}", style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
               onPressed: () async {
                 var aralik = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 30)), initialEntryMode: DatePickerEntryMode.calendarOnly, builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Colors.orangeAccent, onPrimary: Colors.black, surface: Color(0xFF1E1E1E), onSurface: Colors.white)), child: child!));
                 if (aralik != null) setP(() => seciliAralik = aralik);
               }
             ),
             if (hedefSekme == 1 && seciliAralik != null) IconButton(icon: const Icon(Icons.clear, color: Colors.redAccent, size: 16), onPressed: () => setP(() => seciliAralik = null)),
          ]),
        ]),
        content: SizedBox(width: 1050, height: 600, child: contentWidget),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("KAPAT"))],
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$_aktifEkip', style: TextStyle(color: EkipVerisi.renkler[_aktifEkip], fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 4)),
        centerTitle: false,
        backgroundColor: Colors.black, leading: null,
        actions: [
          IconButton(icon: const Icon(Icons.airplanemode_active, color: Colors.greenAccent), tooltip: "Trafik Sayısı", onPressed: _isiHaritasiniAc),
          IconButton(icon: const Text("🌦️", style: TextStyle(fontSize: 22)), tooltip: "LTAI Meteorological Info", onPressed: _airgramEkraniAc),
          IconButton(icon: const Icon(Icons.assignment_late, color: Colors.amber), tooltip: "NOTAM", onPressed: _notamEkraniAc),
          IconButton(icon: const Icon(Icons.handshake, color: Colors.purpleAccent), tooltip: "HOTO (Devir/Teslim)", onPressed: () {}),
          IconButton(icon: const Icon(Icons.calendar_month, color: Colors.cyanAccent), tooltip: "Nöbet Takvimi", onPressed: _nobetTakviminiAc),
          IconButton(icon: const Icon(Icons.settings, color: Colors.orangeAccent), tooltip: "Ayarlar ve Bord Planlama", onPressed: _kadroSecimEkraniAc),
          IconButton(icon: const Icon(Icons.logout, color: Colors.redAccent), tooltip: "Çıkış", onPressed: () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const EkipSecimSayfasi()));
          }),
          const SizedBox(width: 10),
        ],
      ),
      body: Center(
        child: _anaEkranDizilimi(),
      ), 
    );
  }

  Widget _buildMetInfoCell(HavaDurumu hava) {
    String wxEmoji = "☀️"; 
    if (hava.oraj) wxEmoji = "⛈️";
    else if (hava.yagmur) wxEmoji = "🌧️";
    else if (hava.bulutlu) wxEmoji = "☁️";

    BoxDecoration rwyDecoration;
    Color rwyTextColor;

    if (hava.rwy == "36") {
      rwyDecoration = BoxDecoration(color: Colors.cyanAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)));
      rwyTextColor = Colors.cyanAccent;
    } else if (hava.rwy == "18") {
      rwyDecoration = BoxDecoration(color: Colors.orangeAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)));
      rwyTextColor = Colors.orangeAccent;
    } else if (hava.rwy == "36 🔄 18") {
      rwyDecoration = BoxDecoration(
        gradient: LinearGradient(colors: [Colors.cyan.shade700, Colors.orange.shade700]),
        borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white38)
      );
      rwyTextColor = Colors.white;
    } else {
      rwyDecoration = BoxDecoration(
        gradient: LinearGradient(colors: [Colors.orange.shade700, Colors.cyan.shade700]),
        borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white38)
      );
      rwyTextColor = Colors.white;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: rwyDecoration,
            child: Text("RWY ${hava.rwy}", style: TextStyle(fontSize: 9, color: rwyTextColor, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(wxEmoji, style: const TextStyle(fontSize: 18)),
              if (hava.siddetliRuzgar) ...[
                const SizedBox(width: 4),
                const Icon(Icons.air, color: Colors.lightBlueAccent, size: 16),
              ]
            ]
          )
        ]
      ),
    );
  }
  /// İki kişiyi tüm bordda takas eder — motor yeniden çalışmaz.
  void _bordTakasYap(String kisiA, String kisiB) {
    String coreA = _yalnIsim(kisiA);
    String coreB = _yalnIsim(kisiB);
    if (coreA == coreB) return;

    String _mbKey = "$_aktifTarihStr (${isGunduzVardiyasi ? 'Gündüz' : 'Gece'})";
    var sonBord = tamArsiv.lastWhere((b) => b.tarihMetni == _mbKey, orElse: () => tamArsiv.last);

    setState(() {
      for (int r = 0; r < sonBord.satirlar.length; r++) {
        for (int c = 0; c < sonBord.satirlar[r].length; c++) {
          String cell = sonBord.satirlar[r][c];
          String core = _yalnIsim(cell);
          if (core == coreA) {
            sonBord.satirlar[r][c] = cell.replaceFirst(coreA, coreB);
          } else if (core == coreB) {
            sonBord.satirlar[r][c] = cell.replaceFirst(coreB, coreA);
          }
        }
      }
      // İstatistik swap
      var stA = sonBord.istatistik[coreA];
      var stB = sonBord.istatistik[coreB];
      if (stA != null && stB != null) {
        sonBord.istatistik[coreA] = stB;
        sonBord.istatistik[coreB] = stA;
      }
    });
  }

  void _manuelAtamaPenceresiAc(int hIdx, String pos, String currentPerson) {
    String core = pos.split('_')[0].split('/')[0];
    String _mbKey = "$_aktifTarihStr (${isGunduzVardiyasi ? 'Gündüz' : 'Gece'})";
    var sonBord = tamArsiv.lastWhere((b) => b.tarihMetni == _mbKey, orElse: () => tamArsiv.last);
    List<String> prevRow = hIdx > 0 ? sonBord.satirlar[hIdx - 1] : [];
    List<String> nextRow = hIdx < sonBord.satirlar.length - 1 ? sonBord.satirlar[hIdx + 1] : [];
    
    String mevcutSaatNotu = _kilitliSaatlerTarihli[_aktifTarihVeMod]?[hIdx]?[pos] ?? "";
    TextEditingController saatCtrl = TextEditingController(text: mevcutSaatNotu);

    bool _isModaUygunSaat(String input) {
      if (input.trim().isEmpty) return true;
      RegExp regExp = RegExp(r'\b(\d{1,2})[:.]\d{2}\b');
      Iterable<RegExpMatch> matches = regExp.allMatches(input);
      if (matches.isEmpty) return true;
      for (final m in matches) {
        int hour = int.tryParse(m.group(1)!) ?? -1;
        if (hour != -1) {
          if (isGunduzVardiyasi && (hour < 8 || hour > 19)) return false;
          if (!isGunduzVardiyasi && (hour > 9 && hour < 18)) return false;
        }
      }
      return true;
    }

    showDialog(
      context: context,
      builder: (context) {
        bool isTakasMode = currentPerson != "-";
        return StatefulBuilder(builder: (context, setDlg) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Row(children: [
            if (currentPerson != "-") ...[
              GestureDetector(
                onTap: () => setDlg(() => isTakasMode = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isTakasMode ? Colors.cyanAccent.withOpacity(0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isTakasMode ? Colors.cyanAccent : Colors.white24)
                  ),
                  child: const Text("🔄", style: TextStyle(fontSize: 18))
                )
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setDlg(() => isTakasMode = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: !isTakasMode ? Colors.redAccent.withOpacity(0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: !isTakasMode ? Colors.redAccent : Colors.white24)
                  ),
                  child: const Text("📌", style: TextStyle(fontSize: 18))
                )
              ),
              const SizedBox(width: 8),
              Text("${_yalnIsim(currentPerson)} ${isTakasMode ? '↔' : '→'}", style: TextStyle(color: isTakasMode ? Colors.cyanAccent : Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
            ] else
              Text("${saatler[hIdx]} | $pos 📌", style: const TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: ["-", ...tumPersonelHavuzu].map((kisi) {
                    if (kisi == "-") {
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.withOpacity(0.2),
                          side: const BorderSide(color: Colors.grey),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                        ),
                        onPressed: () {
                          if (!_isModaUygunSaat(saatCtrl.text)) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("⚠️ ${isGunduzVardiyasi ? 'Gündüz' : 'Gece'} vardiyasına uymayan mantıksız bir saat girdiniz!"), backgroundColor: Colors.redAccent));
                            return;
                          }
                          setState(() {
                            if (!_manuelAtananKisiler.containsKey(_aktifTarihVeMod)) _manuelAtananKisiler[_aktifTarihVeMod] = {};
                            if (!_manuelAtananKisiler[_aktifTarihVeMod]!.containsKey(hIdx)) _manuelAtananKisiler[_aktifTarihVeMod]![hIdx] = {};
                            _manuelAtananKisiler[_aktifTarihVeMod]![hIdx]![pos] = "-";
                            
                            if (!_kilitliSaatlerTarihli.containsKey(_aktifTarihVeMod)) _kilitliSaatlerTarihli[_aktifTarihVeMod] = {};
                            if (!_kilitliSaatlerTarihli[_aktifTarihVeMod]!.containsKey(hIdx)) _kilitliSaatlerTarihli[_aktifTarihVeMod]![hIdx] = {};
                            if (saatCtrl.text.trim().isNotEmpty) _kilitliSaatlerTarihli[_aktifTarihVeMod]![hIdx]![pos] = saatCtrl.text.trim();
                            else _kilitliSaatlerTarihli[_aktifTarihVeMod]![hIdx]!.remove(pos);
                          });
                          _gruplariGuncelle(arsiveKaydet: false, pinleriTemizle: false);
                          Navigator.pop(context);
                        },
                        child: const Text("-", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 20))
                      );
                    }

                    bool isOff = gunlukDurum[kisi]!.contains('OFF') || gunlukDurum[kisi]!.contains('KAZANDIŞI');
                    if (isOff) return const SizedBox.shrink();
                    if (isTakasMode && kisi == _yalnIsim(currentPerson)) return const SizedBox.shrink();

                    bool yetkiVar = _vizeKontrol(kisi, pos, core);
                    bool prevWorked = prevRow.contains(kisi);
                    bool nextWorked = nextRow.contains(kisi);
                    bool isBizimleKal = hIdx == saatler.length - 1 && bizimleKalSecilenler.contains(kisi);
                    bool uygun = yetkiVar && !prevWorked && !nextWorked && !isBizimleKal;
                    
                    Color btnColor = isTakasMode ? Colors.cyanAccent : (uygun ? Colors.green : Colors.redAccent);
                    
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: btnColor.withOpacity(isTakasMode ? 0.1 : (uygun ? 0.15 : 0.12)),
                        side: BorderSide(color: btnColor.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                      ),
                      onPressed: () {
                        if (isTakasMode) {
                          _bordTakasYap(currentPerson, kisi);
                          Navigator.pop(context);
                        } else {
                          // PIN MODU: Doğrudan hücreye yaz — motor çalışmaz
                          setState(() {
                            int colIdx = sonBord.basliklar.indexOf(pos) + 1; // satirlar[row][0] = saat
                            if (colIdx > 0 && colIdx < sonBord.satirlar[hIdx].length) {
                              sonBord.satirlar[hIdx][colIdx] = kisi;
                            }
                            // Saat notu varsa kaydet
                            if (saatCtrl.text.trim().isNotEmpty) {
                              if (!_kilitliSaatlerTarihli.containsKey(_aktifTarihVeMod)) _kilitliSaatlerTarihli[_aktifTarihVeMod] = {};
                              if (!_kilitliSaatlerTarihli[_aktifTarihVeMod]!.containsKey(hIdx)) _kilitliSaatlerTarihli[_aktifTarihVeMod]![hIdx] = {};
                              _kilitliSaatlerTarihli[_aktifTarihVeMod]![hIdx]![pos] = saatCtrl.text.trim();
                            }
                          });
                          Navigator.pop(context);
                        }
                      },
                      child: Text(kisi, style: TextStyle(color: isTakasMode ? Colors.cyanAccent : (uygun ? Colors.white : Colors.white70), fontWeight: FontWeight.bold)),
                    );
                  }).toList()
                ),
              const SizedBox(height: 16),
              TextField(
                 controller: saatCtrl,
                 textAlign: TextAlign.center,
                 style: const TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold),
                 decoration: InputDecoration(
                   labelText: "⏰",
                   labelStyle: const TextStyle(color: Colors.orangeAccent, fontSize: 20),
                   hintText: "Örn: 13:00 - 14:00",
                   hintStyle: const TextStyle(color: Colors.white24),
                   filled: true,
                   fillColor: Colors.black26,
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                 ),
              )
            ],
          )
        ),
        actions: [
          if ((_kilitliSaatlerTarihli[_aktifTarihVeMod]?[hIdx]?.containsKey(pos) ?? false) || (_manuelAtananKisiler[_aktifTarihVeMod]?[hIdx]?.containsKey(pos) ?? false))
            TextButton(
              onPressed: () {
                setState(() { 
                  _kilitliSaatlerTarihli[_aktifTarihVeMod]?[hIdx]?.remove(pos); 
                  _manuelAtananKisiler[_aktifTarihVeMod]?[hIdx]?.remove(pos); 
                });
                _gruplariGuncelle(arsiveKaydet: false, pinleriTemizle: false);
                Navigator.pop(context);
              },
              child: const Text("PİNİ KALDIR", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İPTAL"))
        ]
      ));
      }
    );
  }

  Widget _anaEkranDizilimi() {
    if (tamArsiv.isEmpty) return const Center(child: CircularProgressIndicator());
    String _sonBordKey = "$_aktifTarihStr (${isGunduzVardiyasi ? 'Gündüz' : 'Gece'})";
    var sonBord = tamArsiv.lastWhere((b) => b.tarihMetni == _sonBordKey, orElse: () => tamArsiv.last); var istat = sonBord.istatistik;
    List<String> izinliler = tumPersonelHavuzu.where((k) => gunlukDurum[k]!.contains('OFF')).toList();
    Color themeColor = isGunduzVardiyasi ? Colors.orangeAccent : Colors.indigoAccent;
    Color themeBgColor = isGunduzVardiyasi ? Colors.orange.withOpacity(0.1) : Colors.indigoAccent.withOpacity(0.1);
    Color borderColor = isGunduzVardiyasi ? Colors.white24 : Colors.indigoAccent.withOpacity(0.3);

    return Column(
      mainAxisSize: MainAxisSize.min, 
      children: [
      Expanded(child: SingleChildScrollView(scrollDirection: Axis.vertical, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DataTable(columnSpacing: 15, dataRowHeight: 65, headingRowHeight: 36, border: TableBorder.all(color: borderColor, width: 1), headingRowColor: MaterialStateProperty.all(Colors.black),
          columns: [ 
            const DataColumn(label: SizedBox(width: 40, child: Center(child: Text("")))),
            DataColumn(label: Text(_aktifTarihStr, style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 12))), 
            ...sonBord.basliklar.map((b) => DataColumn(label: Text(b, style: TextStyle(color: isGunduzVardiyasi ? Colors.white : Colors.indigo.shade100, fontWeight: FontWeight.bold, fontSize: 12)))) 
          ],
          rows: sonBord.satirlar.asMap().entries.map((entry) {
            int idx = entry.key; List<String> cells = entry.value;
            
            TrafikVerisi tVeriGercekci = sonBord.satirlarGercekciTrafik[idx];
            
            List<DataCell> rowCells = [];
            
            rowCells.add(DataCell(_buildMetInfoCell(sonBord.satirlarHava[idx])));
            
            Widget trfWidget = Row(
              mainAxisSize: MainAxisSize.min, 
              children: [
                const Text("🛬 ", style: TextStyle(fontSize: 10)),
                Text("${tVeriGercekci.gelen}", style: const TextStyle(fontSize: 10, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                const Text("🛫 ", style: TextStyle(fontSize: 10)),
                Text("${tVeriGercekci.giden}", style: const TextStyle(fontSize: 10, color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                Text("= ${tVeriGercekci.genelToplam}", style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
              ]
            );

            rowCells.add(DataCell(Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, 
                children: [
                  GestureDetector(
                    onTap: () => _saatDuzenle(idx),
                    child: Text(cells[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white, decoration: TextDecoration.underline, decorationColor: Colors.white54, decorationStyle: TextDecorationStyle.dashed)),
                  ), 
                  const SizedBox(height: 2),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    trfWidget
                  ])
                ]
              ),
            )));

            for(int cIdx = 1; cIdx < cells.length; cIdx++) {
              String text = cells[cIdx];
              String header = sonBord.basliklar[cIdx - 1]; 

              if (text == "-") {
                rowCells.add(DataCell(GestureDetector(
                  onTap: () => _manuelAtamaPenceresiAc(idx, header, text),
                  child: Container(
                     margin: const EdgeInsets.all(4), 
                     decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(4)),
                     child: const Center(child: Text("-", style: TextStyle(color: Colors.white24)))
                  )
                )));
              } else {
                String yIsim = _yalnIsim(text); // Oto-notu ayır: "BE (14:00)" → "BE"
                bool h = isGunduzVardiyasi && (istat[yIsim]?['IS_HAMAL'] ?? false); 
                bool e = isGunduzVardiyasi && (istat[yIsim]?['IS_ENSECI'] ?? false);
                
                String optSaat = _kilitliSaatlerTarihli[_aktifTarihVeMod]?[idx]?[header] ?? "";

                rowCells.add(DataCell(GestureDetector(
                  onTap: () => _manuelAtamaPenceresiAc(idx, header, text),
                  child: Container(
                    margin: const EdgeInsets.all(4), 
                    padding: const EdgeInsets.symmetric(horizontal: 10), 
                    decoration: BoxDecoration(
                      color: h ? Colors.pinkAccent.withOpacity(0.25) : (e ? Colors.lightBlueAccent.withOpacity(0.25) : Colors.transparent), 
                      borderRadius: BorderRadius.circular(4), 
                      border: Border.all(
                        color: h ? Colors.pinkAccent : (e ? Colors.lightBlueAccent : themeColor.withOpacity(0.3)), 
                        width: (h || e) ? 1.5 : 1
                      )
                    ), 
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            if (optSaat.isNotEmpty) Text(optSaat, style: TextStyle(color: themeColor, fontSize: 8, fontWeight: FontWeight.bold))
                          ],
                        ))
                      ]
                    )
                  )
                )));
              }
            }
            return DataRow(cells: rowCells);
          }).toList(),
        ),
        Padding(padding: const EdgeInsets.only(top: 8.0, bottom: 8.0), child: Row(children: [
          Container(constraints: const BoxConstraints(minWidth: 400), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), border: Border.all(color: Colors.redAccent.withOpacity(0.5)), borderRadius: BorderRadius.circular(8)), child: Text("❌ İZİNLİLER: ${izinliler.isEmpty ? 'Yok' : izinliler.join(', ')}", style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 10), overflow: TextOverflow.ellipsis)),
          if (isGunduzVardiyasi) const SizedBox(width: 10),
          if (isGunduzVardiyasi) Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: themeBgColor, border: Border.all(color: themeColor.withOpacity(0.5)), borderRadius: BorderRadius.circular(8)), child: Center(child: Text("☕ BİZİMLE KAL: ${sonBord.bizimleKal}", style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 10)))),
        ])),
      ])))),
    ]);
  }

  void _yeniPersonelEkle(Function setD) {
    TextEditingController c = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Center(
        child: Material(
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Container(
            width: 140, 
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: c,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: "İSİM",
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
                    counterText: "",
                    isDense: true,
                    contentPadding: EdgeInsets.only(bottom: 4),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      onPressed: () => Navigator.pop(context)
                    ),
                    IconButton(
                      padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                      icon: const Icon(Icons.add_circle, color: Colors.greenAccent, size: 20),
                      onPressed: () {
                        String n = c.text.trim().toUpperCase();
                        if (n.isNotEmpty && !tumPersonelHavuzu.contains(n)) {
                          setState(() {
                            tumPersonelHavuzu.add(n);
                            _gunlukDurumGunduz[n] = {'A'}; 
                            _gunlukDurumGece[n] = {'A'}; 
                            yetkiler[n] = {}; 
                          });
                          _savePersonelPrefs();
                          setD(() { _gruplariGuncelle(arsiveKaydet: false); }); 
                          Navigator.pop(context);
                        }
                      }
                    )
                  ]
                )
              ]
            )
          )
        )
      )
    );
  }

  void _kadroSecimEkraniAc() {
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setD) {
      
      // BK kişisi aktif kadroda (shift çalışır), OFF ve KAZANDIŞI hariç
      int tCount = tumPersonelHavuzu.where((k) => !gunlukDurum[k]!.contains('OFF') && !gunlukDurum[k]!.contains('KAZANDIŞI')).length;
      int totalSlots = 0;
      if (anlikTrafik.isNotEmpty) {
        for (int i = 0; i < saatler.length; i++) {
          int trf = anlikTrafik[i % anlikTrafik.length].genelToplam;
          double lvl = tamOtomatikDagitim ? _getIdealLevel(trf) : gunlukSeviye;
          totalSlots += getSektorlerByLevel(lvl).length;
        }
      } else {
        totalSlots = getSektorlerByLevel(gunlukSeviye).length * saatler.length;
      }
      
      int baseTur = tCount > 0 ? (totalSlots ~/ tCount) : 0;
      int rem = tCount > 0 ? (totalSlots % tCount) : 0;
      int majT = 0; int hGerek = 0; int eGerek = 0;
      
      // Manuel seçilen KARINCA/ENSECİ sayıları
      int manuelHamal = tumPersonelHavuzu.where((k) => !gunlukDurum[k]!.contains('OFF') && !gunlukDurum[k]!.contains('KAZANDIŞI') && gunlukDurum[k]!.contains('HAMAL')).length;
      int manuelEnseci = tumPersonelHavuzu.where((k) => !gunlukDurum[k]!.contains('OFF') && !gunlukDurum[k]!.contains('KAZANDIŞI') && gunlukDurum[k]!.contains('ENSECİ')).length;
      
      if (tCount > 0) {
        if (rem == 0) {
          majT = baseTur;
        } else if (rem <= tCount / 2) {
          majT = baseTur; hGerek = rem; 
        } else {
          majT = baseTur + 1; eGerek = tCount - rem;
        }
      }

      return AlertDialog(backgroundColor: const Color(0xFF1A1A1A), titlePadding: EdgeInsets.zero,
        content: SizedBox(width: 500, height: 600, child: Column(children: [
          Builder(builder: (context) {
            String p1G = gunduzKlasik.last.split(' - ').first;
            String p2G = gunduzAlengirli.last.split(' - ').first;
            String n1Txt = "20:40";
            String n2Txt = "21:15";
            Color cAI = tamOtomatikDagitim ? Colors.greenAccent : Colors.teal.withOpacity(0.5);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 35,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                             backgroundColor: cAI.withOpacity(0.15), foregroundColor: cAI,
                             side: BorderSide(color: cAI, width: tamOtomatikDagitim ? 2 : 1),
                             padding: EdgeInsets.zero, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))
                          ),
                          icon: Icon(tamOtomatikDagitim ? Icons.smart_toy : Icons.smart_toy_outlined, size: 16),
                          label: const Text("AI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          onPressed: () => setD(() { tamOtomatikDagitim = !tamOtomatikDagitim; _gruplariGuncelle(arsiveKaydet: false); })
                        )
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 35,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                             backgroundColor: Colors.white.withOpacity(0.1), foregroundColor: Colors.white,
                             side: const BorderSide(color: Colors.white38, width: 1.5),
                             padding: EdgeInsets.zero, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))
                          ),
                          onPressed: () { _gruplariGuncelle(arsiveKaydet: true); Navigator.pop(context); },
                          child: const Icon(Icons.check_circle, size: 20)
                        )
                      ),
                    ]
                  )
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 35,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                             backgroundColor: (isGunduzVardiyasi && saatSenaryosu == 1) ? Colors.orangeAccent.withOpacity(0.3) : Colors.transparent,
                             foregroundColor: (isGunduzVardiyasi && saatSenaryosu == 1) ? Colors.orangeAccent : Colors.white54,
                             side: BorderSide(color: (isGunduzVardiyasi && saatSenaryosu == 1) ? Colors.orangeAccent : Colors.white24, width: (isGunduzVardiyasi && saatSenaryosu == 1) ? 1.5 : 1),
                             padding: EdgeInsets.zero, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))
                          ),
                          onPressed: () => setD(() { bool modDegisti = !isGunduzVardiyasi; isGunduzVardiyasi = true; saatSenaryosu = 1; if (modDegisti) _modGecisiTemizle(true); _gruplariGuncelle(arsiveKaydet: false); }),
                          child: Text("☀️ $p1G", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1))
                        )
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 35,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                             backgroundColor: (isGunduzVardiyasi && saatSenaryosu == 2) ? Colors.orangeAccent.withOpacity(0.3) : Colors.transparent,
                             foregroundColor: (isGunduzVardiyasi && saatSenaryosu == 2) ? Colors.orangeAccent : Colors.white54,
                             side: BorderSide(color: (isGunduzVardiyasi && saatSenaryosu == 2) ? Colors.orangeAccent : Colors.white24, width: (isGunduzVardiyasi && saatSenaryosu == 2) ? 1.5 : 1),
                             padding: EdgeInsets.zero, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))
                          ),
                          onPressed: () => setD(() { bool modDegisti = !isGunduzVardiyasi; isGunduzVardiyasi = true; saatSenaryosu = 2; if (modDegisti) _modGecisiTemizle(true); _gruplariGuncelle(arsiveKaydet: false); }),
                          child: Text("☀️ $p2G", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1))
                        )
                      ),
                    ]
                  )
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 35,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                             backgroundColor: (!isGunduzVardiyasi && saatSenaryosu == 1) ? Colors.indigoAccent.withOpacity(0.3) : Colors.transparent,
                             foregroundColor: (!isGunduzVardiyasi && saatSenaryosu == 1) ? Colors.indigoAccent : Colors.white54,
                             side: BorderSide(color: (!isGunduzVardiyasi && saatSenaryosu == 1) ? Colors.indigoAccent : Colors.white24, width: (!isGunduzVardiyasi && saatSenaryosu == 1) ? 1.5 : 1),
                             padding: EdgeInsets.zero, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))
                          ),
                          onPressed: () => setD(() { bool modDegisti = isGunduzVardiyasi; isGunduzVardiyasi = false; saatSenaryosu = 1; if (modDegisti) _modGecisiTemizle(false); _gruplariGuncelle(arsiveKaydet: false); }),
                          child: Text("🌙 $n1Txt", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1))
                        )
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 35,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                             backgroundColor: (!isGunduzVardiyasi && saatSenaryosu == 2) ? Colors.indigoAccent.withOpacity(0.3) : Colors.transparent,
                             foregroundColor: (!isGunduzVardiyasi && saatSenaryosu == 2) ? Colors.indigoAccent : Colors.white54,
                             side: BorderSide(color: (!isGunduzVardiyasi && saatSenaryosu == 2) ? Colors.indigoAccent : Colors.white24, width: (!isGunduzVardiyasi && saatSenaryosu == 2) ? 1.5 : 1),
                             padding: EdgeInsets.zero, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))
                          ),
                          onPressed: () => setD(() { bool modDegisti = isGunduzVardiyasi; isGunduzVardiyasi = false; saatSenaryosu = 2; if (modDegisti) _modGecisiTemizle(false); _gruplariGuncelle(arsiveKaydet: false); }),
                          child: Text("🌙 $n2Txt", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1))
                        )
                      ),
                    ]
                  )
                ),
              ],
            );
          }),
          Builder(builder: (context) {
            if (!isGunduzVardiyasi) return const SizedBox.shrink();
            
            int gercekHamal = 0;
            int gercekEnseci = 0;
            String _mbKey = "$_aktifTarihStr (${isGunduzVardiyasi ? 'Gündüz' : 'Gece'})";
            var sonBord = tamArsiv.lastWhere((b) => b.tarihMetni == _mbKey, orElse: () => tamArsiv.last);
            
            for (var k in tumPersonelHavuzu) {
              if (sonBord.istatistik[k]?['IS_HAMAL'] == true) gercekHamal++;
              if (sonBord.istatistik[k]?['IS_ENSECI'] == true) gercekEnseci++;
            }
            
            String gMetin = "⚖️ Çoğunluk: $majT Tur | Tabloda: $gercekHamal Karınca - $gercekEnseci Ağustos Böceği";
            if (manuelHamal > 0 || manuelEnseci > 0) {
              gMetin += " (Senin Seçtiğin: ${manuelHamal}K ${manuelEnseci}A)";
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8), 
              child: Text(
                gMetin,
                style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)
              )
            );
          }),
          
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal, 
            child: Row(
              children: [3, 3.5, 4, 4.5, 5, 5.5, 6, 6.5, 7].map((v) { 
                bool iS = gunlukSeviye == v.toDouble();
                bool iA = (v.toDouble() == hakimSeviye) && tamOtomatikDagitim;
                return Padding(
                  padding: const EdgeInsets.only(right: 6), 
                  child: InkWell(
                    onTap: () => setD(() { gunlukSeviye = v.toDouble(); _gruplariGuncelle(arsiveKaydet: false); }), 
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), 
                      decoration: BoxDecoration(
                        color: iS ? Colors.greenAccent : Colors.transparent, 
                        border: Border.all(color: iA ? Colors.greenAccent : (iS ? Colors.black : Colors.greenAccent.withOpacity(0.4)), width: iA ? 2 : 1), 
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: iA ? [BoxShadow(color: Colors.greenAccent.withOpacity(0.3), blurRadius: 4, spreadRadius: 1)] : null
                      ), 
                      child: Text(
                        v % 1 == 0 ? "S${v.toInt()}${iA ? ' 🤖' : ''}" : "S$v${iA ? ' 🤖' : ''}", 
                        style: TextStyle(color: iS ? Colors.black : Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 10)
                      )
                    )
                  )
                ); 
              }).toList()
            )
          ),

          const SizedBox(height: 10),
          const Divider(height: 25, color: Colors.white12),
          Expanded(
            child: ListView.builder(
              itemCount: tumPersonelHavuzu.length + 1, 
              itemBuilder: (context, i) {
                
                if (i == tumPersonelHavuzu.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Center(
                      child: IconButton(
                        icon: const Icon(Icons.add, color: Colors.orangeAccent, size: 28),
                        onPressed: () => _yeniPersonelEkle(setD),
                        tooltip: "Yeni Personel Ekle",
                      ),
                    )
                  );
                }

                String k = tumPersonelHavuzu[i]; bool pas = gunlukDurum[k]!.contains('OFF') || gunlukDurum[k]!.contains('KAZANDIŞI');
                return Card(color: Colors.white.withOpacity(0.04), child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  GestureDetector(onTap: () => _isimDuzenle(i, setD), child: Text(k, style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline, color: pas ? Colors.white24 : Colors.white))),
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [ 
                    if (!tamOtomatikDagitim) ...[
                      _durumBtn(k, 'A', Colors.blue, setD, "A"), 
                      _durumBtn(k, 'B', Colors.blue, setD, "B"), 
                      _durumBtn(k, 'C', Colors.blue, setD, "C"), 
                      _durumBtn(k, 'D', Colors.blue, setD, "D"), 
                      _durumBtn(k, 'E', Colors.blue, setD, "E"),
                    ],
                    if (isGunduzVardiyasi) _durumBtn(k, 'HAMAL', Colors.pinkAccent, setD, "KARINCA"), 
                    if (isGunduzVardiyasi) _durumBtn(k, 'ENSECİ', Colors.lightBlueAccent, setD, "AĞUSTOS BÖCEĞİ")
                  ]),
                  
                  if (!pas) Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 4, runSpacing: 2,
                          children: [
                            ...getSektorlerByLevel(gunlukSeviye).map((pos) => _yetkiBtn(k, pos, setD)),
                            if (isGunduzVardiyasi) _ozelSecimBtn(k, 'SUP ONLY', Colors.red.shade900, setD),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4, runSpacing: 2,
                          children: isGunduzVardiyasi ? [
                            _ozelSecimBtn(k, 'İLK', Colors.purpleAccent, setD),
                            _ozelSecimBtn(k, 'SON', Colors.tealAccent, setD),
                            _ozelSecimBtn(k, 'BİZİMLE KAL', Colors.amberAccent, setD),
                          ] : [
                            _ozelSecimBtn(k, '00⁰⁰-03⁰⁰', Colors.deepPurpleAccent, setD),
                            _ozelSecimBtn(k, 'ARA', Colors.indigoAccent, setD),
                            _ozelSecimBtn(k, '05³⁰-08⁰⁰', Colors.teal, setD),
                            _ozelSecimBtn(k, '08⁰⁰-09⁰⁰', Colors.blueGrey, setD),
                            _ozelSecimBtn(k, 'OFF', Colors.redAccent, setD),
                          ],
                        )
                      ]
                    )
                  )
                ])));
              }
            )
          ),
          const SizedBox(height: 10),
          Align(alignment: Alignment.bottomRight, child: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
               icon: Icon(Icons.archive_outlined, color: isGunduzVardiyasi ? Colors.orangeAccent : Colors.indigoAccent),
               tooltip: "Bord Arşivi",
               onPressed: () { Navigator.pop(context); _arsivVeIstatistikPenceresiniAc(hedefSekme: 0); }
            ),
            IconButton(
               icon: Icon(Icons.bar_chart_outlined, color: isGunduzVardiyasi ? Colors.orangeAccent : Colors.indigoAccent),
               tooltip: "İstatistikler (Kürek Mahkumları)",
               onPressed: () { Navigator.pop(context); _arsivVeIstatistikPenceresiniAc(hedefSekme: 1); }
            ),
          ])),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("KAPAT"))],
      );
    }));
  }

  Future<void> _sadeceNotamVerisiniCek() async {
    try {
      // ?action=refresh_notam → Google Script Gmail'den NOTAM'ları çeker + cache'i döndürür
      final notamUrl = Uri.parse("$gasUrl?action=refresh_notam");
      final response = await http.get(notamUrl).timeout(const Duration(seconds: 45));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['durum'] == 'BAŞARILI') {
          if (mounted) {
            setState(() {
              ltaiNotamlari = decoded['notamlar'] ?? [];
              notamGuncelleme = decoded['notamGuncelleme'] ?? "";
            });
          }
        }
      }
    } catch (e) {
      debugPrint("NOTAM Çekim Hatası: $e");
    }
  }

  // NOTAM Pinleme & Genişletme & Özel Etiket (Rozet) durumlarını tutacağımız yapılar
  Set<String> _pinnedNotams = {};
  Set<String> _collapsedNotams = {};
  Map<String, String> _customNotamTags = {}; // id -> tagName
  Set<String> _collapsedEnglish = {}; // tracks collapsed English content

  // ── Personel Kalıcılığı (SharedPreferences) ──
  static const String _personelVersion = 'v2'; // Versiyon değişince önbellekteki eski liste göz ardı edilir
  Future<void> _loadPersonelPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    String vKey = 'savedPersonelVersion_$_aktifEkip';
    String pKey = 'savedPersonel_$_aktifEkip';
    // Versiyon kontrolu: eski önbellekte farklı versiyon varsa personeli kod listesiyle başlat
    String savedVersion = prefs.getString(vKey) ?? '';
    if (savedVersion != _personelVersion) {
      // Önbellek versiyonu eski — ilk kayda zorla (kod listesindeki varsayılanı kaydet)
      await prefs.setString(vKey, _personelVersion);
      await prefs.setString(pKey, json.encode(tumPersonelHavuzu));
      return; // Kod listesindeki varsayılan listeyi kullan
    }
    String? pJson = prefs.getString(pKey);
    if (pJson != null) {
      try {
        List<dynamic> saved = json.decode(pJson);
        setState(() {
          tumPersonelHavuzu.clear();
          tumPersonelHavuzu.addAll(List<String>.from(saved));
          for (var k in tumPersonelHavuzu) {
            if (!_gunlukDurumGunduz.containsKey(k)) _gunlukDurumGunduz[k] = {'A'};
            if (!_gunlukDurumGece.containsKey(k)) _gunlukDurumGece[k] = {'A'};
          }
        });
        _gruplariGuncelle(arsiveKaydet: false);
      } catch (e) {
        debugPrint("Personel Prefs parse hatasi: $e");
      }
    }
  }

  Future<void> _savePersonelPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('savedPersonel_$_aktifEkip', json.encode(tumPersonelHavuzu));
  }

  // ── Rozet Kalıcılığı (SharedPreferences) ──
  Future<void> _loadNotamPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    // Özel etiketleri yükle
    String? tagsJson = prefs.getString('customNotamTags');
    if (tagsJson != null) {
      try {
        Map<String, dynamic> decoded = jsonDecode(tagsJson);
        setState(() {
          _customNotamTags = decoded.map((k, v) => MapEntry(k, v.toString()));
        });
      } catch (e) { debugPrint("Notam Tags parse: $e"); }
    }
    // Özel rozetleri yükle (built-in olmayanlar)
    String? customTagsJson = prefs.getString('customAllTags');
    if (customTagsJson != null) {
      try {
        Map<String, dynamic> decoded = jsonDecode(customTagsJson);
        setState(() {
          for (var entry in decoded.entries) {
            if (!_builtInTagNames.contains(entry.key)) {
              List<dynamic> val = entry.value;
              _allTags[entry.key] = [Color(val[0]), val[1]];
            }
          }
        });
      } catch (e) { debugPrint("Custom All Tags parse: $e"); }
    }
  }

  Future<void> _saveNotamPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    // Özel etiketleri kaydet
    await prefs.setString('customNotamTags', jsonEncode(_customNotamTags));
    // Özel rozetleri kaydet (built-in olmayanları)
    Map<String, List<dynamic>> customOnly = {};
    _allTags.forEach((k, v) {
      if (!_builtInTagNames.contains(k)) {
        customOnly[k] = [v[0].value, v[1]]; // Color.value → int
      }
    });
    await prefs.setString('customAllTags', jsonEncode(customOnly));
  }
  
  // Öntanımlı Rozetler (Kalıcı ve dinamik olması için sınıf seviyesine taşındı)
  static const Set<String> _builtInTagNames = {
    "🚨 PİST/NAV", "⚠️ TAKSİ/APRON", "⚡ Elektrik/Electric",
    "ℹ️ GENEL", "🌦️ METEOROLOJİ", "🚧 MANİA/VİNÇ",
  };
  Map<String, List<dynamic>> _allTags = {
    "🚨 PİST/NAV": [Colors.redAccent, 0],
    "⚠️ TAKSİ/APRON": [Colors.orangeAccent, 1],
    "⚡ Elektrik/Electric": [Colors.yellowAccent, 2],
    "ℹ️ GENEL": [Colors.lightBlueAccent, 3],
    "🌦️ METEOROLOJİ": [Colors.tealAccent, 5],
    "🚧 MANİA/VİNÇ": [Colors.grey, 6],
  };

  // =============================================
  // NOBET TAKVIMI + IZIN TAKIBI
  // =============================================
  // Tarih -> {kisi: tur} (tur: I=Izin, M=Mazeret, R=Rapor, G=Gorev)
  Map<String, Map<String, String>> _takvimIzinler = {};

  static const Map<String, String> _izinTurleri = {
    'Y': 'IZIN', 'M': 'MAZERET', 'R': 'RAPOR', 'G': 'GOREV'
  };
  static const Map<String, Color> _izinRenkleri = {
    'Y': Colors.redAccent, 'M': Colors.orangeAccent, 'R': Color(0xFF5C6BC0), 'G': Colors.tealAccent
  };

  String _tarihKey(DateTime d) => "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";

  Future<void> _loadTakvimIzinler() async {
    final prefs = await SharedPreferences.getInstance();
    String? raw = prefs.getString('takvimIzin_$_aktifEkip');
    if (raw != null) {
      try {
        Map<String, dynamic> parsed = json.decode(raw);
        _takvimIzinler = {};
        parsed.forEach((k, v) {
          if (v is Map) {
            _takvimIzinler[k] = Map<String, String>.from(v);
          } else if (v is List) {
            // Eski format uyumlulugu (List -> hepsini 'I' yap)
            _takvimIzinler[k] = {for (var name in v) name as String: 'Y'};
          }
        });
      } catch (_) {}
    }
  }

  Future<void> _saveTakvimIzinler() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('takvimIzin_$_aktifEkip', json.encode(_takvimIzinler));
  }

  /// Takvimden bugunun izinlilerini borda uygula
  void _takvimdenIzinUygula() {
    String bugunKey = _tarihKey(DateTime.now());
    Map<String, String> izinliler = _takvimIzinler[bugunKey] ?? {};
    if (izinliler.isEmpty) return;
    setState(() {
      for (var k in izinliler.keys) {
        if (tumPersonelHavuzu.contains(k)) {
          gunlukDurum[k] = {'OFF'};
        }
      }
    });
    _gruplariGuncelle(arsiveKaydet: false);
  }

  void _nobetTakviminiAc() {
    DateTime bugun = DateTime.now();
    int ekipIdx = EkipVerisi.rotasyon.indexOf(_aktifEkip);
    if (ekipIdx < 0) ekipIdx = 0;
    DateTime gorunenAy = DateTime(bugun.year, bugun.month, 1);

    showDialog(context: context, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setD) {
        List<String> gA = ['Pzt', 'Sal', 'Car', 'Per', 'Cum', 'Cmt', 'Paz'];
        List<String> ayAd = ['', 'Ocak', 'Subat', 'Mart', 'Nisan', 'Mayis', 'Haziran', 'Temmuz', 'Agustos', 'Eylul', 'Ekim', 'Kasim', 'Aralik'];

        int yil = gorunenAy.year;
        int ay = gorunenAy.month;
        int gunSayisi = DateTime(yil, ay + 1, 0).day;
        int ilkGunHafta = DateTime(yil, ay, 1).weekday; // 1=Pzt

        // Ekibin bu gundeki rolu
        Color? gunRengi(DateTime tarih) {
          String gE = EkipVerisi.gunduzEkibi(tarih);
          String nE = EkipVerisi.geceEkibi(tarih);
          if (gE == _aktifEkip) return Colors.amber;
          if (nE == _aktifEkip) return Colors.lightBlueAccent;
          return null; // OFF
        }

        void _gunIzinDuzenle(DateTime gun) {
          String dKey = _tarihKey(gun);
          Map<String, String> sec = Map<String, String>.from(_takvimIzinler[dKey] ?? {});
          showDialog(context: ctx, builder: (c2) {
            return StatefulBuilder(builder: (c2, s2) {
              return AlertDialog(
                backgroundColor: const Color(0xFF222222),
                title: Text('${gun.day} ${ayAd[gun.month]} ${gun.year} ${['Pazartesi','Sali','Carsamba','Persembe','Cuma','Cumartesi','Pazar'][gun.weekday - 1]}',
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
                content: SizedBox(width: 340, child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _izinTurleri.entries.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(
                          color: _izinRenkleri[e.key], borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 3),
                        Text(e.value, style: TextStyle(color: _izinRenkleri[e.key], fontSize: 8, fontWeight: FontWeight.bold)),
                      ]),
                    )).toList(),
                  )),
                  Wrap(spacing: 5, runSpacing: 5,
                    children: tumPersonelHavuzu.map((k) {
                      String? tur = sec[k];
                      bool izinli = tur != null;
                      Color renk = izinli ? (_izinRenkleri[tur] ?? Colors.redAccent) : Colors.white70;
                      return GestureDetector(
                        onTap: () => s2(() {
                          List<String> sira = ['Y', 'M', 'R', 'G'];
                          if (tur == null) { sec[k] = 'Y'; }
                          else { int idx = sira.indexOf(tur); if (idx < sira.length - 1) sec[k] = sira[idx + 1]; else sec.remove(k); }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: izinli ? renk.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: izinli ? renk : Colors.white24, width: izinli ? 1.5 : 0.5),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(k, style: TextStyle(color: renk, fontWeight: izinli ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
                            if (izinli) ...[const SizedBox(width: 3),
                              Text(tur!, style: TextStyle(color: renk.withOpacity(0.7), fontSize: 8, fontWeight: FontWeight.bold))],
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ])),
                actions: [
                  TextButton(onPressed: () => s2(() => sec.clear()),
                    child: const Text('TEMIZLE', style: TextStyle(color: Colors.grey, fontSize: 11))),
                  TextButton(onPressed: () {
                    if (sec.isEmpty) _takvimIzinler.remove(dKey); else _takvimIzinler[dKey] = sec;
                    _saveTakvimIzinler();
                    setD(() {});
                    Navigator.pop(c2);
                  }, child: const Icon(Icons.check, color: Colors.greenAccent, size: 20)),
                ],
              );
            });
          });
        }

        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          titlePadding: const EdgeInsets.fromLTRB(8, 8, 4, 0),
          title: Row(children: [
            IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white38, size: 24),
              onPressed: () => setD(() => gorunenAy = DateTime(yil, ay - 1, 1))),
            Expanded(child: Center(child: Text('${ayAd[ay]} $yil',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 3)))),
            IconButton(icon: const Icon(Icons.chevron_right, color: Colors.white38, size: 24),
              onPressed: () => setD(() => gorunenAy = DateTime(yil, ay + 1, 1))),
            IconButton(icon: const Icon(Icons.close, color: Colors.white24, size: 24),
              onPressed: () => Navigator.pop(ctx)),
          ]),
          contentPadding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
          content: SizedBox(
            width: 870,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Gun basliklari
              Row(children: gA.map((g) => Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Center(child: Text(g, style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold))),
                ),
              )).toList()),
              const Divider(color: Colors.white12, height: 1),
              // Haftalik grid
              ...List.generate(6, (haftaIdx) {
                // Bu haftada gosterilecek gun var mi kontrol
                bool haftaGecerli = false;
                for (int gunIdx = 0; gunIdx < 7; gunIdx++) {
                  int hucreNo = haftaIdx * 7 + gunIdx + 1 - (ilkGunHafta - 1);
                  if (hucreNo >= 1 && hucreNo <= gunSayisi) { haftaGecerli = true; break; }
                }
                if (!haftaGecerli) return const SizedBox();

                return Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
                  ),
                  child: IntrinsicHeight(
                    child: Row(children: List.generate(7, (gunIdx) {
                      int hucreNo = haftaIdx * 7 + gunIdx + 1 - (ilkGunHafta - 1);
                      if (hucreNo < 1 || hucreNo > gunSayisi) {
                        return Expanded(child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              right: gunIdx < 6 ? BorderSide(color: Colors.white.withOpacity(0.04)) : BorderSide.none,
                            ),
                          ),
                        ));
                      }

                      DateTime tarih = DateTime(yil, ay, hucreNo);
                      bool bugunMu = tarih.day == bugun.day && tarih.month == bugun.month && tarih.year == bugun.year;
                      Color? renk = gunRengi(tarih);
                      bool off = renk == null;
                      String key = _tarihKey(tarih);
                      Map<String, String> izinliler = _takvimIzinler[key] ?? {};

                      return Expanded(child: GestureDetector(
                        onTap: () => _gunIzinDuzenle(tarih),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
                          decoration: BoxDecoration(
                            color: bugunMu ? Colors.orangeAccent.withOpacity(0.1) : Colors.transparent,
                            border: Border(
                              right: gunIdx < 6 ? BorderSide(color: Colors.white.withOpacity(0.04)) : BorderSide.none,
                              top: bugunMu ? const BorderSide(color: Colors.orangeAccent, width: 2) : BorderSide.none,
                            ),
                          ),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            // Gun numarasi
                            Text('$hucreNo',
                              style: TextStyle(
                                color: bugunMu ? Colors.orangeAccent : (off ? Colors.white24 : Colors.white70),
                                fontSize: 16, fontWeight: (bugunMu || !off) ? FontWeight.bold : FontWeight.normal)),
                            // Renk cubugu (tarihin altinda)
                            Container(width: 30, height: 3, margin: const EdgeInsets.only(top: 2, bottom: 2),
                              decoration: BoxDecoration(
                                color: renk ?? Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(2))),
                            // Izinliler - 3 sutun grid
                            if (izinliler.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              ...List.generate((izinliler.length / 3).ceil(), (r) {
                                List<MapEntry<String, String>> satirKisiler = izinliler.entries.toList().skip(r * 3).take(3).toList();
                                return Row(children: [
                                  for (var e in satirKisiler)
                                    Expanded(child: Center(child: Text(e.key,
                                      style: TextStyle(color: _izinRenkleri[e.value] ?? Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)))),
                                  for (int p = 0; p < 3 - satirKisiler.length; p++)
                                    const Expanded(child: SizedBox()),
                                ]);
                              }),
                            ],
                          ]),
                        ),
                      ));
                    })),
                  ),
                );
              }),
            ]),
          ),
          actions: const [],
        );
      });
    });
  }
  void _notamEkraniAc() {
    bool modalLoading = false;

    // Kategori/Tag Belirleme (Öncelik: 0=Pist, 1=Taksi, 2=Elektrik, 3=Genel, 4=Mania)
    List<dynamic> _getTagAndColor(String icerik, String id) {
      if (_customNotamTags.containsKey(id)) {
        String tagName = _customNotamTags[id]!;
        if (_allTags.containsKey(tagName)) {
          return [tagName, _allTags[tagName]![0], _allTags[tagName]![1]];
        }
      }
      String upper = icerik.toUpperCase();
      if (upper.contains("RWY") || upper.contains("RUNWAY") || upper.contains("ILS") || upper.contains("VOR")) {
        return ["🚨 PİST/NAV", Colors.redAccent, 0];
      } else if (upper.contains("CRANE") || upper.contains("MAST") || upper.contains("OBST") || upper.contains("VINC") || upper.contains("VİNÇ")) {
        return ["🚧 MANİA/VİNÇ", Colors.grey, 6];
      } else if (upper.contains("FLASHING") || upper.contains("SEQUENCED") || upper.contains("EDGE LGT") || upper.contains("PAPI") || upper.contains("IŞIK") || upper.contains("ISIK") || upper.contains("YANIP") || upper.contains("LEVHA") || RegExp(r'\bLIGHT\b|\bLIGHTS\b|\bSIGN\b|\bSIGNS\b').hasMatch(upper)) {
        return ["⚡ Elektrik/Electric", Colors.yellowAccent, 2];
      } else if (upper.contains("TWY") || upper.contains("TAXIWAY") || upper.contains("APRON") || upper.contains("STAND") || upper.contains("GATE") || upper.contains("PARK") || upper.contains("PRKG")) {
        return ["⚠️ TAKSİ/APRON", Colors.orangeAccent, 1];
      } else if (upper.contains("ANEMOMETRE") || upper.contains("ANEMOMETER") ||
                 upper.contains("WINDSOCK") || upper.contains("WIND SOCK") ||
                 upper.contains("RUZGAR TULUMU") || upper.contains("RÜZGAR TULUMU") ||
                 upper.contains("LLWAS") || upper.contains("WINDSHEAR") ||
                 upper.contains("ATIS ") || upper.contains("AWOS") ||
                 upper.contains("TRANSMISSOMETRE") || upper.contains("TRANSMISSOMETER") ||
                 upper.contains("CEILOMETER") || upper.contains("TAVAN OLCER") || upper.contains("TAVAN ÖLÇER") ||
                 upper.contains("RVR ") || upper.contains("METEOROLOJ")) {
        return ["🌦️ METEOROLOJİ", Colors.tealAccent, 5];
      }
      return ["ℹ️ GENEL", Colors.lightBlueAccent, 3];
    }

    // Dil Tespiti
    String _getDil(String id, String icerik) {
      String u = icerik.toUpperCase();
      // Türkçe imzalar (NOTAM'larda büyük harfle yazılmış tipik Türkçe kelimeler)
      if (u.contains("ÇALIŞMAMAKTADIR") || u.contains("CALISMAMAKTADIR") ||
          u.contains("CALISMAKTADIR") || u.contains("KAPALIDIR") || u.contains("KAPALID") ||
          u.contains("FAALDIR") || u.contains("BULUNMAMAKTADIR") || u.contains("GEREKMEKTEDIR") ||
          u.contains("NEDENIYLE") || u.contains("DOLAYI") || u.contains("ARIZASI") ||
          u.contains("TESKIL") || u.contains("KOORDINATLAR") || u.contains("YUKSEKLIGI") ||
          u.contains("MEYDAN") || u.contains("CALISMA SAATLERI") || u.contains("IKAZLA") ||
          u.contains("ARASINDA")) return "TR";
      // İngilizce imzalar
      if (u.contains("OUT OF SERVICE") || u.contains("U/S") || u.contains("AVBL") ||
          u.contains("CLOSED") || u.contains("CONSTRUCTION") || u.contains("UNSERVICEABLE") ||
          u.contains("AS FOLLOWS") || u.contains("OPERATING HOURS") || u.contains("PRESENCE") ||
          u.contains("DUE TO") || u.contains("COORDINATES") || u.contains("ELEVATION") ||
          u.contains("REMOTE CONTROL") || u.contains("SEQUENCED FLASHING") ||
          u.contains("PPR") || u.contains("AVBL FOR") || u.contains("BARRIER IS") ||
          u.contains("OCTANE") || u.contains("PROVIDING")) return "EN";
      // Son çare: ID prefix
      return (id.startsWith("G") || id.startsWith("M") || id.startsWith("A")) ? "EN" : "TR";
    }

    // Her dialog açılışında collapsed listesini sıfırdan kur:
    // Önce pinli olmayanları temizle, sonra sadece EN'leri collapsed yap
    _collapsedNotams.removeWhere((id) => !_pinnedNotams.contains(id));
    for (var n in ltaiNotamlari) {
      String dil = _getDil(n['id'], n['icerik']);
      if (dil == "EN") {
        _collapsedNotams.add(n['id']);
      }
    }

    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setModalState) {

      // ── Sıralama: Pin → Dil (TR önce) → Rozet/Kategori → Bitiş Tarihi ──
      // Sonuç: TR Pist/NAV → TR Taksi → TR Elektrik → TR Genel → TR Vinç
      //          → EN Pist/NAV → EN Taksi → EN Elektrik → EN Genel → EN Vinç
      List<dynamic> sortedNotams = List.from(ltaiNotamlari);
      sortedNotams.sort((a, b) {
        // 1. Pin: pinlenenler en üste
        bool aPinned = _pinnedNotams.contains(a['id']);
        bool bPinned = _pinnedNotams.contains(b['id']);
        if (aPinned != bPinned) return aPinned ? -1 : 1;

        // 2. Dil: TR (0) önce, EN (1) sonra
        String aD = _getDil(a['id'], a['icerik']);
        String bD = _getDil(b['id'], b['icerik']);
        int dilComp = (aD == "TR" ? 0 : 1).compareTo(bD == "TR" ? 0 : 1);
        if (dilComp != 0) return dilComp;

        // 3. Kategori: Pist(0) → Taksi(1) → Elektrik(2) → Genel(3) → Vinç(4)
        int aPrio = _getTagAndColor(a['icerik'], a['id'])[2] as int;
        int bPrio = _getTagAndColor(b['icerik'], b['id'])[2] as int;
        if (aPrio != bPrio) return aPrio.compareTo(bPrio);

        // 4. Aynı dil + aynı kategoride → bitiş tarihine göre
        return (a['bitis'] ?? "").compareTo(b['bitis'] ?? "");
      });

      return AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              const Icon(Icons.assignment_late, color: Colors.amber, size: 24),
              const SizedBox(width: 10),
              Text("LTAI NOTAM (${sortedNotams.length})", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            Row(
              children: [
                Text(notamGuncelleme.isNotEmpty ? "Güncelleme: $notamGuncelleme" : "", style: const TextStyle(color: Colors.white24, fontSize: 10)),
                const SizedBox(width: 15),
                modalLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.lightBlueAccent, strokeWidth: 2))
                  : IconButton(
                      icon: const Icon(Icons.sync, color: Colors.lightBlueAccent, size: 20),
                      tooltip: "Sadece NOTAM'ları Güncelle",
                      onPressed: () async {
                        setModalState(() => modalLoading = true);
                        await _sadeceNotamVerisiniCek();
                        // Yeni NOTAM'lar gelince EN olanları collapsed yap
                        for (var n in ltaiNotamlari) {
                          String dil = _getDil(n['id'], n['icerik']);
                          if (dil == 'EN' || n['icerik'].toString().toUpperCase().contains('CRANE') || n['icerik'].toString().toUpperCase().contains('VINC')) {
                            if (!_collapsedNotams.contains(n['id'])) _collapsedNotams.add(n['id']);
                          }
                        }
                        setModalState(() => modalLoading = false);
                      },
                    )
              ],
            )
          ],
        ),
        content: SizedBox(
          width: 700,
          height: 550,
          child: sortedNotams.isEmpty
            ? const Center(child: Text("Şu an aktif NOTAM bulunamadı.", style: TextStyle(color: Colors.white54)))
            : ListView.builder(
                itemCount: sortedNotams.length,
                itemBuilder: (context, i) {
                  var n = sortedNotams[i];
                  String id = n['id'];
                  String icerik = n['icerik'];
                  
                  bool isPinned = _pinnedNotams.contains(id);
                  bool isCollapsed = _collapsedNotams.contains(id);
                  var tagInfo = _getTagAndColor(icerik, id);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isPinned ? Colors.amber.withOpacity(0.05) : Colors.white.withOpacity(0.03), 
                      borderRadius: BorderRadius.circular(8), 
                      border: Border.all(color: isPinned ? Colors.amber.withOpacity(0.5) : Colors.white12, width: isPinned ? 1.5 : 1.0)
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Üst Bar (Başlık ve İkonlar)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          child: Row(
                            children: [
                              // Pin İkonu
                              GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    if (isPinned) { _pinnedNotams.remove(id); } 
                                    else { _pinnedNotams.add(id); _collapsedNotams.remove(id); }
                                  });
                                },
                                child: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined, size: 18, color: isPinned ? Colors.amber : Colors.white38),
                              ),
                              const SizedBox(width: 8),
                              
                              // ID
                              Text(id, style: TextStyle(color: isPinned ? Colors.amber : Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 10),

                              // Tarih
                              Text("${n['baslangic']} - ${n['bitis']}", style: TextStyle(color: isPinned ? Colors.white54 : Colors.white38, fontSize: 11)),
                              
                              const Spacer(),

                              // Tag Badge (Değiştirilebilir)
                              PopupMenuButton<String>(
                                tooltip: "Rozeti Değiştir",
                                initialValue: tagInfo[0],
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                color: const Color(0xFF2E2E2E), 
                                itemBuilder: (context) => [
                                  ..._allTags.keys.map((String tag) {
                                    bool isBuiltIn = _builtInTagNames.contains(tag);
                                    return PopupMenuItem<String>(
                                      value: tag,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(child: Text(tag, style: TextStyle(color: _allTags[tag]![0], fontSize: 13, fontWeight: FontWeight.bold))),
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.pop(context);
                                              setModalState(() {
                                                // Bu rozeti kullanan tüm NOTAM'ları temizle
                                                _customNotamTags.removeWhere((k, v) => v == tag);
                                                // Sadece özel rozetleri listeden kaldır
                                                _saveNotamPrefs();
                                                if (!isBuiltIn) _allTags.remove(tag);
                                              });
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.only(left: 8),
                                                child: Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem<String>(
                                    value: "__YENI__",
                                    child: Center(child: Icon(Icons.add, size: 20, color: Colors.greenAccent)),
                                  ),
                                ],
                                onSelected: (String val) {
                                  if (val == "__YENI__") {
                                    _yeniRozetOlusturDiyalog(setModalState);
                                  } else {
                                    setModalState(() {
                                      _customNotamTags[id] = val;
                                      // ── TR↔EN Otomatik Çift Etiketleme ──
                                      _autoTagPairNotam(id, val);
                                      _saveNotamPrefs();
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: tagInfo[1].withOpacity(0.15), border: Border.all(color: tagInfo[1].withOpacity(0.5)), borderRadius: BorderRadius.circular(4)),
                                  child: Text(tagInfo[0], style: TextStyle(color: tagInfo[1], fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Genişlet/Daralt İkonu
                              GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    if (isCollapsed) { _collapsedNotams.remove(id); } 
                                    else { _collapsedNotams.add(id); }
                                  });
                                },
                                child: Icon(isCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, color: Colors.white54, size: 24),
                              ),
                            ],
                          ),
                        ),
                        
                        // İçerik (Eğer daraltılmamışsa)
                        if (!isCollapsed)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Text(icerik, style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4)),
                          ),
                      ],
                    ),
                  );
                },
              ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("KAPAT", style: TextStyle(color: Colors.orangeAccent)))],
      );
    }));
  }

  // ── TR↔EN Otomatik Çift Etiketleme Fonksiyonu ──
  void _autoTagPairNotam(String sourceId, String tagName) {
    // Kaynak NOTAM'ı bul
    var sourceNotam = ltaiNotamlari.firstWhere((n) => n['id'] == sourceId, orElse: () => null);
    if (sourceNotam == null) return;
    String sourceIcerik = (sourceNotam['icerik'] ?? "").toString().toUpperCase();
    String sourceBaslangic = sourceNotam['baslangic'] ?? "";
    String sourceBitis = sourceNotam['bitis'] ?? "";

    // İçerikten anahtar kavramları çıkar
    List<String> keywords = [];
    // Konum tanımlayıcıları
    final rwyMatch = RegExp(r'RWY\s*(\d+[LRC]?)').firstMatch(sourceIcerik);
    if (rwyMatch != null) keywords.add('RWY ${rwyMatch.group(1)}');
    final thrMatch = RegExp(r'THR\s*(\d+[LRC]?)').firstMatch(sourceIcerik);
    if (thrMatch != null) keywords.add('THR ${thrMatch.group(1)}');
    final twyMatch = RegExp(r'TWY\s*([A-Z]\d*)').firstMatch(sourceIcerik);
    if (twyMatch != null) keywords.add('TWY ${twyMatch.group(1)}');
    // Ekipman anahtar kelimeleri (her iki dilde)
    const equipmentPairs = [
      ['ANEMOMETRE', 'ANEMOMETER'],
      ['RUZGAR TULUMU', 'WINDSOCK'], ['RUZGAR TULUMU', 'WIND SOCK'],
      ['LLWAS', 'LLWAS'], ['WINDSHEAR', 'WINDSHEAR'],
      ['BARIYER', 'BARRIER'], ['BARIYERI', 'BARRIER'],
      ['PAPI', 'PAPI'], ['ILS', 'ILS'], ['VOR', 'VOR'],
      ['TRANSMISSOMETRE', 'TRANSMISSOMETER'],
      ['TAVAN OLCER', 'CEILOMETER'],
      ['VINC', 'CRANE'], ['MANIA', 'OBSTACLE'],
    ];
    for (var pair in equipmentPairs) {
      if (sourceIcerik.contains(pair[0]) || sourceIcerik.contains(pair[1])) {
        keywords.addAll(pair);
      }
    }

    if (keywords.isEmpty) return; // Eşleşecek anahtar kelime yok

    // Diğer NOTAM'larda eşleşen karşılığı ara
    for (var n in ltaiNotamlari) {
      if (n['id'] == sourceId) continue; // Kendisi değil
      String nIcerik = (n['icerik'] ?? "").toString().toUpperCase();
      String nBaslangic = n['baslangic'] ?? "";
      String nBitis = n['bitis'] ?? "";
      // Tarih eşleşmesi (aynı zaman aralığı → muhtemelen aynı konu)
      bool sameDates = (nBaslangic == sourceBaslangic && nBitis == sourceBitis);
      // Keyword eşleşmesi
      int matchCount = keywords.where((kw) => nIcerik.contains(kw)).length;
      // En az 1 keyword eşleşmesi + tarih eşleşmesi VEYA 2+ keyword eşleşmesi
      if ((matchCount >= 1 && sameDates) || matchCount >= 2) {
        _customNotamTags[n['id']] = tagName;
      }
    }
  }

  void _yeniRozetOlusturDiyalog(Function setModalState) {
    TextEditingController _nameCtrl = TextEditingController();
    Color _selectedColor = Colors.blueAccent;
    final List<Color> _palette = [
      Colors.redAccent, Colors.orangeAccent, Colors.amberAccent, Colors.greenAccent, 
      Colors.tealAccent, Colors.lightBlueAccent, Colors.blueAccent, Colors.purpleAccent,
      Colors.pinkAccent, Colors.deepOrangeAccent, Colors.grey, Colors.brown
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDState) {
        return AlertDialog(
          backgroundColor: const Color(0xFF252525),
          title: const Text("Yeni Rozet Oluştur", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Rozet İsmi (Örn: 🏗️ INSAAT)",
                  labelStyle: TextStyle(color: Colors.white54, fontSize: 12),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orangeAccent)),
                ),
              ),
              const SizedBox(height: 20),
              const Align(alignment: Alignment.centerLeft, child: Text("Renk Seçin:", style: TextStyle(color: Colors.white54, fontSize: 11))),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _palette.map((c) => GestureDetector(
                  onTap: () => setDState(() => _selectedColor = c),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: c, 
                      shape: BoxShape.circle, 
                      border: Border.all(color: _selectedColor == c ? Colors.white : Colors.transparent, width: 2)
                    ),
                  ),
                )).toList(),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("İPTAL", style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
              onPressed: () {
                String name = _nameCtrl.text.trim().toUpperCase();
                if (name.isNotEmpty) {
                  setState(() {
                    // Yeni rozeti ekle
                    _allTags[name] = [_selectedColor, _allTags.length];
                  });
                  _saveNotamPrefs();
                  setModalState(() {}); // Ana modalı güncelle
                  Navigator.pop(context);
                }
              },
              child: const Text("EKLE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            )
          ],
        );
      })
    );
  }


  Widget _ozelSecimBtn(String k, String type, Color c, Function setD) {
    bool isSelected = false;
    if (type == 'İLK') isSelected = ilkSecilenler.contains(k);
    if (type == 'SON') isSelected = sonSecilenler.contains(k);
    if (type == 'BİZİMLE KAL') isSelected = bizimleKalSecilenler.contains(k);
    if (type == '00⁰⁰-03⁰⁰') isSelected = gece1203Secilenler.contains(k);
    if (type == 'ARA') isSelected = geceAraSecilenler.contains(k);
    if (type == '05³⁰-08⁰⁰') isSelected = gece0508Secilenler.contains(k);
    if (type == '08⁰⁰-09⁰⁰') isSelected = gece0809Secilenler.contains(k);
    if (type == 'OFF') isSelected = geceOffSecilenler.contains(k);
    if (type == 'SUP ONLY') isSelected = supOnlySecilenler.contains(k);

    return InkWell(
      onTap: () => setD(() {
        void clearGece() {
          gece1203Secilenler.remove(k);
          geceAraSecilenler.remove(k);
          gece0508Secilenler.remove(k);
          gece0809Secilenler.remove(k);
          geceOffSecilenler.remove(k);
        }

        if (type == 'SUP ONLY') {
           if (isSelected) {
             supOnlySecilenler.remove(k);
           } else {
             supOnlySecilenler.add(k);
             yetkiler[k]?.remove('SUP'); // SUP ONLY seçilince SUP yetkisini kaldır
           }
        } else if (type == 'İLK') {
          if (isSelected) {
            ilkSecilenler.remove(k);
          } else {
            ilkSecilenler.add(k);
            sonSecilenler.remove(k); 
          }
        } else if (type == 'SON') {
          if (isSelected) {
            sonSecilenler.remove(k);
          } else {
            sonSecilenler.add(k);
            ilkSecilenler.remove(k);
            bizimleKalSecilenler.remove(k); 
          }
        } else if (type == 'BİZİMLE KAL') {
          if (isSelected) {
            bizimleKalSecilenler.remove(k);
          } else {
            if (bizimleKalSecilenler.length < 3) { 
              bizimleKalSecilenler.add(k);
              sonSecilenler.remove(k); 
            }
          }
        } else if (type == '00⁰⁰-03⁰⁰') {
           if (isSelected) gece1203Secilenler.remove(k);
           else { clearGece(); gece1203Secilenler.add(k); }
        } else if (type == 'ARA') {
           if (isSelected) geceAraSecilenler.remove(k);
           else { clearGece(); geceAraSecilenler.add(k); }
        } else if (type == '05³⁰-08⁰⁰') {
           if (isSelected) gece0508Secilenler.remove(k);
           else { clearGece(); gece0508Secilenler.add(k); }
        } else if (type == '08⁰⁰-09⁰⁰') {
           if (isSelected) gece0809Secilenler.remove(k);
           else { clearGece(); gece0809Secilenler.add(k); }
        } else if (type == 'OFF') {
           if (isSelected) geceOffSecilenler.remove(k);
           else { clearGece(); geceOffSecilenler.add(k); }
        }
        _gruplariGuncelle(arsiveKaydet: false);
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: isSelected ? c.withOpacity(0.2) : Colors.transparent,
          border: Border.all(
            color: isSelected ? c : Colors.white24,
            width: isSelected ? 1.5 : 1.0
          ),
          borderRadius: BorderRadius.circular(4)
        ),
        child: Text(type, style: TextStyle(
          color: isSelected ? c : Colors.white54,
          fontSize: 9, 
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
        ))
      )
    );
  }

  /// Gündüz ↔ Gece mod geçişinde hedef modun tüm seçimlerini sıfırlar.
  /// Her gün farklı nöbet — seçimler taşınmamalı.
  void _modGecisiTemizle(bool hedefGunduz) {
    if (hedefGunduz) {
      _ilkSecilenlerGunduz.clear();
      _sonSecilenlerGunduz.clear();
      _bizimleKalSecilenlerGunduz.clear();
      _supOnlySecilenlerGunduz.clear();
      for (var k in tumPersonelHavuzu) {
        _gunlukDurumGunduz[k]?.removeAll(['HAMAL', 'ENSECİ']);
      }
    } else {
      _ilkSecilenlerGece.clear();
      _sonSecilenlerGece.clear();
      _bizimleKalSecilenlerGece.clear();
      _supOnlySecilenlerGece.clear();
      gece1203Secilenler.clear();
      geceAraSecilenler.clear();
      gece0508Secilenler.clear();
      gece0809Secilenler.clear();
      geceOffSecilenler.clear();
    }
    // Yetkiler (TWR/GND/DEL/SUP) de sıfırlanır — her gün farklı
    for (var k in tumPersonelHavuzu) {
      yetkiler[k]?.clear();
    }
  }

  Widget _durumBtn(String k, String d, Color c, Function setD, String txt) {
    bool s = gunlukDurum[k]!.contains(d);
    return InkWell(
      onTap: () => setD(() {
        if (d == 'OFF' || d == 'KAZANDIŞI') {
          if (s) {
            gunlukDurum[k] = {'A'}; 
          } else {
            gunlukDurum[k] = {d};
          }
        } else {
          gunlukDurum[k]!.remove('OFF');
          gunlukDurum[k]!.remove('KAZANDIŞI');
          if (!tamOtomatikDagitim && ['A','B','C','D','E'].contains(d)) {
            gunlukDurum[k]!.removeWhere((x) => ['A','B','C','D','E'].contains(x));
            gunlukDurum[k]!.add(d);
          } else {
            if (s) gunlukDurum[k]!.remove(d);
            else gunlukDurum[k]!.add(d);
          }
        }
        _gruplariGuncelle(arsiveKaydet: false);
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: s ? c : Colors.transparent,
          border: Border.all(color: s ? Colors.black : c, width: 1.5),
          borderRadius: BorderRadius.circular(4)
        ),
        child: Text(txt, style: TextStyle(
          color: s ? Colors.black : c, 
          fontSize: txt == "AĞUSTOS BÖCEĞİ" ? 6.5 : 8, 
          fontWeight: FontWeight.bold
        ))
      )
    );
  }

  Widget _yetkiBtn(String k, String y, Function setD) {
    yetkiler[k] ??= <String>{};
    bool s = yetkiler[k]!.contains(y);
    return InkWell(
      onTap: () => setD(() {
        if (s) yetkiler[k]!.remove(y);
        else {
          yetkiler[k]!.add(y);
          if (y == 'SUP') supOnlySecilenler.remove(k); // SUP seçilince SUP ONLY'yi kaldır
        }
        _gruplariGuncelle(arsiveKaydet: false);
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: s ? Colors.cyanAccent.withOpacity(0.2) : Colors.transparent,
          border: Border.all(
            color: s ? Colors.cyanAccent : Colors.white24, 
            width: s ? 1.5 : 1.0
          ),
          borderRadius: BorderRadius.circular(4)
        ),
        child: Text(y, style: TextStyle(
          color: s ? Colors.cyanAccent : Colors.white54, 
          fontSize: 9, 
          fontWeight: s ? FontWeight.bold : FontWeight.normal
        ))
      )
    );
  }

  void _isimDuzenle(int i, Function setD) {
    TextEditingController c = TextEditingController(text: tumPersonelHavuzu[i]);
    showDialog(
      context: context,
      builder: (context) => Center(
        child: Material(
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Container(
            width: 140, 
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: c, 
                  autofocus: true,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    counterText: "",
                    isDense: true,
                    contentPadding: EdgeInsets.only(bottom: 4),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orangeAccent)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                      icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                      tooltip: "Sil",
                      onPressed: () {
                        setState(() {
                          String k = tumPersonelHavuzu[i];
                          tumPersonelHavuzu.removeAt(i);
                          _gunlukDurumGunduz.remove(k);
                          _gunlukDurumGece.remove(k);
                          yetkiler.remove(k);
                          _ilkSecilenlerGunduz.remove(k);
                          _ilkSecilenlerGece.remove(k);
                          _sonSecilenlerGunduz.remove(k);
                          _sonSecilenlerGece.remove(k);
                          _bizimleKalSecilenlerGunduz.remove(k);
                          _bizimleKalSecilenlerGece.remove(k);
                          _supOnlySecilenlerGunduz.remove(k);
                          _supOnlySecilenlerGece.remove(k);
                          gece1203Secilenler.remove(k);
                          geceAraSecilenler.remove(k);
                          gece0508Secilenler.remove(k);
                          gece0809Secilenler.remove(k);
                          geceOffSecilenler.remove(k);
                        });
                        _savePersonelPrefs();
                        setD(() { _gruplariGuncelle(arsiveKaydet: false); });
                        Navigator.pop(context);
                      },
                    ),
                    IconButton(
                      padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      tooltip: "İptal",
                      onPressed: () => Navigator.pop(context)
                    ),
                    IconButton(
                      padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                      icon: const Icon(Icons.save, color: Colors.orangeAccent, size: 20),
                      tooltip: "Kaydet",
                      onPressed: () {
                        setState(() {
                          String old = tumPersonelHavuzu[i];
                          String n = c.text.trim().toUpperCase();
                          if (n.isNotEmpty && n != old) {
                            tumPersonelHavuzu[i] = n;
                            _gunlukDurumGunduz[n] = _gunlukDurumGunduz[old]!;
                            _gunlukDurumGece[n] = _gunlukDurumGece[old]!;
                            yetkiler[n] = yetkiler[old]!;
                            
                            if(_ilkSecilenlerGunduz.contains(old)) { _ilkSecilenlerGunduz.remove(old); _ilkSecilenlerGunduz.add(n); }
                            if(_ilkSecilenlerGece.contains(old)) { _ilkSecilenlerGece.remove(old); _ilkSecilenlerGece.add(n); }
                            if(_sonSecilenlerGunduz.contains(old)) { _sonSecilenlerGunduz.remove(old); _sonSecilenlerGunduz.add(n); }
                            if(_sonSecilenlerGece.contains(old)) { _sonSecilenlerGece.remove(old); _sonSecilenlerGece.add(n); }
                            if(_bizimleKalSecilenlerGunduz.contains(old)) { _bizimleKalSecilenlerGunduz.remove(old); _bizimleKalSecilenlerGunduz.add(n); }
                            if(_bizimleKalSecilenlerGece.contains(old)) { _bizimleKalSecilenlerGece.remove(old); _bizimleKalSecilenlerGece.add(n); }
                            if(_supOnlySecilenlerGunduz.contains(old)) { _supOnlySecilenlerGunduz.remove(old); _supOnlySecilenlerGunduz.add(n); }
                            if(_supOnlySecilenlerGece.contains(old)) { _supOnlySecilenlerGece.remove(old); _supOnlySecilenlerGece.add(n); }
                            if(gece1203Secilenler.contains(old)) { gece1203Secilenler.remove(old); gece1203Secilenler.add(n); }
                            if(geceAraSecilenler.contains(old)) { geceAraSecilenler.remove(old); geceAraSecilenler.add(n); }
                            if(gece0508Secilenler.contains(old)) { gece0508Secilenler.remove(old); gece0508Secilenler.add(n); }
                            if(gece0809Secilenler.contains(old)) { gece0809Secilenler.remove(old); gece0809Secilenler.add(n); }
                            if(geceOffSecilenler.contains(old)) { geceOffSecilenler.remove(old); geceOffSecilenler.add(n); }
                            _gunlukDurumGunduz.remove(old);
                            _gunlukDurumGece.remove(old);
                            yetkiler.remove(old);
                          }
                        });
                        _savePersonelPrefs();
                        setD(() { _gruplariGuncelle(arsiveKaydet: false); });
                        Navigator.pop(context); 
                      }
                    )
                  ],
                )
              ]
            )
          )
        )
      )
    );
  }

  // NOT: Saat düzenlemeleri session-only — uygulama kapanınca varsayılanlara döner (kasıtlı)
  void _saatDuzenle(int i) {
    TextEditingController c = TextEditingController(text: saatler[i]);
    showDialog(
      context: context,
      builder: (context) => Center(
        child: Material(
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Container(
            width: 220, 
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("SAAT ARALIĞI", style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: c, 
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.only(bottom: 4),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orangeAccent)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      tooltip: "İptal",
                      onPressed: () => Navigator.pop(context)
                    ),
                    IconButton(
                      padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                      icon: const Icon(Icons.save, color: Colors.greenAccent, size: 20),
                      tooltip: "Kaydet",
                      onPressed: () {
                        String n = c.text.trim();
                        n = n.replaceAll('.', ':').replaceAll(RegExp(r'\s*-\s*'), ' - ');

                        if (RegExp(r'^\d{2}:\d{2} - \d{2}:\d{2}$').hasMatch(n)) {
                          if (n != saatler[i]) {
                            setState(() {
                              if (isGunduzVardiyasi) {
                                if (saatSenaryosu == 1) { gunduzKlasik[i] = n; } else { gunduzAlengirli[i] = n; }
                              } else {
                                if (saatSenaryosu == 1) { geceKlasik[i] = n; } else { geceAlengirli[i] = n; }
                              }
                            });
                            _gruplariGuncelle();
                          }
                          Navigator.pop(context); 
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Formatı kontrol et! (Örn: 09:00 - 10:40)"),
                              backgroundColor: Colors.redAccent,
                              duration: Duration(seconds: 2),
                            )
                          );
                        }
                      }
                    )
                  ],
                )
              ]
            )
          )
        )
      )
    );
  }
}