# صراحة — إعداد API الاختباري وبناء Android

هذا المشروع يتضمن عميل Flutter أصليًا وواجهة PHP JSON تحت `deployment/api/v1/`. الواجهة ليست بديلًا مستقلًا لسكربت الموقع: تعتمد على `inc.php` وجداول الموقع ودواله. لا تتصل بقاعدة البيانات مباشرة من التطبيق. أبقِ ملفات موقع PHP وملف الإعداد وقاعدة البيانات الاختبارية خارج هذا المستودع.

> لا ترفع أي ملف إلى Hostinger، ولا تستخدم بيانات اعتماد الموقع أو قاعدة بيانات الإنتاج. أول طلب إلى API يحمّل `inc.php`، والذي يشغّل ترقية مخطط الموقع v12 عند الحاجة. كل الخطوات أدناه موجّهة إلى نسخة محلية منفصلة وقاعدة اختبار فارغة.

## 1) المتطلبات

- PHP **8.3** مع `pdo_mysql`, `mbstring` و`session` مفعّلة.
- MySQL أو MariaDB محلي منفصل. لا تمنح مستخدم الاختبار صلاحية على قاعدة الإنتاج.
- Flutter **3.32 أو أحدث** (Dart 3.8 أو أحدث)، Android SDK، وJava/JDK **17**.
- Android Emulator أو جهاز Android للاختبار. `10.0.2.2` هو عنوان الجهاز الافتراضي للوصول إلى خدمة الحاسوب المضيف من Android Emulator.

تحقق من نسخ PHP وإضافاته بـ `php -v` و`php -m`، ومن بيئة Android بـ `flutter doctor -v`. لم تُشغّل هذه الأدوات داخل بيئة إنشاء المشروع.

## 2) أنشئ نسخة PHP وقاعدة اختبار محليتين

1. أنشئ مجلدًا جديدًا خارج المشروع مثل `/tmp/sarehny-test-site`، وانسخ إليه **ملفات سكربت PHP الأصلية** من أرشيف محلي تملكه. لا تنسخ `config.php` أو مجلدات الرفع/النسخ الاحتياطية من الموقع الحي، ولا تستخدم اتصال Hostinger. احتفظ بملفات PHP والمخطط `schema.sql` المتطابقة مع إصدار السكربت.
2. أنشئ قاعدة فارغة ومستخدمًا مخصصًا لها على MySQL المحلي. مثال SQL (استبدل كلمة المرور بقيمة محلية عشوائية، ولا تحفظها في Git):

   ```sql
   CREATE DATABASE sarehny_mobile_test
     CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   CREATE USER 'sarehny_mobile_test'@'localhost' IDENTIFIED BY 'ضع-كلمة-مرور-محلية-عشوائية';
   GRANT ALL PRIVILEGES ON sarehny_mobile_test.* TO 'sarehny_mobile_test'@'localhost';
   ```

3. شغّل النسخة المحلية على قاعدة الاختبار فقط، وافتح `install.php` محليًا إذا لم يوجد `config.php`. أدخل بيانات القاعدة المحلية وأنشئ حساب إدارة تجريبيًا اصطناعيًا. المثبّت ينشئ `config.php` محليًا؛ لا تنقله إلى هذا المشروع ولا ترفعه.
4. انسخ API إلى جذر النسخة المحلية مع الحفاظ على المسار:

   ```sh
   mkdir -p /tmp/sarehny-test-site/api
   cp -a /path/to/project/deployment/api/v1 /tmp/sarehny-test-site/api/v1
   ```

   استبدل `/path/to/project` بمكان فك ضغط هذا المشروع. تأكد أن الملف المحلي هو `/tmp/sarehny-test-site/api/v1/index.php` وأن `inc.php` الخاص بالنسخة المحلية في جذر `/tmp/sarehny-test-site/`.
5. شغّل خادم PHP من جذر نسخة الاختبار:

   ```sh
   php -S 0.0.0.0:8080 -t /tmp/sarehny-test-site
   ```

   خادم PHP المضمّن لا يقرأ `.htaccess`، لكن التطبيق يستخدم `index.php?r=...` ولذلك لا يحتاج إعادة كتابة العناوين. افحص بدء الجلسة محليًا:

   ```sh
   curl -i 'http://127.0.0.1:8080/api/v1/index.php?r=session'
   ```

   المتوقّع استجابة JSON بحالة `200` و`user: null` قبل تسجيل الدخول. إذا ظهر خطأ قاعدة بيانات/مخطط، أوقف الاختبار وافحص **قاعدة الاختبار** وصلاحياتها وسجلات PHP؛ لا تغيّر وجهة اتصال إلى قاعدة حقيقية.

لا تستورد نسخة بيانات من المستخدمين أو الرسائل. أنشئ حسابًا تجريبيًا ورسائل اصطناعية من التطبيق. لا تستخدم تحليل الشخصية أثناء هذا الاختبار؛ النقطة الأصلية قد تتصل بمزوّد AI وتستهلك حصة أو تكلفة أُعدّت في سكربت الموقع.

