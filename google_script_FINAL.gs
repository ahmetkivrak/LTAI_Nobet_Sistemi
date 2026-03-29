// ================================================================
// LTAI TAKTİK TAHTASI - Google Apps Script FINAL
// IFR : Gmail'deki "Haftalık" Excel eki (Fraport/TAV) → haftalık saatlik trafik
// VFR : Gmail'deki ERAH PDF eki → OCR ile LTAI geliş/gidiş (Kasım-Nisan sezonu)
// Arşiv: Drive'da LTAI_TRAFIK_CACHE.txt
//
// KURULUM:
//   1. Bu scripti Apps Script projenize yapıştırın
//   2. Services → Drive API (v3) ekleyin
//   3. asciVeriyiHazirla() için günde 1 kez Time-triggered tetikleyici kurun
//   4. doGet URL'ini Flutter'daki gasUrl sabitine yazın
// ================================================================

// --- TETIKLEYICI FONKSİYON (günde bir çalışır) ---
function asciVeriyiHazirla() {
  try {
    console.log("AŞÇI: Motor çalıştı...");

    var haftalikVeri = {};

    // BÖLÜM 1: IFR - Haftalık Excel'den trafik çek
    haftalikVeri = _ifrExcelOku(haftalikVeri);

    // BÖLÜM 2: VFR - Sadece Kasım-Nisan (kış) sezonunda çalışır
    var ay = new Date().getMonth() + 1;
    var vfrSezonu = (ay >= 11 || ay <= 4);
    if (vfrSezonu) {
      haftalikVeri = _vfrPdfOku(haftalikVeri);
    } else {
      console.log("VFR: Yaz sezonu (May-Ekim), ERAH taraması atlandı.");
    }

    // BÖLÜM 3: Drive cache'e yaz
    var paket = {
      "durum": "BAŞARILI",
      "guncelleme": new Date().toLocaleString("tr-TR"),
      "haftalikVeri": haftalikVeri
    };

    _cacheYaz(paket);
    console.log("AŞÇI: IFR+VFR paketi hazır, Drive'a bırakıldı.");

  } catch (e) {
    console.log("SİSTEM HATASI: " + e.toString());
  }
}

// --- GARSON (Flutter buradan okur, anlık yanıt) ---
function doGet(e) {
  var dosyaIsmi = "LTAI_TRAFIK_CACHE.txt";
  var dosyalar = DriveApp.getFilesByName(dosyaIsmi);
  if (dosyalar.hasNext()) {
    var icerik = dosyalar.next().getBlob().getDataAsString();
    return ContentService.createTextOutput(icerik).setMimeType(ContentService.MimeType.JSON);
  }
  return ContentService.createTextOutput(
    JSON.stringify({"error": "Henüz paket hazırlanmadı. asciVeriyiHazirla() çalıştırın."})
  ).setMimeType(ContentService.MimeType.JSON);
}

// ================================================================
// IFR: "Haftalık" Excel ekinden saatlik trafik ayrıştır
// ================================================================
function _ifrExcelOku(haftalikVeri) {
  var query = 'has:attachment (filename:xls OR filename:xlsx) "Haftalık" newer_than:7d';
  var threads = GmailApp.search(query, 0, 10);

  if (threads.length === 0) {
    console.log("IFR: 'Haftalık' Excel maili bulunamadı.");
    return haftalikVeri;
  }

  for (var t = 0; t < threads.length; t++) {
    var messages = threads[t].getMessages();
    var atts = messages[messages.length - 1].getAttachments();

    for (var a = 0; a < atts.length; a++) {
      var att = atts[a];
      if (att.getName().toLowerCase().indexOf('haftal') === -1) continue;

      console.log("IFR: Excel bulundu → " + att.getName());

      // Excel'i Google Sheets'e çevir (OCR değil, format dönüşümü)
      var fileBlob = att.copyBlob();
      var convertedFile = Drive.Files.create(
        { name: "GECICI_LTAI_" + new Date().getTime(), mimeType: MimeType.GOOGLE_SHEETS },
        fileBlob
      );
      var sheet = SpreadsheetApp.openById(convertedFile.id).getSheets()[0];
      var displayData = sheet.getDataRange().getDisplayValues();
      var aktifTarih = "";

      for (var i = 0; i < displayData.length; i++) {
        var row = displayData[i];
        var rowText = row.join(" ").trim();

        // Özet/Toplam satırlarını atla
        if (rowText.toUpperCase().indexOf("TOPLAM") > -1 ||
            rowText.toUpperCase().indexOf("TOTAL") > -1) continue;

        // Tarih satırı yakalama (iki format: YYYY-MM-DD ve DD.MM.YYYY)
        var olasiTarih = row[0] + " " + row[1];
        var tarih = _tarihCoz(olasiTarih);
        if (tarih) {
          aktifTarih = tarih;
          if (!haftalikVeri[aktifTarih]) haftalikVeri[aktifTarih] = {};
          continue;
        }
        if (aktifTarih === "") continue;

        // Saat satırı yakalama
        var saatBilgisi = _saatBul(row, 4);
        if (!saatBilgisi) continue;

        // Gelen/giden sütunları (saat kolonundan 9-10 sütun sağda)
        var gelenStr = String(row[saatBilgisi.idx + 9] || "0").replace(/[^0-9]/g, "");
        var gidenStr = String(row[saatBilgisi.idx + 10] || "0").replace(/[^0-9]/g, "");
        var gelen = parseInt(gelenStr) || 0;
        var giden = parseInt(gidenStr) || 0;

        haftalikVeri[aktifTarih][saatBilgisi.saat] = {
          "hareket": gelen + giden,
          "gelen": gelen,
          "giden": giden,
          "vfrGelen": 0,  // VFR'lar Bölüm 2'de doldurulur
          "vfrGiden": 0
        };
      }

      DriveApp.getFileById(convertedFile.id).setTrashed(true);
      console.log("IFR: " + Object.keys(haftalikVeri).length + " günlük veri çekildi.");
      return haftalikVeri; // İlk geçerli Excel yeterli
    }
  }
  return haftalikVeri;
}

