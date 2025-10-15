import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi')
  ];

  /// No description provided for @selectLocation.
  ///
  /// In en, this message translates to:
  /// **'Select a location'**
  String get selectLocation;

  /// No description provided for @selectState.
  ///
  /// In en, this message translates to:
  /// **'Select a State'**
  String get selectState;

  /// No description provided for @selectDistrict.
  ///
  /// In en, this message translates to:
  /// **'Select a District'**
  String get selectDistrict;

  /// No description provided for @selectTehsil.
  ///
  /// In en, this message translates to:
  /// **'Select a Tehsil'**
  String get selectTehsil;

  /// No description provided for @selectStateDistrictTehsil.
  ///
  /// In en, this message translates to:
  /// **'Select State, District and Tehsil from the dropdown'**
  String get selectStateDistrictTehsil;

  /// No description provided for @onlineMode.
  ///
  /// In en, this message translates to:
  /// **'Online mode'**
  String get onlineMode;

  /// No description provided for @offlineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline mode'**
  String get offlineMode;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @onlineModeSelected.
  ///
  /// In en, this message translates to:
  /// **'You have selected ONLINE mode'**
  String get onlineModeSelected;

  /// No description provided for @offlineModeSelected.
  ///
  /// In en, this message translates to:
  /// **'You have selected OFFLINE mode'**
  String get offlineModeSelected;

  /// No description provided for @betaOfflineNote.
  ///
  /// In en, this message translates to:
  /// **'*BETA Offline mode works in remote areas without internet with limited features.'**
  String get betaOfflineNote;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'version:'**
  String get version;

  /// No description provided for @fileaBugReport.
  ///
  /// In en, this message translates to:
  /// **'File a bug report'**
  String get fileaBugReport;

  /// No description provided for @whatsNew.
  ///
  /// In en, this message translates to:
  /// **'What\'s New'**
  String get whatsNew;

  /// No description provided for @accessApplicationWithoutInternet.
  ///
  /// In en, this message translates to:
  /// **'Access Application without Internet'**
  String get accessApplicationWithoutInternet;

  /// No description provided for @downloadLayersMessage.
  ///
  /// In en, this message translates to:
  /// **'To download the layers for offline connectivity, please tick off agree and press on download button. The layers will take around 300 MB of your phone storage.'**
  String get downloadLayersMessage;

  /// No description provided for @agreeAndDownloadLayers.
  ///
  /// In en, this message translates to:
  /// **'Agree and Download Layers'**
  String get agreeAndDownloadLayers;

  /// No description provided for @downloadLayers.
  ///
  /// In en, this message translates to:
  /// **'Download Layers'**
  String get downloadLayers;

  /// No description provided for @pleaseSelectStateDistrictBlock.
  ///
  /// In en, this message translates to:
  /// **'Please select State, District, and Block.'**
  String get pleaseSelectStateDistrictBlock;

  /// No description provided for @errorLoadingOfflineView.
  ///
  /// In en, this message translates to:
  /// **'Error loading offline view:'**
  String get errorLoadingOfflineView;

  /// No description provided for @couldNotOpenEmailClient.
  ///
  /// In en, this message translates to:
  /// **'Could not open email client. Please send your report to support@core-stack.org'**
  String get couldNotOpenEmailClient;

  /// No description provided for @createNewRegion.
  ///
  /// In en, this message translates to:
  /// **'Create a new region'**
  String get createNewRegion;

  /// No description provided for @markLocationOnMap.
  ///
  /// In en, this message translates to:
  /// **'Mark a location on the map'**
  String get markLocationOnMap;

  /// No description provided for @nameYourRegion.
  ///
  /// In en, this message translates to:
  /// **'Name your region'**
  String get nameYourRegion;

  /// No description provided for @createRegion.
  ///
  /// In en, this message translates to:
  /// **'Create Region'**
  String get createRegion;

  /// No description provided for @pleaseEnterRegionName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a region name'**
  String get pleaseEnterRegionName;

  /// No description provided for @selectARegion.
  ///
  /// In en, this message translates to:
  /// **'Select a region'**
  String get selectARegion;

  /// No description provided for @looksLikeNoRegionsCreated.
  ///
  /// In en, this message translates to:
  /// **'Looks like there are no regions created yet'**
  String get looksLikeNoRegionsCreated;

  /// No description provided for @pleaseCreateRegionToStart.
  ///
  /// In en, this message translates to:
  /// **'Please create a region to start using the app'**
  String get pleaseCreateRegionToStart;

  /// No description provided for @readyForOfflineUse.
  ///
  /// In en, this message translates to:
  /// **'Ready for offline use'**
  String get readyForOfflineUse;

  /// No description provided for @notYetDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Not yet downloaded'**
  String get notYetDownloaded;

  /// No description provided for @refreshAllLayers.
  ///
  /// In en, this message translates to:
  /// **'Refresh all layers'**
  String get refreshAllLayers;

  /// No description provided for @refreshPlanLayersOnly.
  ///
  /// In en, this message translates to:
  /// **'Refresh plan layers only'**
  String get refreshPlanLayersOnly;

  /// No description provided for @deleteRegion.
  ///
  /// In en, this message translates to:
  /// **'Delete region'**
  String get deleteRegion;

  /// No description provided for @deleteRegionConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Region'**
  String get deleteRegionConfirmTitle;

  /// No description provided for @deleteRegionConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will delete all offline data for {regionName}. Continue?'**
  String deleteRegionConfirmMessage(Object regionName);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @regionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Region {regionName} deleted'**
  String regionDeleted(Object regionName);

  /// No description provided for @newRegion.
  ///
  /// In en, this message translates to:
  /// **'New Region'**
  String get newRegion;

  /// No description provided for @navigate.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get navigate;

  /// No description provided for @refreshLayers.
  ///
  /// In en, this message translates to:
  /// **'Refresh Layers'**
  String get refreshLayers;

  /// No description provided for @layersNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'The layers for this region are not yet downloaded. Do you want to refresh all layers now?'**
  String get layersNotDownloaded;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @regionMismatch.
  ///
  /// In en, this message translates to:
  /// **'Region Mismatch'**
  String get regionMismatch;

  /// No description provided for @regionMismatchMessage.
  ///
  /// In en, this message translates to:
  /// **'The selected region does not match with the selected State, District and Tehsil.'**
  String get regionMismatchMessage;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @couldNotFindBlockInfo.
  ///
  /// In en, this message translates to:
  /// **'Could not find block information to re-download.'**
  String get couldNotFindBlockInfo;

  /// No description provided for @refreshingPlanData.
  ///
  /// In en, this message translates to:
  /// **'Refreshing plan data for {regionName}...'**
  String refreshingPlanData(Object regionName);

  /// No description provided for @couldNotFindBlockInfoRefresh.
  ///
  /// In en, this message translates to:
  /// **'Could not find block information to refresh.'**
  String get couldNotFindBlockInfoRefresh;

  /// No description provided for @noPlanLayersToRefresh.
  ///
  /// In en, this message translates to:
  /// **'No plan layers to refresh.'**
  String get noPlanLayersToRefresh;

  /// No description provided for @successfullyRefreshedPlanData.
  ///
  /// In en, this message translates to:
  /// **'Successfully refreshed plan data for {regionName}'**
  String successfullyRefreshedPlanData(Object regionName);

  /// No description provided for @errorRefreshingData.
  ///
  /// In en, this message translates to:
  /// **'Error refreshing data: {error}'**
  String errorRefreshingData(Object error);

  /// No description provided for @latitude.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get latitude;

  /// No description provided for @longitude.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get longitude;

  /// No description provided for @returnToLocationSelection.
  ///
  /// In en, this message translates to:
  /// **'Return to Location Selection'**
  String get returnToLocationSelection;

  /// No description provided for @returnToPlanSelection.
  ///
  /// In en, this message translates to:
  /// **'Return to Plan Selection'**
  String get returnToPlanSelection;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Please login to continue'**
  String get loginTitle;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @phoneNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get phoneNumberHint;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @hindi.
  ///
  /// In en, this message translates to:
  /// **'हिंदी (hi)'**
  String get hindi;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English (en)'**
  String get english;

  /// No description provided for @pleaseEnterPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number'**
  String get pleaseEnterPhoneNumber;

  /// No description provided for @pleaseEnterValidPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number'**
  String get pleaseEnterValidPhoneNumber;

  /// No description provided for @phoneNumberShouldBeAtLeast10Digits.
  ///
  /// In en, this message translates to:
  /// **'Phone number should be at least 10 digits'**
  String get phoneNumberShouldBeAtLeast10Digits;

  /// No description provided for @pleaseEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get pleaseEnterPassword;

  /// No description provided for @invalidUsernameOrPassword.
  ///
  /// In en, this message translates to:
  /// **'Invalid username or password. Please try again.'**
  String get invalidUsernameOrPassword;

  /// No description provided for @networkErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection and try again.'**
  String get networkErrorMessage;

  /// No description provided for @usernameOrPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get usernameOrPhoneNumber;

  /// No description provided for @usernameOrPhoneNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get usernameOrPhoneNumberHint;

  /// No description provided for @pleaseEnterUsernameOrPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number'**
  String get pleaseEnterUsernameOrPhoneNumber;

  /// No description provided for @placeYourMarker.
  ///
  /// In en, this message translates to:
  /// **'Place your marker'**
  String get placeYourMarker;

  /// No description provided for @addLatLon.
  ///
  /// In en, this message translates to:
  /// **'Add Lat/Lon'**
  String get addLatLon;

  /// No description provided for @enterCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Enter Coordinates'**
  String get enterCoordinates;

  /// No description provided for @pleaseEnterLatitude.
  ///
  /// In en, this message translates to:
  /// **'Please enter latitude'**
  String get pleaseEnterLatitude;

  /// No description provided for @pleaseEnterLongitude.
  ///
  /// In en, this message translates to:
  /// **'Please enter longitude'**
  String get pleaseEnterLongitude;

  /// No description provided for @pleaseEnterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number'**
  String get pleaseEnterValidNumber;

  /// No description provided for @latitudeMustBeBetween.
  ///
  /// In en, this message translates to:
  /// **'Latitude must be between -90 and 90'**
  String get latitudeMustBeBetween;

  /// No description provided for @longitudeMustBeBetween.
  ///
  /// In en, this message translates to:
  /// **'Longitude must be between -180 and 180'**
  String get longitudeMustBeBetween;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @locationServicesDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled. Please enable them.'**
  String get locationServicesDisabled;

  /// No description provided for @locationPermissionsDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permissions are denied'**
  String get locationPermissionsDenied;

  /// No description provided for @locationPermissionsPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permissions are permanently denied, we cannot request permissions.'**
  String get locationPermissionsPermanentlyDenied;

  /// No description provided for @movedToCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Moved to current location'**
  String get movedToCurrentLocation;

  /// No description provided for @errorGettingLocation.
  ///
  /// In en, this message translates to:
  /// **'Error getting location: {error}'**
  String errorGettingLocation(Object error);

  /// No description provided for @selectMapLayer.
  ///
  /// In en, this message translates to:
  /// **'Select Map Layer'**
  String get selectMapLayer;

  /// No description provided for @defaultLayer.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultLayer;

  /// No description provided for @openStreetMapLayer.
  ///
  /// In en, this message translates to:
  /// **'OpenStreetMap'**
  String get openStreetMapLayer;

  /// No description provided for @changeMapLayer.
  ///
  /// In en, this message translates to:
  /// **'Change map layer'**
  String get changeMapLayer;

  /// No description provided for @goToCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Go to current location'**
  String get goToCurrentLocation;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
