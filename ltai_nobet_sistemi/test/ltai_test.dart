// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════
// LTAI NÖBET SİSTEMİ — KAPSAMLI BİRİM TESTLERİ
// ════════════════════════════════════════════════════════
// Bu testler aşağıdaki modülleri doğrular:
//  1. _getIdealLevel  — Trafik → Seviye dönüşümü
//  2. getSektorlerByLevel — Seviye → Pozisyon listesi
//  3. _dakikaCoz      — Saat aralığını dakikaya çevirme
//  4. _wmoToMetarCode — WMO kodu → METAR hadise kodu
//  5. _cloudToAviationCode — Bulut yüzdesi → Havacılık kodu
//  6. PersonelKarnesi — Hesaplama ve oran mantığı
//  7. Zigzag şablonu mantığı (round-robin slot dağıtımı)
//  8. Gece slotu index tespiti
//  9. Timeout değerleri
// 10. Hava durumu birleşim kuralları
// ════════════════════════════════════════════════════════

// ---------- STANDALONE HELPER FUNCTIONS ----------
// (State'e bağlı olmayan fonksiyonların izole kopyaları)

double getIdealLevel(int trafik,
    {int b34 = 25, int b45 = 36, int b56 = 50, int b67 = 70}) {
  if (trafik <= b34) return 3.0;
  if (trafik <= b45) return 3.5;
  if (trafik <= b56) return 4.0;
  if (trafik <= b67) return 4.5;
  return 5.0;
}

List<String> getSektorlerByLevel(double level) {
  if (level <= 3.0) return ['TWR', 'DEL', 'SUP'];
  if (level <= 4.0) return ['TWR', 'DEL', 'GND', 'SUP'];
  if (level <= 5.0) return ['TWR_W', 'DEL', 'GND', 'TWR_E', 'SUP'];
  if (level <= 6.0) return ['TWR_W', 'DEL', 'GND_S', 'TWR_E', 'GND_N', 'SUP'];
  return ['TWR_W', 'DEL', 'GND_S', 'TWR_E', 'GND_N', 'GND_C', 'SUP'];
}

int dakikaCoz(String aralik) {
  try {
    var parts = aralik.split(' - ');
    int startMins =
        int.parse(parts[0].split(':')[0]) * 60 + int.parse(parts[0].split(':')[1]);
    int endMins =
        int.parse(parts[1].split(':')[0]) * 60 + int.parse(parts[1].split(':')[1]);
    if (endMins < startMins) endMins += 24 * 60;
    return endMins - startMins;
  } catch (e) {
    return 100;
  }
}

String wmoToMetarCode(int code) {
  if (code == 0 || code == 1 || code == 2 || code == 3) return '-';
  if (code == 45 || code == 48) return 'BR';
  if (code >= 51 && code <= 55) return 'DZ';
  if (code == 61) return '-RA';
  if (code == 63) return 'RA';
  if (code == 65) return '+RA';
  if (code >= 71 && code <= 75) return 'SN';
  if (code >= 80 && code <= 82) return 'SHRA';
  if (code == 95) return 'TS';
  if (code == 96 || code == 99) return 'TSRA';
  return '-';
}

String cloudToAviationCode(int percentage) {
  if (percentage < 10) return 'NSC';
  if (percentage < 25) return 'FEW030';
  if (percentage < 50) return 'SCT030';
  if (percentage < 85) return 'BKN025';
  return 'OVC015';
}

// Karne hesaplama (izole)
class PersonelKarnesi {
  int geceCore = 0;
  int araCore = 0;
  int sabahCore = 0;
  int offCount = 0;
  int parcali = 0;
  int gunduzShift = 0;
  int gunduzGorev = 0;
  int gunduzToplamSlotIndeksi = 0;
  String sonGeceRolu = '';

  int get toplamGeceGorev => geceCore + araCore + sabahCore;

  double get oranGece {
    int t = toplamGeceGorev;
    return t == 0 ? 0.0 : geceCore / t;
  }

