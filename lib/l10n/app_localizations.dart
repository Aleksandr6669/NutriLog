import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_uk.dart';

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
    Locale('ru'),
    Locale('uk')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'NutriLog'**
  String get appTitle;

  /// No description provided for @breakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get breakfast;

  /// No description provided for @lunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get lunch;

  /// No description provided for @dinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get dinner;

  /// No description provided for @snacks.
  ///
  /// In en, this message translates to:
  /// **'Snacks'**
  String get snacks;

  /// No description provided for @water.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get water;

  /// No description provided for @steps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get steps;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @calories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get calories;

  /// No description provided for @protein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get protein;

  /// No description provided for @fat.
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get fat;

  /// No description provided for @carbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get carbs;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining;

  /// No description provided for @consumed.
  ///
  /// In en, this message translates to:
  /// **'Consumed'**
  String get consumed;

  /// No description provided for @burned.
  ///
  /// In en, this message translates to:
  /// **'Burned'**
  String get burned;

  /// No description provided for @addFood.
  ///
  /// In en, this message translates to:
  /// **'Add food'**
  String get addFood;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @recipes.
  ///
  /// In en, this message translates to:
  /// **'Recipes'**
  String get recipes;

  /// No description provided for @whatsNew.
  ///
  /// In en, this message translates to:
  /// **'What\'s New'**
  String get whatsNew;

  /// No description provided for @userAgreement.
  ///
  /// In en, this message translates to:
  /// **'User Agreement'**
  String get userAgreement;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @kcal.
  ///
  /// In en, this message translates to:
  /// **'kcal'**
  String get kcal;

  /// No description provided for @goal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get goal;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @meals.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get meals;

  /// No description provided for @physicalCondition.
  ///
  /// In en, this message translates to:
  /// **'Physical Condition'**
  String get physicalCondition;

  /// No description provided for @manualStepsInput.
  ///
  /// In en, this message translates to:
  /// **'Manual Steps Input'**
  String get manualStepsInput;

  /// No description provided for @enterStepsCount.
  ///
  /// In en, this message translates to:
  /// **'Enter steps count'**
  String get enterStepsCount;

  /// No description provided for @noDataForDate.
  ///
  /// In en, this message translates to:
  /// **'No data for this date.'**
  String get noDataForDate;

  /// No description provided for @editGoals.
  ///
  /// In en, this message translates to:
  /// **'Edit Goals'**
  String get editGoals;

  /// No description provided for @diary.
  ///
  /// In en, this message translates to:
  /// **'Diary'**
  String get diary;

  /// No description provided for @analysis.
  ///
  /// In en, this message translates to:
  /// **'Analysis'**
  String get analysis;

  /// No description provided for @chooseAvatar.
  ///
  /// In en, this message translates to:
  /// **'Choose Avatar'**
  String get chooseAvatar;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @loseWeight.
  ///
  /// In en, this message translates to:
  /// **'Lose Weight'**
  String get loseWeight;

  /// No description provided for @gainWeight.
  ///
  /// In en, this message translates to:
  /// **'Gain Weight'**
  String get gainWeight;

  /// No description provided for @gainMuscle.
  ///
  /// In en, this message translates to:
  /// **'Gain Muscle'**
  String get gainMuscle;

  /// No description provided for @healthyEating.
  ///
  /// In en, this message translates to:
  /// **'Healthy Eating'**
  String get healthyEating;

  /// No description provided for @energetic.
  ///
  /// In en, this message translates to:
  /// **'Energetic'**
  String get energetic;

  /// No description provided for @sedentary.
  ///
  /// In en, this message translates to:
  /// **'Sedentary'**
  String get sedentary;

  /// No description provided for @lightActivity.
  ///
  /// In en, this message translates to:
  /// **'Light Activity'**
  String get lightActivity;

  /// No description provided for @moderateActivity.
  ///
  /// In en, this message translates to:
  /// **'Moderate Activity'**
  String get moderateActivity;

  /// No description provided for @activeActivity.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeActivity;

  /// No description provided for @veryActiveActivity.
  ///
  /// In en, this message translates to:
  /// **'Very Active'**
  String get veryActiveActivity;

  /// No description provided for @yearsOld.
  ///
  /// In en, this message translates to:
  /// **'years old'**
  String get yearsOld;

  /// No description provided for @height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// No description provided for @heightCm.
  ///
  /// In en, this message translates to:
  /// **'Height (cm)'**
  String get heightCm;

  /// No description provided for @weightKg.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get weightKg;

  /// No description provided for @physicalParams.
  ///
  /// In en, this message translates to:
  /// **'Physical Parameters'**
  String get physicalParams;

  /// No description provided for @birthDate.
  ///
  /// In en, this message translates to:
  /// **'Birth Date'**
  String get birthDate;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @generalGoals.
  ///
  /// In en, this message translates to:
  /// **'General Goals'**
  String get generalGoals;

  /// No description provided for @weightGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'Weight Goal'**
  String get weightGoalTitle;

  /// No description provided for @goalTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Goal Type'**
  String get goalTypeTitle;

  /// No description provided for @dailyGoalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Goals'**
  String get dailyGoalsTitle;

  /// No description provided for @myRecipes.
  ///
  /// In en, this message translates to:
  /// **'My Recipes'**
  String get myRecipes;

  /// No description provided for @addToMeal.
  ///
  /// In en, this message translates to:
  /// **'Add to Meal'**
  String get addToMeal;

  /// No description provided for @searchRecipe.
  ///
  /// In en, this message translates to:
  /// **'Search recipe...'**
  String get searchRecipe;

  /// No description provided for @nothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get nothingFound;

  /// No description provided for @tryChangingQuery.
  ///
  /// In en, this message translates to:
  /// **'Try changing your query'**
  String get tryChangingQuery;

  /// No description provided for @noRecipesYet.
  ///
  /// In en, this message translates to:
  /// **'You have no recipes yet'**
  String get noRecipesYet;

  /// No description provided for @pressPlusToAdd.
  ///
  /// In en, this message translates to:
  /// **'Press + to add your first recipe'**
  String get pressPlusToAdd;

  /// No description provided for @added.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get added;

  /// No description provided for @showAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get showAll;

  /// No description provided for @collapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get collapse;

  /// No description provided for @removeOnePortion.
  ///
  /// In en, this message translates to:
  /// **'Remove one portion'**
  String get removeOnePortion;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @cancelSelection.
  ///
  /// In en, this message translates to:
  /// **'Cancel selection'**
  String get cancelSelection;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selected;

  /// No description provided for @builtinRecipesCannotBeDeleted.
  ///
  /// In en, this message translates to:
  /// **'Built-in recipes cannot be deleted.'**
  String get builtinRecipesCannotBeDeleted;

  /// No description provided for @byPhoto.
  ///
  /// In en, this message translates to:
  /// **'By Photo'**
  String get byPhoto;

  /// No description provided for @byDescription.
  ///
  /// In en, this message translates to:
  /// **'By Description'**
  String get byDescription;

  /// No description provided for @manually.
  ///
  /// In en, this message translates to:
  /// **'Manually'**
  String get manually;

  /// No description provided for @acknowledged.
  ///
  /// In en, this message translates to:
  /// **'Acknowledged'**
  String get acknowledged;

  /// No description provided for @agreementSection1Title.
  ///
  /// In en, this message translates to:
  /// **'1. Data Collection and Use'**
  String get agreementSection1Title;

  /// No description provided for @agreementSection1Content.
  ///
  /// In en, this message translates to:
  /// **'NutriLog collects data about your nutrition, weight, physical parameters, and goals to provide personalized nutrient calculations and recommendations. Your data is used exclusively for the app\'s functioning and improving your experience.'**
  String get agreementSection1Content;

  /// No description provided for @agreementSection2Title.
  ///
  /// In en, this message translates to:
  /// **'2. Data Storage'**
  String get agreementSection2Title;

  /// No description provided for @agreementSection2Content.
  ///
  /// In en, this message translates to:
  /// **'All your data (nutrition diary, recipes, anthropometric data) is stored directly in the app\'s memory on your device or in your personal NutriLog account. We do not share your personal information with third parties without your explicit consent.'**
  String get agreementSection2Content;

  /// No description provided for @agreementSection3Title.
  ///
  /// In en, this message translates to:
  /// **'3. Neural Network Technologies'**
  String get agreementSection3Title;

  /// No description provided for @agreementSection3Content.
  ///
  /// In en, this message translates to:
  /// **'The app uses modern neural network technologies to analyze your meals, automatically recognize products by description or photo, and help in creating a diet and recipes. Data processing is anonymous.'**
  String get agreementSection3Content;

  /// No description provided for @agreementSection4Title.
  ///
  /// In en, this message translates to:
  /// **'4. Responsibility'**
  String get agreementSection4Title;

  /// No description provided for @agreementSection4Content.
  ///
  /// In en, this message translates to:
  /// **'The app is a tool for monitoring nutrition and does not replace doctor\'s consultation or professional nutritionist. All calculations are recommendations.'**
  String get agreementSection4Content;

  /// No description provided for @agreementCheckboxText.
  ///
  /// In en, this message translates to:
  /// **'I have read and accept the terms of the user agreement'**
  String get agreementCheckboxText;

  /// No description provided for @agreementContinueText.
  ///
  /// In en, this message translates to:
  /// **'By continuing to use the app, you agree to these terms.'**
  String get agreementContinueText;

  /// No description provided for @agreementAcceptButton.
  ///
  /// In en, this message translates to:
  /// **'I accept the terms'**
  String get agreementAcceptButton;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @saveAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Save and continue'**
  String get saveAndContinue;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required field'**
  String get requiredField;

  /// No description provided for @enterNumberGreaterThanZero.
  ///
  /// In en, this message translates to:
  /// **'Enter a number greater than 0'**
  String get enterNumberGreaterThanZero;

  /// No description provided for @userDefaultName.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get userDefaultName;

  /// No description provided for @guest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guest;

  /// No description provided for @onboardingPhysicalInfo.
  ///
  /// In en, this message translates to:
  /// **'Enter basic physical parameters: gender, age, height, and current weight. This data is needed for personalized calculations.'**
  String get onboardingPhysicalInfo;

  /// No description provided for @onboardingGeneralInfo.
  ///
  /// In en, this message translates to:
  /// **'Set your progress strategy: target weight, goal type, and activity level. This data is sent to AI for more accurate daily targets.'**
  String get onboardingGeneralInfo;

  /// No description provided for @onboardingDailyInfo.
  ///
  /// In en, this message translates to:
  /// **'Set daily targets: calories, water, steps, and macros. You can adjust them later in profile settings.'**
  String get onboardingDailyInfo;

  /// No description provided for @enterYourName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get enterYourName;

  /// No description provided for @enterYourHeight.
  ///
  /// In en, this message translates to:
  /// **'Enter your height'**
  String get enterYourHeight;

  /// No description provided for @enterYourWeight.
  ///
  /// In en, this message translates to:
  /// **'Enter your weight'**
  String get enterYourWeight;

  /// No description provided for @enterWeightGoal.
  ///
  /// In en, this message translates to:
  /// **'Enter your weight goal'**
  String get enterWeightGoal;

  /// No description provided for @sportsActivities.
  ///
  /// In en, this message translates to:
  /// **'What sports/activities do you do'**
  String get sportsActivities;

  /// No description provided for @canBeLeftEmpty.
  ///
  /// In en, this message translates to:
  /// **'Can be left empty'**
  String get canBeLeftEmpty;

  /// No description provided for @additionalForAi.
  ///
  /// In en, this message translates to:
  /// **'Additional context for AI'**
  String get additionalForAi;

  /// No description provided for @additionalForAiHint.
  ///
  /// In en, this message translates to:
  /// **'For example: sedentary work, early training, food restrictions. Can be left empty.'**
  String get additionalForAiHint;

  /// No description provided for @aiCalculatingGoals.
  ///
  /// In en, this message translates to:
  /// **'AI is calculating targets...'**
  String get aiCalculatingGoals;

  /// No description provided for @aiCalculateGoals.
  ///
  /// In en, this message translates to:
  /// **'Calculate daily targets with AI'**
  String get aiCalculateGoals;

  /// No description provided for @aiGoalsNotice.
  ///
  /// In en, this message translates to:
  /// **'AI calculates targets based on your parameters. It is recommended to review values before saving.'**
  String get aiGoalsNotice;

  /// No description provided for @enterCalorieGoal.
  ///
  /// In en, this message translates to:
  /// **'Enter calorie target'**
  String get enterCalorieGoal;

  /// No description provided for @enterWaterGoal.
  ///
  /// In en, this message translates to:
  /// **'Enter water target'**
  String get enterWaterGoal;

  /// No description provided for @enterStepsGoal.
  ///
  /// In en, this message translates to:
  /// **'Enter steps target'**
  String get enterStepsGoal;

  /// No description provided for @enterProteinGoal.
  ///
  /// In en, this message translates to:
  /// **'Enter protein target'**
  String get enterProteinGoal;

  /// No description provided for @enterCarbsGoal.
  ///
  /// In en, this message translates to:
  /// **'Enter carbs target'**
  String get enterCarbsGoal;

  /// No description provided for @enterFatGoal.
  ///
  /// In en, this message translates to:
  /// **'Enter fat target'**
  String get enterFatGoal;

  /// No description provided for @activityFrequencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity frequency'**
  String get activityFrequencyTitle;

  /// No description provided for @weightScreenInfo.
  ///
  /// In en, this message translates to:
  /// **'Here you record your weight for the selected date. This helps track progress and improve calorie calculations in analytics.'**
  String get weightScreenInfo;

  /// No description provided for @currentGoal.
  ///
  /// In en, this message translates to:
  /// **'Current goal'**
  String get currentGoal;

  /// No description provided for @weightNotSavedForDate.
  ///
  /// In en, this message translates to:
  /// **'No weight saved for'**
  String get weightNotSavedForDate;

  /// No description provided for @savedForDate.
  ///
  /// In en, this message translates to:
  /// **'Saved for'**
  String get savedForDate;

  /// No description provided for @saveWeight.
  ///
  /// In en, this message translates to:
  /// **'Save weight'**
  String get saveWeight;

  /// No description provided for @chooseIcon.
  ///
  /// In en, this message translates to:
  /// **'Choose icon'**
  String get chooseIcon;

  /// No description provided for @goalLoseWeightHint.
  ///
  /// In en, this message translates to:
  /// **'Gradual weight loss through a moderate calorie deficit, portion control, and consistent meal routine without strict restrictions.'**
  String get goalLoseWeightHint;

  /// No description provided for @goalGainWeightHint.
  ///
  /// In en, this message translates to:
  /// **'Steady weight gain through a careful calorie surplus, regular meals, and weekly tracking.'**
  String get goalGainWeightHint;

  /// No description provided for @goalGainMuscleHint.
  ///
  /// In en, this message translates to:
  /// **'Muscle growth with focus on protein, strength training, and recovery for sustainable progress.'**
  String get goalGainMuscleHint;

  /// No description provided for @goalHealthyEatingHint.
  ///
  /// In en, this message translates to:
  /// **'Balanced daily diet: more whole foods, nutrient diversity, and a comfortable routine without extremes.'**
  String get goalHealthyEatingHint;

  /// No description provided for @goalEnergeticHint.
  ///
  /// In en, this message translates to:
  /// **'More energy throughout the day through regular meals, quality sleep, enough water, and stable activity.'**
  String get goalEnergeticHint;

  /// No description provided for @activitySedentaryHint.
  ///
  /// In en, this message translates to:
  /// **'Sedentary work, rare workouts, and low step count.'**
  String get activitySedentaryHint;

  /// No description provided for @activityLightHint.
  ///
  /// In en, this message translates to:
  /// **'Occasional sports or walks, but without a stable routine.'**
  String get activityLightHint;

  /// No description provided for @activityModerateHint.
  ///
  /// In en, this message translates to:
  /// **'Regular activity several times a week.'**
  String get activityModerateHint;

  /// No description provided for @activityActiveHint.
  ///
  /// In en, this message translates to:
  /// **'Frequent workouts and high average movement.'**
  String get activityActiveHint;

  /// No description provided for @activityVeryActiveHint.
  ///
  /// In en, this message translates to:
  /// **'Intense activity and sports almost every day.'**
  String get activityVeryActiveHint;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Your path to health'**
  String get appTagline;
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
      <String>['en', 'ru', 'uk'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
