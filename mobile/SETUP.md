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

## 4) عنوان API وإعدادات التطوير والإنتاج

الإعداد في `mobile/lib/src/api_config.dart` هو `API_BASE_URL`، وقيمته الافتراضية تبقى فارغة عمدًا. دون إعداد صريح، يرفض العميل الطلب قبل استخدام Dio. يرسل العميل الطلبات إلى `index.php?r=...`؛ يحدد مسار المجلد المنشور مكان `index.php`، وتسمح قواعد `.htaccess` داخل مجلد API بتوجيه المسارات البديلة.

Workflow الإنتاج يمرر `https://sarehny.com/api/v1/` إلى **خطوة بناء APK فقط** عبر `--dart-define`. لا يمرر العنوان إلى `flutter analyze` أو `flutter test`، لذلك لا تتصل اختبارات CI بخادم الإنتاج. هذا إعداد بناء وليس اختبارًا لتوفر الخادم أو نجاح تسجيل الدخول والرسائل. للتطوير المحلي، أبقِ الإعداد الافتراضي فارغًا ومرّر عنوان خادم التطوير الذي شغّلته فعلًا، مثل `--dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1/` للمحاكي. لا تستخدم عنوان الإنتاج في إعدادات التطوير. السماح باتصالات HTTP موجود في Manifest نسخة **debug فقط**؛ Manifest إصدار release يرفض HTTP.

## 5) فحوصات التطبيق وبناء Android

افتح الطرفية في مجلد `mobile/`:

```sh
flutter doctor -v
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

ملفات Android وGradle Wrapper مضمنة. Gradle يستخدم JDK 17 ونسخة wrapper 8.14.3 وAndroid Gradle Plugin 8.11.1. لم يتوفر Flutter/Dart عند إعداد الحزمة، لذلك لا يوجد `pubspec.lock` مولّد بعد؛ ينشئه `flutter pub get`، وبعد مراجعته احتفظ به في Git لتثبيت نسخ الاعتماديات. إذا لم ينشئ Flutter `mobile/android/local.properties`، أضف إليه محليًا المسار الذي يعرضه `flutter doctor -v`:

```properties
flutter.sdk=/المسار/إلى/flutter
```

هذا الملف مستثنى من Git لأنه يختلف بين الأجهزة. ملف APK التجريبي يظهر في `mobile/build/app/outputs/flutter-apk/app-debug.apk`.

بناء APK محلي دون تمرير `API_BASE_URL` ينتج تطبيقًا لا يرسل طلبات API. Workflow في GitHub مخصص لبناء APK debug مضبوط على عنوان الإنتاج المحدد؛ تشغيل التحليل والاختبارات يظل دون إعداد API. قبل توزيع إصدار فعلي، أعدّ توقيع Android بمفتاح تملكه في بيئتك الخارجية. لا تُضمّن keystore أو كلمات مروره في ZIP/Git؛ إعداد التوقيع غير مهيأ عمدًا هنا.

## 6) الاختبار السلوكي المتوقع

في APK الاختبار الذي لا يتضمن عنوان API، تظهر رسالة بأن الخادم غير مهيأ ولا تُرسل أي طلبات؛ لذلك لا تتوفر وظائف الحساب والرسائل في هذا الوضع. الخطوات التالية لا تنطبق إلا بعد تجهيز API وقاعدة اختبار حقيقيين وتمرير عنوان API الاختباري صراحةً:

1. أنشئ حساب اختبار إذا كان `allow_register` مفعّلًا في قاعدة الاختبار، وإلا سجّل بحساب اختبار أنشأته محليًا.
2. أرسل رسالة اصطناعية إلى اسم المستخدم التجريبي، ثم اختبر ظهورها، والفلترة، والمفضلة، والإجابة، والإبلاغ والحذف.
3. سجّل الخروج وأعد فتح التطبيق؛ يجب ألا تبقى جلسة PHP المحلية بعد حذفها من التخزين الآمن.
4. إذا أوقفت PHP، يجب أن يعرض التطبيق خطأ اتصال مع خيار إعادة المحاولة.

يستخدم API جلسة PHP وCSRF، ويخزن معرّف الجلسة في `flutter_secure_storage`. الواجهة الحالية لا تسجل الصوت أو ترفع الصور أو تنفذ تسجيل الدخول الاجتماعي أو إشعارات FCM؛ لا تدّعي هذه الوظائف أنها تعمل.

## 7) بناء APK تلقائيًا وتنزيله دون Android Studio

سير GitHub Actions في `.github/workflows/android-apk.yml` يجهز Ubuntu وJDK 17 وFlutter Stable، ثم يشغّل `flutter pub get`, `flutter analyze`, `flutter test` دون إعداد API، ويبني APK debug مع `API_BASE_URL=https://sarehny.com/api/v1/` ويرفعه كـArtifact. يبدأ تلقائيًا عند دفع تغييرات ضمن `mobile/` أو ملف Workflow، ويمكن تشغيله من **Actions → Build Android APK (production API configured) → Run workflow**. نزّل `sarehny-android-production-api-debug-<رقم التشغيل>` من **Artifacts**؛ يبقى 14 يومًا. APK مضبوط على هذا المسار لكنه debug وغير موقّع كإصدار release. يجب أن تكون ملفات PHP من `deployment/api/v1/` منشورة يدويًا من مالك الاستضافة في المسار المقابل؛ الـWorkflow لا يرفع ملفات Hostinger ولا يغيّر قاعدة البيانات.

