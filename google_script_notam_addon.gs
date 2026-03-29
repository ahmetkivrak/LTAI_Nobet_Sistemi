// ================================================================
// LTAI NOTAM MODÜLÜ - Bağımsız Fonksiyon
// Mevcut IFR/VFR scriptinize dokunmadan bu fonksiyonu ekleyin.
//
// KURULUM:
//   1. Bu fonksiyonları mevcut Apps Script dosyanıza yapıştırın
//   2. ltaiNotamEkle() için ayrı bir Time-triggered tetikleyici kurun
//      (günde bir kez, Eurocontrol mailinin geldiği sabah saatlerinde)
// ================================================================

function ltaiNotamEkle() {
  try {
    // 1. Mevcut cache dosyasını oku (Trafiği bozmamak için)
    var dosyaIsmi = "LTAI_TRAFIK_CACHE.txt";
    var dosyalar = DriveApp.getFilesByName(dosyaIsmi);
    if (!dosyalar.hasNext()) {
      console.log("NOTAM: Cache dosyası bulunamadı. Önce IFR/VFR verilerini oluşturun.");
      return;
    }
    
    var dosya = dosyalar.next();
    var paket = JSON.parse(dosya.getBlob().getDataAsString());

    // 2. Eurocontrol PIB maillerini ara
    // Son 3 gün içindeki "Aerodrome PIB" maillerine bak
    var query = 'from:cdc@ead.eurocontrol.int "Aerodrome PIB" newer_than:3d';
    var threads = GmailApp.search(query, 0, 5);

    if (threads.length === 0) {
      console.log("NOTAM: Eurocontrol PIB maili bulunamadı.");
      return;
    }

    // En son gelen maili al
    var msg = threads[0].getMessages().pop();
    var body = msg.getPlainBody(); // Düz metin olarak oku 

    console.log("NOTAM: PIB maili bulundu → " + msg.getSubject());
    
    // HATA AYIKLAMA İÇİN: Mailin ilk 1000 karakterini konsola yazdıralım
    console.log("----- MAİL BAŞLANGICI -----");
    console.log(body.substring(0, 1000));
    console.log("---------------------------");

    // 3. LTAI Bölümünü Bul ve NOTAM'ları Ayıkla
    var notamlar = [];
    
    // Ham veriye göre yeni ayrıştırma mantığı:
    // NOTAM'lar G0196/26 gibi bir ID ile başlıyor ve altında *FROM*: * B * TO: * C * gibi devam ediyor.
    // Metni "\n\n" veya benzeri boşluklarla değil, direkt RegEx ile tarayacağız.
    
    // Tüm metni tek bir satıra indirgeyelim (gereksiz satır atlamalarını çözeriz)
    var tekSatir = body.replace(/\r?\n|\r/g, " ");

    // Şunu arıyoruz: G0196/26 *FROM*: * 09 JAN 2026 08:30* *TO*: * 09 FEB 2026 15:00*  veya PERM
    // LTAI bilgisini içeren NOTAM'ları seçmeliyiz. PIB'de zaten hepsi LTAI için geliyor ancak kontrol edebiliriz.
    
    // [A-Z]\d{4}\/\d{2} formatındaki tüm ID'lerin indekslerini bulalım:
    var regex_id = /([A-Z]\d{4}\/\d{2})\s+\*FROM:\s*\*/g;
    var matches = [...tekSatir.matchAll(regex_id)];

    for (var i = 0; i < matches.length; i++) {
       var currentStart = matches[i].index;
       var nextStart = (i + 1 < matches.length) ? matches[i+1].index : tekSatir.length;
       var block = tekSatir.substring(currentStart, nextStart);
       
       // PIB zaten Aerodrome: LTAI şeklinde bütünü kapsıyor, bu yüzden mail içindeki her item LTAI'nindir.
       var id = matches[i][1];
       
       // Tarihleri bul: 
       // *FROM: * 19 MAR 2026 07:46* (yıldız ile kapanır) 
       // *TO: * 17 APR 2026 14:00 + (artı işareti ile devam eder veya yıldızla kapanır)
       var fromMatch = block.match(/\*FROM:\s*\*\s*([^*+]+)/);
       var toMatch   = block.match(/\*TO:\s*\*\s*([^*+]+)/);
       
       var rawBaslangic = fromMatch ? fromMatch[1].trim().replace(/\*$/, "") : "Bilinmiyor";
       var rawBitis     = toMatch   ? toMatch[1].trim().replace(/\*$/, "")  : "Bilinmiyor";
       
       var baslangic = _tarihCevir(rawBaslangic);
       var bitis     = _tarihCevir(rawBitis);
       
       // İçerik: + işaretinden sonrası (TO tarihinden sonra)
       var icerik = "";
       var plusSplit = block.match(/\*TO:\s*\*\s*[^*+]+\+\s*([\s\S]*)/);
       if (plusSplit) {
         icerik = plusSplit[1].trim();
       } else if (toMatch) {
         var icerikBaslangici = toMatch.index + toMatch[0].length;
         icerik = block.substring(icerikBaslangici).trim().replace(/^\*?\s*/, "");
       } else if (fromMatch) {
         var icerikBaslangici = fromMatch.index + fromMatch[0].length;
         icerik = block.substring(icerikBaslangici).trim();
       } else {
         icerik = block.substring(id.length).trim();
       }
       
       // Eğer icerik çok uzunsa gereksiz kısımları temizle (örn: LOWER: 000 UPPER: 999 vb.)
       // Genellikle içerik kısmı düz İngilizce metindir.
       icerik = icerik.replace(/\*?[A-Z][a-z]+:\s*\*[^*]+\*/g, "").trim(); // Geri kalan yıldızlı etiketleri sil
       
       // J1266 gibi "END OF PIB Briefing..." pseudo-NOTAM'ları gizle
       if (icerik.toUpperCase().indexOf("END OF PIB BRIEFING") > -1) {
         continue;
       }
       
       notamlar.push({
         "id": id,
         "baslangic": baslangic,
         "bitis": bitis,
         "icerik": icerik.replace(/\s+/g, " ") 
       });
    }

    // 4. Cache'e ekle ve kaydet
    paket.notamlar = notamlar;
    paket.notamGuncelleme = new Date().toLocaleString("tr-TR");
    
    dosya.setContent(JSON.stringify(paket));
    console.log("NOTAM: " + notamlar.length + " adet LTAI NOTAM'ı cache'e eklendi.");

  } catch (e) {
    console.log("NOTAM HATA: " + e.toString());
  }
}

// "19 MAR 2026 07:46" -> "19.03.2026 07:46" formatına çeviren yardımcı
function _tarihCevir(str) {
  if (!str) return "Bilinmiyor";
  str = str.trim();
  if (str === "PERM") return "KALICI";
  
  var aylar = {"JAN":"01", "FEB":"02", "MAR":"03", "APR":"04", "MAY":"05", "JUN":"06", "JUL":"07", "AUG":"08", "SEP":"09", "OCT":"10", "NOV":"11", "DEC":"12"};
  var parts = str.toUpperCase().split(/\s+/); // Boşluklara göre böl
  
  if (parts.length >= 3) {
    var day = parts[0].padStart(2, '0');
    var month = aylar[parts[1]] || parts[1];
    var year = parts[2];
    var time = parts.length > 3 ? " " + parts[3] : "";
    return day + "." + month + "." + year + time;
  }
  return str;
}

// Test için:
function notamTestEt() {
  ltaiNotamEkle();
}
}

// Test için:
function notamTestEt() {
  ltaiNotamEkle();
}
