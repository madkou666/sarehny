import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api_client.dart';

class SiteBrowser {
  SiteBrowser._();

  static const _platform = MethodChannel('com.sarehny/platform');

  static Future<void> open(ApiClient api, String path, {Map<String, String>? queryParameters}) async {
    final result = await _platform.invokeMapMethod<String, Object?>(
      'openSite',
      {
        'url': api.sitePage(path, queryParameters: queryParameters).toString(),
        'origin': api.siteOrigin.toString(),
        'sessionCookie': await api.readPhpSessionCookie(),
      },
    );
    final updatedCookie = result?['sessionCookie'];
    if (updatedCookie is String) await api.savePhpSessionCookie(updatedCookie);
  }
}

class NativeImagePicker {
  NativeImagePicker._();

  static const _platform = MethodChannel('com.sarehny/platform');

  static Future<Map<String, Object?>?> pickImage() =>
      _platform.invokeMapMethod<String, Object?>('pickImage');
}

class SitePagePaths {
  SitePagePaths._();

  static const home = 'index.php';
  static const publicProfile = 'u.php';
  static const blog = 'blog.php';
  static const about = 'about.php';
  static const contact = 'contact.php';
  static const support = 'support.php';
  static const dashboard = 'dashboard.php';
  static const account = 'account.php';
  static const voice = 'voice.php';
  static const push = 'push.php';
  static const analysis = 'analysis.php';
  static const insights = 'insights.php';
  static const socialLab = 'social-lab.php';
  static const admin = 'admin.php';
}

class SiteDestination {
  const SiteDestination({
    required this.label,
    required this.path,
    required this.icon,
    required this.description,
  });

  final String label;
  final String path;
  final IconData icon;
  final String description;
}

const sitePublicDestinations = <SiteDestination>[
  SiteDestination(label: 'الصفحة الرئيسية', path: SitePagePaths.home, icon: Icons.home_outlined, description: 'محتوى الموقع الحالي'),
  SiteDestination(label: 'مدونة صراحة', path: SitePagePaths.blog, icon: Icons.article_outlined, description: 'المقالات المنشورة'),
  SiteDestination(label: 'من نحن', path: SitePagePaths.about, icon: Icons.info_outline_rounded, description: 'معلومات الخدمة والسياسات'),
  SiteDestination(label: 'اتصل بنا', path: SitePagePaths.contact, icon: Icons.mail_outline_rounded, description: 'أرسل استفسارًا للفريق'),
  SiteDestination(label: 'الدعم الفني', path: SitePagePaths.support, icon: Icons.support_agent_rounded, description: 'تواصل مع فريق الدعم'),
];

const siteAccountDestinations = <SiteDestination>[
  SiteDestination(label: 'لوحة الموقع', path: SitePagePaths.dashboard, icon: Icons.dashboard_outlined, description: 'الرسائل والميزات الأصلية'),
  SiteDestination(label: 'إعدادات الحساب', path: SitePagePaths.account, icon: Icons.manage_accounts_outlined, description: 'الملف والأمان وإدارة الحساب'),
  SiteDestination(label: 'الرسائل الصوتية', path: SitePagePaths.voice, icon: Icons.mic_none_rounded, description: 'أدوات الصوت الأصلية'),
  SiteDestination(label: 'الإشعارات', path: SitePagePaths.push, icon: Icons.notifications_none_rounded, description: 'إعدادات إشعارات الموقع'),
  SiteDestination(label: 'تحليل الشخصية', path: SitePagePaths.analysis, icon: Icons.auto_awesome_outlined, description: 'حسب إعدادات وموافقة الموقع'),
  SiteDestination(label: 'إحصاءات المرسل', path: SitePagePaths.insights, icon: Icons.query_stats_rounded, description: 'إذا كانت مفعلة لحسابك'),
  SiteDestination(label: 'المختبر الاجتماعي', path: SitePagePaths.socialLab, icon: Icons.science_outlined, description: 'أدوات المختبر المتاحة على الموقع'),
];
