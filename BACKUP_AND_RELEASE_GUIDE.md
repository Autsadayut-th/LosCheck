# ทำความเข้าใจการสำรองข้อมูล (Backup) และการปล่อย (Release)

## 🔐 การสำรองและกู้คืนข้อมูล (ป้องกันการสูญหายข้อมูล)

### ✅ สิ่งที่ได้แก้ไข
1. **Web Support (IndexedDB)** - แอปตอนนี้รองรับทั้ง Android/iOS (SQLite) และเว็บ (IndexedDB)
2. **Database Migrations** - สามารถเปลี่ยนแปลง schema ได้อย่างปลอดภัย
3. **Error Handling** - แสดง error message ให้ผู้ใช้เห็นชัดเจน
4. **Backup Service** - มีฟังก์ชัน export/import ข้อมูลแบบเต็ม

### 📱 วิธีใช้ Settings Page (ที่เพิ่มใหม่)

เปิดแอปและไปที่ **Settings** tab (ปุ่มลูกเล่นที่เพิ่มไป)

#### 1️⃣ **ส่งออกข้อมูล (Export Backup)**
```
1. ไปที่ Settings
2. กด "ส่งออกข้อมูล"
3. ข้อมูล JSON จะคัดลอกไปยังคลิปบอร์ด
4. เก็บไฟล์นี้สำหรับกรณี์เพื่อนำเข้าภายหลัง
   - วาง JSON ลงใน Notes / Google Drive / ไฟล์ข้อความ
```

#### 2️⃣ **นำเข้าข้อมูล (Import Backup) - แทนที่ข้อมูลปัจจุบัน**
```
1. ไปที่ Settings
2. กด "นำเข้าข้อมูล"
3. วาง JSON ที่บันทึกไว้ เลือก "นำเข้า"
4. ข้อมูลปัจจุบันจะถูกแทนที่ด้วยข้อมูลจากไฟล์
```

⚠️ **ข้อเตือน**: นำเข้าจะลบข้อมูลปัจจุบันทั้งหมด — ต้องส่งออกก่อนนำเข้า

#### 3️⃣ **ผสานข้อมูล (Merge Backup) - เพิ่มไปในข้อมูลปัจจุบัน**
```
1. ไปที่ Settings
2. กด "ผสานข้อมูล"
3. วาง JSON ที่บันทึกไว้ เลือก "ผสาน"
4. ข้อมูลจะถูกเพิ่มไปยังข้อมูลปัจจุบัน (ไม่ลบข้อมูลเดิม)
```

✅ **ผสาน** ปลอดภัยกว่า — ใช้เมื่อต้องการรวมข้อมูลจากหลายอุปกรณ์

---

## 🚀 ขั้นตอน Release (Android)

### ⚠️ สิ่งที่ต้องตรวจสอบ **ก่อน** ปล่อย Version 1.0

1. **ตั้ง Application ID คงที่**
   - หา: `android/app/build.gradle.kts` บรรทัด `applicationId = "com.example.loscheck"`
   - ✅ ตรวจสอบว่าไม่เปลี่ยนแปลง (ต่อจากนี้ห้ามเปลี่ยน!)
   - 💡 **สำคัญ**: ถ้าเปลี่ยนแอป ID ผู้ใช้เก่าจะไม่สามารถ upgrade ได้ เนื่องจาก Play Store ถือว่าเป็นแอปคนละตัว

2. **สร้าง Signing Key (ด้วยความระวัง)**
   ```bash
   # Windows PowerShell (ที่เดียว)
   keytool -genkey -v -keystore my-release-key.keystore -keyalg RSA -keysize 2048 -validity 10000 -alias my-key-alias
   ```
   - ใส่รหัสผ่านที่แข็งแรง และ **เก็บไฟล์อย่างปลอดภัย**
   - ❌ **อย่าให้ใครรู้ key นี้** — ถ้าหาย ผู้ไม่ประสงค์ดีอาจลงแอป fake ผ่าน Play Store ได้

3. **ตั้งค่า Release Signing** ใน `android/app/build.gradle.kts`
   ```gradle
   signingConfigs {
       release {
           storeFile file('path/to/my-release-key.keystore')
           storePassword 'your-keystore-password'
           keyAlias 'my-key-alias'
           keyPassword 'your-key-password'
       }
   }
   
   buildTypes {
       release {
           signingConfig signingConfigs.release
       }
   }
   ```
   - ⚠️ **อย่าให้ keystore ในไฟล์ Source Code** — ใช้ environment variables หรือ CI/CD secrets แทน

