# صراحة — إعداد API الاختباري وبناء Android

هذا المشروع يتضمن عميل Flutter أصليًا وواجهة PHP JSON تحت `deployment/api/v1/`. الواجهة ليست بديلًا مستقلًا لسكربت الموقع: تعتمد على `inc.php` وجداول الموقع ودواله. لا تتصل بقاعدة البيانات مباشرة من التطبيق. أبقِ ملفات موقع PHP وملف الإعداد وقاعدة البيانات الاختبارية خارج هذا المستودع.

> لا ترفع أي ملف إلى Hostinger، ولا تستخدم بيانات اعتماد الموقع أو قاعدة بيانات الإنتاج. أول طلب إلى API يحمّل `inc.php`، والذي يشغّل ترقية مخطط الموقع v12 عند الحاجة. كل الخطوات أدناه موجّهة إلى نسخة محلية منفصلة وقاعدة اختبار فارغة.

## 1) المتطلبات

- PHP **8.3** مع `pdo_mysql`, `mbstring` و`session` مفعّلة.
- MySQL أو MariaDB محلي منفصل. لا تمنح مستخدم الاختبار صلاحية على قاعدة الإنتاج.
- Flutter **3.32 أو أحدث** (Dart 3.8 أو أحدث)، Android SDK، وJava/JDK **17**.
- Android Emulator أو جهاز Android للاختبار. `10.0.2.2` هو عنوان الجهاز الافتراضي للوصول إلى خدمة الحاسوب المضيف من Android Emulator.

تحقق من نسخ PHP وإضافاته بـ `php -v` و`php -m`، ومن بيئة Android بـ `flutter doctor -v`. لم تُشغّل هذه الأدوات داخل بيئة إنشاء المشروع.

## 2) تجهيز بيئة البناء الخارجية (Flutter وJava وAndroid SDK)

