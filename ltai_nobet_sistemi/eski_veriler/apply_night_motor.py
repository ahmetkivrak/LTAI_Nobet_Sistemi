import re

with open('/Users/ece/Desktop/LTAI_Nobet_Sistemi/ltai_nobet_sistemi/lib/main.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# 1. Replace _gecePhase1SlotAtama
start_marker = "  // ════════════════════════════════════════════════\n  // GECE MODE — 3 AŞAMALI TERS ATAMA ALGORİTMASI"
end_marker = "  /// Phase 2: Zigzag pozisyon atama"

if start_marker in code and end_marker in code:
    start_idx = code.find(start_marker)
    end_idx = code.find(end_marker)
    
    new_func = r'''  // ════════════════════════════════════════════════
  // GECE MODE — NUMARA SİSTEMLİ TERS ATAMA ALGORİTMASI
  // ════════════════════════════════════════════════
  Map<int, Map<String, String>> _geceAtama(List<String> aktifPersonel) {
    int slotCount = saatler.length;
    Map<int, Map<String, String>> gunlukPlan = {for (int i = 0; i < slotCount; i++) i: {}};
    if (aktifPersonel.isEmpty) return gunlukPlan;

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
    
    for (var k in gece0508Secilenler) { if (kalanlar.contains(k)) { siraliKisiler.add(k); kalanlar.remove(k); } }
    for (var k in geceAraSecilenler) { if (kalanlar.contains(k)) { siraliKisiler.add(k); kalanlar.remove(k); } }
    for (var k in gece1203Secilenler) { if (kalanlar.contains(k)) { siraliKisiler.add(k); kalanlar.remove(k); } }
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
    // ADIM 4: Numaraları Slotlara Eşle (Sarmal)
    // ─────────────────────────────────────────────
    int numIdx = 0;
    Map<int, List<String>> slotTakiKisiler = {};
    for (int slotIdx in siralama) {
      if (!slotPozisyonlari.containsKey(slotIdx)) continue;
      int kapasite = slotPozisyonlari[slotIdx]!.length;
      List<String> sKisiler = [];
      for (int i = 0; i < kapasite; i++) {
        sKisiler.add(siraliKisiler[numIdx % siraliKisiler.length]);
        numIdx++;
      }
      slotTakiKisiler[slotIdx] = sKisiler;
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
          if (supOnlySecilenler.contains(k)) continue; 
          
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
\n'''
    code = code[:start_idx] + new_func + code[end_idx:]

code = code.replace("bool isAraSlotu = (!isGunduzVardiyasi && saatler[slot].startsWith('03:00'));", "bool isAraSlotu = false;")
code = code.replace("bool isYarin = !isGunduzVardiyasi && (ah < 12);", "bool isYarin = false;")
code = code.replace("if (!isGunduzVardiyasi) score += (kisiler.length - kisiler.indexOf(k)) * 50;", "")
code = code.replace("if (isGunduzVardiyasi && bugunkuPozisyonlar[k]!.isNotEmpty) {", "if (bugunkuPozisyonlar[k]!.isNotEmpty) {")

orig_orchestration = '''    // Phase 1: Kim hangi slota?
    Map<int, List<String>> slotAtamalari = isGunduzVardiyasi
        ? _phase1SlotAtama(aktifPersonel)
        : _gecePhase1SlotAtama(aktifPersonel);
    
    // Phase 2: Pozisyon ataması (post-process pinleri de içerir)
    Map<int, Map<String, String>> gunlukPlan = _phase2PozisyonAtama(slotAtamalari, aktifPersonel, aktifBK);'''

new_orchestration = '''    Map<int, Map<String, String>> gunlukPlan = {};
    if (isGunduzVardiyasi) {
      // GÜNDÜZ: Phase 1 (Slotlara dağılım) + Phase 2 (Pozisyonlara dağılım)
      Map<int, List<String>> slotAtamalari = _phase1SlotAtama(aktifPersonel);
      gunlukPlan = _phase2PozisyonAtama(slotAtamalari, aktifPersonel, aktifBK);
    } else {
      // GECE: Bağımsız Motor (Numara tabanlı tam atama)
      gunlukPlan = _geceAtama(aktifPersonel);
    }'''

code = code.replace(orig_orchestration, new_orchestration)

with open('/Users/ece/Desktop/LTAI_Nobet_Sistemi/ltai_nobet_sistemi/lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(code)

print("SUCCESS")
