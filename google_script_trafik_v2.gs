// =========================================================
// LTAI TAKTİK TAHTASI - Google Apps Script v2
// IFR  : Gmail'deki "Haftalık" Excel eki → saatlik hareket
// VFR  : Gmail'deki "ERAH Havacılık" PDF eki → LTAI geliş/gidiş
// NOTAM: Gmail'deki Eurocontrol PIB maili → LTAI NOTAMları
// Her şey LTAI_TRAFIK_CACHE.txt dosyasına birleşir.
// =========================================================

// ----------------------------------------------------------
// ANA FONKSİYON - Time-trigger ile günlük çalıştır
// ----------------------------------------------------------
function asciVeriyiHazirla() {
  try {
    console.log("AŞÇI: Motor çalıştı, IFR + VFR hazırlanıyor...");

    var haftalikVeri = {};

    // 1) IFR - Haftalık Excel'den çek
    haftalikVeri = ifrExceldenDoldur(haftalikVeri);

    // 2) VFR - ERAH PDF'lerinden çek (1 Kasım - 1 Nisan sezonu)
    haftalikVeri = vfrErahPdfdenDoldur(haftalikVeri);

    // 3) Cache'e yaz
    var paket = {
      "durum": "BAŞARILI",
      "guncelleme": new Date().toLocaleString("tr-TR"),
      "haftalikVeri": haftalikVeri
    };

    var dosyaIsmi = "LTAI_TRAFIK_CACHE.txt";
    var dosyalar = DriveApp.getFilesByName(dosyaIsmi);
    if (dosyalar.hasNext()) {
      dosyalar.next().setContent(JSON.stringify(paket));
    } else {
      DriveApp.createFile(dosyaIsmi, JSON.stringify(paket), MimeType.PLAIN_TEXT);
    }
    console.log("AŞÇI: Paket hazır. IFR+VFR birleştirildi.");

  } catch (e) {
    console.log("SİSTEM ÇÖKTÜ: " + e.toString());
  }
}

// ----------------------------------------------------------
// IFR: "Haftalık" Excel eki → haftalikVeri doldur
// ----------------------------------------------------------
function ifrExceldenDoldur(haftalikVeri) {
  var query = 'has:attachment (filename:xls OR filename:xlsx) "Haftalık" newer_than:7d';
  var threads = GmailApp.search(query, 0, 10);

  if (threads.length === 0) {
    console.log("IFR: Haftalık Excel maili bulunamadı, atlanıyor.");
    return haftalikVeri;
  }

  for (var t = 0; t < threads.length; t++) {
    var messages = threads[t].getMessages();
    var atts = messages[messages.length - 1].getAttachments();

    for (var a = 0; a < atts.length; a++) {
      var att = atts[a];
      if (att.getName().toLowerCase().indexOf('haftal') === -1) continue;

      console.log("IFR: Excel dosyası bulundu, dönüştürülüyor...");
      var fileBlob = att.copyBlob();
      var convertedFile = Drive.Files.create(
        { name: "GECICI_IFR_" + new Date().getTime(), mimeType: MimeType.GOOGLE_SHEETS },
        fileBlob
      );
      var ss = SpreadsheetApp.openById(convertedFile.id);
      var displayData = ss.getSheets()[0].getDataRange().getDisplayValues();
      var aktifTarih = "";

      for (var i = 0; i < displayData.length; i++) {
        var row = displayData[i];
        var rowText = row.join(" ").trim();
        if (rowText.toUpperCase().indexOf("TOPLAM") > -1 || rowText.toUpperCase().indexOf("TOTAL") > -1) continue;

        var tarih = tarihBul(row[0] + " " + row[1]);
        if (tarih) {
          aktifTarih = tarih;
          if (!haftalikVeri[aktifTarih]) haftalikVeri[aktifTarih] = {};
          continue;
        }
        if (aktifTarih === "") continue;

        var saatBilgisi = saatBul(row, 4);
        if (saatBilgisi) {
          var gelenStr = String(row[saatBilgisi.idx + 9] || "0").replace(/[^0-9]/g, "");
          var gidenStr = String(row[saatBilgisi.idx + 10] || "0").replace(/[^0-9]/g, "");
          var gelen = parseInt(gelenStr) || 0;
          var giden = parseInt(gidenStr) || 0;

          if (!haftalikVeri[aktifTarih][saatBilgisi.saat]) {
            haftalikVeri[aktifTarih][saatBilgisi.saat] = { hareket: 0, gelen: 0, giden: 0, vfrGelen: 0, vfrGiden: 0 };
          }
          haftalikVeri[aktifTarih][saatBilgisi.saat].hareket += gelen + giden;
          haftalikVeri[aktifTarih][saatBilgisi.saat].gelen   += gelen;
          haftalikVeri[aktifTarih][saatBilgisi.saat].giden   += giden;
        }
      }

      DriveApp.getFileById(convertedFile.id).setTrashed(true);
      return haftalikVeri;
    }
  }
  return haftalikVeri;
}

