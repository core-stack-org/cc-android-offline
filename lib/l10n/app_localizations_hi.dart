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
  String get selectStateDistrictTehsil => 'नीचे दिए गए ड्रॉप-डाउन से राज्य, जिला और तहसील का चयन करें।';

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
  String get betaOfflineNote => '*बीटा ऑफलाइन मोड सीमित सुविधाओं के साथ इंटरनेट के बिना दूरदराज के क्षेत्रों में काम करता है।';

  @override
  String get version => 'संस्करण:';

  @override
  String get fileaBugReport => 'बग रिपोर्ट दर्ज करें';

  @override
  String get whatsNew => 'नया क्या है';

  @override
  String get accessApplicationWithoutInternet => 'इंटरनेट के बिना एप्लिकेशन तक पहुंचें';

  @override
  String get downloadLayersMessage => 'ऑफलाइन कनेक्टिविटी के लिए लेयर डाउनलोड करने हेतु, कृपया सहमत पर टिक करें और डाउनलोड बटन दबाएं। लेयर आपके फोन स्टोरेज का लगभग 300 MB लेंगे।';

  @override
  String get agreeAndDownloadLayers => 'सहमत हैं और लेयर डाउनलोड करें';

  @override
  String get downloadLayers => 'लेयर डाउनलोड करें';

  @override
  String get pleaseSelectStateDistrictBlock => 'कृपया राज्य, जिला और ब्लॉक चुनें।';

  @override
  String get errorLoadingOfflineView => 'ऑफलाइन व्यू लोड करने में त्रुटि:';

  @override
  String get couldNotOpenEmailClient => 'ईमेल क्लाइंट नहीं खोल सके। कृपया अपनी रिपोर्ट support@core-stack.org पर भेजें';

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
  String get looksLikeNoRegionsCreated => 'लगता है अभी तक कोई क्षेत्र नहीं बनाया गया है';

  @override
  String get pleaseCreateRegionToStart => 'ऐप का उपयोग शुरू करने के लिए कृपया एक क्षेत्र बनाएं';

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
  String get layersNotDownloaded => 'इस क्षेत्र के लिए लेयर अभी तक डाउनलोड नहीं हुए हैं। क्या आप अभी सभी लेयर रीफ्रेश करना चाहते हैं?';

  @override
  String get refresh => 'रीफ्रेश करें';

  @override
  String get regionMismatch => 'क्षेत्र मेल नहीं खाता';

  @override
  String get regionMismatchMessage => 'चयनित क्षेत्र चयनित राज्य, जिला और तहसील से मेल नहीं खाता।';

  @override
  String get ok => 'ठीक है';

  @override
  String get couldNotFindBlockInfo => 'पुनः डाउनलोड के लिए ब्लॉक जानकारी नहीं मिली।';

  @override
  String refreshingPlanData(Object regionName) {
    return '$regionName के लिए योजना डेटा रीफ्रेश हो रहा है...';
  }

  @override
  String get couldNotFindBlockInfoRefresh => 'रीफ्रेश के लिए ब्लॉक जानकारी नहीं मिली।';

  @override
  String get noPlanLayersToRefresh => 'रीफ्रेश करने के लिए कोई योजना लेयर नहीं।';

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
  String get phoneNumberShouldBeAtLeast10Digits => 'फोन नंबर कम से कम 10 अंकों का होना चाहिए';

  @override
  String get pleaseEnterPassword => 'कृपया अपना पासवर्ड दर्ज करें';

  @override
  String get invalidUsernameOrPassword => 'अमान्य उपयोगकर्ता नाम या पासवर्ड। कृपया फिर से कोशिश करें।';

  @override
  String get networkErrorMessage => 'नेटवर्क त्रुटि। कृपया अपना कनेक्शन जांचें और फिर से कोशिश करें।';

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
  String get locationServicesDisabled => 'स्थान सेवाएं अक्षम हैं। कृपया उन्हें सक्षम करें।';

  @override
  String get locationPermissionsDenied => 'स्थान अनुमतियां अस्वीकृत हैं';

  @override
  String get locationPermissionsPermanentlyDenied => 'स्थान अनुमतियां स्थायी रूप से अस्वीकृत हैं, हम अनुमतियों का अनुरोध नहीं कर सकते।';

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

  @override
  String get downloadingLayers => 'लेयर डाउनलोड हो रही हैं';

  @override
  String get doNotClosePageWhileDownloading => 'कृपया डाउनलोड प्रक्रिया चल रहे समय इस पेज को बंद न करें।';

  @override
  String get regionName => 'क्षेत्र का नाम:';

  @override
  String get estimatedTimeToDownload => 'डाउनलोड का अनुमानित समय: 10 मिनट';

  @override
  String get downloadStatus => 'डाउनलोड स्थिति';

  @override
  String get baseMap => 'बेस मैप';

  @override
  String get retry => 'पुनः प्रयास';

  @override
  String get vectorLayers => 'वेक्टर लेयर';

  @override
  String completedOf(String completed, String total) {
    return '$total में से $completed पूर्ण';
  }

  @override
  String get planLayers => 'योजना लेयर';

  @override
  String get rasterLayersGeoTiffPng => 'रास्टर लेयर (GeoTIFF + PNG)';

  @override
  String get formDataFiles => 'फॉर्म डेटा फाइलें';

  @override
  String get webAppFiles => 'वेब ऐप फाइलें';

  @override
  String get clartLayerGeoTiff => 'CLART लेयर (GeoTIFF)';

  @override
  String get clartLayerPng => 'CLART लेयर (PNG)';

  @override
  String get downloadingOfflineData => 'ऑफलाइन डेटा डाउनलोड हो रहा है';

  @override
  String preparingToDownload(String containerName) {
    return '$containerName डाउनलोड करने की तैयारी हो रही है';
  }

  @override
  String downloadedPercent(String percent, String containerName) {
    return '$containerName के लिए $percent% डाउनलोड हो गया';
  }

  @override
  String successfullyDownloadedData(String containerName) {
    return 'क्षेत्र के लिए डेटा सफलतापूर्वक डाउनलोड हो गया: $containerName';
  }

  @override
  String failedToDownloadData(String error) {
    return 'डेटा डाउनलोड करने में विफल: $error';
  }

  @override
  String get downloadCancelled => 'डाउनलोड रद्द कर दिया गया।';

  @override
  String get baseMapDownloadedSuccessfully => 'बेस मैप सफलतापूर्वक डाउनलोड हो गया';

  @override
  String failedToRetryBaseMap(String error) {
    return 'बेस मैप पुनः प्रयास में विफल: $error';
  }

  @override
  String get vectorLayersRetryCompleted => 'वेक्टर लेयर पुनः प्रयास पूर्ण';

  @override
  String failedToRetryVectorLayers(String error) {
    return 'वेक्टर लेयर पुनः प्रयास में विफल: $error';
  }

  @override
  String get planLayersRetryCompleted => 'योजना लेयर पुनः प्रयास पूर्ण';

  @override
  String failedToRetryPlanLayers(String error) {
    return 'योजना लेयर पुनः प्रयास में विफल: $error';
  }

  @override
  String get formDataRetryCompleted => 'फॉर्म डेटा पुनः प्रयास पूर्ण';

  @override
  String failedToRetryFormData(String error) {
    return 'फॉर्म डेटा पुनः प्रयास में विफल: $error';
  }

  @override
  String get imageLayersDownloadedSuccessfully => 'इमेज लेयर सफलतापूर्वक डाउनलोड हो गईं';

  @override
  String get someImageLayersFailed => 'कुछ इमेज लेयर विफल रहीं। व्यक्तिगत स्थिति देखें।';

  @override
  String failedToRetryImageLayers(String error) {
    return 'इमेज लेयर पुनः प्रयास में विफल: $error';
  }

  @override
  String get webAppFilesRetryCompleted => 'वेब ऐप फाइलें पुनः प्रयास पूर्ण';

  @override
  String failedToRetryWebApp(String error) {
    return 'वेब ऐप पुनः प्रयास में विफल: $error';
  }

  @override
  String get downloadComplete => 'डाउनलोड पूर्ण';

  @override
  String get allLayersDownloadedSuccessfully => 'सभी लेयर सफलतापूर्वक डाउनलोड हो गई हैं। अब आप इस क्षेत्र को ऑफलाइन एक्सेस कर सकते हैं।';

  @override
  String get downloadIncomplete => 'डाउनलोड अधूरा';

  @override
  String get someLayersFailedToDownload => 'कुछ लेयर डाउनलोड होने में विफल रहीं। आप विफल लेयर पुनः प्रयास कर सकते हैं या बाहर निकल सकते हैं। कंटेनर को पूर्ण के रूप में चिह्नित नहीं किया जाएगा।';

  @override
  String get exitAnyway => 'फिर भी बाहर निकलें';

  @override
  String get exit => 'बाहर निकलें';

  @override
  String get profile => 'प्रोफ़ाइल';

  @override
  String get notSpecified => 'निर्दिष्ट नहीं';

  @override
  String get personalInformation => 'व्यक्तिगत जानकारी';

  @override
  String get username => 'उपयोगकर्ता नाम';

  @override
  String get email => 'ईमेल';

  @override
  String get contactNumber => 'संपर्क नंबर';

  @override
  String get userId => 'उपयोगकर्ता आईडी';

  @override
  String get organizationAndRole => 'संगठन और भूमिका';

  @override
  String get organization => 'संगठन';

  @override
  String get organizationId => 'संगठन आईडी';

  @override
  String get roles => 'भूमिका(एं)';

  @override
  String get projects => 'परियोजनाएं';

  @override
  String get noProjectsAssigned => 'कोई परियोजना नहीं सौंपी गई';

  @override
  String get noRolesAssigned => 'कोई भूमिका नहीं सौंपी गई';

  @override
  String get unknownProject => 'अज्ञात परियोजना';

  @override
  String get adminStatus => 'व्यवस्थापक स्थिति';

  @override
  String get superAdministrator => 'सुपर व्यवस्थापक';

  @override
  String get security => 'सुरक्षा';

  @override
  String get changePassword => 'पासवर्ड बदलें';

  @override
  String get updateYourAccountPassword => 'अपने खाते का पासवर्ड अपडेट करें';

  @override
  String get appData => 'ऐप डेटा';

  @override
  String get clearCache => 'कैश साफ़ करें';

  @override
  String get clearWebViewCacheAndCookies => 'वेबव्यू कैश और कुकीज़ साफ़ करें';

  @override
  String get currentPassword => 'वर्तमान पासवर्ड';

  @override
  String get newPassword => 'नया पासवर्ड';

  @override
  String get confirmNewPassword => 'नए पासवर्ड की पुष्टि करें';

  @override
  String get youWillBeLoggedOut => 'आप सभी उपकरणों से लॉग आउट हो जाएंगे';

  @override
  String get minPasswordRequirements => 'कम से कम 8 अक्षर, अल्फान्यूमेरिक, विशेष प्रतीक';

  @override
  String get allFieldsRequired => 'सभी फ़ील्ड आवश्यक हैं';

  @override
  String get newPasswordsDoNotMatch => 'नए पासवर्ड मेल नहीं खाते';

  @override
  String get passwordMustBeAtLeast8 => 'पासवर्ड कम से कम 8 अक्षरों का होना चाहिए';

  @override
  String get passwordMustContainLettersNumbersSpecial => 'पासवर्ड में अक्षर, संख्या और विशेष वर्ण होने चाहिए';

  @override
  String get networkErrorOccurred => 'नेटवर्क त्रुटि हुई';

  @override
  String get invalidCurrentPassword => 'अमान्य वर्तमान पासवर्ड या पासवर्ड आवश्यकताएं पूरी नहीं हुईं';

  @override
  String get currentPasswordIncorrect => 'वर्तमान पासवर्ड गलत है';

  @override
  String get failedToChangePassword => 'पासवर्ड बदलने में विफल। कृपया पुनः प्रयास करें।';

  @override
  String get passwordChanged => 'पासवर्ड बदल गया';

  @override
  String get passwordUpdatedSuccessfully => 'आपका पासवर्ड सफलतापूर्वक अपडेट हो गया है।';

  @override
  String get youWillBeLoggedOutPleaseLogin => 'आप लॉग आउट हो जाएंगे। कृपया फिर से लॉगिन करें।';

  @override
  String get clearCacheTitle => 'कैश साफ़ करें';

  @override
  String get clearCacheMessage => 'यह सभी वेबव्यू कैश और कुकीज़ साफ़ कर देगा। ऐप को डेटा पुनः लोड करने की आवश्यकता हो सकती है।';

  @override
  String get thisActionCannotBeUndone => 'इस क्रिया को पूर्ववत नहीं किया जा सकता';

  @override
  String get cacheClearedSuccessfully => 'कैश सफलतापूर्वक साफ़ हो गया!';

  @override
  String get failedToClearCache => 'कैश साफ़ करने में विफल';

  @override
  String get unableToLoadProfile => 'प्रोफ़ाइल डेटा लोड करने में असमर्थ';
}
