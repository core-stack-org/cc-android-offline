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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
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

  /// No description provided for @downloadingLayers.
  ///
  /// In en, this message translates to:
  /// **'Downloading Layers'**
  String get downloadingLayers;

  /// No description provided for @doNotClosePageWhileDownloading.
  ///
  /// In en, this message translates to:
  /// **'Please do not close this page while download process is in progress.'**
  String get doNotClosePageWhileDownloading;

  /// No description provided for @regionName.
  ///
  /// In en, this message translates to:
  /// **'Region name:'**
  String get regionName;

  /// No description provided for @estimatedTimeToDownload.
  ///
  /// In en, this message translates to:
  /// **'Estimated time to download: 10 minutes'**
  String get estimatedTimeToDownload;

  /// No description provided for @downloadStatus.
  ///
  /// In en, this message translates to:
  /// **'Download Status'**
  String get downloadStatus;

  /// No description provided for @baseMap.
  ///
  /// In en, this message translates to:
  /// **'Base Map'**
  String get baseMap;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @vectorLayers.
  ///
  /// In en, this message translates to:
  /// **'Vector Layers'**
  String get vectorLayers;

  /// No description provided for @completedOf.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} completed'**
  String completedOf(String completed, String total);

  /// No description provided for @planLayers.
  ///
  /// In en, this message translates to:
  /// **'Plan Layers'**
  String get planLayers;

  /// No description provided for @rasterLayersGeoTiffPng.
  ///
  /// In en, this message translates to:
  /// **'Raster Layers (GeoTIFF + PNG)'**
  String get rasterLayersGeoTiffPng;

  /// No description provided for @formDataFiles.
  ///
  /// In en, this message translates to:
  /// **'Form Data Files'**
  String get formDataFiles;

  /// No description provided for @webAppFiles.
  ///
  /// In en, this message translates to:
  /// **'Web App Files'**
  String get webAppFiles;

  /// No description provided for @clartLayerGeoTiff.
  ///
  /// In en, this message translates to:
  /// **'CLART Layer (GeoTIFF)'**
  String get clartLayerGeoTiff;

  /// No description provided for @clartLayerPng.
  ///
  /// In en, this message translates to:
  /// **'CLART Layer (PNG)'**
  String get clartLayerPng;

  /// No description provided for @downloadingOfflineData.
  ///
  /// In en, this message translates to:
  /// **'Downloading Offline Data'**
  String get downloadingOfflineData;

  /// No description provided for @preparingToDownload.
  ///
  /// In en, this message translates to:
  /// **'Preparing to download {containerName}'**
  String preparingToDownload(String containerName);

  /// No description provided for @downloadedPercent.
  ///
  /// In en, this message translates to:
  /// **'Downloaded {percent}% for {containerName}'**
  String downloadedPercent(String percent, String containerName);

  /// No description provided for @successfullyDownloadedData.
  ///
  /// In en, this message translates to:
  /// **'Successfully downloaded data for the region: {containerName}'**
  String successfullyDownloadedData(String containerName);

  /// No description provided for @failedToDownloadData.
  ///
  /// In en, this message translates to:
  /// **'Failed to download data: {error}'**
  String failedToDownloadData(String error);

  /// No description provided for @downloadCancelled.
  ///
  /// In en, this message translates to:
  /// **'Download cancelled.'**
  String get downloadCancelled;

  /// No description provided for @baseMapDownloadedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Base map downloaded successfully'**
  String get baseMapDownloadedSuccessfully;

  /// No description provided for @failedToRetryBaseMap.
  ///
  /// In en, this message translates to:
  /// **'Failed to retry base map: {error}'**
  String failedToRetryBaseMap(String error);

  /// No description provided for @vectorLayersRetryCompleted.
  ///
  /// In en, this message translates to:
  /// **'Vector layers retry completed'**
  String get vectorLayersRetryCompleted;

  /// No description provided for @failedToRetryVectorLayers.
  ///
  /// In en, this message translates to:
  /// **'Failed to retry vector layers: {error}'**
  String failedToRetryVectorLayers(String error);

  /// No description provided for @planLayersRetryCompleted.
  ///
  /// In en, this message translates to:
  /// **'Plan layers retry completed'**
  String get planLayersRetryCompleted;

  /// No description provided for @failedToRetryPlanLayers.
  ///
  /// In en, this message translates to:
  /// **'Failed to retry plan layers: {error}'**
  String failedToRetryPlanLayers(String error);

  /// No description provided for @formDataRetryCompleted.
  ///
  /// In en, this message translates to:
  /// **'Form data retry completed'**
  String get formDataRetryCompleted;

  /// No description provided for @failedToRetryFormData.
  ///
  /// In en, this message translates to:
  /// **'Failed to retry form data: {error}'**
  String failedToRetryFormData(String error);

  /// No description provided for @imageLayersDownloadedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Image layers downloaded successfully'**
  String get imageLayersDownloadedSuccessfully;

  /// No description provided for @someImageLayersFailed.
  ///
  /// In en, this message translates to:
  /// **'Some image layers failed. Check individual statuses.'**
  String get someImageLayersFailed;

  /// No description provided for @failedToRetryImageLayers.
  ///
  /// In en, this message translates to:
  /// **'Failed to retry image layers: {error}'**
  String failedToRetryImageLayers(String error);

  /// No description provided for @webAppFilesRetryCompleted.
  ///
  /// In en, this message translates to:
  /// **'Web app files retry completed'**
  String get webAppFilesRetryCompleted;

  /// No description provided for @failedToRetryWebApp.
  ///
  /// In en, this message translates to:
  /// **'Failed to retry web app: {error}'**
  String failedToRetryWebApp(String error);

  /// No description provided for @downloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Download Complete'**
  String get downloadComplete;

  /// No description provided for @allLayersDownloadedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'All layers have been downloaded successfully. You can now access this region offline.'**
  String get allLayersDownloadedSuccessfully;

  /// No description provided for @downloadIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Download Incomplete'**
  String get downloadIncomplete;

  /// No description provided for @someLayersFailedToDownload.
  ///
  /// In en, this message translates to:
  /// **'Some layers failed to download. You can retry failed layers or exit. The container will not be marked as complete.'**
  String get someLayersFailedToDownload;

  /// No description provided for @exitAnyway.
  ///
  /// In en, this message translates to:
  /// **'Exit Anyway'**
  String get exitAnyway;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @notSpecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get notSpecified;

  /// No description provided for @personalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInformation;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @contactNumber.
  ///
  /// In en, this message translates to:
  /// **'Contact Number'**
  String get contactNumber;

  /// No description provided for @userId.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get userId;

  /// No description provided for @organizationAndRole.
  ///
  /// In en, this message translates to:
  /// **'Organization & Role'**
  String get organizationAndRole;

  /// No description provided for @organization.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get organization;

  /// No description provided for @organizationId.
  ///
  /// In en, this message translates to:
  /// **'Organization ID'**
  String get organizationId;

  /// No description provided for @roles.
  ///
  /// In en, this message translates to:
  /// **'Role(s)'**
  String get roles;

  /// No description provided for @projects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projects;

  /// No description provided for @noProjectsAssigned.
  ///
  /// In en, this message translates to:
  /// **'No projects assigned'**
  String get noProjectsAssigned;

  /// No description provided for @noRolesAssigned.
  ///
  /// In en, this message translates to:
  /// **'No roles assigned'**
  String get noRolesAssigned;

  /// No description provided for @unknownProject.
  ///
  /// In en, this message translates to:
  /// **'Unknown Project'**
  String get unknownProject;

  /// No description provided for @adminStatus.
  ///
  /// In en, this message translates to:
  /// **'Admin Status'**
  String get adminStatus;

  /// No description provided for @superAdministrator.
  ///
  /// In en, this message translates to:
  /// **'Super Administrator'**
  String get superAdministrator;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @updateYourAccountPassword.
  ///
  /// In en, this message translates to:
  /// **'Update your account password'**
  String get updateYourAccountPassword;

  /// No description provided for @appData.
  ///
  /// In en, this message translates to:
  /// **'App Data'**
  String get appData;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get clearCache;

  /// No description provided for @clearWebViewCacheAndCookies.
  ///
  /// In en, this message translates to:
  /// **'Clear WebView cache and cookies'**
  String get clearWebViewCacheAndCookies;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmNewPassword;

  /// No description provided for @youWillBeLoggedOut.
  ///
  /// In en, this message translates to:
  /// **'You will be logged out from all devices'**
  String get youWillBeLoggedOut;

  /// No description provided for @minPasswordRequirements.
  ///
  /// In en, this message translates to:
  /// **'Min 8 chars, alphanumeric, special symbols'**
  String get minPasswordRequirements;

  /// No description provided for @allFieldsRequired.
  ///
  /// In en, this message translates to:
  /// **'All fields are required'**
  String get allFieldsRequired;

  /// No description provided for @newPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'New passwords do not match'**
  String get newPasswordsDoNotMatch;

  /// No description provided for @passwordMustBeAtLeast8.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordMustBeAtLeast8;

  /// No description provided for @passwordMustContainLettersNumbersSpecial.
  ///
  /// In en, this message translates to:
  /// **'Password must contain letters, numbers, and special characters'**
  String get passwordMustContainLettersNumbersSpecial;

  /// No description provided for @networkErrorOccurred.
  ///
  /// In en, this message translates to:
  /// **'Network error occurred'**
  String get networkErrorOccurred;

  /// No description provided for @invalidCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Invalid current password or password requirements not met'**
  String get invalidCurrentPassword;

  /// No description provided for @currentPasswordIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Current password is incorrect'**
  String get currentPasswordIncorrect;

  /// No description provided for @failedToChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Failed to change password. Please try again.'**
  String get failedToChangePassword;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password Changed'**
  String get passwordChanged;

  /// No description provided for @passwordUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Your password has been updated successfully.'**
  String get passwordUpdatedSuccessfully;

  /// No description provided for @youWillBeLoggedOutPleaseLogin.
  ///
  /// In en, this message translates to:
  /// **'You will be logged out. Please login again.'**
  String get youWillBeLoggedOutPleaseLogin;

  /// No description provided for @clearCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get clearCacheTitle;

  /// No description provided for @clearCacheMessage.
  ///
  /// In en, this message translates to:
  /// **'This will clear all WebView cache and cookies. The app may need to reload data.'**
  String get clearCacheMessage;

  /// No description provided for @thisActionCannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone'**
  String get thisActionCannotBeUndone;

  /// No description provided for @cacheClearedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared successfully!'**
  String get cacheClearedSuccessfully;

  /// No description provided for @failedToClearCache.
  ///
  /// In en, this message translates to:
  /// **'Failed to clear cache'**
  String get failedToClearCache;

  /// No description provided for @unableToLoadProfile.
  ///
  /// In en, this message translates to:
  /// **'Unable to load profile data'**
  String get unableToLoadProfile;

  /// No description provided for @loadingLocations.
  ///
  /// In en, this message translates to:
  /// **'Loading Locations'**
  String get loadingLocations;

  /// No description provided for @pleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait...'**
  String get pleaseWait;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'hi': return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
