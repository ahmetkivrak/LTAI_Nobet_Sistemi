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
      home: const AnaSayfa(),
    );
  }
}

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});
  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  bool isGunduzVardiyasi = true;
  int saatSenaryosu = 1; 
  
  List<String> gunduzKlasik = ["09:00 - 10:40", "10:40 - 12:20", "12:20 - 14:00", "14:00 - 15:40", "15:40 - 17:20", "17:20 - 19:00"];
  List<String> gunduzAlengirli = ["09:00 - 10:40", "10:40 - 12:20", "12:20 - 14:00", "14:00 - 15:20", "15:20 - 16:40", "16:40 - 17:50", "17:50 - 19:00"];
  
  List<String> geceKlasik = ["19:00 - 21:20", "21:20 - 23:40", "23:40 - 02:00", "02:00 - 04:20", "04:20 - 06:40", "06:40 - 09:00"];
  List<String> geceAlengirli = ["19:00 - 21:00", "21:00 - 23:00", "23:00 - 01:00", "01:00 - 03:00", "03:00 - 05:00", "05:00 - 07:00", "07:00 - 09:00"];

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

  final List<String> tumPersonelHavuzu = ["GP", "AI", "AK", "BE", "MK", "AN", "BA", "BL", "DE", "MI", "FL", "YT", "GI", "AP", "DC"];
  
  Map<String, Set<String>> gunlukDurum = {};
  Map<String, Set<String>> yetkiler = {}; 
  
  Set<String> ilkSecilenler = {};
  Set<String> ortaSecilenler = {};
  Set<String> sonSecilenler = {};
  Set<String> bizimleKalSecilenler = {};

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


  Map<String, int> turSayisi = {}; Map<String, int> dakikaSayisi = {}; 
  Map<String, int> supSayisi = {}; Map<String, int> twrSayisi = {}; Map<String, int> gndSayisi = {}; Map<String, int> delSayisi = {};

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
    _tabController = TabController(length: 2, vsync: this);
    for (var k in tumPersonelHavuzu) {
      gunlukDurum[k] = {'A'};
      yetkiler[k] = {}; 
    }
    
    anlikTrafik24 = List.generate(24, (i) => TrafikVerisi(0, 0, vfrGelen: 0, vfrGiden: 0));
    _varsayilanAirgramYarat();

    for (int i = 0; i < 24; i++) {
      anlikHava24[i] = HavaDurumu(gunesli: true); 
    }
    
    _meteorolojiVerisiniCek();
    _trafikVerisiniCek();
    _trafikSlotlariniHesapla();
    gunlukSeviye = hakimSeviye;
    _gruplariGuncelle(arsiveKaydet: false);
    _loadNotamPrefs(); // Rozet tercihlerini yükle
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
      final response = await http.get(Uri.parse(gasUrl)).timeout(const Duration(seconds: 15));
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
          debugPrint("AŞÇI'DAN PAKET ALINDI!");
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
      setState(() { _veriCekiliyor = false; });
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
      final response = await http.get(url).timeout(const Duration(seconds: 10));
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
        bool isYarin = !isGunduzVardiyasi && (h < 12); 
        TrafikVerisi curTrf = isYarin ? yarinTrafik24[h] : anlikTrafik24[h];
        if (curTrf.genelToplam > maxTrf.genelToplam) maxTrf = curTrf;
        if (h == endH && endM == 0) break; 
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
        HavaDurumu hwDurum = anlikHava24[hw] ?? HavaDurumu();
        if (hwDurum.rwy.contains("36")) has36 = true; if (hwDurum.rwy.contains("18")) has18 = true;
        if (hwDurum.yagmur) hasRain = true; if (hwDurum.oraj) hasStorm = true;
        if (hwDurum.bulutlu) hasCloud = true; if (hwDurum.siddetliRuzgar) hasWind = true;
        if (hw == endH && endM == 0) break; if (hw == endH) break; hw = (hw + 1) % 24;
      }

      String finalRwy = baseRwy;
      if (has36 && has18) finalRwy = (baseRwy.contains("36")) ? "36 🔄 18" : "18 🔄 36";
      else finalRwy = has18 ? "18" : "36";

      anlikHava.add(HavaDurumu(rwy: finalRwy, oraj: hasStorm, yagmur: hasRain && !hasStorm, bulutlu: hasCloud && !hasStorm && !hasRain, gunesli: !hasStorm && !hasRain && !hasCloud, siddetliRuzgar: hasWind));
    }
  }

  void _gruplariGuncelle({bool arsiveKaydet = true}) {
    setState(() { 
      _trafikSlotlariniHesapla(); 
      _hafizayiSifirla(); 
      _arsiveOtomatikKaydet(kaydet: arsiveKaydet); 
    });
  }

  void _hafizayiSifirla() {
    for (var k in tumPersonelHavuzu) {
      turSayisi[k] = 0; dakikaSayisi[k] = 0;
      supSayisi[k] = 0; twrSayisi[k] = 0; gndSayisi[k] = 0; delSayisi[k] = 0;
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
         isAnyActiveSup = aktifPersonelHavuzu.any((k) => yetkiler[k]!.contains('SUP'));
      } else {
         isAnyActiveSup = tumPersonelHavuzu.any((k) => !gunlukDurum[k]!.contains('OFF') && !gunlukDurum[k]!.contains('KAZANDIŞI') && yetkiler[k]!.contains('SUP'));
      }
      if (!isAnyActiveSup) return true; 
      return yetkiler[kisi]!.contains('SUP');
    } else {
      if (yetkiler[kisi]!.isEmpty) return true; 
      if (yetkiler[kisi]!.contains(pozisyon) || yetkiler[kisi]!.contains(core)) return true; 
      if (acilDurum && yetkiler[kisi]!.length == 1 && yetkiler[kisi]!.contains('SUP')) return true; 
      return false;
    }
  }

  // 18 nöbetlik otonom hafıza (izinlileri ezmez)
  double _getArsivYorgunlukOrtalamasi(String k) {
    int c = 0;
    int totalDk = 0;
    int shiftCount = 0;
    for (var a in tamArsiv.reversed) {
       if (a.satirlar.isEmpty) continue;
       String ilkSaat = a.satirlar.first.first;
       bool aGunduz = ilkSaat.startsWith("08:") || ilkSaat.startsWith("09:") || ilkSaat.startsWith("10:");
       if (aGunduz == isGunduzVardiyasi) {
          shiftCount++;
          if (a.istatistik.containsKey(k)) {
             if (!a.izinliler.contains(k) && !a.istatistik[k]!.containsKey('KAZANDIŞI')) {
               totalDk += (a.istatistik[k]!['DK'] as int? ?? 0);
               c++;
             }
          }
          if (shiftCount >= 18) break;
       }
    }
    if (c == 0) return 0.0;
    return totalDk / c;
  }

  // ════════════════════════════════════════════════
  // ALGORİTMA v3 — NUMARALI ZİGZAG DÖNGÜ
  //   Adım 1: Zigzag numaralı şablon oluştur
  //   Adım 2: Kişileri numaralara ata (SUP havuzu öncelikli)
  //   Adım 3: İnce ayar (aynı pozisyon tekrarını grup içi swap ile çöz)
  // ════════════════════════════════════════════════

  /// Phase 1: Her kişi hangi slot(lar)da çalışacak?
  /// Döndürür: {slotIndex: [kişi1, kişi2, kişi3], ...}
  Map<int, List<String>> _phase1SlotAtama(List<String> aktifPersonel, int majT, Set<String> aktifBK) {
    int slotCount = saatler.length;
    
    // Her kişinin hedef tur sayısını belirle
    int toplamSandalye = 0;
    for (int i = 0; i < slotCount; i++) {
      double sLvl = tamOtomatikDagitim 
          ? _getIdealLevel(anlikTrafik[i % anlikTrafik.length].genelToplam) 
          : gunlukSeviye;
      toplamSandalye += getSektorlerByLevel(sLvl).length;
    }
    
    int aCount = aktifPersonel.length;
    int baseTurLocal = aCount > 0 ? (toplamSandalye ~/ aCount) : 0;
    int remLocal = aCount > 0 ? (toplamSandalye % aCount) : 0;
    
    // HAMAL/ENSECİ sayısını kontrol et
    int hamalSayisi = aktifPersonel.where((k) => gunlukDurum[k]!.contains('HAMAL')).length;
    int enseciSayisi = aktifPersonel.where((k) => gunlukDurum[k]!.contains('ENSECİ')).length;
    
    Map<String, int> hedefTur = {};
    
    if (hamalSayisi == 0 && enseciSayisi == 0 && remLocal > 0) {
      // Kimse seçilmemiş → arşiv yorgunluğuna göre otomatik karınca
      List<String> sirali = List.from(aktifPersonel);
      sirali.sort((a, b) => _getArsivYorgunlukOrtalamasi(a).compareTo(_getArsivYorgunlukOrtalamasi(b)));
      for (int i = 0; i < sirali.length; i++) {
        hedefTur[sirali[i]] = i < remLocal ? baseTurLocal + 1 : baseTurLocal;
      }
    } else {
      for (var k in aktifPersonel) {
        if (gunlukDurum[k]!.contains('HAMAL')) {
          hedefTur[k] = majT + 1;
        } else if (gunlukDurum[k]!.contains('ENSECİ')) {
          hedefTur[k] = (majT - 1).clamp(1, slotCount);
        } else {
          hedefTur[k] = majT;
        }
      }
      // Eksik sandalye kontrolü
      int toplamHedef = hedefTur.values.fold(0, (a, b) => a + b);
      int eksik = toplamSandalye - toplamHedef;
      if (eksik > 0) {
        List<String> adaylar = aktifPersonel.where((k) => !gunlukDurum[k]!.contains('HAMAL')).toList();
        adaylar.sort((a, b) => _getArsivYorgunlukOrtalamasi(a).compareTo(_getArsivYorgunlukOrtalamasi(b)));
        for (int i = 0; i < eksik && i < adaylar.length; i++) {
          hedefTur[adaylar[i]] = hedefTur[adaylar[i]]! + 1;
        }
      }
    }
    
    for (var k in aktifPersonel) {
      if (hedefTur[k] == null || hedefTur[k]! < 1) hedefTur[k] = 1;
    }
    

    
    // Slot kapasiteleri
    List<int> slotKapasiteleri = [];
    for (int i = 0; i < slotCount; i++) {
      double sLvl = tamOtomatikDagitim 
          ? _getIdealLevel(anlikTrafik[i % anlikTrafik.length].genelToplam) 
          : gunlukSeviye;
      slotKapasiteleri.add(getSektorlerByLevel(sLvl).length);
    }
    
    // ═══════════════════════════════════════════════════════════
    // NUMARALI DÖNGÜ: Kişileri arşiv yorgunluğuna göre sırala,
    // sonra zigzag şablona göre slotlara yerleştir
    // ═══════════════════════════════════════════════════════════
    
    // Kişileri sırala: arşiv yorgunluk (az çalışan önce)
    List<String> siraliPersonel = List.from(aktifPersonel);
    siraliPersonel.sort((a, b) => _getArsivYorgunlukOrtalamasi(a).compareTo(_getArsivYorgunlukOrtalamasi(b)));
    
    // İlk/Son/Orta seçili mantığı — sınıf seviyesi Set'lerden oku (shadow bug düzeltmesi)
    Set<String> aktifIlkSecilenler = this.ilkSecilenler.where((k) => aktifPersonel.contains(k)).toSet();
    Set<String> aktifSonSecilenler = this.sonSecilenler.where((k) => aktifPersonel.contains(k)).toSet();
    Set<String> aktifOrtaSecilenler = this.ortaSecilenler.where((k) => aktifPersonel.contains(k)).toSet();
    
    // BK son slotta oturamaz
    // İlk seçili → sıranın başına al, Son seçili → sıranın sonuna al
    // Orta seçili → ne başa ne sona, ortaya yerleştir (ilk ve son slota giremez)
    List<String> bOnce = siraliPersonel.where((k) => aktifIlkSecilenler.contains(k)).toList();
    List<String> bSonra = siraliPersonel.where((k) => aktifSonSecilenler.contains(k)).toList();
    List<String> bOrta = siraliPersonel.where((k) => aktifOrtaSecilenler.contains(k) && !aktifIlkSecilenler.contains(k) && !aktifSonSecilenler.contains(k)).toList();
    List<String> bNormal = siraliPersonel.where((k) => !aktifIlkSecilenler.contains(k) && !aktifSonSecilenler.contains(k) && !aktifOrtaSecilenler.contains(k)).toList();
    // Sıralama: İLK → Normal(1.yarı) → ORTA → Normal(2.yarı) → SON
    int normalYari = bNormal.length ~/ 2;
    siraliPersonel = [...bOnce, ...bNormal.sublist(0, normalYari), ...bOrta, ...bNormal.sublist(normalYari), ...bSonra];
    
    // Sonuç haritaları
    Map<int, List<String>> slotAtamalari = {for (int i = 0; i < slotCount; i++) i: []};
    Map<String, List<int>> kisiSlotlari = {for (var k in aktifPersonel) k: []};
    
    // Numaralı döngü: sıralı kişi listesinden slotlara at
    int kisiBas = 0; // Hangi kişiden başladık
    
    for (int slot = 0; slot < slotCount; slot++) {
      int kap = slotKapasiteleri[slot];
      int eklenen = 0;
      
      while (eklenen < kap && kisiBas < siraliPersonel.length * 3) {
        // Döngüsel: tüm listeyi tekrar tekrar tara
        String k = siraliPersonel[kisiBas % siraliPersonel.length];
        kisiBas++;
        
        // Zaten bu slotta mı?
        if (slotAtamalari[slot]!.contains(k)) continue;
        // Hedef tur aşıldı mı?
        if (kisiSlotlari[k]!.length >= hedefTur[k]!) continue;
        // K1: Arka arkaya yasak
        if (slot > 0 && slotAtamalari[slot - 1]!.contains(k)) continue;
        // K5: BK son slotta oturamaz
        if (slot == slotCount - 1 && aktifBK.contains(k)) continue;
        // K6: ORTA seçili → ilk ve son slota giremez (geç gelip erken gidiyor)
        if (aktifOrtaSecilenler.contains(k) && (slot == 0 || slot == slotCount - 1)) continue;
        
        slotAtamalari[slot]!.add(k);
        kisiSlotlari[k]!.add(slot);
        eklenen++;
      }
    }
    
    // Boş kalan slotları doldur (hedefTur aşılanlarla)
    for (int slot = 0; slot < slotCount; slot++) {
      while (slotAtamalari[slot]!.length < slotKapasiteleri[slot]) {
        String? bestK;
        int bestScore = -999999;
        
        for (var k in siraliPersonel) {
          if (slotAtamalari[slot]!.contains(k)) continue;
          if (slot > 0 && slotAtamalari[slot - 1]!.contains(k)) continue;
          if (slot < slotCount - 1 && slotAtamalari[slot + 1]!.contains(k)) continue;
          if (slot == slotCount - 1 && aktifBK.contains(k)) continue;
          // K6: ORTA seçili → ilk ve son slota giremez
          if (aktifOrtaSecilenler.contains(k) && (slot == 0 || slot == slotCount - 1)) continue;
          
          int score = 0;
          // Hedef aşımı az olanı tercih et
          int ekstra = kisiSlotlari[k]!.length - hedefTur[k]!;
          score -= ekstra * 5000;
          // Boşluk bonusu
          if (kisiSlotlari[k]!.isNotEmpty) {
            score += (slot - kisiSlotlari[k]!.last).abs() * 1000;
          } else {
            score += 3000;
          }
          score -= (_getArsivYorgunlukOrtalamasi(k) * 10).toInt();
          if (score > bestScore) { bestScore = score; bestK = k; }
        }
        
        if (bestK != null) {
          slotAtamalari[slot]!.add(bestK);
          kisiSlotlari[bestK]!.add(slot);
        } else {
          break;
        }
      }
    }
    
    return slotAtamalari;
  }

  /// Phase 2: Zigzag pozisyon atama + SUP havuzu + ince ayar
  /// Döndürür: {slotIndex: {pozisyon: kişi, ...}, ...}
  Map<int, Map<String, String>> _phase2PozisyonAtama(
    Map<int, List<String>> slotAtamalari, 
    List<String> aktifPersonel
  ) {
    int slotCount = saatler.length;
    Map<int, Map<String, String>> gunlukPlan = {};
    
    // Kişinin bugün hangi pozisyonlarda oturduğunu takip et
    Map<String, List<String>> bugunkuPozisyonlar = {for (var k in aktifPersonel) k: []};
    
    // SUP mikro seçili kişiler (yetkilerinde SUP olanlar)
    Set<String> supHavuzu = aktifPersonel.where((k) => yetkiler[k]!.contains('SUP')).toSet();
    Set<String> supYazmislar = {};
    
    for (int slot = 0; slot < slotCount; slot++) {
      double sLvl = tamOtomatikDagitim 
          ? _getIdealLevel(anlikTrafik[slot % anlikTrafik.length].genelToplam) 
          : gunlukSeviye;
      List<String> pozisyonlar = getSektorlerByLevel(sLvl);
      List<String> kisiler = List.from(slotAtamalari[slot] ?? []);
      
      // Zigzag yön: çift slot = ileri, tek slot = ters
      bool ters = slot % 2 == 1;
      List<String> pozSirasi = ters ? pozisyonlar.reversed.toList() : List.from(pozisyonlar);
      
      Map<String, String> atama = {for (var p in pozisyonlar) p: "-"};
      Set<String> atanmislar = {};
      
      // ─────────────────────────────────────────────
      // ADIM 1: SUP koltuğunu önce doldur
      // ─────────────────────────────────────────────
      String? supPos = pozisyonlar.firstWhere(
        (p) => p.split('_')[0].split('/')[0] == 'SUP', orElse: () => '');
      
      if (supPos.isNotEmpty) {
        String? supKisi;
        
        // Öncelik 1: SUP havuzunda olup henüz SUP yazmamış
        for (var k in kisiler) {
          if (atanmislar.contains(k)) continue;
          if (supHavuzu.contains(k) && !supYazmislar.contains(k)) {
            supKisi = k;
            break;
          }
        }
        // Öncelik 2: SUP havuzunda olan (zaten yazmış ama en az yazan)
        if (supKisi == null) {
          for (var k in kisiler) {
            if (atanmislar.contains(k)) continue;
            if (supHavuzu.contains(k)) {
              supKisi = k;
              break;
            }
          }
        }
        // Öncelik 3: Gruptaki herhangi biri
        if (supKisi == null) {
          for (var k in kisiler) {
            if (!atanmislar.contains(k)) { supKisi = k; break; }
          }
        }
        
        if (supKisi != null) {
          atama[supPos] = supKisi;
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
          
          int score = 0;
          String core = pos.split('_')[0].split('/')[0];
          
          // Yetki kontrolü
          bool yetkili = yetkiler[k]!.isEmpty || 
                         yetkiler[k]!.contains(pos) || 
                         yetkiler[k]!.contains(core);
          if (!yetkili) score -= 100000;
          
          // Pozisyon çeşitliliği: daha önce bu pozisyonda oturmamış tercih et
          if (bugunkuPozisyonlar[k]!.contains(pos)) score -= 5000;
          bool ayniCoreVar = bugunkuPozisyonlar[k]!.any(
            (p) => p.split('_')[0].split('/')[0] == core);
          if (ayniCoreVar) score -= 3000;
          
          // Zigzag rotasyon: son pozisyonundan farklı yere yönlendir
          if (bugunkuPozisyonlar[k]!.isNotEmpty) {
            String lastCore = bugunkuPozisyonlar[k]!.last.split('_')[0].split('/')[0];
            if (lastCore != core) score += 2000;
          }
          
          if (score > bestScore) { bestScore = score; bestK = k; }
        }
        
        if (bestK != null) {
          atama[pos] = bestK;
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
        if (core == 'SUP' && supHavuzu.contains(kisi)) continue; // SUP havuzu tekrar yapabilir
        
        // Aynı gruptaki başka biriyle swap et
        for (var entry2 in atama.entries.toList()) {
          String pos2 = entry2.key;
          String kisi2 = entry2.value;
          if (kisi2 == "-" || kisi2 == kisi) continue;
          
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
    
    return gunlukPlan;
  }

  void _istatistikleriYenidenHesapla(Map<int, Map<String, String>> plan) {
    _hafizayiSifirla();
    for (int i = 0; i < saatler.length; i++) {
      if (plan[i] == null) continue;
      int dk = _dakikaCoz(saatler[i]);
      plan[i]!.forEach((pos, kisi) {
        if (kisi != "-") {
          String core = pos.split('_')[0].split('/')[0];
          turSayisi[kisi] = (turSayisi[kisi] ?? 0) + 1;
          dakikaSayisi[kisi] = (dakikaSayisi[kisi] ?? 0) + dk;
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
    
    Set<String> aktifBK = Set.from(bizimleKalSecilenler);
    var aktifPersonel = tumPersonelHavuzu.where((k) => !gunlukDurum[k]!.contains('OFF') && !gunlukDurum[k]!.contains('KAZANDIŞI')).toList();

    if (aktifBK.isEmpty && tamOtomatikDagitim) {
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
        aktifPersonel.sort((a, b) => totalBK[a]!.compareTo(totalBK[b]!));
        aktifBK.add(aktifPersonel.first);
      }
    }

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
    
    // === YENİ ALGORİTMA v2 ===
    // Phase 1: Kim hangi slota?
    Map<int, List<String>> slotAtamalari = _phase1SlotAtama(aktifPersonel, majT, aktifBK);
    
    // Phase 2: Pozisyon ataması
    Map<int, Map<String, String>> gunlukPlan = _phase2PozisyonAtama(slotAtamalari, aktifPersonel);
    
    // İstatistikleri hesapla
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
        
        if (atamalar.containsKey(header)) {
          cellText = atamalar[header]!;
        }
        // Seviye farkı eşleme: atamada TWR varsa → TWR_W'ye yaz
        else if (headerCore == 'TWR' && atamalar.containsKey('TWR')) {
          cellText = (header == tabloBaslikSektorleri.firstWhere((h) => h.startsWith('TWR'), orElse: () => '')) ? atamalar['TWR']! : '-';
        }
        else if (headerCore == 'GND' && atamalar.containsKey('GND')) {
          cellText = (header == tabloBaslikSektorleri.firstWhere((h) => h.startsWith('GND'), orElse: () => '')) ? atamalar['GND']! : '-';
        }
        // Seviye farkı: atamada TWR_W var ama tabloda TWR → ilk TWR varyantını yaz
        else if (header == 'TWR') {
          cellText = atamalar['TWR_W'] ?? atamalar['TWR_E'] ?? '-';
        }
        else if (header == 'GND') {
          cellText = atamalar['GND_S'] ?? atamalar['GND_N'] ?? atamalar['GND_C'] ?? '-';
        }
        
        row.add(cellText);
      }
      tempRows.add([saatler[i], ...row]);
    }
    
    Map<String, Map<String, dynamic>> bugunIstat = {};
    for(var k in tumPersonelHavuzu) {
      int ts = turSayisi[k] ?? 0;
      bugunIstat[k] = { 
        'DEL': delSayisi[k] ?? 0, 'TWR': twrSayisi[k] ?? 0, 'GND': gndSayisi[k] ?? 0, 'SUP': supSayisi[k] ?? 0, 
        'TUR': ts, 'DK': dakikaSayisi[k] ?? 0, 
        'IS_HAMAL': ts > majT, 'IS_ENSECI': ts < majT && ts > 0,
        'H_SAYI': ts > majT ? (ts - majT) : 0, 'E_SAYI': ts < majT && ts > 0 ? (majT - ts) : 0,
        'ILK_S': ilkSecilenler.contains(k),
        'ORTA_S': ortaSecilenler.contains(k),
        'SON_S': sonSecilenler.contains(k),
        'BK_S': aktifBK.contains(k)
      };
    }

    String guncelBK = aktifBK.isEmpty ? "-" : aktifBK.join(', ');

    DateTime recordDate = _aktifTarih; 
    String recordDateStr = _aktifTarihStr;
    
    var yeniBord = BordArsivi(recordDate, recordDateStr, [...tabloBaslikSektorleri], tempRows, tempTrf, tempGercekciTrf, tempHava, bugunIstat, tumPersonelHavuzu.where((k) => gunlukDurum[k]!.contains('OFF')).toList(), guncelBK);
    
    int varOlanIndex = tamArsiv.indexWhere((b) => b.tarihMetni == recordDateStr);
    if (varOlanIndex != -1) {
      tamArsiv[varOlanIndex] = yeniBord;
    } else if (kaydet || tamArsiv.isEmpty) {
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

  void _arsivEkraniAc() {
    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Row(children: [Icon(Icons.archive, color: Colors.blueAccent), SizedBox(width: 10), Text("BORD ARŞİVİ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
      content: SizedBox(width: 1000, height: 600, child: tamArsiv.isEmpty ? const Center(child: Text("Arşiv kaydı bulunamadı.", style: TextStyle(color: Colors.white54))) : ListView.builder(itemCount: tamArsiv.length, itemBuilder: (context, i) {
            var siraliArsiv = List<BordArsivi>.from(tamArsiv)..sort((a, b) => b.tarih.compareTo(a.tarih));
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
                      
                      TrafikVerisi tVeriPeak = arsiv.satirlarTrafik[rIdx]; 
                      TrafikVerisi tVeriGercekci = arsiv.satirlarGercekciTrafik[rIdx];
                      
                      List<DataCell> rCells = [];
                      
                      rCells.add(DataCell(_buildMetInfoCell(arsiv.satirlarHava[rIdx])));
                      
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

                      rCells.add(DataCell(Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(cells[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)), 
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            trfWidget
                          ])
                        ]),
                      )));

                      for(int c = 1; c < cells.length; c++) {
                        String text = cells[c];
                        if (text == "-") {
                          rCells.add(const DataCell(Center(child: Text("-", style: TextStyle(color: Colors.white12)))));
                        } else {
                          rCells.add(DataCell(Container(margin: const EdgeInsets.all(4), padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)), borderRadius: BorderRadius.circular(4)), child: Center(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))))));
                        }
                      }
                      return DataRow(cells: rCells);
                    }).toList(),
                  )),
                  Padding(padding: const EdgeInsets.only(top: 12.0), child: Row(children: [
                    Container(width: ((arsiv.basliklar.length + 2) * 90.0) * (2/3), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), border: Border.all(color: Colors.redAccent.withOpacity(0.5)), borderRadius: BorderRadius.circular(8)), child: Text("❌ İZİNLİLER: ${arsiv.izinliler.isEmpty ? 'Yok' : arsiv.izinliler.join(', ')}", style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 10),
                    Container(width: ((arsiv.basliklar.length + 2) * 90.0) * (1/3) - 10, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.1), border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)), borderRadius: BorderRadius.circular(8)), child: Center(child: Text("☕ BİZİMLE KAL: ${arsiv.bizimleKal}", style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 11), overflow: TextOverflow.ellipsis))),
                  ])),
                ])) ]
            ));
      })),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("KAPAT"))],
    ));
  }

  void _sifreSor() {
    TextEditingController ctrl = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: const Color(0xFF1E1E1E), title: const Text("YETKİLİ GİRİŞİ", style: TextStyle(color: Colors.redAccent)), content: TextField(controller: ctrl, obscureText: true, decoration: const InputDecoration(labelText: "Şifre (ltai)")), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("İPTAL")), ElevatedButton(onPressed: () { if(ctrl.text.toLowerCase() == "ltai") { Navigator.pop(context); _istatistikGoster(); } }, child: const Text("GİRİŞ"))]));
  }

  void _istatistikGoster() {
    DateTimeRange? seciliAralik;
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setIstatState) {
      List<BordArsivi> gosterilecek = tamArsiv;
      if (seciliAralik != null) gosterilecek = tamArsiv.where((b) => b.tarih.isAfter(seciliAralik!.start.subtract(const Duration(days: 1))) && b.tarih.isBefore(seciliAralik!.end.add(const Duration(days: 1)))).toList();
      Map<String, Map<String, dynamic>> aggIstat = {};
      
      for (String k in tumPersonelHavuzu) aggIstat[k] = {'DEL': 0, 'TWR': 0, 'GND': 0, 'SUP': 0, 'H_SAYI': 0, 'E_SAYI': 0, 'DK': 0, 'ILK_S': 0, 'ORTA_S': 0, 'SON_S': 0, 'BK_S': 0};
      
      for (var b in gosterilecek) {
        b.istatistik.forEach((k, v) {
          if (aggIstat.containsKey(k)) {
            aggIstat[k]!['DEL'] = (aggIstat[k]!['DEL'] as int) + (v['DEL'] as int);
            aggIstat[k]!['TWR'] = (aggIstat[k]!['TWR'] as int) + (v['TWR'] as int);
            aggIstat[k]!['GND'] = (aggIstat[k]!['GND'] as int) + (v['GND'] as int);
            aggIstat[k]!['SUP'] = (aggIstat[k]!['SUP'] as int) + (v['SUP'] as int);
            aggIstat[k]!['H_SAYI'] = (aggIstat[k]!['H_SAYI'] as int) + (v['H_SAYI'] as int);
            aggIstat[k]!['E_SAYI'] = (aggIstat[k]!['E_SAYI'] as int) + (v['E_SAYI'] as int);
            aggIstat[k]!['DK'] = (aggIstat[k]!['DK'] as int) + (v['DK'] as int);
            
            aggIstat[k]!['ILK_S'] = (aggIstat[k]!['ILK_S'] as int) + ((v['ILK_S'] == true) ? 1 : 0);
            aggIstat[k]!['ORTA_S'] = (aggIstat[k]!['ORTA_S'] as int) + ((v['ORTA_S'] == true) ? 1 : 0);
            aggIstat[k]!['SON_S'] = (aggIstat[k]!['SON_S'] as int) + ((v['SON_S'] == true) ? 1 : 0);
            aggIstat[k]!['BK_S'] = (aggIstat[k]!['BK_S'] as int) + ((v['BK_S'] == true) ? 1 : 0);
          }
        });
      }
      return AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Row(children: [Icon(Icons.format_list_bulleted, color: Colors.blueAccent), SizedBox(width: 10), Text("KÜREK MAHKUMLARI", style: TextStyle(fontSize: 16))]),
          Row(children: [
            TextButton(onPressed: () => setIstatState(() => seciliAralik = null), child: Text("TÜM ZAMANLAR", style: TextStyle(color: seciliAralik == null ? Colors.greenAccent : Colors.white54, fontWeight: FontWeight.bold, fontSize: 12))),
            const SizedBox(width: 15),
            TextButton.icon(icon: const Icon(Icons.calendar_month, color: Colors.orangeAccent, size: 16), label: Text(seciliAralik == null ? "TARİH ARALIĞI SEÇ" : "${seciliAralik!.start.day}.${seciliAralik!.start.month} - ${seciliAralik!.end.day}.${seciliAralik!.end.month}", style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
              onPressed: () async {
                var aralik = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 30)), initialEntryMode: DatePickerEntryMode.calendarOnly,
                  builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Colors.orangeAccent, onPrimary: Colors.black, surface: Color(0xFF1E1E1E), onSurface: Colors.white)), child: child!),
                );
                if (aralik != null) setIstatState(() => seciliAralik = aralik);
              }
            ),
          ])
        ]),
        content: SizedBox(width: 950, height: 600, child: gosterilecek.isEmpty ? const Center(child: Text("Seçili aralıkta kayıt yok.", style: TextStyle(color: Colors.white54))) : SingleChildScrollView(child: DataTable(
            columnSpacing: 10, headingRowHeight: 40, dataRowHeight: 45, border: TableBorder.all(color: Colors.white12),
            columns: const [ 
              DataColumn(label: SizedBox(width: 60, child: Text(""))), 
              DataColumn(label: Text("DEL", style: TextStyle(fontSize: 10))), 
              DataColumn(label: Text("TWR", style: TextStyle(fontSize: 10))), 
              DataColumn(label: Text("GND", style: TextStyle(fontSize: 10))), 
              DataColumn(label: Text("SUP", style: TextStyle(fontSize: 10))), 
              DataColumn(label: Text("İLK", style: TextStyle(fontSize: 10, color: Colors.purpleAccent))),
              DataColumn(label: Text("ORTA", style: TextStyle(fontSize: 10, color: Colors.blue))),
              DataColumn(label: Text("SON", style: TextStyle(fontSize: 10, color: Colors.tealAccent))),
              DataColumn(label: Text("B.KAL", style: TextStyle(fontSize: 10, color: Colors.amberAccent))),
              DataColumn(label: Text("KARINCA", style: TextStyle(fontSize: 10))), 
              DataColumn(label: Text("A.BÖCEĞİ", style: TextStyle(fontSize: 10))), 
              DataColumn(label: Text("Dakika", style: TextStyle(fontSize: 10))), 
            ],
            rows: aggIstat.entries.map((e) => DataRow(cells: [ 
              DataCell(Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))), 
              DataCell(Text("${e.value['DEL']}", style: const TextStyle(fontSize: 11))), 
              DataCell(Text("${e.value['TWR']}", style: const TextStyle(fontSize: 11))), 
              DataCell(Text("${e.value['GND']}", style: const TextStyle(fontSize: 11))), 
              DataCell(Text("${e.value['SUP']}", style: const TextStyle(fontSize: 11))), 
              DataCell(Text("${e.value['ILK_S'] > 0 ? e.value['ILK_S'] : '-'}", style: const TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold))), 
              DataCell(Text("${e.value['ORTA_S'] > 0 ? e.value['ORTA_S'] : '-'}", style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold))), 
              DataCell(Text("${e.value['SON_S'] > 0 ? e.value['SON_S'] : '-'}", style: const TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold))), 
              DataCell(Text("${e.value['BK_S'] > 0 ? e.value['BK_S'] : '-'}", style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold))), 
              DataCell(Text("${e.value['H_SAYI']}", style: TextStyle(color: e.value['H_SAYI'] > 0 ? Colors.pinkAccent : Colors.white24, fontSize: 11))), 
              DataCell(Text("${e.value['E_SAYI']}", style: TextStyle(color: e.value['E_SAYI'] > 0 ? Colors.lightBlueAccent : Colors.white24, fontSize: 11))), 
              DataCell(Text("${e.value['DK']}", style: const TextStyle(color: Colors.orangeAccent, fontSize: 11))) 
            ])).toList(),
        ))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("KAPAT"))],
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: null, backgroundColor: Colors.black, leading: null,
        actions: [
          IconButton(icon: const Icon(Icons.airplanemode_active, color: Colors.greenAccent), tooltip: "Trafik Sayısı", onPressed: _isiHaritasiniAc),
          IconButton(icon: const Text("🌦️", style: TextStyle(fontSize: 22)), tooltip: "LTAI Meteorological Info", onPressed: _airgramEkraniAc),
          IconButton(icon: const Icon(Icons.assignment_late, color: Colors.amber), tooltip: "NOTAM", onPressed: _notamEkraniAc),
          IconButton(icon: const Icon(Icons.handshake, color: Colors.purpleAccent), tooltip: "HOTO (Devir/Teslim)", onPressed: () {}),
          IconButton(icon: const Icon(Icons.settings, color: Colors.orangeAccent), tooltip: "Ayarlar ve Bord Planlama", onPressed: _kadroSecimEkraniAc),
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

  void _manuelAtamaPenceresiAc(int hIdx, String pos, String currentPerson) {
    if (currentPerson == "-") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kapalı sektöre atama yapılamaz! (Limitin altında kaldığı için otonom olarak kapatıldı)"), backgroundColor: Colors.redAccent));
      return;
    }
    String core = pos.split('_')[0].split('/')[0];
    var sonBord = tamArsiv.lastWhere((b) => b.tarihMetni == _aktifTarihStr, orElse: () => tamArsiv.last);
    List<String> prevRow = hIdx > 0 ? sonBord.satirlar[hIdx - 1] : [];
    List<String> nextRow = hIdx < saatler.length - 1 ? sonBord.satirlar[hIdx + 1] : [];
    
    String mevcutSaatNotu = _kilitliSaatlerTarihli[_aktifTarihStr]?[hIdx]?[pos] ?? "";
    TextEditingController saatCtrl = TextEditingController(text: mevcutSaatNotu);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text("${saatler[hIdx]} | $pos 📌", style: const TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8, runSpacing: 8,
                children: tumPersonelHavuzu.map((kisi) {
                  bool isOff = gunlukDurum[kisi]!.contains('OFF') || gunlukDurum[kisi]!.contains('KAZANDIŞI');
                  if (isOff) return const SizedBox.shrink();

                  bool yetkiVar = _vizeKontrol(kisi, pos, core);
                  bool prevWorked = prevRow.contains(kisi);
                  bool nextWorked = nextRow.contains(kisi);
                  bool isBizimleKal = hIdx == saatler.length - 1 && bizimleKalSecilenler.contains(kisi);
                  
                  // Yeşil = tamamen uygun, Kırmızı = en az bir kural çiğneniyor ama SEÇİLEBİLİR
                  bool uygun = yetkiVar && !prevWorked && !nextWorked && !isBizimleKal;
                  bool vizeSiz = !yetkiVar; // Tek engel: vize yoksa uyarı ver ama yine seçilebilir
                  
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: uygun ? Colors.green.withOpacity(0.15) : Colors.redAccent.withOpacity(0.12),
                      side: BorderSide(color: uygun ? Colors.green : Colors.redAccent.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                    ),
                    onPressed: () {
                      // Uyarı göster ama seçimi engelleme
                      if (!uygun) {
                        List<String> uyarilar = [];
                        if (vizeSiz) uyarilar.add("$kisi için $core yetkisi yok");
                        if (prevWorked) uyarilar.add("Önceki saat çalışıyor");
                        if (nextWorked) uyarilar.add("Sonraki saat çalışıyor");
                        if (isBizimleKal) uyarilar.add("Son saat Bizimle Kal nöbetinde");
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text("⚠️ ${uyarilar.join(' | ')} — Yine de pinlendi!"),
                          backgroundColor: Colors.orange.shade800,
                          duration: const Duration(seconds: 3)
                        ));
                      }
                      // Her durumda pini kaydet (kısaltılmış süre notu)
                      setState(() {
                        if (!_kilitliSaatlerTarihli.containsKey(_aktifTarihStr)) _kilitliSaatlerTarihli[_aktifTarihStr] = {};
                        if (!_kilitliSaatlerTarihli[_aktifTarihStr]!.containsKey(hIdx)) _kilitliSaatlerTarihli[_aktifTarihStr]![hIdx] = {};
                        if (saatCtrl.text.trim().isNotEmpty) {
                          _kilitliSaatlerTarihli[_aktifTarihStr]![hIdx]![pos] = saatCtrl.text.trim();
                        } else {
                          _kilitliSaatlerTarihli[_aktifTarihStr]?[hIdx]?.remove(pos);
                        }
                        // Manuel isim değişikliği: bord satırını güncelle
                        var hedefBord = tamArsiv.lastWhere((b) => b.tarihMetni == _aktifTarihStr, orElse: () => tamArsiv.last);
                        var satirlar = hedefBord.satirlar;
                        if (hIdx < satirlar.length) {
                          var basliklar = hedefBord.basliklar;
                          int colIdx = basliklar.indexOf(pos);
                          if (colIdx >= 0 && colIdx + 1 < satirlar[hIdx].length) {
                            satirlar[hIdx][colIdx + 1] = kisi;
                          }
                        }
                      });
                      Navigator.pop(context);
                    },
                    child: Text(kisi, style: TextStyle(color: uygun ? Colors.white : Colors.white70, fontWeight: FontWeight.bold)),
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
          if (_kilitliSaatlerTarihli[_aktifTarihStr]?[hIdx]?.containsKey(pos) ?? false)
            TextButton(
              onPressed: () {
                setState(() { _kilitliSaatlerTarihli[_aktifTarihStr]?[hIdx]?.remove(pos); });
                Navigator.pop(context);
              },
              child: const Text("PİNİ KALDIR", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İPTAL"))
        ]
      )
    );
  }

  Widget _anaEkranDizilimi() {
    if (tamArsiv.isEmpty) return const Center(child: CircularProgressIndicator());
    var sonBord = tamArsiv.lastWhere((b) => b.tarihMetni == _aktifTarihStr, orElse: () => tamArsiv.last); var istat = sonBord.istatistik;
    List<String> izinliler = tumPersonelHavuzu.where((k) => gunlukDurum[k]!.contains('OFF')).toList();
    
    return Column(
      mainAxisSize: MainAxisSize.min, 
      children: [
      Expanded(child: SingleChildScrollView(scrollDirection: Axis.vertical, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DataTable(columnSpacing: 15, dataRowHeight: 65, headingRowHeight: 36, border: TableBorder.all(color: Colors.white24, width: 1), headingRowColor: MaterialStateProperty.all(Colors.black),
          columns: [ 
            const DataColumn(label: SizedBox(width: 40, child: Center(child: Text("")))),
            DataColumn(label: Text(_aktifTarihStr, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12))), 
            ...sonBord.basliklar.map((b) => DataColumn(label: Text(b, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)))) 
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
                bool h = istat[text]?['IS_HAMAL'] ?? false; 
                bool e = istat[text]?['IS_ENSECI'] ?? false;
                
                bool isPinned = _kilitliSaatlerTarihli[_aktifTarihStr]?[idx]?.containsKey(header) ?? false;
                String optSaat = _kilitliSaatlerTarihli[_aktifTarihStr]?[idx]?[header] ?? "";

                rowCells.add(DataCell(GestureDetector(
                  onTap: () => _manuelAtamaPenceresiAc(idx, header, text),
                  child: Container(
                    margin: const EdgeInsets.all(4), 
                    padding: const EdgeInsets.symmetric(horizontal: 10), 
                    decoration: BoxDecoration(
                      color: isPinned ? Colors.orange.withOpacity(0.1) : (h ? Colors.pinkAccent.withOpacity(0.25) : (e ? Colors.lightBlueAccent.withOpacity(0.25) : Colors.transparent)), 
                      borderRadius: BorderRadius.circular(4), 
                      border: Border.all(
                        color: isPinned ? Colors.orangeAccent : (h ? Colors.pinkAccent : (e ? Colors.lightBlueAccent : Colors.orangeAccent.withOpacity(0.3))), 
                        width: isPinned ? 2 : ((h || e) ? 1.5 : 1)
                      )
                    ), 
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            if (optSaat.isNotEmpty) Text(optSaat, style: const TextStyle(color: Colors.orangeAccent, fontSize: 8, fontWeight: FontWeight.bold))
                          ],
                        )),
                        if (isPinned) const Positioned(right: -8, top: -8, child: Icon(Icons.push_pin, size: 12, color: Colors.orangeAccent))
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
          const SizedBox(width: 10),
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.1), border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)), borderRadius: BorderRadius.circular(8)), child: Center(child: Text("☕ BİZİMLE KAL: ${sonBord.bizimleKal}", style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 10)))),
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
                            gunlukDurum[n] = {'A'}; 
                            yetkiler[n] = {}; 
                          });
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
      
      int tCount = tumPersonelHavuzu.where((k) => !gunlukDurum[k]!.contains('OFF') && !gunlukDurum[k]!.contains('KAZANDIŞI')).length;
      int totalSlots = 0;
      for (int i = 0; i < saatler.length; i++) {
        int trf = anlikTrafik[i % anlikTrafik.length].genelToplam;
        double lvl = _getIdealLevel(trf);
        totalSlots += (lvl <= 3.0 ? 3 : getSektorlerByLevel(lvl).length);
      }
      
      int baseTur = tCount > 0 ? (totalSlots ~/ tCount) : 0;
      int rem = tCount > 0 ? (totalSlots % tCount) : 0;
      int majT = 0; int hGerek = 0; int eGerek = 0;
      
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
            String p1 = (isGunduzVardiyasi ? gunduzKlasik : geceKlasik).last.split(' - ').first;
            String p2 = (isGunduzVardiyasi ? gunduzAlengirli : geceAlengirli).last.split(' - ').first;
            Color cAI = tamOtomatikDagitim ? Colors.orangeAccent : Colors.lightBlueAccent;
            return Row(
              children: [
                Expanded(
                  flex: 3,
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
                const SizedBox(width: 6),
                Expanded(
                  flex: 4,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                       backgroundColor: saatSenaryosu == 1 ? cAI.withOpacity(0.3) : Colors.transparent,
                       foregroundColor: saatSenaryosu == 1 ? cAI : Colors.white54,
                       side: BorderSide(color: saatSenaryosu == 1 ? cAI : Colors.white24, width: saatSenaryosu == 1 ? 1.5 : 1),
                       padding: EdgeInsets.zero, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))
                    ),
                    onPressed: () => setD(() { saatSenaryosu = 1; _gruplariGuncelle(arsiveKaydet: false); }),
                    child: Text("⏱️ $p1", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1))
                  )
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 4,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                       backgroundColor: saatSenaryosu == 2 ? cAI.withOpacity(0.3) : Colors.transparent,
                       foregroundColor: saatSenaryosu == 2 ? cAI : Colors.white54,
                       side: BorderSide(color: saatSenaryosu == 2 ? cAI : Colors.white24, width: saatSenaryosu == 2 ? 1.5 : 1),
                       padding: EdgeInsets.zero, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))
                    ),
                    onPressed: () => setD(() { saatSenaryosu = 2; _gruplariGuncelle(arsiveKaydet: false); }),
                    child: Text("🔀 $p2", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1))
                  )
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                       backgroundColor: cAI.withOpacity(0.15), foregroundColor: cAI,
                       side: BorderSide(color: cAI, width: 1.5),
                       padding: EdgeInsets.zero, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))
                    ),
                    onPressed: () { _gruplariGuncelle(arsiveKaydet: true); Navigator.pop(context); },
                    child: const Icon(Icons.check_circle, size: 20)
                  )
                ),
              ]
            );
          }),
          Padding(padding: const EdgeInsets.only(top: 8), child: Text("⚖️ Çoğunluk: $majT Tur | $hGerek Karınca - $eGerek Ağustos Böceği Gerekli", style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold))),
          
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
                    _durumBtn(k, 'OFF', Colors.redAccent, setD, "İZİN"), _durumBtn(k, 'KAZANDIŞI', Colors.grey, setD, "KAZANDIŞI"), _durumBtn(k, 'HAMAL', Colors.pinkAccent, setD, "KARINCA"), _durumBtn(k, 'ENSECİ', Colors.lightBlueAccent, setD, "AĞUSTOS BÖCEĞİ") 
                  ]),
                  
                  if (!pas) Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Dinamik mikro seçilim: mevcut senaryonun pozisyonları
                        ...getSektorlerByLevel(gunlukSeviye)
                            .map((pos) => _yetkiBtn(k, pos, setD)),
                        Container(width: 1, height: 16, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 2)), 
                        _ozelSecimBtn(k, 'İLK', Colors.purpleAccent, setD),
                        _ozelSecimBtn(k, 'ORTA', Colors.blue, setD),
                        _ozelSecimBtn(k, 'SON', Colors.tealAccent, setD),
                        _ozelSecimBtn(k, 'BİZİMLE KAL', Colors.amberAccent, setD),
                      ]
                    )
                  )
                ])));
              }
            )
          ),
          const SizedBox(height: 10),
          Align(alignment: Alignment.bottomRight, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                GestureDetector(onTap: () { Navigator.pop(context); _arsivEkraniAc(); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white24)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.archive_outlined, size: 14, color: Colors.orangeAccent), SizedBox(width: 6), Text("BORD ARŞİVİ", style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1))]))),
                const SizedBox(height: 8),
                GestureDetector(onDoubleTap: () { Navigator.pop(context); _sifreSor(); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white24)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.format_list_bulleted, size: 14, color: Colors.white54), SizedBox(width: 6), Text("KÜREK MAHKUMLARI", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1))]))),
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
          setState(() {
            ltaiNotamlari = decoded['notamlar'] ?? [];
            notamGuncelleme = decoded['notamGuncelleme'] ?? "";
          });
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

  // ── Rozet Kalıcılığı (SharedPreferences) ──
  Future<void> _loadNotamPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    // Özel etiketleri yükle
    String? tagsJson = prefs.getString('customNotamTags');
    if (tagsJson != null) {
      Map<String, dynamic> decoded = jsonDecode(tagsJson);
      setState(() {
        _customNotamTags = decoded.map((k, v) => MapEntry(k, v.toString()));
      });
    }
    // Özel rozetleri yükle (built-in olmayanlar)
    String? customTagsJson = prefs.getString('customAllTags');
    if (customTagsJson != null) {
      Map<String, dynamic> decoded = jsonDecode(customTagsJson);
      setState(() {
        for (var entry in decoded.entries) {
          if (!_builtInTagNames.contains(entry.key)) {
            List<dynamic> val = entry.value;
            _allTags[entry.key] = [Color(val[0]), val[1]];
          }
        }
      });
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
    if (type == 'ORTA') isSelected = ortaSecilenler.contains(k);
    if (type == 'SON') isSelected = sonSecilenler.contains(k);
    if (type == 'BİZİMLE KAL') isSelected = bizimleKalSecilenler.contains(k);

    return InkWell(
      onTap: () => setD(() {
        if (type == 'İLK') {
          if (isSelected) {
            ilkSecilenler.remove(k);
          } else {
            ilkSecilenler.add(k);
            ortaSecilenler.remove(k);
            sonSecilenler.remove(k); 
          }
        } else if (type == 'ORTA') {
          if (isSelected) {
            ortaSecilenler.remove(k);
          } else {
            ortaSecilenler.add(k);
            ilkSecilenler.remove(k);
            sonSecilenler.remove(k);
          }
        } else if (type == 'SON') {
          if (isSelected) {
            sonSecilenler.remove(k);
          } else {
            sonSecilenler.add(k);
            ilkSecilenler.remove(k); 
            ortaSecilenler.remove(k);
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: s ? c : Colors.transparent,
          border: Border.all(color: s ? Colors.black : c, width: 1.5),
          borderRadius: BorderRadius.circular(4)
        ),
        child: Text(txt, style: TextStyle(color: s ? Colors.black : c, fontSize: 8, fontWeight: FontWeight.bold))
      )
    );
  }

  Widget _yetkiBtn(String k, String y, Function setD) {
    bool s = yetkiler[k]!.contains(y);
    return InkWell(
      onTap: () => setD(() {
        if (s) yetkiler[k]!.remove(y);
        else yetkiler[k]!.add(y);
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
                          gunlukDurum.remove(k);
                          yetkiler.remove(k);
                          ilkSecilenler.remove(k);
                          ortaSecilenler.remove(k);
                          sonSecilenler.remove(k);
                          bizimleKalSecilenler.remove(k);
                        });
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
                            gunlukDurum[n] = gunlukDurum[old]!;
                            yetkiler[n] = yetkiler[old]!;
                            
                            if(ilkSecilenler.contains(old)) { ilkSecilenler.remove(old); ilkSecilenler.add(n); }
                            if(ortaSecilenler.contains(old)) { ortaSecilenler.remove(old); ortaSecilenler.add(n); }
                            if(sonSecilenler.contains(old)) { sonSecilenler.remove(old); sonSecilenler.add(n); }
                            if(bizimleKalSecilenler.contains(old)) { bizimleKalSecilenler.remove(old); bizimleKalSecilenler.add(n); }
                            
                            gunlukDurum.remove(old);
                            yetkiler.remove(old);
                          }
                        });
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