1. ثبّت Git من [git-scm.com](https://git-scm.com/downloads).
2. ثبّت JDK 17. يمكن تنزيل Temurin 17 من [Adoptium](https://adoptium.net/temurin/releases/?version=17)، أو استخدام JDK 17 المرفق مع Android Studio إن كان مثبتًا. بعد التثبيت، تحقق بـ `java -version` وتأكد أن الإصدار 17. إذا اختار Flutter Java أخرى، حدّد مسار JDK 17 مرة واحدة عبر `flutter config --jdk-dir="/مسار/jdk-17"`، ثم افحص `flutter doctor -v`.
3. ثبّت Flutter SDK Stable باتباع الدليل الرسمي لنظامك: [Install Flutter](https://docs.flutter.dev/get-started/install). فكّ SDK في مجلد تملكه، وأضف مجلد `flutter/bin` إلى PATH، ثم افتح طرفية جديدة وتحقق بـ `flutter --version` و`dart --version`.
   - Windows: أضف المسار مثل `C:\src\flutter\bin` إلى متغير PATH من إعدادات النظام.
   - macOS/Linux: أضف `export PATH="$HOME/develop/flutter/bin:$PATH"` إلى ملف إعداد الطرفية (عدّل المسار حسب موقع SDK)، ثم أعد فتح الطرفية أو حمّل إعدادها.
4. نزّل Android Studio من [الموقع الرسمي](https://developer.android.com/studio/install) وشغّل Setup Wizard. من **SDK Manager** ثبّت Android SDK Platform التي يطلبها Flutter، و**Android SDK Platform-Tools**، و**Android SDK Command-line Tools (latest)**. ثبّت Android Emulator وصورة جهاز افتراضي إذا أردت الاختبار بالمحاكي. اترك إعداد SDK في المسار الافتراضي الذي يحدده Android Studio، أو استخدم المسار الذي يعرضه `flutter doctor -v`.
5. من الطرفية نفّذ `flutter doctor --android-licenses` واقبل التراخيص بعد مراجعتها، ثم نفّذ `flutter doctor -v`. عالج كل بند Android أحمر قبل متابعة البناء.
6. شغّل Android Studio/المحاكي أو صِل جهازًا فعليًا مع تفعيل USB debugging. عند بناء التطبيق على محاكي Android، عنوان الحاسوب المضيف هو `10.0.2.2`؛ أما الجهاز الفعلي فيستخدم IP الحاسوب على شبكة الاختبار.

## 3) أنشئ نسخة PHP وقاعدة اختبار محليتين

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

## 4) عنوان API واحد وآمن افتراضيًا

الإعداد الوحيد للعميل موجود في `mobile/lib/src/api_config.dart` باسم `API_BASE_URL`. الافتراضي هو خادم الاختبار المحلي `http://10.0.2.2:8080/api/v1/`، وليس عنوان الموقع الحي. تُرسل الطلبات إلى `index.php?r=...`؛ لذلك لا يحتاج عميل Android إلى `mod_rewrite`.

لتشغيل المحاكي على الإعداد المحلي:

```sh
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1/
```

إذا كان اختبارك على جهاز حقيقي، استبدل العنوان بعنوان IP للحاسوب على شبكة الاختبار. ولخادم اختبار منفصل استخدم عنوان HTTPS الخاص به في `--dart-define`. لا تضع عنوان الإنتاج أو أي سر في المصدر. السماح باتصالات HTTP موجود في Manifest نسخة **debug فقط**؛ Manifest إصدار release يرفض HTTP.

## 5) فحوصات التطبيق وبناء Android

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

## 6) الاختبار السلوكي المتوقع

على بيئة الاختبار وحدها:

1. افتح التطبيق وتأكد أن صفحة الدخول تظهر دون اتصال بالموقع الحي.
2. أنشئ حساب اختبار إذا كان `allow_register` مفعّلًا في قاعدة الاختبار، وإلا سجّل بحساب الاختبار الذي أنشأته محليًا.
3. أرسل رسالة اصطناعية إلى اسم المستخدم التجريبي، ثم اختبر ظهورها، الفلترة، المفضلة، الإجابة، الإبلاغ والحذف.
4. سجّل الخروج وأعد فتح التطبيق؛ يجب ألا تبقى جلسة PHP المحلية بعد حذفها من التخزين الآمن.
5. إذا أوقفت PHP، يجب أن يعرض التطبيق خطأ اتصال مع خيار إعادة المحاولة.

يستخدم API جلسة PHP وCSRF، ويخزن معرّف الجلسة في `flutter_secure_storage`. الواجهة الحالية لا تسجل الصوت أو ترفع الصور أو تنفذ تسجيل الدخول الاجتماعي أو إشعارات FCM؛ لا تدّعي هذه الوظائف أنها تعمل.

## 7) بناء APK تلقائيًا وتنزيله دون Android Studio

أُضيف سير عمل GitHub Actions في `.github/workflows/android-apk.yml`. يجهز Ubuntu وJDK 17 وFlutter Stable وAndroid SDK، ثم يشغّل `flutter pub get`, `flutter analyze`, `flutter test`, ويبني APK، ويثبته ويشغله على محاكي Android آليًا. لا يحتاج جهازك إلى Android Studio أو SDK.

1. اربط المشروع بمستودع GitHub من **Settings → GitHub** في v0، وادفع هذا الفرع إلى المستودع. صلاحية الوصول إلى مستودع GitHub غير متاحة من بيئة البناء هذه؛ لذلك لم أستطع تشغيل workflow عنك.
2. عند وصول التغييرات إلى GitHub يبدأ البناء آليًا؛ أو افتح **Actions → Build Android APK → Run workflow** لإدخال عنوان API تجريبي. الافتراضي `https://test.example.invalid/api/v1/` عنوان وهمي يمنع الاتصال بموقع صراحة ولا يمثل Backend عامل. يقبل الـworkflow خادم HTTPS تجريبي خارجي فقط، ويرفض نطاق `sarehny.com` والعناوين المحلية.
3. بعد نجاح الفحوصات والبناء واختبار التشغيل على المحاكي، نزّل ملف `sarehny-android-debug-<رقم التشغيل>` من قسم **Artifacts** في صفحة تشغيل Workflow. الـArtifact متاح 14 يومًا. هذا APK debug قابل للتثبيت، وليس نسخة إنتاج موقعة.

**حدود ما يثبته الـworkflow:** نجاح البناء واختبار ظهور عملية التطبيق على محاكي نظيف لا يثبت اتصال API أو قاعدة بيانات. عنوان `.invalid` الافتراضي لا يتصل بخادم؛ استخدم عنوانًا منفصلًا لبيئة اختبار تملكها. لم يُنشر API إلى Hostinger ولم تُختبر قاعدة بيانات الموقع. قبل ربط Backend الحقيقي، يلزم نشر نسخة API معزولة وربطها بقاعدة تجريبية ومراجعة مصادقة الجلسات وCSRF والتوافق معها. لا تدخل أسرارًا أو مفاتيح داخل عنوان URL.

## 8) تنزيل المشروع كاملًا أو ZIP

- لتنزيل المصدر مع المجلدات والمسارات من v0، استخدم قائمة النقاط الثلاث أعلى المشروع واختر **Download ZIP**. يشمل المشروع ملف CI. لفتح Flutter، فك الضغط وافتح مجلد `mobile/` في الطرفية أو Android Studio.
- أو استخدم GitHub المتصل مع المشروع، واستنسخ الفرع الذي يحتوي التغييرات.
- يحجب `.gitignore` ملفات الإعداد ومخرجات Flutter/Gradle ومفاتيح Android وقواعد البيانات المحلية. لا تُدرج `local.properties`, `config.php`, قواعد بيانات أو dumps، ملفات `.env`, مفاتيح توقيع، `google-services.json` أو بيانات مستخدمين في ZIP/Git. `pubspec.lock` غير مولّد هنا؛ يولّده `flutter pub get` في CI قبل التحليل والبناء.

## حالة التحقق في بيئة الإنشاء

تمت مراجعة ملفات Flutter وPHP المتاحة ومقارنة أسماء حقول/مسارات API مع سكربت PHP المرفق. أُصلح عنوان الاختبار الافتراضي، تحقق CSRF لطلبات POST، حقول الملف العام الناقصة، وإنشاء Android Gradle scaffold وWrapper. أُضيف workflow خارجي يشغّل التحليل والاختبارات والبناء واختبار تثبيت/بدء التطبيق على محاكي GitHub Actions. **لم يُشغّل** `php -l`, `flutter analyze`, `flutter test`, Gradle أو محاكي Android في بيئة v0 لعدم توفر PHP وFlutter/Dart وJava/Android SDK. لم أشغّل workflow على GitHub لأن هذا المشروع غير موصول بمستودع GitHub في السياق الحالي ولا تتوفر صلاحيات GitHub هنا. لا توجد نتيجة اتصال مؤكدة بقاعدة أو خادم، ولم يحدث أي نشر أو تعديل على Hostinger أو قاعدة بيانات حقيقية.
