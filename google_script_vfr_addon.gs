// ================================================================
// ERAH VFR MODÜLÜ - Bağımsız Fonksiyon
// Mevcut IFR scriptinize dokunmadan bu fonksiyonu ekleyin.
//
// KURULUM:
//   1. Bu fonksiyonları mevcut Apps Script dosyanıza yapıştırın
//   2. erahVfrEkle() için ayrı bir Time-triggered tetikleyici kurun
//      (günde bir, ERAH mailinin geldiği saatten sonra - genellikle sabah)
//   3. Tetikleyici sadece 1 Kasım - 1 Nisan arası çalışmalı
//      (veya alttaki sezon kontrolü halleder)
//
// ÇALIŞMA MANTIĞI:
//   1. Mevcut LTAI_TRAFIK_CACHE.txt'yi okur (IFR verisi kaybolmaz)
//   2. ERAH mailindeki PDF'i OCR ile okur
//   3. LTAI kalkış → vfrGiden, LTAI iniş → vfrGelen olarak ekler
//   4. Cache'i vfrGelen/vfrGiden dolu halde geri yazar
// ================================================================

function erahVfrEkle() {
  try {
    // SEZON KONTROLÜ: Sadece 1 Kasım - 1 Nisan arası çalışır
    var ay = new Date().getMonth() + 1; // 1-12
    if (ay >= 5 && ay <= 10) { // Mayıs-Ekim = yaz sezonu, ERAH yok
      console.log("VFR: Yaz sezonu, ERAH PDF taranmıyor.");
      return;
    }

    // 1. Mevcut IFR cache'ini oku
    var dosyaIsmi = "LTAI_TRAFIK_CACHE.txt";
    var dosyalar = DriveApp.getFilesByName(dosyaIsmi);
    if (!dosyalar.hasNext()) {
      console.log("VFR: Cache dosyası bulunamadı. Önce IFR fonksiyonunu çalıştırın.");
      return;
    }

    var mevcutPaket = JSON.parse(dosyalar.next().getBlob().getDataAsString());
    // haftalikVeri yapısı: { "16.03.2026": { "09:00": { hareket, gelen, giden, vfrGelen, vfrGiden } } }
    var haftalikVeri = mevcutPaket.haftalikVeri || mevcutPaket.veriler || {};

    // 2. ERAH maillerini tara (son 30 gün - sezon boyunca her günü kapsar)
    // NOT: ERAH Kasım-Nisan arası günlük mail atar, 7 günlük filtre yetmez
    var query = 'from:planlama@erah.aero has:attachment newer_than:30d';
    var threads = GmailApp.search(query, 0, 30);

    if (threads.length === 0) {
      console.log("VFR: ERAH maili bulunamadı.");
      return;
    }

    var islenenSayisi = 0;

    for (var t = 0; t < threads.length; t++) {
      var messages = threads[t].getMessages();

      for (var mIdx = messages.length - 1; mIdx >= 0; mIdx--) {
        var atts = messages[mIdx].getAttachments();

        // PDF ekini bul
        var pdfAtt = null;
        for (var j = 0; j < atts.length; j++) {
          if (atts[j].getName().toLowerCase().indexOf('.pdf') > -1) {
            pdfAtt = atts[j]; break;
          }
        }
        if (!pdfAtt) continue;

        try {
          console.log("VFR: PDF bulundu → " + pdfAtt.getName());

          // 3. PDF'i Google Docs'a OCR ile çevir
          var blob = pdfAtt.copyBlob();
          var ocrDosya = Drive.Files.create(
            { name: "GECICI_ERAH_" + new Date().getTime(), mimeType: MimeType.GOOGLE_DOCS },
            blob,
            { ocr: true, ocrLanguage: 'tr' }
          );
          var doc = DocumentApp.openById(ocrDosya.id);
          var ocrMetin = doc.getBody().getText();
          DriveApp.getFileById(ocrDosya.id).setTrashed(true); // Geçici dosyayı sil

          // 4. PDF başlığından tarihi çek: "16 Mart 2026, Pazartesi(Rev.00)"
          var pdfTarih = _vfr_tarihCoz(ocrMetin);
          if (!pdfTarih) {
            console.log("VFR: Tarih çıkarılamadı, PDF atlandı.");
            continue;
          }
          console.log("VFR: PDF tarihi → " + pdfTarih);

          // Bu tarihin verisi yoksa boş oluştur
          if (!haftalikVeri[pdfTarih]) haftalikVeri[pdfTarih] = {};

          // VFR sayıları eklemeden önce sıfırla (aynı PDF'i ikinci kez okuma durumuna karşı)
          Object.keys(haftalikVeri[pdfTarih]).forEach(function(saat) {
            haftalikVeri[pdfTarih][saat].vfrGelen = 0;
            haftalikVeri[pdfTarih][saat].vfrGiden = 0;
          });

          // 5. OCR metnini satır satır tara
          // LTAI'li uçuşları TC-XXX bloklarından yakala
          var satirlar = ocrMetin.split('\n');
          var ltaiGelen = 0, ltaiGiden = 0;

          for (var l = 0; l < satirlar.length; l++) {
            var satir = satirlar[l].trim().toUpperCase();

            // TC-XXX tescil numarasını referans al
            if (satir.indexOf("TC-") === -1) continue;

            // Bu satırın ardından gelen 10 satırda: saat ve ICAO kodları
            var offBlock = "", onBlock = "";
            var meydanlar = [];

            for (var k = 1; k <= 10; k++) {
              if (l + k >= satirlar.length) break;
              var alt = satirlar[l + k].trim().toUpperCase();

              // HH:MM formatı (tam saat)
              if (/^\d{2}:\d{2}$/.test(alt)) {
                if (offBlock === "") offBlock = alt;
                else if (onBlock === "") onBlock = alt;
              }

              // LT+2harf = ICAO kodu (LTAI, LTBS, LTFE, vb.)
              if (/^LT[A-Z]{2}$/.test(alt)) {
                meydanlar.push(alt);
              }

              // 2 meydan + offBlock bulunca dur
              if (meydanlar.length >= 2 && offBlock !== "") break;
            }

            if (meydanlar.length < 2 || offBlock === "") continue;

            var kalkis = meydanlar[0]; // İlk LTXX = Kalkış
            var inis   = meydanlar[1]; // İkinci LTXX = İniş

            // LTAI'den kalkış → offBlock saatine vfrGiden ekle
            if (kalkis === "LTAI") {
              var depSaat = offBlock.split(":")[0] + ":00";
              if (!haftalikVeri[pdfTarih][depSaat]) {
                haftalikVeri[pdfTarih][depSaat] = {hareket:0, gelen:0, giden:0, vfrGelen:0, vfrGiden:0};
              }
              haftalikVeri[pdfTarih][depSaat].vfrGiden += 1;
              ltaiGiden++;
            }

            // LTAI'ye iniş → onBlock saatine vfrGelen ekle
            if (inis === "LTAI" && onBlock !== "") {
              var arrSaat = onBlock.split(":")[0] + ":00";
              if (!haftalikVeri[pdfTarih][arrSaat]) {
                haftalikVeri[pdfTarih][arrSaat] = {hareket:0, gelen:0, giden:0, vfrGelen:0, vfrGiden:0};
              }
              haftalikVeri[pdfTarih][arrSaat].vfrGelen += 1;
              ltaiGelen++;
            }
          }

          console.log("VFR (" + pdfTarih + "): ltaiGelen=" + ltaiGelen + ", ltaiGiden=" + ltaiGiden);
          islenenSayisi++;

        } catch (ocrErr) {
          console.log("VFR - OCR hatası: " + ocrErr.toString());
        }
      }
    }

    // 6. Güncellenmiş veriyi cache'e geri yaz
    mevcutPaket.haftalikVeri = haftalikVeri;
    mevcutPaket.vfrGuncelleme = new Date().toLocaleString("tr-TR");

    var dosyalar2 = DriveApp.getFilesByName(dosyaIsmi);
    if (dosyalar2.hasNext()) {
      dosyalar2.next().setContent(JSON.stringify(mevcutPaket));
    }

    console.log("VFR: " + islenenSayisi + " PDF işlendi. Cache güncellendi.");

  } catch (e) {
    console.log("VFR HATA: " + e.toString());
  }
}

// Türkçe ay adıyla tarih çözümleme: "16 Mart 2026" → "16.03.2026"
function _vfr_tarihCoz(metin) {
  var AYLAR = {
    "OCAK":"01","ŞUBAT":"02","MART":"03","NİSAN":"04",
    "MAYIS":"05","HAZİRAN":"06","TEMMUZ":"07","AĞUSTOS":"08",
    "EYLÜL":"09","EKİM":"10","KASIM":"11","ARALIK":"12"
  };
  var m = metin.match(/(\d{1,2})\s+(OCAK|ŞUBAT|MART|NİSAN|MAYIS|HAZİRAN|TEMMUZ|AĞUSTOS|EYLÜL|EKİM|KASIM|ARALIK)\s+(\d{4})/i);
  if (!m) return null;
  return ("0" + m[1]).slice(-2) + "." + AYLAR[m[2].toUpperCase()] + "." + m[3];
}

// Bu fonksiyonu Apps Script'te manuel test etmek için:
function vfrTestEt() {
  erahVfrEkle();
}
