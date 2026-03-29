// LTAI IFR Haftalık Trafik - Google Apps Script
// Gmail'den "Haftalık" başlıklı Excel ekini okur, tarih/saat/hareket sayılarını ayıklar,
// LTAI_TRAFIK_CACHE.txt'e JSON olarak yazar.

function asciVeriyiHazirla() {
  try {
    console.log("AŞÇI: Yeni nesil motor çalıştırıldı. Mail aranıyor...");
    
    var query = 'has:attachment (filename:xls OR filename:xlsx) "Haftalık" newer_than:7d';
    var threads = GmailApp.search(query, 0, 10); 
    
    if (threads.length === 0) {
      return console.log("HATA: Son 7 gün içinde 'Haftalık' Excel maili bulunamadı.");
    }

    var haftalikVeri = {};
    var bulundu = false;

    for (var t = 0; t < threads.length; t++) {
      var messages = threads[t].getMessages();
      var atts = messages[messages.length - 1].getAttachments();
      
      for (var a = 0; a < atts.length; a++) {
        var att = atts[a];
        if (att.getName().toLowerCase().indexOf('haftal') > -1) {
          
          console.log("Dosya bulundu. Google Sheet'e dönüştürülüyor...");
          
          var fileBlob = att.copyBlob();
          var resource = {
            name: "GECICI_LTAI_" + new Date().getTime(), 
            mimeType: MimeType.GOOGLE_SHEETS
          };
          
          var convertedFile = Drive.Files.create(resource, fileBlob);
          var ss = SpreadsheetApp.openById(convertedFile.id);
          var sheet = ss.getSheets()[0];
          
          var displayData = sheet.getDataRange().getDisplayValues();
          var aktifTarih = "";
          
          for (var i = 0; i < displayData.length; i++) {
            var displayRow = displayData[i];
            var satirMetni = displayRow.join(" ").trim();
            
            if (satirMetni.toUpperCase().indexOf("TOPLAM") > -1 || satirMetni.toUpperCase().indexOf("TOTAL") > -1) {
              continue;
            }

            var olasiTarih = displayRow[0] + " " + displayRow[1]; 
            var dM1 = olasiTarih.match(/(202\d)[-\/.](\d{1,2})[-\/.](\d{1,2})/); 
            var dM2 = olasiTarih.match(/(\d{1,2})[-\/.](\d{1,2})[-\/.](202\d)/); 
            
            if (dM1) {
              aktifTarih = ("0" + dM1[3]).slice(-2) + "." + ("0" + dM1[2]).slice(-2) + "." + dM1[1];
              if (!haftalikVeri[aktifTarih]) haftalikVeri[aktifTarih] = {};
              continue;
            } else if (dM2) {
              var p1 = parseInt(dM2[1]);
              var p2 = parseInt(dM2[2]);
              var gun = (p1 > 12) ? p1 : (p2 > 12 ? p2 : p1);
              var ay = (p1 > 12) ? p2 : (p2 > 12 ? p1 : p2);
              aktifTarih = ("0" + gun).slice(-2) + "." + ("0" + ay).slice(-2) + "." + dM2[3];
              if (!haftalikVeri[aktifTarih]) haftalikVeri[aktifTarih] = {};
              continue;
            }

            if (aktifTarih === "") continue; 

            var saatBulundu = false;
            var kaydedilecekSaat = "";
            var timeIndex = -1;
            
            for (var c = 0; c < 4; c++) {
              var huc = String(displayRow[c]).trim();
              
              if (huc === "00:00:00" || huc.indexOf("12:00:00 AM") > -1) {
                saatBulundu = true;
                kaydedilecekSaat = "00:00";
                timeIndex = c;
                break;
              }
              
              var tMatch = huc.match(/^(\d{2})[:.]\d{2}/);
              if (tMatch && huc.indexOf("-") > -1) {
                saatBulundu = true;
                kaydedilecekSaat = tMatch[1] + ":00";
                timeIndex = c;
                break;
              }
            }

            if (saatBulundu && timeIndex !== -1) {
              var gelenIdx = timeIndex + 9;
              var gidenIdx = timeIndex + 10;
              
              var gelenStr = String(displayRow[gelenIdx] || "0").replace(/[^0-9]/g, "");
              var gidenStr = String(displayRow[gidenIdx] || "0").replace(/[^0-9]/g, "");
              
              var gelen = parseInt(gelenStr) || 0;
              var giden = parseInt(gidenStr) || 0;
              
              haftalikVeri[aktifTarih][kaydedilecekSaat] = {
                "hareket": gelen + giden,
                "gelen": gelen,
                "giden": giden,
                "vfrGelen": 0,   // TODO: ERAH'tan doldurulacak
                "vfrGiden": 0    // TODO: ERAH'tan doldurulacak
              };
              bulundu = true;
            }
          }
          
          DriveApp.getFileById(convertedFile.id).setTrashed(true);
          
          if (bulundu) break;
        }
      }
      if (bulundu) break;
    }

    if (bulundu) {
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
      console.log("AŞÇI: İŞLEM TAMAM!");
    } else {
      console.log("HATA: Excel çevrildi ama içinden tarih/saat çıkarılamadı.");
    }

  } catch (e) {
    console.log("SİSTEM ÇÖKTÜ: " + e.toString());
  }
}

function doGet(e) {
  var dosyaIsmi = "LTAI_TRAFIK_CACHE.txt";
  var dosyalar = DriveApp.getFilesByName(dosyaIsmi);
  if (dosyalar.hasNext()) {
    var icerik = dosyalar.next().getBlob().getDataAsString();
    return ContentService.createTextOutput(icerik).setMimeType(ContentService.MimeType.JSON);
  }
  return ContentService.createTextOutput(JSON.stringify({"error": "Henüz paket hazırlanmadı."})).setMimeType(ContentService.MimeType.JSON);
}
