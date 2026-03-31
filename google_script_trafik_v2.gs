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
// GERÇEK FORMAT (uçuş bazlı satırlar):
//   Sütun 0: DATE    → "30.03.26" (DD.MM.YY)
//   Sütun 1: AIRLINE → "PEGASUS", "TURKISH AIRLINES" vb.
//   Sütun 2: IN      → Gelen uçuş numarası (boşsa gelen yok)
//   Sütun 3: OUT     → Giden uçuş numarası (boşsa giden yok)
//   Sütun 4: STA     → Varış saati "HH:MM" (veya "RON")
//   Sütun 5: STD     → Kalkış saati "HH:MM" (veya "RON")
//   Sütun 6: FROM    → Kalkış havalimanı
//   Sütun 7: TO      → Varış havalimanı
// Her satır BİR UÇUŞ. Saatlik toplama biz yapıyoruz.
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

      console.log("IFR: Excel dosyası bulundu, dönüştürülüyor... " + att.getName());
      var fileBlob = att.copyBlob();
      var convertedFile = Drive.Files.create(
        { name: "GECICI_IFR_" + new Date().getTime(), mimeType: MimeType.GOOGLE_SHEETS },
        fileBlob
      );
      var ss = SpreadsheetApp.openById(convertedFile.id);
      var displayData = ss.getSheets()[0].getDataRange().getDisplayValues();
      
      var ucusSayaci = 0;
      var aktifTarih = "";

      for (var i = 0; i < displayData.length; i++) {
        var row = displayData[i];
        if (row.length < 6) continue;
        
        // İlk sütundan tarih çıkar (DD.MM.YY veya DD.MM.YYYY)
        var dateCell = String(row[0]).trim();
        var tarih = ifrTarihCevir(dateCell);
        if (tarih) {
          aktifTarih = tarih;
        }
        if (!aktifTarih) continue;
        if (!haftalikVeri[aktifTarih]) haftalikVeri[aktifTarih] = {};
        
        // IN sütunu (gelen uçuş) ve STA (varış saati)
        var inFlight = String(row[2] || "").trim();
        var sta = String(row[4] || "").trim();
        
        // OUT sütunu (giden uçuş) ve STD (kalkış saati)
        var outFlight = String(row[3] || "").trim();
        var std = String(row[5] || "").trim();
        
        // GELEN: IN doluysa ve STA geçerli bir saatse
        if (inFlight && inFlight.length > 1) {
          var gelenSaat = saatCikar(sta);
          if (gelenSaat) {
            if (!haftalikVeri[aktifTarih][gelenSaat]) {
              haftalikVeri[aktifTarih][gelenSaat] = { hareket: 0, gelen: 0, giden: 0, vfrGelen: 0, vfrGiden: 0 };
            }
            haftalikVeri[aktifTarih][gelenSaat].gelen += 1;
            haftalikVeri[aktifTarih][gelenSaat].hareket += 1;
            ucusSayaci++;
          }
        }
        
        // GİDEN: OUT doluysa ve STD geçerli bir saatse
        if (outFlight && outFlight.length > 1) {
          var gidenSaat = saatCikar(std);
          if (gidenSaat) {
            if (!haftalikVeri[aktifTarih][gidenSaat]) {
              haftalikVeri[aktifTarih][gidenSaat] = { hareket: 0, gelen: 0, giden: 0, vfrGelen: 0, vfrGiden: 0 };
            }
            haftalikVeri[aktifTarih][gidenSaat].giden += 1;
            haftalikVeri[aktifTarih][gidenSaat].hareket += 1;
            ucusSayaci++;
          }
        }
      }

      var tarihSayisi = Object.keys(haftalikVeri).length;
      console.log("IFR: " + ucusSayaci + " hareket, " + tarihSayisi + " gün işlendi.");
      DriveApp.getFileById(convertedFile.id).setTrashed(true);
      return haftalikVeri;
    }
  }
  return haftalikVeri;
}

// Uçuş tarihini çevir: "30.03.26" → "30.03.2026"
function ifrTarihCevir(metin) {
  if (!metin || metin.length < 6) return null;
  
  // DD.MM.YY formatı (ör: "30.03.26")
  var m1 = metin.match(/^(\d{1,2})\.(\d{1,2})\.(\d{2})$/);
  if (m1) {
    var yil = parseInt(m1[3]) + 2000;
    return ("0" + m1[1]).slice(-2) + "." + ("0" + m1[2]).slice(-2) + "." + yil;
  }
  
  // DD.MM.YYYY formatı (ör: "30.03.2026")
  var m2 = metin.match(/^(\d{1,2})\.(\d{1,2})\.(20\d{2})$/);
  if (m2) {
    return ("0" + m2[1]).slice(-2) + "." + ("0" + m2[2]).slice(-2) + "." + m2[3];
  }
  
  // M/D/YYYY formatı (ör: "3/30/2026")
  var m3 = metin.match(/^(\d{1,2})\/(\d{1,2})\/(20\d{2})$/);
  if (m3) {
    var p1 = parseInt(m3[1]), p2 = parseInt(m3[2]);
    var gun = p2, ay = p1;
    if (p1 > 12) { gun = p1; ay = p2; }
    return ("0" + gun).slice(-2) + "." + ("0" + ay).slice(-2) + "." + m3[3];
  }
  
  return null;
}

// STA/STD saatinden "HH:00" formatına çevir
// "00:05" → "00:00", "14:35" → "14:00", "RON" → null
function saatCikar(metin) {
  if (!metin) return null;
  var m = metin.match(/^(\d{1,2}):(\d{2})/);
  if (m) {
    return ("0" + parseInt(m[1])).slice(-2) + ":00";
  }
  return null;
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

    var tekSatir = body.replace(/\r?\n|\r/g, " ");
    var regex_id = /([A-Z]\d{4}\/\d{2})\s+\*FROM:\s*\*/g;
    var matches = [...tekSatir.matchAll(regex_id)];
    var notamlar = [];

    for (var i = 0; i < matches.length; i++) {
      var id = matches[i][1];
      var idStart = matches[i].index;
      var nextStart = (i + 1 < matches.length) ? matches[i+1].index : tekSatir.length;
      var block = tekSatir.substring(idStart, nextStart);

      var fromMatch = block.match(/\*FROM:\s*\*\s*([^*+]+)/);
      var toMatch   = block.match(/\*TO:\s*\*\s*([^*+]+)/);
      var rawFrom = fromMatch ? fromMatch[1].trim().replace(/\*$/, "") : "Bilinmiyor";
      var rawTo   = toMatch   ? toMatch[1].trim().replace(/\*$/, "")  : "Bilinmiyor";

      var icerik = "";
      if (i === 0) {
        var oncesi = tekSatir.substring(0, idStart);
        var sonPlus = oncesi.lastIndexOf(" + ");
        icerik = sonPlus >= 0 ? oncesi.substring(sonPlus + 3) : oncesi;
      } else {
        var prevBlock = tekSatir.substring(matches[i-1].index, idStart);
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

// "19 MAR 2026 07:46" -> "19.03.2026 07:46"
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