## 3) عنوان API واحد وآمن افتراضيًا

الإعداد الوحيد للعميل موجود في `mobile/lib/src/api_config.dart` باسم `API_BASE_URL`. الافتراضي هو خادم الاختبار المحلي `http://10.0.2.2:8080/api/v1/`، وليس عنوان الموقع الحي. تُرسل الطلبات إلى `index.php?r=...`؛ لذلك لا يحتاج عميل Android إلى `mod_rewrite`.

لتشغيل المحاكي على الإعداد المحلي:

```sh
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1/
```

إذا كان اختبارك على جهاز حقيقي، استبدل العنوان بعنوان IP للحاسوب على شبكة الاختبار. ولخادم اختبار منفصل استخدم عنوان HTTPS الخاص به في `--dart-define`. لا تضع عنوان الإنتاج أو أي سر في المصدر. السماح باتصالات HTTP موجود في Manifest نسخة **debug فقط**؛ Manifest إصدار release يرفض HTTP.

## 4) فحوصات التطبيق وبناء Android

افتح الطرفية في مجلد `mobile/`:

```sh
flutter doctor -v
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1/
```

ملفات Android وGradle Wrapper مضمنة. Gradle يستخدم JDK 17 ونسخة wrapper 8.14.3 وAndroid Gradle Plugin 8.11.1. لم يتوفر Flutter/Dart عند إعداد الحزمة، لذلك لا يوجد `pubspec.lock` مولّد بعد؛ ينشئه `flutter pub get`، وبعد مراجعته احتفظ به في Git لتثبيت نسخ الاعتماديات. إذا لم ينشئ Flutter `mobile/android/local.properties`، أضف إليه محليًا المسار الذي يعرضه `flutter doctor -v`:

```properties
flutter.sdk=/المسار/إلى/flutter
```

هذا الملف مستثنى من Git لأنه يختلف بين الأجهزة. ملف APK التجريبي يظهر في `mobile/build/app/outputs/flutter-apk/app-debug.apk`.

لبناء release إلى خادم اختبار HTTPS:

```sh
flutter build apk --release --dart-define=API_BASE_URL=https://test.example.invalid/api/v1/
flutter build appbundle --release --dart-define=API_BASE_URL=https://test.example.invalid/api/v1/
```

قبل توزيع إصدار فعلي، أعدّ توقيع Android بمفتاح تملكه في بيئتك الخارجية. لا تُضمّن keystore أو كلمات مروره في ZIP/Git؛ إعداد التوقيع غير مهيأ عمدًا هنا.

## 5) الاختبار السلوكي المتوقع

على بيئة الاختبار وحدها:

1. افتح التطبيق وتأكد أن صفحة الدخول تظهر دون اتصال بالموقع الحي.
2. أنشئ حساب اختبار إذا كان `allow_register` مفعّلًا في قاعدة الاختبار، وإلا سجّل بحساب الاختبار الذي أنشأته محليًا.
3. أرسل رسالة اصطناعية إلى اسم المستخدم التجريبي، ثم اختبر ظهورها، الفلترة، المفضلة، الإجابة، الإبلاغ والحذف.
4. سجّل الخروج وأعد فتح التطبيق؛ يجب ألا تبقى جلسة PHP المحلية بعد حذفها من التخزين الآمن.
5. إذا أوقفت PHP، يجب أن يعرض التطبيق خطأ اتصال مع خيار إعادة المحاولة.

يستخدم API جلسة PHP وCSRF، ويخزن معرّف الجلسة في `flutter_secure_storage`. الواجهة الحالية لا تسجل الصوت أو ترفع الصور أو تنفذ تسجيل الدخول الاجتماعي أو إشعارات FCM؛ لا تدّعي هذه الوظائف أنها تعمل.

## 6) التصدير إلى GitHub أو ZIP

صدّر المشروع كما هو، ثم ابنِه من `mobile/` في بيئة Flutter/Android خارجية. احتفظ بملفات `mobile/android/gradlew*` و`gradle-wrapper.jar` في التصدير. لا تضف `local.properties`, `config.php`, قواعد بيانات أو dumps، ملفات `.env`, مفاتيح توقيع، `google-services.json` أو بيانات مستخدمين. `.gitignore` يستثني الملفات المحلية ومخرجات Flutter/Gradle ومفاتيح Android.

## حالة التحقق في بيئة الإنشاء

تمت مراجعة ملفات Flutter وPHP المتاحة ومقارنة أسماء حقول/مسارات API مع سكربت PHP المرفق. أُصلح عنوان الاختبار الافتراضي، تحقق CSRF لطلبات POST، حقول الملف العام الناقصة، وإنشاء Android Gradle scaffold وWrapper. **لم يُشغّل** `php -l`, `flutter analyze`, `flutter test`, Gradle أو محاكي Android هنا لعدم توفر PHP وFlutter/Dart وJava/Android SDK في البيئة. لا توجد نتيجة اتصال مؤكدة بقاعدة أو خادم، ولم يحدث أي نشر أو تعديل على Hostinger أو قاعدة بيانات حقيقية.
