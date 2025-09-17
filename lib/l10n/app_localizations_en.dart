// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get selectLocation => 'Select a location';

  @override
  String get selectState => 'Select a State';

  @override
  String get selectDistrict => 'Select a District';

  @override
  String get selectTehsil => 'Select a Tehsil';

  @override
  String get selectStateDistrictTehsil =>
      'Select State, District and Tehsil from the dropdown';

  @override
  String get onlineMode => 'Online mode';

  @override
  String get offlineMode => 'Offline mode';

  @override
  String get submit => 'Submit';

  @override
  String get onlineModeSelected => 'You have selected ONLINE mode';

  @override
  String get offlineModeSelected => 'You have selected OFFLINE mode';

  @override
  String get betaOfflineNote =>
      '*BETA Offline mode works in remote areas without internet with limited features.';

  @override
  String get version => 'version:';

  @override
  String get fileaBugReport => 'File a bug report';

  @override
  String get whatsNew => 'What\'s New';

  @override
  String get accessApplicationWithoutInternet =>
      'Access Application without Internet';

  @override
  String get downloadLayersMessage =>
      'To download the layers for offline connectivity, please tick off agree and press on download button. The layers will take around 300 MB of your phone storage.';

  @override
  String get agreeAndDownloadLayers => 'Agree and Download Layers';

  @override
  String get downloadLayers => 'Download Layers';

  @override
  String get pleaseSelectStateDistrictBlock =>
      'Please select State, District, and Block.';

  @override
  String get errorLoadingOfflineView => 'Error loading offline view:';

  @override
  String get couldNotOpenEmailClient =>
      'Could not open email client. Please send your report to support@core-stack.org';

  @override
  String get createNewRegion => 'Create a new region';

  @override
  String get markLocationOnMap => 'Mark a location on the map';

  @override
  String get nameYourRegion => 'Name your region';

  @override
  String get createRegion => 'Create Region';

  @override
  String get pleaseEnterRegionName => 'Please enter a region name';

  @override
  String get selectARegion => 'Select a region';

  @override
  String get looksLikeNoRegionsCreated =>
      'Looks like there are no regions created yet';

  @override
  String get pleaseCreateRegionToStart =>
      'Please create a region to start using the app';

  @override
  String get readyForOfflineUse => 'Ready for offline use';

  @override
  String get notYetDownloaded => 'Not yet downloaded';

  @override
  String get refreshAllLayers => 'Refresh all layers';

  @override
  String get refreshPlanLayersOnly => 'Refresh plan layers only';

  @override
  String get deleteRegion => 'Delete region';

  @override
  String get deleteRegionConfirmTitle => 'Delete Region';

  @override
  String deleteRegionConfirmMessage(Object regionName) {
    return 'This will delete all offline data for $regionName. Continue?';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String regionDeleted(Object regionName) {
    return 'Region $regionName deleted';
  }

  @override
  String get newRegion => 'New Region';

  @override
  String get navigate => 'Navigate';

  @override
  String get refreshLayers => 'Refresh Layers';

  @override
  String get layersNotDownloaded =>
      'The layers for this region are not yet downloaded. Do you want to refresh all layers now?';

  @override
  String get refresh => 'Refresh';

  @override
  String get regionMismatch => 'Region Mismatch';

  @override
  String get regionMismatchMessage =>
      'The selected region does not match with the selected State, District and Tehsil.';

  @override
  String get ok => 'OK';

  @override
  String get couldNotFindBlockInfo =>
      'Could not find block information to re-download.';

  @override
  String refreshingPlanData(Object regionName) {
    return 'Refreshing plan data for $regionName...';
  }

  @override
  String get couldNotFindBlockInfoRefresh =>
      'Could not find block information to refresh.';

  @override
  String get noPlanLayersToRefresh => 'No plan layers to refresh.';

  @override
  String successfullyRefreshedPlanData(Object regionName) {
    return 'Successfully refreshed plan data for $regionName';
  }

  @override
  String errorRefreshingData(Object error) {
    return 'Error refreshing data: $error';
  }

  @override
  String get latitude => 'Latitude';

  @override
  String get longitude => 'Longitude';

  @override
  String get returnToLocationSelection => 'Return to Location Selection';

  @override
  String get returnToPlanSelection => 'Return to Plan Selection';

  @override
  String get loginTitle => 'Please login to continue';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get phoneNumberHint => 'Enter your phone number';

  @override
  String get password => 'Password';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get login => 'Login';

  @override
  String get hindi => 'हिंदी (hi)';

  @override
  String get english => 'English (en)';

  @override
  String get pleaseEnterPhoneNumber => 'Please enter your phone number';

  @override
  String get pleaseEnterValidPhoneNumber => 'Please enter a valid phone number';

  @override
  String get phoneNumberShouldBeAtLeast10Digits =>
      'Phone number should be at least 10 digits';

  @override
  String get pleaseEnterPassword => 'Please enter your password';

  @override
  String get invalidUsernameOrPassword =>
      'Invalid username or password. Please try again.';

  @override
  String get networkErrorMessage =>
      'Network error. Please check your connection and try again.';

  @override
  String get usernameOrPhoneNumber => 'Phone number';

  @override
  String get usernameOrPhoneNumberHint => 'Enter your phone number';

  @override
  String get pleaseEnterUsernameOrPhoneNumber =>
      'Please enter your phone number';

  @override
  String get placeYourMarker => 'Place your marker';

  @override
  String get addLatLon => 'Add Lat/Lon';

  @override
  String get enterCoordinates => 'Enter Coordinates';

  @override
  String get pleaseEnterLatitude => 'Please enter latitude';

  @override
  String get pleaseEnterLongitude => 'Please enter longitude';

  @override
  String get pleaseEnterValidNumber => 'Please enter a valid number';

  @override
  String get latitudeMustBeBetween => 'Latitude must be between -90 and 90';

  @override
  String get longitudeMustBeBetween => 'Longitude must be between -180 and 180';

  @override
  String get done => 'Done';

  @override
  String get confirm => 'Confirm';

  @override
  String get locationServicesDisabled =>
      'Location services are disabled. Please enable them.';

  @override
  String get locationPermissionsDenied => 'Location permissions are denied';

  @override
  String get locationPermissionsPermanentlyDenied =>
      'Location permissions are permanently denied, we cannot request permissions.';

  @override
  String get movedToCurrentLocation => 'Moved to current location';

  @override
  String errorGettingLocation(Object error) {
    return 'Error getting location: $error';
  }

  @override
  String get selectMapLayer => 'Select Map Layer';

  @override
  String get defaultLayer => 'Default';

  @override
  String get openStreetMapLayer => 'OpenStreetMap';

  @override
  String get changeMapLayer => 'Change map layer';

  @override
  String get goToCurrentLocation => 'Go to current location';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';
}