**حدود التحقق:** نجاح التحليل والاختبارات والبناء يثبت سلامة الكود وإعداد عنوان API وقت البناء فقط. اختبارات CI تعمل دون عنوان API ولا تتصل بالموقع. لا يثبت ذلك أن endpoint متاح أو أن تسجيل الدخول وجلب الرسائل وإرسالها يعمل؛ يلزم اختبار اتصال واستجابات حقيقية منفصل قبل إعلان نجاح الربط.

## 8) تنزيل المشروع كاملًا أو ZIP

- لتنزيل المصدر مع المجلدات والمسارات من v0، استخدم قائمة النقاط الثلاث أعلى المشروع واختر **Download ZIP**. يشمل المشروع ملف CI. لفتح Flutter، فك الضغط وافتح مجلد `mobile/` في الطرفية أو Android Studio.
- أو استخدم GitHub المتصل مع المشروع، واستنسخ الفرع الذي يحتوي التغييرات.
- يحجب `.gitignore` ملفات الإعداد ومخرجات Flutter/Gradle ومفاتيح Android وقواعد البيانات المحلية. لا تُدرج `local.properties`, `config.php`, قواعد بيانات أو dumps، ملفات `.env`, مفاتيح توقيع، `google-services.json` أو بيانات مستخدمين في ZIP/Git. `pubspec.lock` غير مولّد هنا؛ يولّده `flutter pub get` في CI قبل التحليل والبناء.

## حالة التحقق في بيئة الإنشاء

يفحص التطبيق `GET index.php?r=session` عند البدء، ويستخدم `POST index.php?r=auth/login` مع حقلي `identifier` و`password` ورمز CSRF، ثم `GET index.php?r=inbox` مع مرشحات وترقيم صفحات. فحص القراءة الحي الأخير إلى `https://sarehny.com/api/v1/index.php?r=session` أعاد `200` و`user: null`، بينما أعاد `GET ...?r=app-theme` الحالة `404` مع `code: not_found`. هذا يؤكد أن عنوان الجلسة متاح، لكنه يثبت أيضًا أن واجهة API المنشورة لا تتضمن مسار المظهر الحالي؛ لم تُختبر مصادقة مستخدم أو عمليات كتابة على الإنتاج.

أضافت نسخة المستودع ترقيمًا بالمؤشر للرسائل القديمة، وبيانات دور المدير اللازمة لعرض مدخل الإدارة فقط للمشرف، ومسارات تحديث الحساب وحذفه المؤمّنة بـCSRF وكلمة المرور. هذه التغييرات محلية ولم تُنشر إلى Hostinger. بعد مراجعة نسخة احتياطية، ارفع `deployment/api/v1/index.php` و`deployment/api/v1/.htaccess` فقط إلى `/api/v1/` في بيئة اختبار منفصلة، ثم تحقق من `/session` و`/app-theme` وقراءة الصفحات القديمة قبل أي اختبار كتابة. أرشيف التسليم المطابق هو `deployment/hostinger-api-v1.zip`؛ لا يغيّر هذا المشروع ملفات Hostinger أو قاعدة البيانات ولا ينفذ رفعًا تلقائيًا.

لم تتوفر أوامر `php` أو `flutter` أو `dart` في بيئة الإنشاء، لذلك لم يمكن تشغيل فحص PHP أو `flutter analyze` أو الاختبارات أو بناء APK. كما لم تُختبر شاشة Flutter على جهاز Android أو بحساب/بيانات رسائل قديمة. يلزم تشغيل هذه الفحوص في بيئة Flutter، ثم إجراء اختبار سلوكي على قاعدة اختبار آمنة قبل اعتبار العمل منشورًا أو مكتملًا.
