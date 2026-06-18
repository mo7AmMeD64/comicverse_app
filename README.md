# Comicverse App

تطبيق Flutter لقراءة كوميكس موقع [Comicverse](https://arcomixverse.blogspot.com)، يسحب بياناته مباشرة من واجهة Blogger JSON Feed الرسمية (بدون تحليل HTML).

## كيف يعمل التطبيق (نظرة سريعة)

الموقع مبني على Blogger، وكل "عمل" (مثل INVINCIBLE) وكل "عدد" تابع له يشتركون في نفس **الوسم (label)** الذي هو اسم العمل بالضبط. هذا يجعل جلب البيانات بسيطًا جدًا عبر:

- `GET /feeds/posts/default?alt=json&max-results=150` → كل المنشورات (لشاشة البحث)
- `GET /feeds/posts/summary/-/{اسم التصنيف}?alt=json` → كل منشورات تصنيف معيّن (ناشر مثل MARVEL، أو اسم عمل لجلب أعداده)
- صور القراءة تُستخرج من حقل `content.$t` لمنشور العدد، بالبحث عن كل `<img src="...">` بالترتيب.

كل هذا منطق موجود في:
- `lib/services/comic_service.dart` — الاتصال بـ API
- `lib/models/comic_post.dart` — تحويل JSON إلى نموذج Dart

## الرفع على GitHub والبناء التلقائي (الطريقة الموصى بها)

المشروع جاهز كما هو للرفع المباشر، **بدون أي خطوة تحضير على Termux**. مجلد `android/` غير موجود الآن عمدًا؛ سير العمل `.github/workflows/build.yml` يولّده تلقائيًا على خوادم GitHub عبر `flutter create .` قبل البناء (لتفادي مشاكل توافق ملفات Gradle الثنائية بين البيئات).

```bash
cd comicverse_app
git init
git add .
git commit -m "init comicverse app"
git branch -M main
git remote add origin https://github.com/mo7AmMeD64/comicverse_app.git
git push -u origin main
```

بعد الـ push:
1. اذهب لتبويب **Actions** في المستودع، وتابع تشغيل "Build APK & Release".
2. بعد اكتماله (عادة 3-6 دقائق)، اذهب لتبويب **Releases** في المستودع الرئيسي — ستجد إصدارًا جديدًا (مثل `v1.0.1`) يحوي ملف APK جاهز للتنزيل والتثبيت مباشرة.
3. كل `push` جديد إلى `main` ينشئ Release جديد تلقائيًا برقم تسلسلي تالٍ.

## البناء محليًا على Termux (اختياري)

إن أردت تجربته محليًا قبل الرفع:

```bash
cd comicverse_app
flutter create . --platforms=android --org com.mo7ammed64 --project-name comicverse_app

# أضف صلاحية الإنترنت في android/app/src/main/AndroidManifest.xml
# داخل عنصر <manifest> مباشرة (قبل <application>):
#   <uses-permission android:name="android.permission.INTERNET" />

flutter pub get
flutter build apk --release
```

الملف الناتج: `build/app/outputs/flutter-apk/app-release.apk`

⚠️ إن جرّبت هذا محليًا، **لا ترفع مجلد android/ الناتج لاحقًا** إلى GitHub (هو مُستثنى أصلًا في `.gitignore`)، حتى يبقى الـ workflow هو المصدر الوحيد المعتمد لتوليده بشكل متطابق مع بيئة CI.

## بنية المجلدات

```
lib/
  models/comic_post.dart        نموذج بيانات المنشور (عمل أو عدد)
  services/comic_service.dart   الاتصال بـ Blogger JSON Feed
  services/favorites_service.dart  حفظ المفضلة وتقدم القراءة محليًا
  screens/home_screen.dart      الرئيسية (أقسام MARVEL/DC/IMAGE)
  screens/category_screen.dart  شبكة كل أعمال تصنيف معيّن
  screens/search_screen.dart    البحث بالاسم
  screens/comic_detail_screen.dart  تفاصيل العمل + قائمة الأعداد
  screens/issue_reader_screen.dart  قارئ صور العدد + تنقل بين الأعداد
  screens/favorites_screen.dart     المفضلة
  widgets/                      بطاقات وعناصر واجهة قابلة لإعادة الاستخدام
  theme.dart                    الألوان والتصميم العام
  main.dart                     نقطة الدخول
.github/workflows/build.yml     بناء APK وإصدار Release تلقائي
```

## ملاحظات مهمة

- لتغيير الموقع المصدر مستقبلاً، يكفي تعديل `baseUrl` في `comic_service.dart`، بشرط أن يكون الموقع الجديد مبنيًا على Blogger بنفس نظام الوسوم (عمل ↔ أعداد بنفس label).
- شاشة المفضلة وتقدم القراءة تُخزَّن محليًا فقط (`shared_preferences`)، لا حساب مستخدم أو مزامنة سحابية.
- التوقيع الحالي للـ APK هو توقيع debug المؤقت الخاص بـ Flutter (كافٍ للتثبيت والاستخدام الشخصي). لتوقيع رسمي بمفتاحك الخاص لاحقًا (مطلوب فقط لو نويت نشره على متجر)، يلزم إنشاء keystore وتعديل خطوة البناء في `build.yml`.
- **البحث**: يستخدم بحث Blogger الرسمي على الخادم (`?q=`) بدل تحميل كل منشورات الموقع محليًا، لأن الموقع قد يحوي آلاف المنشورات (كل عدد منشور مستقل) يتجاوز حد الجلب الأقصى لـ Blogger (500 منشور/طلب).
- **صور القراءة**: الموقع يحمّل صور صفحات الفصل عبر نظام Lazy-load حيث يكون الرابط الحقيقي في خاصية `data-src` بدل `src` المباشر. `extractAllImages()` في `comic_post.dart` يتحقق من `data-src` أولاً ثم `src` كحل بديل.
- **الخط**: يستخدم التطبيق خط Cairo عبر حزمة `google_fonts` (يُجلب ويُخزَّن تلقائيًا، لا حاجة لإضافة ملفات خط يدويًا في `pubspec.yaml`).