// ================================================================
// VFR: ERAH PDF'lerinden LTAI geliş/gidiş say
// TC-XXX tescil numarasını referans alarak satır bloklarını okur
// ================================================================
function _vfrPdfOku(haftalikVeri) {
  // ERAH günde 1 PDF gönderir: Dispatch <planlama@erah.aero>
  var query = 'from:planlama@erah.aero has:attachment newer_than:7d';
  var threads = GmailApp.search(query, 0, 7); // Haftanın 7 günü için

  if (threads.length === 0) {
    console.log("VFR: ERAH maili bulunamadı.");
    return haftalikVeri;
  }

  var islenenPdfler = 0;

  for (var t = 0; t < threads.length; t++) {
    var messages = threads[t].getMessages();

    for (var mIdx = messages.length - 1; mIdx >= 0; mIdx--) {
      var atts = messages[mIdx].getAttachments();
      var pdfAtt = null;

      for (var j = 0; j < atts.length; j++) {
        if (atts[j].getName().toLowerCase().indexOf('.pdf') > -1) {
          pdfAtt = atts[j]; break;
        }
      }
      if (!pdfAtt) continue;

      try {
        // PDF → Google Docs (OCR)
        var blob = pdfAtt.copyBlob();
        var ocrDosya = Drive.Files.create(
          { name: "GECICI_ERAH_" + new Date().getTime(), mimeType: MimeType.GOOGLE_DOCS },
          blob,
          { ocr: true, ocrLanguage: 'tr' }
        );
        var doc = DocumentApp.openById(ocrDosya.id);
        var text = doc.getBody().getText();
        DriveApp.getFileById(ocrDosya.id).setTrashed(true);

        // PDF başlığındaki Türkçe tarihi bul: "16 Mart 2026, Pazartesi(Rev.00)"
        var pdfTarih = _turkceAyTarihCoz(text);
        if (!pdfTarih) {
          console.log("VFR: PDF'ten tarih çıkarılamadı, atlanıyor.");
          continue;
        }

        // Bu tarihin IFR verisi yoksa, boş ekle (sadece VFR olan gün)
        if (!haftalikVeri[pdfTarih]) haftalikVeri[pdfTarih] = {};
        var hedefGun = haftalikVeri[pdfTarih];

        console.log("VFR (" + pdfTarih + "): PDF parse ediliyor...");

        // TC- ile başlayan uçak tescilini referans al → bloğu oku
        var satirlar = text.split('\n');
        for (var l = 0; l < satirlar.length; l++) {
          var satir = satirlar[l].trim().toUpperCase();
          if (satir.indexOf("TC-") === -1) continue;

          // TC-XXX satırından sonraki 10 satırda: saatler ve LTXX kodları
          var offBlock = "", onBlock = "";
          var meydanlar = [];

          for (var k = 1; k <= 10; k++) {
            if (l + k >= satirlar.length) break;
            var alt = satirlar[l + k].trim().toUpperCase();

            // HH:MM formatı → ilk = offBlock, ikinci = onBlock
            if (/^\d{2}:\d{2}$/.test(alt)) {
              if (offBlock === "") offBlock = alt;
              else if (onBlock === "") onBlock = alt;
            }

            // LTXX formatı (4 harfli ICAO kodu)
            if (/^LT[A-Z]{2}$/.test(alt)) {
              meydanlar.push(alt);
            }

            if (meydanlar.length >= 2 && offBlock !== "") break;
          }

          if (meydanlar.length < 2 || offBlock === "") continue;

          var kalkis = meydanlar[0];
          var inis   = meydanlar[1];

          // LTAI'den kalkmış → VFR Giden
          if (kalkis === "LTAI") {
            var depSaat = offBlock.split(":")[0] + ":00";
            if (!hedefGun[depSaat]) hedefGun[depSaat] = {hareket:0, gelen:0, giden:0, vfrGelen:0, vfrGiden:0};
            hedefGun[depSaat].vfrGiden += 1;
          }

          // LTAI'ye inmekte → VFR Gelen (on block saatine yaz)
          if (inis === "LTAI" && onBlock !== "") {
            var arrSaat = onBlock.split(":")[0] + ":00";
            if (!hedefGun[arrSaat]) hedefGun[arrSaat] = {hareket:0, gelen:0, giden:0, vfrGelen:0, vfrGiden:0};
            hedefGun[arrSaat].vfrGelen += 1;
          }
        }

        islenenPdfler++;
        console.log("VFR (" + pdfTarih + "): PDF işlendi.");

      } catch (ocrErr) {
        console.log("VFR - OCR hatası: " + ocrErr);
      }
    }
  }

  console.log("VFR: " + islenenPdfler + " PDF işlendi.");
  return haftalikVeri;
}