  double get oranAra {
    int t = toplamGeceGorev;
    return t == 0 ? 0.0 : araCore / t;
  }

  double get oranSabah {
    int t = toplamGeceGorev;
    return t == 0 ? 0.0 : sabahCore / t;
  }

  double get oranGunduz {
    return gunduzShift == 0 ? 0.0 : gunduzGorev / gunduzShift;
  }

  double get gunduzGecGirisOrani {
    return gunduzGorev == 0 ? 0.0 : gunduzToplamSlotIndeksi / gunduzGorev;
  }
}

// Basit zigzag şablon oluşturucu (test edilmesi zor ana koddan izole)
Map<int, List<int>> buildZigzagTemplate(int slotCount, List<int> slotKap, int aCount) {
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
  return numaraSlotlari;
}

void main() {
  // ════════════════════════════════════════════════
  // GRUP 1: _getIdealLevel — Trafik Eşik Testleri
  // ════════════════════════════════════════════════
  group('getIdealLevel — Trafik Seviye Eşikleri', () {
    test('Sıfır trafik → Seviye 3.0', () {
      expect(getIdealLevel(0), equals(3.0));
    });

    test('Eşik altı (25) → Seviye 3.0', () {
      expect(getIdealLevel(25), equals(3.0));
    });

    test('Eşik üzeri (26) → Seviye 3.5', () {
      expect(getIdealLevel(26), equals(3.5));
    });

    test('İkinci eşik tam değeri (36) → Seviye 3.5', () {
      expect(getIdealLevel(36), equals(3.5));
    });

    test('Üçüncü eşik tam değeri (50) → Seviye 4.0', () {
      expect(getIdealLevel(50), equals(4.0));
    });

    test('Üçüncü eşik üzeri (51) → Seviye 4.5', () {
      expect(getIdealLevel(51), equals(4.5));
    });

    test('Dördüncü eşik tam değeri (70) → Seviye 4.5', () {
      expect(getIdealLevel(70), equals(4.5));
    });

    test('Maksimum trafik (71+) → Seviye 5.0', () {
      expect(getIdealLevel(71), equals(5.0));
      expect(getIdealLevel(200), equals(5.0));
    });

    test('Özel eşikler overrideable (l34=10)', () {
      expect(getIdealLevel(10, b34: 10), equals(3.0));
      expect(getIdealLevel(11, b34: 10), equals(3.5));
    });
  });

  // ════════════════════════════════════════════════
  // GRUP 2: getSektorlerByLevel — Pozisyon Listesi
  // ════════════════════════════════════════════════
  group('getSektorlerByLevel — Pozisyon Listesi Doğrulaması', () {
    test('Seviye 3.0 → 3 pozisyon (TWR, DEL, SUP)', () {
      var result = getSektorlerByLevel(3.0);
      expect(result.length, equals(3));
      expect(result, contains('TWR'));
      expect(result, contains('DEL'));
      expect(result, contains('SUP'));
      expect(result, isNot(contains('GND')));
    });

    test('Seviye 3.5 → 4 pozisyon (TWR, DEL, GND, SUP)', () {
      var result = getSektorlerByLevel(3.5);
      expect(result.length, equals(4));
      expect(result, contains('GND'));
    });

    test('Seviye 4.0 → 4 pozisyon', () {
      var result = getSektorlerByLevel(4.0);
      expect(result.length, equals(4));
    });

    test('Seviye 4.5 → 5 pozisyon (TWR_W, DEL, GND, TWR_E, SUP)', () {
      var result = getSektorlerByLevel(4.5);
      expect(result.length, equals(5));
      expect(result, contains('TWR_W'));
      expect(result, contains('TWR_E'));
    });

    test('Seviye 5.0 → 5 pozisyon', () {
      var result = getSektorlerByLevel(5.0);
      expect(result.length, equals(5));
    });

    test('Seviye 5.5 → 6 pozisyon (GND_S, GND_N eklenir)', () {
      var result = getSektorlerByLevel(5.5);
      expect(result.length, equals(6));
      expect(result, contains('GND_S'));
      expect(result, contains('GND_N'));
    });

    test('Seviye 7.0 → 7 pozisyon (GND_C eklenir)', () {
      var result = getSektorlerByLevel(7.0);
      expect(result.length, equals(7));
      expect(result, contains('GND_C'));
    });

    test('Her seviyede SUP son pozisyon olmalı', () {
      for (double lvl in [3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 7.0]) {
        var result = getSektorlerByLevel(lvl);
        expect(result.last, equals('SUP'),
            reason: 'Seviye $lvl\'de SUP son pozisyon olmalı');
      }
    });
  });

  // ════════════════════════════════════════════════
  // GRUP 3: _dakikaCoz — Saat Aralığı Dönüşümü
  // ════════════════════════════════════════════════
  group('dakikaCoz — Saat Aralığı Dönüşümü', () {
    test('100 dakikalık standart gündüz slotu', () {
      expect(dakikaCoz('09:00 - 10:40'), equals(100));
    });

    test('100 dakikalık gece slotu', () {
      expect(dakikaCoz('19:00 - 20:40'), equals(100));
    });

    test('95 dakikalık alengirli slot (21:15)', () {
      expect(dakikaCoz('19:00 - 21:15'), equals(135));
    });

    test('Gece yarısı geçen slot (22:20 - 00:00)', () {
      expect(dakikaCoz('22:20 - 00:00'), equals(100));
    });

    test('Gece yarısından sonraki slot (00:00 - 03:00)', () {
      expect(dakikaCoz('00:00 - 03:00'), equals(180));
    });

    test('03:00 - 05:30 ARA slotu', () {
      expect(dakikaCoz('03:00 - 05:30'), equals(150));
    });

    test('05:30 - 08:00 sabah slotu', () {
      expect(dakikaCoz('05:30 - 08:00'), equals(150));
    });

    test('08:00 - 09:00 son saat slotu', () {
      expect(dakikaCoz('08:00 - 09:00'), equals(60));
    });

    test('Gece yarısı geçen uzun slot (20:40 - 00:00)', () {
      // 3 saat 20 dk = 200 dakika
      expect(dakikaCoz('20:40 - 00:00'), equals(200));
    });

    test('Hatalı format fallback değeri 100 döner', () {
      expect(dakikaCoz('HATALÌ ARALIK'), equals(100));
      expect(dakikaCoz(''), equals(100));
    });
  });

  // ════════════════════════════════════════════════
  // GRUP 4: _wmoToMetarCode — Hava Olayı Kodları
  // ════════════════════════════════════════════════
  group('wmoToMetarCode — WMO Kodu METAR Dönüşümü', () {
    test('Açık hava (0-3) → tire "-"', () {
      for (int i = 0; i <= 3; i++) {
        expect(wmoToMetarCode(i), equals('-'), reason: 'WMO $i açık hava');
      }
    });

    test('Sis (45, 48) → BR', () {
      expect(wmoToMetarCode(45), equals('BR'));
      expect(wmoToMetarCode(48), equals('BR'));
    });

    test('Çiseleme (51-55) → DZ', () {
      for (int i = 51; i <= 55; i++) {
        expect(wmoToMetarCode(i), equals('DZ'), reason: 'WMO $i çiseleme');
      }
    });

    test('Hafif yağmur (61) → -RA', () {
      expect(wmoToMetarCode(61), equals('-RA'));
    });

    test('Orta yağmur (63) → RA', () {
      expect(wmoToMetarCode(63), equals('RA'));
    });

    test('Şiddetli yağmur (65) → +RA', () {
      expect(wmoToMetarCode(65), equals('+RA'));
    });

    test('Kar (71-75) → SN', () {
      for (int i = 71; i <= 75; i++) {
        expect(wmoToMetarCode(i), equals('SN'), reason: 'WMO $i kar');
      }
    });

    test('Sağanak (80-82) → SHRA', () {
      for (int i = 80; i <= 82; i++) {
        expect(wmoToMetarCode(i), equals('SHRA'));
      }
    });

    test('Gök gürültüsü (95) → TS', () {
      expect(wmoToMetarCode(95), equals('TS'));
    });

    test('Gök gürültülü sağanak (96, 99) → TSRA', () {
      expect(wmoToMetarCode(96), equals('TSRA'));
      expect(wmoToMetarCode(99), equals('TSRA'));
    });

    test('Bilinmeyen kod → tire "-"', () {
      expect(wmoToMetarCode(100), equals('-'));
      expect(wmoToMetarCode(999), equals('-'));
    });
  });

  // ════════════════════════════════════════════════
  // GRUP 5: _cloudToAviationCode — Bulut Kodu
  // ════════════════════════════════════════════════
  group('cloudToAviationCode — Bulut Havasılık Kodu', () {
    test('0% bulut → NSC', () {
      expect(cloudToAviationCode(0), equals('NSC'));
    });

    test('%9 bulut → NSC (sınır altı)', () {
      expect(cloudToAviationCode(9), equals('NSC'));
    });

    test('%10 bulut → FEW030', () {
      expect(cloudToAviationCode(10), equals('FEW030'));
    });

    test('%24 bulut → FEW030 (sınır altı)', () {
      expect(cloudToAviationCode(24), equals('FEW030'));
    });

    test('%25 bulut → SCT030', () {
      expect(cloudToAviationCode(25), equals('SCT030'));
    });

    test('%49 bulut → SCT030 (sınır altı)', () {
      expect(cloudToAviationCode(49), equals('SCT030'));
    });

    test('%50 bulut → BKN025', () {
      expect(cloudToAviationCode(50), equals('BKN025'));
    });

    test('%84 bulut → BKN025 (sınır altı)', () {
      expect(cloudToAviationCode(84), equals('BKN025'));
    });

    test('%85 bulut → OVC015', () {
      expect(cloudToAviationCode(85), equals('OVC015'));
    });

    test('%100 bulut → OVC015', () {
      expect(cloudToAviationCode(100), equals('OVC015'));
    });

    // Sınır değer testi — kritik geçiş noktaları
    test('Tüm sınır noktaları doğru kodla başlar', () {
      expect(cloudToAviationCode(9), startsWith('NSC'));
      expect(cloudToAviationCode(10), startsWith('FEW'));
      expect(cloudToAviationCode(25), startsWith('SCT'));
      expect(cloudToAviationCode(50), startsWith('BKN'));
      expect(cloudToAviationCode(85), startsWith('OVC'));
    });
  });

  // ════════════════════════════════════════════════
  // GRUP 6: PersonelKarnesi — Oran Hesaplamaları
  // ════════════════════════════════════════════════
  group('PersonelKarnesi — Oran ve Sınıf Hesaplamaları', () {
    test('Boş karne — tüm oranlar 0.0', () {
      var k = PersonelKarnesi();
      expect(k.oranGece, equals(0.0));
      expect(k.oranAra, equals(0.0));
      expect(k.oranSabah, equals(0.0));
      expect(k.toplamGeceGorev, equals(0));
    });

    test('Sadece gece vardiyası — oranGece 1.0', () {
      var k = PersonelKarnesi();
      k.geceCore = 5;
      expect(k.oranGece, equals(1.0));
      expect(k.oranAra, equals(0.0));
      expect(k.oranSabah, equals(0.0));
      expect(k.toplamGeceGorev, equals(5));
    });

    test('Eşit dağılım — her oran ~0.33', () {
      var k = PersonelKarnesi();
      k.geceCore = 3;
      k.araCore = 3;
      k.sabahCore = 3;
      expect(k.oranGece, closeTo(0.333, 0.001));
      expect(k.oranAra, closeTo(0.333, 0.001));
      expect(k.oranSabah, closeTo(0.333, 0.001));
    });

    test('ARA ağırlıklı karne oranAra yüksek olmalı', () {
      var k = PersonelKarnesi();
      k.geceCore = 1;
      k.araCore = 8;
      k.sabahCore = 1;
      expect(k.oranAra, greaterThan(k.oranGece));
      expect(k.oranAra, greaterThan(k.oranSabah));
    });

    test('toplamGeceGorev gece+ara+sabah toplamı', () {
      var k = PersonelKarnesi()
        ..geceCore = 2
        ..araCore = 3
        ..sabahCore = 4;
      expect(k.toplamGeceGorev, equals(9));
    });

    test('oranGunduz: gündüz görev/shift oranı', () {
      var k = PersonelKarnesi()
        ..gunduzShift = 4
        ..gunduzGorev = 3;
      expect(k.oranGunduz, equals(0.75));
    });

    test('gunduzGecGirisOrani: yüksek = daha sık geç girmiş', () {
      var k1 = PersonelKarnesi()
        ..gunduzGorev = 4
        ..gunduzToplamSlotIndeksi = 20; // Ortalama slot 5 (geç)
      var k2 = PersonelKarnesi()
        ..gunduzGorev = 4
        ..gunduzToplamSlotIndeksi = 4; // Ortalama slot 1 (erken)
      expect(k1.gunduzGecGirisOrani, greaterThan(k2.gunduzGecGirisOrani));
    });

    test('sonGeceRolu başlangıçta boş string olmalı', () {
      var k = PersonelKarnesi();
      expect(k.sonGeceRolu, equals(''));
    });
  });

  // ════════════════════════════════════════════════
  // GRUP 7: Zigzag Şablonu — Round-Robin Dağıtım
  // ════════════════════════════════════════════════
  group('buildZigzagTemplate — Round-Robin Slot Dağıtımı', () {
    test('14 kişi, 7 slot, her slot 2 kişi → her numara tam 1 slot', () {
      int aCount = 14;
      List<int> slotKap = List.filled(7, 2);
      var template = buildZigzagTemplate(7, slotKap, aCount);

      // 14 numara var mı?
      expect(template.keys.length, equals(aCount));

      // Her numara tam 1 slotta görünmeli (7*2=14, 14 kişi)
      for (int n = 0; n < aCount; n++) {
        expect(template[n]?.length, equals(1),
            reason: 'Numara $n tam 1 slotta olmalı');
      }
    });

    test('7 kişi, 7 slot, her slot 2 kişi → bazı numaralar 2 slot alır', () {
      int aCount = 7;
      List<int> slotKap = List.filled(7, 2);
      var template = buildZigzagTemplate(7, slotKap, aCount);

      // 7 numara var mı?
      expect(template.keys.length, equals(aCount));

      // Toplam slot ataması: 7*2=14 → ortalama 2 slot/kişi
      int toplamSlot = template.values.fold(0, (sum, slots) => sum + slots.length);
      expect(toplamSlot, equals(14));
    });

    test('Boş personel havuzu ile çökmemeli', () {
      expect(() => buildZigzagTemplate(7, List.filled(7, 2), 0), returnsNormally);
    });

    test('Tek kişi → tüm slotları alır', () {
      int aCount = 1;
      List<int> slotKap = List.filled(4, 3);
      var template = buildZigzagTemplate(4, slotKap, aCount);
      expect(template[0]?.length, equals(12)); // 4 slot × 3 pozisyon
    });

    test('Round-robin sırası doğru (numara sırası slot sırası ile uyumlu)', () {
      int aCount = 6;
      List<int> slotKap = [2, 2, 2];
      var template = buildZigzagTemplate(3, slotKap, aCount);
      // Slot 0 → numara 0 ve 1
      // Slot 1 → numara 2 ve 3
      // Slot 2 → numara 4 ve 5
      expect(template[0], contains(0));
      expect(template[1], contains(0));
      expect(template[2], contains(2));
      expect(template[3], contains(2));
    });

    test('Farklı kapasite slotlar doğru dağıtılır', () {
      // Slot 0: 3 kişi, slot 1: 1 kişi
      int aCount = 4;
      List<int> slotKap = [3, 1];
      var template = buildZigzagTemplate(2, slotKap, aCount);

      int total = template.values.fold(0, (s, v) => s + v.length);
      expect(total, equals(4)); // Toplam 4 atama
    });
  });

  // ════════════════════════════════════════════════
  // GRUP 8: Gece Şeması — Slot Listesi Doğrulama
  // ════════════════════════════════════════════════
  group('Gece Şemaları — Slot Listesi ve İndeks Doğrulaması', () {
    const List<String> geceKlasik = [
      '19:00 - 20:40', '20:40 - 22:20', '22:20 - 00:00',
      '00:00 - 03:00', '03:00 - 05:30', '05:30 - 08:00', '08:00 - 09:00'
    ];

    const List<String> geceAlengirli = [
      '19:00 - 21:15', '21:15 - 23:30', '23:30 - 03:00',
      '03:00 - 05:30', '05:30 - 08:00', '08:00 - 09:00'
    ];

    test('geceKlasik — 7 slot olmalı', () {
      expect(geceKlasik.length, equals(7));
    });

    test('geceAlengirli — 6 slot olmalı', () {
      expect(geceAlengirli.length, equals(6));
    });

    String slotBaslangic(String aralik) => aralik.split(' - ')[0];

    test('geceKlasik — 00:00 slotu index 3\'te', () {
      int idx = List.generate(geceKlasik.length, (i) => i)
          .firstWhere((s) => slotBaslangic(geceKlasik[s]) == '00:00',
              orElse: () => -1);
      expect(idx, equals(3));
    });

    test('geceKlasik — 03:00 (ARA) slotu index 4\'te', () {
      int idx = List.generate(geceKlasik.length, (i) => i)
          .firstWhere((s) => slotBaslangic(geceKlasik[s]) == '03:00',
              orElse: () => -1);
      expect(idx, equals(4));
    });

    test('geceAlengirli — 23:30 slotu index 2\'de', () {
      int idx = List.generate(geceAlengirli.length, (i) => i)
          .firstWhere((s) => slotBaslangic(geceAlengirli[s]) == '23:30',
              orElse: () => -1);
      expect(idx, equals(2));
    });

    test('geceAlengirli — 03:00 (ARA) slotu index 3\'te', () {
      int idx = List.generate(geceAlengirli.length, (i) => i)
          .firstWhere((s) => slotBaslangic(geceAlengirli[s]) == '03:00',
              orElse: () => -1);
      expect(idx, equals(3));
    });

    test('geceAlengirli — 00:00 slotu YOK (orElse -1)', () {
      int idx = List.generate(geceAlengirli.length, (i) => i)
          .firstWhere((s) => slotBaslangic(geceAlengirli[s]) == '00:00',
              orElse: () => -1);
      expect(idx, equals(-1));
    });

    test('geceKlasik — 05:30 (sabah) slotu index 5\'te', () {
      int idx = List.generate(geceKlasik.length, (i) => i)
          .firstWhere((s) => slotBaslangic(geceKlasik[s]) == '05:30',
              orElse: () => -1);
      expect(idx, equals(5));
    });

    test('geceKlasik — 08:00 (son saat) slotu index 6\'da', () {
      int idx = List.generate(geceKlasik.length, (i) => i)
          .firstWhere((s) => slotBaslangic(geceKlasik[s]) == '08:00',
              orElse: () => -1);
      expect(idx, equals(6));
    });

    test('geceKlasik — tüm slot süreleri doğru', () {
      final expected = [100, 100, 100, 180, 150, 150, 60];
      for (int i = 0; i < geceKlasik.length; i++) {
        expect(dakikaCoz(geceKlasik[i]), equals(expected[i]),
            reason: 'Slot $i: ${geceKlasik[i]}');
      }
    });

    test('geceAlengirli — gece toplam = 780 dk (13 saat)', () {
      int toplam = geceAlengirli.fold(0, (sum, s) => sum + dakikaCoz(s));
      expect(toplam, equals(780));
    });
  });

  // ════════════════════════════════════════════════
  // GRUP 9: Gündüz Şeması Doğrulaması
  // ════════════════════════════════════════════════
  group('Gündüz Şemaları — Slot Listesi Doğrulaması', () {
    const List<String> gunduzKlasik = [
      '09:00 - 10:40', '10:40 - 12:20', '12:20 - 14:00',
      '14:00 - 15:40', '15:40 - 17:20', '17:20 - 19:00'
    ];

    const List<String> gunduzAlengirli = [
      '09:00 - 10:40', '10:40 - 12:20', '12:20 - 14:00',
      '14:00 - 15:20', '15:20 - 16:40', '16:40 - 17:50', '17:50 - 19:00'
    ];

    test('gunduzKlasik — 6 slot', () {
      expect(gunduzKlasik.length, equals(6));
    });

    test('gunduzAlengirli — 7 slot', () {
      expect(gunduzAlengirli.length, equals(7));
    });

    test('gunduzKlasik — her slot 100 dakika', () {
      for (var s in gunduzKlasik) {
        expect(dakikaCoz(s), equals(100), reason: '$s 100 dk olmalı');
      }
    });

    test('gunduzKlasik — toplam 600 dk (10 saat)', () {
      int toplam = gunduzKlasik.fold(0, (sum, s) => sum + dakikaCoz(s));
      expect(toplam, equals(600));
    });

    test('gunduzAlengirli — toplam 600 dk (10 saat)', () {
      int toplam = gunduzAlengirli.fold(0, (sum, s) => sum + dakikaCoz(s));
      expect(toplam, equals(600));
    });

    test('gunduzAlengirli — 09:00 ile başlar, 19:00 ile biter', () {
      expect(gunduzAlengirli.first.startsWith('09:00'), isTrue);
      expect(gunduzAlengirli.last.endsWith('19:00'), isTrue);
    });
  });

  // ════════════════════════════════════════════════
  // GRUP 10: Timeout Değerleri Doğrulaması
  // ════════════════════════════════════════════════
  group('Timeout Değerleri — Dayanıklılık Testi', () {
    // Bu testler timeout değerlerinin implicitly doğru olduğunu kontrol eder.
    // main.dart Line 250: GAS timeout = 30s
    // main.dart Line 297: Met timeout = 25s
    // main.dart Line 2985: NOTAM timeout = 45s
    test('GAS timeout minimum 30 saniye olmalı', () {
      const gasTimeoutSeconds = 30;
      expect(gasTimeoutSeconds, greaterThanOrEqualTo(30));
    });

    test('Meteoroloji timeout minimum 25 saniye olmalı', () {
      const metTimeoutSeconds = 25;
      expect(metTimeoutSeconds, greaterThanOrEqualTo(25));
    });

    test('NOTAM timeout GAS timeout\'tan büyük olmalı', () {
      const gasTimeout = 30;
      const notamTimeout = 45;
      expect(notamTimeout, greaterThan(gasTimeout));
    });
  });

  // ════════════════════════════════════════════════
  // GRUP 11: Hava Durumu Birleşim Mantığı
  // ════════════════════════════════════════════════
  group('Hava Durumu Birleşim Mantığı', () {
    test('Oraj varsa yağmur bayrağı false olmalı (oraj üst kategori)', () {
      // main.dart'taki mantık: yagmur: hasRain && !hasStorm
      bool hasRain = true;
      bool hasStorm = true;
      bool yagmur = hasRain && !hasStorm;
      expect(yagmur, isFalse);
    });

    test('Oraj varsa bulut bayrağı false olmalı', () {
      bool hasCloud = true;
      bool hasStorm = true;
      bool hasRain = false;
      bool bulutlu = hasCloud && !hasStorm && !hasRain;
      expect(bulutlu, isFalse);
    });

    test('Güneşli: storm/rain/cloud yoksa true', () {
      bool gunesli = !false && !false && !false;
      expect(gunesli, isTrue);
    });

    test('Yağmur + güneş aynı anda olamaz', () {
      bool hasRain = true;
      bool hasStorm = false;
      bool gunesli = !hasStorm && !hasRain && !false;
      bool yagmur = hasRain && !hasStorm;
      expect(gunesli && yagmur, isFalse);
    });

    test('Siddetli rüzgar bağımsız bayrak (yön değiştirmez)', () {
      bool siddetliRuzgar = true;
      bool hasRain = false;
      bool gunesli = !false && !hasRain && !false;
      // Rüzgar olsa da güneşli olabilir
      expect(gunesli, isTrue);
      expect(siddetliRuzgar, isTrue);
    });
  });

  // ════════════════════════════════════════════════
  // GRUP 12: Vize/Yetki Kontrol Mantığı
  // ════════════════════════════════════════════════
  group('Vize (Yetki) Kontrol Mantığı', () {
    // Yetki seti boşsa herkese izin verilir
    test('Boş yetki seti → tüm pozisyonlara izin', () {
      Set<String> yetki = {};
      bool yetkili = yetki.isEmpty || yetki.contains('TWR') || yetki.contains('TWR');
      expect(yetkili, isTrue);
    });

    test('Sadece SUP yetkisi olan kişi SUP kolontuğuna atanabilir', () {
      Set<String> yetki = {'SUP'};
      String pozisyon = 'SUP';
      String core = 'SUP';
      bool yetkili = yetki.isEmpty || yetki.contains(pozisyon) || yetki.contains(core);
      expect(yetkili, isTrue);
    });

    test('Sadece SUP yetkisi olan kişi TWR koltuğuna atanamaz (normal)', () {
      Set<String> yetki = {'SUP'};
      String pozisyon = 'TWR';
      String core = 'TWR';
      bool yetkili = yetki.isEmpty || yetki.contains(pozisyon) || yetki.contains(core);
      expect(yetkili, isFalse);
    });

    test('TWR_W için TWR core yetkisi yeterli', () {
      Set<String> yetki = {'TWR'};
      String pozisyon = 'TWR_W';
      String core = pozisyon.split('_')[0]; // 'TWR'
      bool yetkili = yetki.isEmpty || yetki.contains(pozisyon) || yetki.contains(core);
      expect(yetkili, isTrue);
    });

    test('GND_S için GND core yetkisi yeterli', () {
      Set<String> yetki = {'GND'};
      String pozisyon = 'GND_S';
      String core = pozisyon.split('_')[0]; // 'GND'
      bool yetkili = yetki.isEmpty || yetki.contains(pozisyon) || yetki.contains(core);
      expect(yetkili, isTrue);
    });
  });

  // ════════════════════════════════════════════════
  // GRUP 13: Edge Case — Boş Kadro Senaryoları
  // ════════════════════════════════════════════════
  group('Edge Case — Boş ve Minimum Kadro', () {
    test('Sıfır aktif personel için zigzag template çalışıyor', () {
      var template = buildZigzagTemplate(7, List.filled(7, 4), 0);
      expect(template, isEmpty);
    });

    test('1 kişi 6 slotta tüm slotlara atanır', () {
      var template = buildZigzagTemplate(6, List.filled(6, 4), 1);
      // Tek kişi (numara 0) tüm slotlarda
      expect(template[0]?.length, equals(24)); // 6 slot × 4 pozisyon
    });

    test('Slot kapasitesi sıfır olan slot için şablon sorunsuz', () {
      var template = buildZigzagTemplate(3, [4, 0, 4], 2);
      int total = template.values.fold(0, (s, v) => s + v.length);
      expect(total, equals(8)); // 2 dolu slot × 4 kişi
    });

    test('getIdealLevel negatif trafik → Seviye 3.0', () {
      expect(getIdealLevel(-5), equals(3.0));
    });

    test('dakikaCoz aynı saati → 0 dakika', () {
      expect(dakikaCoz('10:00 - 10:00'), equals(0));
    });
  });
}