// ----------------------------------------------------------
// VFR: "ERAH Havacılık" PDF ekleri → LTAI geliş/gidiş say
// ----------------------------------------------------------
function vfrErahPdfdenDoldur(haftalikVeri) {
  var query = 'from:dispatch@erah.aero has:attachment filename:pdf "ERAH Havacılık" newer_than:7d';
  var threads = GmailApp.search(query, 0, 10);

  if (threads.length === 0) {
    console.log("VFR: ERAH maili bulunamadı, atlanıyor.");
    return haftalikVeri;
  }

  for (var t = 0; t < threads.length; t++) {
    var messages = threads[t].getMessages();
    var msg = messages[messages.length - 1];

    var konu = msg.getSubject();
    var tarihMatch = konu.match(/(\d{1,2})[\/\.](\d{1,2})[\/\.](20\d{2})/);
    if (!tarihMatch) {
      console.log("VFR: Konudan tarih çıkarılamadı: " + konu);
      continue;
    }
    var aktifTarih = ("0" + tarihMatch[1]).slice(-2) + "." + ("0" + tarihMatch[2]).slice(-2) + "." + tarihMatch[3];
    if (!haftalikVeri[aktifTarih]) haftalikVeri[aktifTarih] = {};

    var atts = msg.getAttachments();
    for (var a = 0; a < atts.length; a++) {
      var att = atts[a];
      var attName = att.getName().toLowerCase();
      if (attName.indexOf('.pdf') === -1) continue;

      console.log("VFR (" + aktifTarih + "): PDF bulundu, OCR başlıyor... " + att.getName());

      var pdfBlob = att.copyBlob().setContentType('application/pdf');
      var ocrDosya = Drive.Files.create(
        { name: "GECICI_ERAH_" + new Date().getTime(), mimeType: MimeType.GOOGLE_DOCS },
        pdfBlob,
        { ocr: true, ocrLanguage: 'tr' }
      );

      var doc = DocumentApp.openById(ocrDosya.id);
      var metin = doc.getBody().getText();
      DriveApp.getFileById(ocrDosya.id).setTrashed(true);

      var satirlar = metin.split('\n');
      for (var s = 0; s < satirlar.length; s++) {
        var satir = satirlar[s].trim();
        if (satir.indexOf('LTAI') === -1) continue;
        if (satir.toUpperCase().indexOf('TOPLAM') > -1 ||
            satir.toUpperCase().indexOf('TOTAL') > -1 ||
            satir.toUpperCase().indexOf('SORTIES') > -1) continue;

        var saatMatch = satir.match(/\b(\d{2}):(\d{2})\b/);
        if (!saatMatch) continue;
        var saat = saatMatch[1] + ":00";

        var ltMatches = satir.match(/\bLT[A-Z]{2}\b/g);
        if (!ltMatches || ltMatches.length < 2) continue;

        var kalkis = ltMatches[0];
        var inis   = ltMatches[1];

        if (!haftalikVeri[aktifTarih][saat]) {
          haftalikVeri[aktifTarih][saat] = { hareket: 0, gelen: 0, giden: 0, vfrGelen: 0, vfrGiden: 0 };
        }

        if (kalkis === 'LTAI') {
          haftalikVeri[aktifTarih][saat].vfrGiden += 1;
          console.log("  VFR GİDEN: " + aktifTarih + " " + saat + " → " + inis);
        }
        if (inis === 'LTAI') {
          haftalikVeri[aktifTarih][saat].vfrGelen += 1;
          console.log("  VFR GELEN: " + aktifTarih + " " + saat + " ← " + kalkis);
        }
      }

      console.log("VFR (" + aktifTarih + "): PDF işlendi.");
      break;
    }
  }

  return haftalikVeri;
}

