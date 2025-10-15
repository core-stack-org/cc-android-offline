// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get selectLocation => 'स्थान चुनें';

  @override
  String get selectState => 'राज्य चुनें';

  @override
  String get selectDistrict => 'जिला चुनें';

  @override
  String get selectTehsil => 'तहसील चुनें';

  @override
  String get selectStateDistrictTehsil =>
      'नीचे दिए गए ड्रॉप-डाउन से राज्य, जिला और तहसील का चयन करें।';

  @override
  String get onlineMode => 'ऑनलाइन मोड';

  @override
  String get offlineMode => 'ऑफलाइन मोड';

  @override
  String get submit => 'जमा करें';

  @override
  String get onlineModeSelected => 'आपने ऑनलाइन मोड चुना है';

  @override
  String get offlineModeSelected => 'आपने ऑफलाइन मोड चुना है';

  @override
  String get betaOfflineNote =>
      '*बीटा ऑफलाइन मोड सीमित सुविधाओं के साथ इंटरनेट के बिना दूरदराज के क्षेत्रों में काम करता है।';

  @override
  String get version => 'संस्करण:';

  @override
  String get fileaBugReport => 'बग रिपोर्ट दर्ज करें';

  @override
  String get whatsNew => 'नया क्या है';

  @override
  String get accessApplicationWithoutInternet =>
      'इंटरनेट के बिना एप्लिकेशन तक पहुंचें';

  @override
  String get downloadLayersMessage =>
      'ऑफलाइन कनेक्टिविटी के लिए लेयर डाउनलोड करने हेतु, कृपया सहमत पर टिक करें और डाउनलोड बटन दबाएं। लेयर आपके फोन स्टोरेज का लगभग 300 MB लेंगे।';

  @override
  String get agreeAndDownloadLayers => 'सहमत हैं और लेयर डाउनलोड करें';

  @override
  String get downloadLayers => 'लेयर डाउनलोड करें';

  @override
  String get pleaseSelectStateDistrictBlock =>
      'कृपया राज्य, जिला और ब्लॉक चुनें।';

  @override
  String get errorLoadingOfflineView => 'ऑफलाइन व्यू लोड करने में त्रुटि:';

  @override
  String get couldNotOpenEmailClient =>
      'ईमेल क्लाइंट नहीं खोल सके। कृपया अपनी रिपोर्ट support@core-stack.org पर भेजें';

  @override
  String get createNewRegion => 'नया क्षेत्र बनाएं';

  @override
  String get markLocationOnMap => 'मानचित्र पर स्थान चिह्नित करें';

  @override
  String get nameYourRegion => 'अपने क्षेत्र का नाम दें';

  @override
  String get createRegion => 'क्षेत्र बनाएं';

  @override
  String get pleaseEnterRegionName => 'कृपया क्षेत्र का नाम दर्ज करें';

  @override
  String get selectARegion => 'एक क्षेत्र चुनें';

  @override
  String get looksLikeNoRegionsCreated =>
      'लगता है अभी तक कोई क्षेत्र नहीं बनाया गया है';

  @override
  String get pleaseCreateRegionToStart =>
      'ऐप का उपयोग शुरू करने के लिए कृपया एक क्षेत्र बनाएं';

  @override
  String get readyForOfflineUse => 'ऑफलाइन उपयोग के लिए तैयार';

  @override
  String get notYetDownloaded => 'अभी तक डाउनलोड नहीं हुआ';

  @override
  String get refreshAllLayers => 'सभी लेयर रीफ्रेश करें';

  @override
  String get refreshPlanLayersOnly => 'केवल योजना लेयर रीफ्रेश करें';

  @override
  String get deleteRegion => 'क्षेत्र हटाएं';

  @override
  String get deleteRegionConfirmTitle => 'क्षेत्र हटाएं';

  @override
  String deleteRegionConfirmMessage(Object regionName) {
    return 'यह $regionName के लिए सभी ऑफलाइन डेटा हटा देगा। जारी रखें?';
  }

  @override
  String get cancel => 'रद्द करें';

  @override
  String get delete => 'हटाएं';

  @override
  String regionDeleted(Object regionName) {
    return 'क्षेत्र $regionName हटा दिया गया';
  }

  @override
  String get newRegion => 'नया क्षेत्र';

  @override
  String get navigate => 'नेविगेट करें';

  @override
  String get refreshLayers => 'लेयर रीफ्रेश करें';

  @override
  String get layersNotDownloaded =>
      'इस क्षेत्र के लिए लेयर अभी तक डाउनलोड नहीं हुए हैं। क्या आप अभी सभी लेयर रीफ्रेश करना चाहते हैं?';

  @override
  String get refresh => 'रीफ्रेश करें';

  @override
  String get regionMismatch => 'क्षेत्र मेल नहीं खाता';

  @override
  String get regionMismatchMessage =>
      'चयनित क्षेत्र चयनित राज्य, जिला और तहसील से मेल नहीं खाता।';

  @override
  String get ok => 'ठीक है';

  @override
  String get couldNotFindBlockInfo =>
      'पुनः डाउनलोड के लिए ब्लॉक जानकारी नहीं मिली।';

  @override
  String refreshingPlanData(Object regionName) {
    return '$regionName के लिए योजना डेटा रीफ्रेश हो रहा है...';
  }

  @override
  String get couldNotFindBlockInfoRefresh =>
      'रीफ्रेश के लिए ब्लॉक जानकारी नहीं मिली।';

  @override
  String get noPlanLayersToRefresh =>
      'रीफ्रेश करने के लिए कोई योजना लेयर नहीं।';

  @override
  String successfullyRefreshedPlanData(Object regionName) {
    return '$regionName के लिए योजना डेटा सफलतापूर्वक रीफ्रेश हो गया';
  }

  @override
  String errorRefreshingData(Object error) {
    return 'डेटा रीफ्रेश करने में त्रुटि: $error';
  }

  @override
  String get latitude => 'अक्षांश (lat)';

  @override
  String get longitude => 'देशांतर (lon)';

  @override
  String get returnToLocationSelection => 'स्थान चयन पर वापस जाएं';

  @override
  String get returnToPlanSelection => 'योजना चयन पर वापस जाएं';

  @override
  String get loginTitle => 'कृपया जारी रखने के लिए लॉगिन करें';

  @override
  String get phoneNumber => 'फोन नंबर';

  @override
  String get phoneNumberHint => 'अपना फोन नंबर दर्ज करें';

  @override
  String get password => 'पासवर्ड';

  @override
  String get passwordHint => 'अपना पासवर्ड दर्ज करें';

  @override
  String get login => 'लॉगिन';

  @override
  String get hindi => 'हिंदी (hi)';

  @override
  String get english => 'English (en)';

  @override
  String get pleaseEnterPhoneNumber => 'कृपया अपना फोन नंबर दर्ज करें';

  @override
  String get pleaseEnterValidPhoneNumber => 'कृपया एक वैध फोन नंबर दर्ज करें';

  @override
  String get phoneNumberShouldBeAtLeast10Digits =>
      'फोन नंबर कम से कम 10 अंकों का होना चाहिए';

  @override
  String get pleaseEnterPassword => 'कृपया अपना पासवर्ड दर्ज करें';

  @override
  String get invalidUsernameOrPassword =>
      'अमान्य उपयोगकर्ता नाम या पासवर्ड। कृपया फिर से कोशिश करें।';

  @override
  String get networkErrorMessage =>
      'नेटवर्क त्रुटि। कृपया अपना कनेक्शन जांचें और फिर से कोशिश करें।';

  @override
  String get usernameOrPhoneNumber => 'फोन नंबर';

  @override
  String get usernameOrPhoneNumberHint => 'फोन नंबर दर्ज करें';

  @override
  String get pleaseEnterUsernameOrPhoneNumber => 'कृपया फोन नंबर दर्ज करें';

  @override
  String get placeYourMarker => 'अपना मार्कर रखें';

  @override
  String get addLatLon => 'अक्षांश/देशांतर जोड़ें';

  @override
  String get enterCoordinates => 'निर्देशांक दर्ज करें';

  @override
  String get pleaseEnterLatitude => 'कृपया अक्षांश दर्ज करें';

  @override
  String get pleaseEnterLongitude => 'कृपया देशांतर दर्ज करें';

  @override
  String get pleaseEnterValidNumber => 'कृपया एक वैध संख्या दर्ज करें';

  @override
  String get latitudeMustBeBetween => 'अक्षांश -90 और 90 के बीच होना चाहिए';

  @override
  String get longitudeMustBeBetween => 'देशांतर -180 और 180 के बीच होना चाहिए';

  @override
  String get done => 'पूर्ण';

  @override
  String get confirm => 'पुष्टि करें';

  @override
  String get locationServicesDisabled =>
      'स्थान सेवाएं अक्षम हैं। कृपया उन्हें सक्षम करें।';

  @override
  String get locationPermissionsDenied => 'स्थान अनुमतियां अस्वीकृत हैं';

  @override
  String get locationPermissionsPermanentlyDenied =>
      'स्थान अनुमतियां स्थायी रूप से अस्वीकृत हैं, हम अनुमतियों का अनुरोध नहीं कर सकते।';

  @override
  String get movedToCurrentLocation => 'वर्तमान स्थान पर पहुंचे';

  @override
  String errorGettingLocation(Object error) {
    return 'स्थान प्राप्त करने में त्रुटि: $error';
  }

  @override
  String get selectMapLayer => 'मानचित्र परत चुनें';

  @override
  String get defaultLayer => 'डिफ़ॉल्ट';

  @override
  String get openStreetMapLayer => 'ओपनस्ट्रीटमैप';

  @override
  String get changeMapLayer => 'मानचित्र परत बदलें';

  @override
  String get goToCurrentLocation => 'वर्तमान स्थान पर जाएं';

  @override
  String get zoomIn => 'ज़ूम इन';

  @override
  String get zoomOut => 'ज़ूम आउट';
}
