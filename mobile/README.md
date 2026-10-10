ابدأ من [SETUP.md](SETUP.md): يشرح إعداد PHP 8.3 وقاعدة اختبار محلية، تشغيل API، إعداد عنوان API، بناء Android والتصدير بأمان.

عنوان API الافتراضي فارغ في `lib/src/api_config.dart`، ويُحدد وقت البناء عبر `API_BASE_URL`. يبني GitHub Actions نسخة الإنتاج بعنوان `https://sarehny.com/api/v1/`؛ يتطلب ذلك وجود واجهة PHP منشورة على Hostinger في هذا المسار. ملف الواجهة في هذا المستودع (`../deployment/api/v1/`) لا يُرفع تلقائيًا، ولا يغيّر Workflow ملفات Hostinger أو قاعدة البيانات.