// ----------------------------------------------------------
// YARDIMCI: Hücreden tarih çıkar
// ----------------------------------------------------------
function tarihBul(metin) {
  var dM1 = metin.match(/(202\d)[-\/.](\d{1,2})[-\/.](\d{1,2})/);
  if (dM1) return ("0" + dM1[3]).slice(-2) + "." + ("0" + dM1[2]).slice(-2) + "." + dM1[1];

  var dM2 = metin.match(/(\d{1,2})[-\/.](\d{1,2})[-\/.](202\d)/);
  if (dM2) {
    var p1 = parseInt(dM2[1]), p2 = parseInt(dM2[2]);
    var gun = (p1 > 12) ? p1 : (p2 > 12 ? p2 : p1);
    var ay  = (p1 > 12) ? p2 : (p2 > 12 ? p1 : p2);
    return ("0" + gun).slice(-2) + "." + ("0" + ay).slice(-2) + "." + dM2[3];
  }
  return null;
}

// ----------------------------------------------------------
// YARDIMCI: Satırdan Off Block saatini bul
// ----------------------------------------------------------
function saatBul(row, maxCol) {
  for (var c = 0; c < Math.min(maxCol, row.length); c++) {
    var huc = String(row[c]).trim();
    if (huc === "00:00:00" || huc.indexOf("12:00:00 AM") > -1) {
      return { saat: "00:00", idx: c };
    }
    var tMatch = huc.match(/^(\d{2})[:.](\d{2})/);
    if (tMatch && huc.indexOf("-") > -1) {
      return { saat: tMatch[1] + ":00", idx: c };
    }
  }
  return null;
}

// ----------------------------------------------------------
// doGet - Flutter uygulaması buradan okur
// ?action=refresh_notam → Gmail'den yeni NOTAM'ları çek, kaydet, sonra döndür
// (parametre yok)       → Sadece cache'i oku (hızlı)
// ----------------------------------------------------------
function doGet(e) {
  var params = e && e.parameter ? e.parameter : {};

  if (params.action === "refresh_notam") {
    try {
      ltaiNotamEkle();
    } catch (err) {
      console.log("doGet/refresh_notam HATA: " + err.toString());
    }
  }

  var dosyaIsmi = "LTAI_TRAFIK_CACHE.txt";
  var dosyalar = DriveApp.getFilesByName(dosyaIsmi);
  if (dosyalar.hasNext()) {
    var icerik = dosyalar.next().getBlob().getDataAsString();
    return ContentService.createTextOutput(icerik).setMimeType(ContentService.MimeType.JSON);
  }
  return ContentService.createTextOutput(
    JSON.stringify({ "error": "Henüz paket hazırlanmadı." })
  ).setMimeType(ContentService.MimeType.JSON);
}