// ================================================================
// YARDIMCI FONKSİYONLAR
// ================================================================

// Tarih metni → "DD.MM.YYYY" formatı
function _tarihCoz(metin) {
  // Format 1: 2026-03-16 veya 2026/03/16
  var m1 = metin.match(/(202\d)[-\/.](\d{1,2})[-\/.](\d{1,2})/);
  if (m1) return ("0" + m1[3]).slice(-2) + "." + ("0" + m1[2]).slice(-2) + "." + m1[1];

  // Format 2: 16.03.2026 veya 16-03-2026
  var m2 = metin.match(/(\d{1,2})[-\/.](\d{1,2})[-\/.](202\d)/);
  if (m2) {
    var p1 = parseInt(m2[1]), p2 = parseInt(m2[2]);
    var gun = (p1 > 12) ? p1 : (p2 > 12 ? p2 : p1);
    var ay  = (p1 > 12) ? p2 : (p2 > 12 ? p1 : p2);
    return ("0" + gun).slice(-2) + "." + ("0" + ay).slice(-2) + "." + m2[3];
  }
  return null;
}

// Türkçe ay adıyla tarih: "16 Mart 2026" → "16.03.2026"
function _turkceAyTarihCoz(metin) {
  var AYLAR = {
    "OCAK":"01","ŞUBAT":"02","MART":"03","NİSAN":"04",
    "MAYIS":"05","HAZİRAN":"06","TEMMUZ":"07","AĞUSTOS":"08",
    "EYLÜL":"09","EKİM":"10","KASIM":"11","ARALIK":"12"
  };
  var m = metin.match(/(\d{1,2})\s+(OCAK|ŞUBAT|MART|NİSAN|MAYIS|HAZİRAN|TEMMUZ|AĞUSTOS|EYLÜL|EKİM|KASIM|ARALIK)\s+(\d{4})/i);
  if (!m) return null;
  return ("0" + m[1]).slice(-2) + "." + AYLAR[m[2].toUpperCase()] + "." + m[3];
}

// Excel satırından off-block saatini bul
function _saatBul(row, maxCol) {
  for (var c = 0; c < Math.min(maxCol, row.length); c++) {
    var huc = String(row[c]).trim();
    if (huc === "00:00:00" || huc.indexOf("12:00:00 AM") > -1) {
      return { saat: "00:00", idx: c };
    }
    var m = huc.match(/^(\d{2})[:.]\d{2}/);
    if (m && huc.indexOf("-") > -1) {
      return { saat: m[1] + ":00", idx: c };
    }
  }
  return null;
}

// Cache dosyasına yaz
function _cacheYaz(paket) {
  var dosyaIsmi = "LTAI_TRAFIK_CACHE.txt";
  var icerik = JSON.stringify(paket);
  var dosyalar = DriveApp.getFilesByName(dosyaIsmi);
  if (dosyalar.hasNext()) {
    dosyalar.next().setContent(icerik);
  } else {
    DriveApp.createFile(dosyaIsmi, icerik, MimeType.PLAIN_TEXT);
  }
}

// ================================================================
// TEST FONKSİYONLARI
// ================================================================

// Manuel test: Apps Script editöründe çalıştırın
function testEt() {
  asciVeriyiHazirla();
  console.log("--- doGet çıktısı ---");
  console.log(doGet().getContent());
}