4. **ทดสอบ Upgrade Path** (สำคัญมาก!)
   ```bash
   # ติดตั้ง Release APK (version 1.0) ครั้งแรก
   flutter build apk --release
   adb install build/app/outputs/flutter-apk/app-release.apk
   
   # ตรวจสอบข้อมูลยังคงอยู่ / dashboard โหลดได้
   # (เปิดแอป ตรวจสอบลูกค้า/รายการ/dashboard)
   
   # ทดสอบ upgrade (เปลี่ยน pubspec.yaml version + rebuild)
   flutter build apk --release
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   
   # ตรวจสอบข้อมูลยังคงอยู่หลังอัพเดต
   ```

5. **บันทึก App Signing (Google Play Console)**
   - เมื่อสร้างแอปใน Play Console เลือก:
     - ✅ "App Signing by Google Play" (แนะนำ) — Google จัดการ keystore
     - หรือ Upload keystore เอง

---

### 🔧 ขั้นตอนสร้าง Release APK / AAB

#### Build APK (สำหรับทดสอบเอง หรือ sideload)
```bash
flutter build apk --release
# ไฟล์: build/app/outputs/flutter-apk/app-release.apk
```

#### Build AAB (สำหรับ Play Store - แนะนำ)
```bash
flutter build appbundle --release
# ไฟล์: build/app/outputs/bundle/release/app-release.aab
```

---

## 📋 Checklist ก่อน Submit Play Store

- [ ] ตั้ง Application ID ให้คงที่ (`com.example.loscheck` หรือชื่อจริง)
- [ ] เพิ่มข้อมูล Privacy Policy (บังคับ)
- [ ] บันทึก Signing Key อย่างปลอดภัย
- [ ] ทดสอบ upgrade path บน emulator/device
- [ ] ตรวจสอบข้อมูลไม่หาย + error messages แสดงได้
- [ ] เพิ่ม App Icons และ Screenshots
- [ ] ตั้ง Target API Level เป็นค่าล่าสุด (34+)
- [ ] ทดสอบบน Android 8+ (minSdk 21)

---

## 🔄 วิธี Migrate Data จาก localhost → Vercel (Web)

### ถ้าใช้เว็บ + Deploy ไป Vercel

#### Step 1: Export จาก localhost
```javascript
// รันใน Browser Console ที่ localhost:xxxx (DevTools → Console)
(async () => {
  const dbs = await indexedDB.databases();
  const exportObj = {};
  
  for (const entry of dbs) {
    const name = entry.name;
    exportObj[name] = {};
    const req = indexedDB.open(name);
    
    await new Promise((res, rej) => {
      req.onsuccess = async () => {
        const db = req.result;
        const tx = db.transaction(db.objectStoreNames, 'readonly');
        
        for (const storeName of db.objectStoreNames) {
          exportObj[name][storeName] = [];
          const store = tx.objectStore(storeName);
          const getAllReq = store.getAll();
          
          await new Promise((r2) => {
            getAllReq.onsuccess = () => {
              exportObj[name][storeName] = getAllReq.result;
              r2();
            };
          });
        }
        
        db.close();
        res();
      };
      req.onerror = () => rej(req.error);
    });
  }
  
  // Download as JSON
  const blob = new Blob([JSON.stringify(exportObj)], {type: 'application/json'});
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'indexeddb-export.json';
  a.click();
  console.log('Export complete!');
})();
```

#### Step 2: Import ไป Vercel
- เปิด Vercel URL (`https://los-check.vercel.app`)
- รันคำสั่ง import ใน Console

---

## 💡 Tips หลัง Release

1. **Backup ก่อนทำอะไร**: หลังจาก release ให้ train users ใช้ Settings → Export ทุกสัปดาห์
2. **Monitor errors**: ดูว่าผู้ใช้เจอ error อะไรบ้างจาก Crash Analytics
3. **Plan future versions**: ทดสอบ upgrade path ก่อนทุกครั้ง
4. **Schema changes**: ต้องเขียน migration ใน `onUpgrade` ก่อน release

---

## 📚 อ่านเพิ่มเติม

- [Drift Documentation](https://drift.simonbinder.eu/)
- [Flutter Release Guide](https://flutter.dev/to/review-gradle-config)
- [Google Play Console Setup](https://play.google.com/console)