// ----------------------------------------------------------
// LTAI NOTAM MODÜLÜ
// PIB FORMAT GERÇEĞI (Gmail plain body, yıldız biçimli):
//   [İÇERİK_i]  ID_i *FROM: * tarihX* *TO: * tarihY*  +  [İÇERİK_{i+1}]  ID_{i+1} *FROM: * ...
//
// Yani her ID_i bloğunun SONRAKI '+' işaretinden sonraki metin
// bir SONRAKİ NOTAM'a ait.
// İÇERİK_i ise bir önceki bloğun '+' işaretinden sonra, bu ID'den önce gelir.
// ----------------------------------------------------------
function ltaiNotamEkle() {
  try {
    var dosyaIsmi = "LTAI_TRAFIK_CACHE.txt";
    var dosyalar = DriveApp.getFilesByName(dosyaIsmi);
    if (!dosyalar.hasNext()) {
      console.log("NOTAM: Cache dosyası bulunamadı.");
      return;
    }

    var dosya = dosyalar.next();
    var paket = JSON.parse(dosya.getBlob().getDataAsString());

    var query = 'from:cdc@ead.eurocontrol.int "Aerodrome PIB" newer_than:3d';
    var threads = GmailApp.search(query, 0, 5);
    if (threads.length === 0) { console.log("NOTAM: PIB maili bulunamadı."); return; }

    var msg = threads[0].getMessages().pop();
    var body = msg.getPlainBody();
    console.log("NOTAM: PIB maili → " + msg.getSubject());

    // Tüm metni tek satıra indir
    var tekSatir = body.replace(/\r?\n|\r/g, " ");

    // Her ID'yi *FROM: * ile birlikte bul
    var regex_id = /([A-Z]\d{4}\/\d{2})\s+\*FROM:\s*\*/g;
    var matches = [...tekSatir.matchAll(regex_id)];
    var notamlar = [];

    for (var i = 0; i < matches.length; i++) {
      var id = matches[i][1];
      var idStart = matches[i].index;
      var nextStart = (i + 1 < matches.length) ? matches[i+1].index : tekSatir.length;
      var block = tekSatir.substring(idStart, nextStart);

      // FROM ve TO tarihleri bu bloğun içinde (doğru)
      var fromMatch = block.match(/\*FROM:\s*\*\s*([^*+]+)/);
      var toMatch   = block.match(/\*TO:\s*\*\s*([^*+]+)/);
      var rawFrom = fromMatch ? fromMatch[1].trim().replace(/\*$/, "") : "Bilinmiyor";
      var rawTo   = toMatch   ? toMatch[1].trim().replace(/\*$/, "")  : "Bilinmiyor";

      // İÇERİK: bir önceki bloğun '+' işaretinden sonraki metin bu NOTAM'a ait
      var icerik = "";
      if (i === 0) {
        // İlk NOTAM: metnin başından bu ID'ye kadar olan kısım
        var oncesi = tekSatir.substring(0, idStart);
        var sonPlus = oncesi.lastIndexOf(" + ");
        icerik = sonPlus >= 0 ? oncesi.substring(sonPlus + 3) : oncesi;
      } else {
        // Önceki blok: matches[i-1].index'ten bu idStart'a kadar
        var prevBlock = tekSatir.substring(matches[i-1].index, idStart);
        // '*TO:* tarih* + İÇERİK' formatında + işaretini bul
        var sepMatch = prevBlock.match(/\*\s*\+\s*([\s\S]*)$/);
        if (sepMatch) {
          icerik = sepMatch[1];
        } else {
          var lastPlus = prevBlock.lastIndexOf(" + ");
          icerik = lastPlus >= 0 ? prevBlock.substring(lastPlus + 3) : "";
        }
      }

      icerik = icerik.replace(/\s+/g, " ").trim();
      if (!icerik || icerik.toUpperCase().indexOf("END OF PIB") > -1) continue;

      notamlar.push({
        "id": id,
        "baslangic": _tarihCevir(rawFrom),
        "bitis":     _tarihCevir(rawTo),
        "icerik":    icerik
      });
    }

    paket.notamlar = notamlar;
    paket.notamGuncelleme = new Date().toLocaleString("tr-TR");
    dosya.setContent(JSON.stringify(paket));
    console.log("NOTAM: " + notamlar.length + " adet LTAI NOTAM cache'e eklendi.");

  } catch (e) {
    console.log("NOTAM HATA: " + e.toString());
  }
}

// "19 MAR 2026 07:46" -> "19.03.2026 07:46" formatına çeviren yardımcı
function _tarihCevir(str) {
  if (!str) return "Bilinmiyor";
  str = str.trim();
  if (str === "PERM") return "KALICI";

  var aylar = {"JAN":"01","FEB":"02","MAR":"03","APR":"04","MAY":"05","JUN":"06","JUL":"07","AUG":"08","SEP":"09","OCT":"10","NOV":"11","DEC":"12"};
  var parts = str.toUpperCase().split(/\s+/);

  if (parts.length >= 3) {
    var day   = parts[0].padStart(2, '0');
    var month = aylar[parts[1]] || parts[1];
    var year  = parts[2];
    var time  = parts.length > 3 ? " " + parts[3] : "";
    return day + "." + month + "." + year + time;
  }
  return str;
}
