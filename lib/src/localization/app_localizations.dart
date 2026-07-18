import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
    Locale('de'),
    Locale('fr'),
    Locale('es'),
    Locale('ar'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  String get languageName => switch (locale.languageCode) {
        'tr' => 'Türkçe',
        'de' => 'Deutsch',
        'fr' => 'Français',
        'es' => 'Español',
        'ar' => 'العربية',
        _ => 'English',
      };

  String t(String key) => (_values[locale.languageCode] ?? _values['en']!)[key] ??
      _values['en']![key] ??
      key;

  static const Map<String, Map<String, String>> _values = {
    'en': {
      'tagline': 'End indecision. Get on with your life.',
      'today': 'What should I eat today?',
      'heroSubtitle': 'One confident, personalized decision in seconds.',
      'goalTitle': 'How do you want to feel?',
      'budget': 'Budget',
      'meal': 'Meal',
      'decide': 'Let Decidoo decide',
      'again': 'Make another decision',
      'decision': 'Decide',
      'explore': 'Explore',
      'history': 'History',
      'popular': 'Popular choices from around the world',
      'emptyHistory': 'Your first decision will appear here.',
      'match': 'match',
      'minutes': 'min',
      'language': 'Language',
      'settings': 'Settings',
      'surprise': 'Surprise me',
      'light': 'Light',
      'filling': 'Filling',
      'healthy': 'Healthy',
      'comfort': 'Comfort',
      'budgetLow': 'Budget',
      'standard': 'Standard',
      'premium': 'Premium',
      'breakfast': 'Breakfast',
      'lunch': 'Lunch',
      'dinner': 'Dinner',
      'lateNight': 'Late night',
    },
    'tr': {
      'tagline': 'Kararsızlığı kapat. Hayatına devam et.',
      'today': 'Bugün ne yesem?',
      'heroSubtitle': 'Birkaç saniyede sana özel tek bir güçlü karar.',
      'goalTitle': 'Nasıl hissetmek istiyorsun?',
      'budget': 'Bütçe',
      'meal': 'Öğün',
      'decide': 'Decidoo karar versin',
      'again': 'Başka bir karar',
      'decision': 'Karar',
      'explore': 'Keşfet',
      'history': 'Geçmiş',
      'popular': 'Dünyadan popüler seçimler',
      'emptyHistory': 'İlk kararın burada görünecek.',
      'match': 'eşleşme',
      'minutes': 'dk',
      'language': 'Dil',
      'settings': 'Ayarlar',
      'surprise': 'Şaşırt beni',
      'light': 'Hafif',
      'filling': 'Doyurucu',
      'healthy': 'Sağlıklı',
      'comfort': 'Keyif',
      'budgetLow': 'Ekonomik',
      'standard': 'Standart',
      'premium': 'Premium',
      'breakfast': 'Kahvaltı',
      'lunch': 'Öğle',
      'dinner': 'Akşam',
      'lateNight': 'Gece',
    },
    'de': {
      'tagline': 'Beende die Unentschlossenheit. Mach weiter.',
      'today': 'Was soll ich heute essen?',
      'heroSubtitle': 'Eine starke, persönliche Entscheidung in Sekunden.',
      'goalTitle': 'Wie möchtest du dich fühlen?',
      'budget': 'Budget',
      'meal': 'Mahlzeit',
      'decide': 'Decidoo entscheiden lassen',
      'again': 'Andere Entscheidung',
      'decision': 'Entscheiden',
      'explore': 'Entdecken',
      'history': 'Verlauf',
      'popular': 'Beliebte Gerichte aus aller Welt',
      'emptyHistory': 'Deine erste Entscheidung erscheint hier.',
      'match': 'Übereinstimmung',
      'minutes': 'Min.',
      'language': 'Sprache',
      'settings': 'Einstellungen',
      'surprise': 'Überrasche mich',
      'light': 'Leicht',
      'filling': 'Sättigend',
      'healthy': 'Gesund',
      'comfort': 'Wohlfühlen',
      'budgetLow': 'Günstig',
      'standard': 'Standard',
      'premium': 'Premium',
      'breakfast': 'Frühstück',
      'lunch': 'Mittagessen',
      'dinner': 'Abendessen',
      'lateNight': 'Spätabend',
    },
    'fr': {
      'tagline': "Terminez l'indécision. Continuez votre journée.",
      'today': "Qu'est-ce que je mange aujourd'hui ?",
      'heroSubtitle': 'Une décision personnalisée et sûre en quelques secondes.',
      'goalTitle': 'Comment voulez-vous vous sentir ?',
      'budget': 'Budget',
      'meal': 'Repas',
      'decide': 'Laisser Decidoo décider',
      'again': 'Une autre décision',
      'decision': 'Décider',
      'explore': 'Explorer',
      'history': 'Historique',
      'popular': 'Choix populaires du monde entier',
      'emptyHistory': 'Votre première décision apparaîtra ici.',
      'match': 'correspondance',
      'minutes': 'min',
      'language': 'Langue',
      'settings': 'Paramètres',
      'surprise': 'Surprends-moi',
      'light': 'Léger',
      'filling': 'Copieux',
      'healthy': 'Sain',
      'comfort': 'Réconfort',
      'budgetLow': 'Économique',
      'standard': 'Standard',
      'premium': 'Premium',
      'breakfast': 'Petit-déjeuner',
      'lunch': 'Déjeuner',
      'dinner': 'Dîner',
      'lateNight': 'Tard le soir',
    },
    'es': {
      'tagline': 'Termina con la indecisión. Sigue con tu vida.',
      'today': '¿Qué debería comer hoy?',
      'heroSubtitle': 'Una decisión personalizada y segura en segundos.',
      'goalTitle': '¿Cómo quieres sentirte?',
      'budget': 'Presupuesto',
      'meal': 'Comida',
      'decide': 'Dejar que Decidoo decida',
      'again': 'Otra decisión',
      'decision': 'Decidir',
      'explore': 'Explorar',
      'history': 'Historial',
      'popular': 'Opciones populares de todo el mundo',
      'emptyHistory': 'Tu primera decisión aparecerá aquí.',
      'match': 'coincidencia',
      'minutes': 'min',
      'language': 'Idioma',
      'settings': 'Ajustes',
      'surprise': 'Sorpréndeme',
      'light': 'Ligero',
      'filling': 'Contundente',
      'healthy': 'Saludable',
      'comfort': 'Reconfortante',
      'budgetLow': 'Económico',
      'standard': 'Estándar',
      'premium': 'Premium',
      'breakfast': 'Desayuno',
      'lunch': 'Almuerzo',
      'dinner': 'Cena',
      'lateNight': 'Madrugada',
    },
    'ar': {
      'tagline': 'أنهِ الحيرة وواصل يومك.',
      'today': 'ماذا آكل اليوم؟',
      'heroSubtitle': 'قرار شخصي وواثق خلال ثوانٍ.',
      'goalTitle': 'كيف تريد أن تشعر؟',
      'budget': 'الميزانية',
      'meal': 'الوجبة',
      'decide': 'دع Decidoo يقرر',
      'again': 'قرار آخر',
      'decision': 'قرار',
      'explore': 'استكشاف',
      'history': 'السجل',
      'popular': 'خيارات شائعة من حول العالم',
      'emptyHistory': 'سيظهر قرارك الأول هنا.',
      'match': 'تطابق',
      'minutes': 'د',
      'language': 'اللغة',
      'settings': 'الإعدادات',
      'surprise': 'فاجئني',
      'light': 'خفيف',
      'filling': 'مشبع',
      'healthy': 'صحي',
      'comfort': 'مريح',
      'budgetLow': 'اقتصادي',
      'standard': 'عادي',
      'premium': 'فاخر',
      'breakfast': 'فطور',
      'lunch': 'غداء',
      'dinner': 'عشاء',
      'lateNight': 'وقت متأخر',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales
      .any((item) => item.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
