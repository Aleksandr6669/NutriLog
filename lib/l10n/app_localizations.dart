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

  /// No description provided for @statsInfoText.
  ///
  /// In en, this message translates to:
  /// **'Analytics helps you see the big picture of your nutrition, water, weight, and activity over a period. Use it to timely adjust your goals and track steady progress without overload.'**
  String get statsInfoText;

  /// No description provided for @statsCaloriesDynamics.
  ///
  /// In en, this message translates to:
  /// **'Calorie Trend'**
  String get statsCaloriesDynamics;

  /// No description provided for @statsWeightDynamics.
  ///
  /// In en, this message translates to:
  /// **'Weight Trend'**
  String get statsWeightDynamics;

  /// No description provided for @statsAvgMacros.
  ///
  /// In en, this message translates to:
  /// **'Average Macros'**
  String get statsAvgMacros;

  /// No description provided for @statsProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get statsProgress;

  /// No description provided for @statsAiReportTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Report'**
  String get statsAiReportTitle;

  /// No description provided for @statsPeriodWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get statsPeriodWeek;

  /// No description provided for @statsPeriodMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get statsPeriodMonth;

  /// No description provided for @statsPeriodYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get statsPeriodYear;

  /// No description provided for @statsNoData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get statsNoData;

  /// No description provided for @statsNoDataForAnalysis.
  ///
  /// In en, this message translates to:
  /// **'No data for analysis.'**
  String get statsNoDataForAnalysis;

  /// No description provided for @statsNoDataToDisplay.
  ///
  /// In en, this message translates to:
  /// **'No data to display'**
  String get statsNoDataToDisplay;

  /// No description provided for @statsAnalysisFor.
  ///
  /// In en, this message translates to:
  /// **'Analysis for {period}'**
  String statsAnalysisFor(String period);

  /// No description provided for @statsAiDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'AI may be off by ~10%. Use the report as a reference.'**
  String get statsAiDisclaimer;

  /// No description provided for @statsAiLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading AI report...'**
  String get statsAiLoading;

  /// No description provided for @statsAiError.
  ///
  /// In en, this message translates to:
  /// **'Could not generate AI report. Please try again later.'**
  String get statsAiError;

  /// No description provided for @statsPeriodLabelWeek.
  ///
  /// In en, this message translates to:
  /// **'the week'**
  String get statsPeriodLabelWeek;

  /// No description provided for @statsPeriodLabelMonth.
  ///
  /// In en, this message translates to:
  /// **'the month'**
  String get statsPeriodLabelMonth;

  /// No description provided for @statsPeriodLabelYear.
  ///
  /// In en, this message translates to:
  /// **'the year'**
  String get statsPeriodLabelYear;

  /// No description provided for @statsErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading data: {error}'**
  String statsErrorLoading(Object error);

  /// No description provided for @dayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get dayMon;

  /// No description provided for @dayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get dayTue;

  /// No description provided for @dayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get dayWed;

  /// No description provided for @dayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get dayThu;

  /// No description provided for @dayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get dayFri;

  /// No description provided for @daySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get daySat;

  /// No description provided for @daySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get daySun;

  /// No description provided for @monthJan.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get monthJan;

  /// No description provided for @monthFeb.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get monthFeb;

  /// No description provided for @monthMar.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get monthMar;

  /// No description provided for @monthApr.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get monthApr;

  /// No description provided for @monthMayAbbr.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthMayAbbr;

  /// No description provided for @monthJun.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get monthJun;

  /// No description provided for @monthJul.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get monthJul;

  /// No description provided for @monthAug.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get monthAug;

  /// No description provided for @monthSep.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get monthSep;

  /// No description provided for @monthOct.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get monthOct;

  /// No description provided for @monthNov.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get monthNov;

  /// No description provided for @monthDec.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get monthDec;

  /// No description provided for @statsStepsAvg.
  ///
  /// In en, this message translates to:
  /// **'Average: {value} steps'**
  String statsStepsAvg(Object value);

  /// No description provided for @statsStepsLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest: {value} steps'**
  String statsStepsLatest(Object value);

  /// No description provided for @statsWeightAvgKg.
  ///
  /// In en, this message translates to:
  /// **'Average: {value} kg'**
  String statsWeightAvgKg(String value);

  /// No description provided for @statsWeightLatestKg.
  ///
  /// In en, this message translates to:
  /// **'Latest: {value} kg'**
  String statsWeightLatestKg(String value);

  /// No description provided for @statsActivityAvgKcal.
  ///
  /// In en, this message translates to:
  /// **'Average: {value} kcal'**
  String statsActivityAvgKcal(Object value);

  /// No description provided for @statsWorkoutsCount.
  ///
  /// In en, this message translates to:
  /// **'Workouts: {count}'**
  String statsWorkoutsCount(Object count);

  /// No description provided for @statsWaterAvgL.
  ///
  /// In en, this message translates to:
  /// **'Average: {value} L'**
  String statsWaterAvgL(String value);

  /// No description provided for @statsWaterLatestL.
  ///
  /// In en, this message translates to:
  /// **'Latest: {value} L'**
  String statsWaterLatestL(String value);

  /// No description provided for @statsGoalWeightKg.
  ///
  /// In en, this message translates to:
  /// **'Goal: {value} kg'**
  String statsGoalWeightKg(String value);

  /// No description provided for @statsGoalKcal.
  ///
  /// In en, this message translates to:
  /// **'Goal: {value} kcal'**
  String statsGoalKcal(Object value);

  /// No description provided for @goalAbove.
  ///
  /// In en, this message translates to:
  /// **'Goal > {value}'**
  String goalAbove(Object value);

  /// No description provided for @goalWeightKg.
  ///
  /// In en, this message translates to:
  /// **'Goal: {value} kg'**
  String goalWeightKg(String value);

  /// No description provided for @goalWaterL.
  ///
  /// In en, this message translates to:
  /// **'Goal: {value} L'**
  String goalWaterL(String value);

  /// No description provided for @goalValue.
  ///
  /// In en, this message translates to:
  /// **'Goal: {value}'**
  String goalValue(Object value);

  /// No description provided for @recipeNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Recipe name'**
  String get recipeNameLabel;

  /// No description provided for @recipeDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get recipeDescriptionLabel;

  /// No description provided for @recipeNutritionPer100g.
  ///
  /// In en, this message translates to:
  /// **'Nutrition (per 100g)'**
  String get recipeNutritionPer100g;

  /// No description provided for @fieldCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Field cannot be empty'**
  String get fieldCannotBeEmpty;

  /// No description provided for @invalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid format'**
  String get invalidFormat;

  /// No description provided for @grams.
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get grams;

  /// No description provided for @liters.
  ///
  /// In en, this message translates to:
  /// **'l'**
  String get liters;

  /// No description provided for @connectionsSection.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get connectionsSection;

  /// No description provided for @loginToAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginToAccount;

  /// No description provided for @inDevelopment.
  ///
  /// In en, this message translates to:
  /// **'In development'**
  String get inDevelopment;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @notificationMessagesSection.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationMessagesSection;

  /// No description provided for @waterReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Water reminder'**
  String get waterReminderTitle;

  /// No description provided for @waterReminderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Time and amount are calculated automatically based on your daily water goal'**
  String get waterReminderSubtitle;

  /// No description provided for @mealRemindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Meal reminders'**
  String get mealRemindersTitle;

  /// No description provided for @mealRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Breakfast, lunch and dinner at the chosen time'**
  String get mealRemindersSubtitle;

  /// No description provided for @weightReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Weigh-in reminder'**
  String get weightReminderTitle;

  /// No description provided for @weightReminderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable daily reminder to log weight'**
  String get weightReminderSubtitle;

  /// No description provided for @weightReminderTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Weigh-in reminder time'**
  String get weightReminderTimeTitle;

  /// No description provided for @appSettingsSection.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get appSettingsSection;

  /// No description provided for @changelogTitle.
  ///
  /// In en, this message translates to:
  /// **'Version history'**
  String get changelogTitle;

  /// No description provided for @userAgreementSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Data, storage and AI'**
  String get userAgreementSubtitle;

  /// No description provided for @notificationSettingsError.
  ///
  /// In en, this message translates to:
  /// **'Could not apply notification settings. Details: {error}'**
  String notificationSettingsError(Object error);

  /// No description provided for @noUpdateInfo.
  ///
  /// In en, this message translates to:
  /// **'No update information available.'**
  String get noUpdateInfo;

  /// No description provided for @connectionsAndMessages.
  ///
  /// In en, this message translates to:
  /// **'Connections and notifications'**
  String get connectionsAndMessages;

  /// No description provided for @physicalParamsInfoText.
  ///
  /// In en, this message translates to:
  /// **'Enter your basic physical parameters:\ngender, age, height and current weight.\nThis data is needed for accurate calculations\nand personalized recommendations.'**
  String get physicalParamsInfoText;

  /// No description provided for @currentWeightKg.
  ///
  /// In en, this message translates to:
  /// **'Current weight (kg)'**
  String get currentWeightKg;

  /// No description provided for @generalGoalsInfoText.
  ///
  /// In en, this message translates to:
  /// **'This section defines your main strategy:\ntarget weight and goal type (loss, gain, etc.).\nBased on this data, the app suggests\nthe appropriate nutrition direction.'**
  String get generalGoalsInfoText;

  /// No description provided for @weightGoalKg.
  ///
  /// In en, this message translates to:
  /// **'Weight goal (kg)'**
  String get weightGoalKg;

  /// No description provided for @dailyGoalsInfoText.
  ///
  /// In en, this message translates to:
  /// **'Set your daily targets:\ncalories, water, steps and macros.\nThese values are used in the diary\nto track your daily progress.'**
  String get dailyGoalsInfoText;

  /// No description provided for @aiGoalsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not fill goals with AI.'**
  String get aiGoalsFailed;

  /// No description provided for @caloriesKcal.
  ///
  /// In en, this message translates to:
  /// **'Calories (kcal)'**
  String get caloriesKcal;

  /// No description provided for @waterMl.
  ///
  /// In en, this message translates to:
  /// **'Water (ml)'**
  String get waterMl;

  /// No description provided for @proteinG.
  ///
  /// In en, this message translates to:
  /// **'Protein (g)'**
  String get proteinG;

  /// No description provided for @carbsG.
  ///
  /// In en, this message translates to:
  /// **'Carbs (g)'**
  String get carbsG;

  /// No description provided for @fatG.
  ///
  /// In en, this message translates to:
  /// **'Fat (g)'**
  String get fatG;

  /// No description provided for @addFromRecipes.
  ///
  /// In en, this message translates to:
  /// **'Add from recipes'**
  String get addFromRecipes;

  /// No description provided for @mealSummary.
  ///
  /// In en, this message translates to:
  /// **'Meal summary'**
  String get mealSummary;

  /// No description provided for @recipesInMeal.
  ///
  /// In en, this message translates to:
  /// **'Recipes in meal'**
  String get recipesInMeal;

  /// No description provided for @nothingAddedYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing added yet'**
  String get nothingAddedYet;

  /// No description provided for @pressPlusToAddFood.
  ///
  /// In en, this message translates to:
  /// **'Tap \"+\" to add a food item'**
  String get pressPlusToAddFood;

  /// No description provided for @removeRecipeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove recipe'**
  String get removeRecipeTooltip;

  /// No description provided for @nutritionValue.
  ///
  /// In en, this message translates to:
  /// **'Nutrition facts'**
  String get nutritionValue;

  /// No description provided for @minerals.
  ///
  /// In en, this message translates to:
  /// **'Minerals'**
  String get minerals;

  /// No description provided for @sodium.
  ///
  /// In en, this message translates to:
  /// **'Sodium'**
  String get sodium;

  /// No description provided for @potassium.
  ///
  /// In en, this message translates to:
  /// **'Potassium'**
  String get potassium;

  /// No description provided for @calcium.
  ///
  /// In en, this message translates to:
  /// **'Calcium'**
  String get calcium;

  /// No description provided for @iron.
  ///
  /// In en, this message translates to:
  /// **'Iron'**
  String get iron;

  /// No description provided for @vitamins.
  ///
  /// In en, this message translates to:
  /// **'Vitamins'**
  String get vitamins;

  /// No description provided for @vitaminA.
  ///
  /// In en, this message translates to:
  /// **'Vitamin A'**
  String get vitaminA;

  /// No description provided for @vitaminC.
  ///
  /// In en, this message translates to:
  /// **'Vitamin C'**
  String get vitaminC;

  /// No description provided for @vitaminD.
  ///
  /// In en, this message translates to:
  /// **'Vitamin D'**
  String get vitaminD;

  /// No description provided for @mg.
  ///
  /// In en, this message translates to:
  /// **'mg'**
  String get mg;

  /// No description provided for @mcg.
  ///
  /// In en, this message translates to:
  /// **'mcg'**
  String get mcg;

  /// No description provided for @sugarSub.
  ///
  /// In en, this message translates to:
  /// **'incl. Sugar'**
  String get sugarSub;

  /// No description provided for @fiberSub.
  ///
  /// In en, this message translates to:
  /// **'incl. Fiber'**
  String get fiberSub;

  /// No description provided for @saturatedFatSub.
  ///
  /// In en, this message translates to:
  /// **'Saturated'**
  String get saturatedFatSub;

  /// No description provided for @polyunsaturatedFatSub.
  ///
  /// In en, this message translates to:
  /// **'Polyunsaturated'**
  String get polyunsaturatedFatSub;

  /// No description provided for @monounsaturatedFatSub.
  ///
  /// In en, this message translates to:
  /// **'Monounsaturated'**
  String get monounsaturatedFatSub;

  /// No description provided for @transFatSub.
  ///
  /// In en, this message translates to:
  /// **'Trans fat'**
  String get transFatSub;

  /// No description provided for @cholesterolSub.
  ///
  /// In en, this message translates to:
  /// **'Cholesterol'**
  String get cholesterolSub;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionLabel(String version);

  /// No description provided for @appLogs.
  ///
  /// In en, this message translates to:
  /// **'App logs'**
  String get appLogs;

  /// No description provided for @noLogs.
  ///
  /// In en, this message translates to:
  /// **'No logs available'**
  String get noLogs;

  /// No description provided for @weightUnit.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get weightUnit;

  /// No description provided for @editActivity.
  ///
  /// In en, this message translates to:
  /// **'Edit activity'**
  String get editActivity;

  /// No description provided for @newActivity.
  ///
  /// In en, this message translates to:
  /// **'New activity'**
  String get newActivity;

  /// No description provided for @activityIcon.
  ///
  /// In en, this message translates to:
  /// **'Activity icon'**
  String get activityIcon;

  /// No description provided for @activityNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Activity name'**
  String get activityNameLabel;

  /// No description provided for @burnedCaloriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Calories burned'**
  String get burnedCaloriesLabel;

  /// No description provided for @enterActivityName.
  ///
  /// In en, this message translates to:
  /// **'Enter activity name'**
  String get enterActivityName;

  /// No description provided for @enterCorrectCalories.
  ///
  /// In en, this message translates to:
  /// **'Enter valid calories'**
  String get enterCorrectCalories;

  /// No description provided for @activityLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activityLogTitle;

  /// No description provided for @activityInfoText.
  ///
  /// In en, this message translates to:
  /// **'Here you log all activities for the selected day.\nThis data helps calculate burned calories more accurately\nand affects the daily balance in the diary and analytics.'**
  String get activityInfoText;

  /// No description provided for @totalBurned.
  ///
  /// In en, this message translates to:
  /// **'Total burned'**
  String get totalBurned;

  /// No description provided for @activityRecordsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} records'**
  String activityRecordsCount(int count);

  /// No description provided for @noActivities.
  ///
  /// In en, this message translates to:
  /// **'No activities yet'**
  String get noActivities;

  /// No description provided for @deleteActivity.
  ///
  /// In en, this message translates to:
  /// **'Delete activity'**
  String get deleteActivity;

  /// No description provided for @enterCorrectNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number (0 or more)'**
  String get enterCorrectNumber;

  /// No description provided for @waterGoalText.
  ///
  /// In en, this message translates to:
  /// **'Goal: {value} L'**
  String waterGoalText(String value);

  /// No description provided for @litersValue.
  ///
  /// In en, this message translates to:
  /// **'{value} L'**
  String litersValue(String value);

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @pedometerTitle.
  ///
  /// In en, this message translates to:
  /// **'Pedometer'**
  String get pedometerTitle;

  /// No description provided for @stepsCountValue.
  ///
  /// In en, this message translates to:
  /// **'{count} steps'**
  String stepsCountValue(int count);

  /// No description provided for @enterValue.
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get enterValue;

  /// No description provided for @kgValue.
  ///
  /// In en, this message translates to:
  /// **'{value} kg'**
  String kgValue(String value);

  /// No description provided for @kcalValue.
  ///
  /// In en, this message translates to:
  /// **'{value} kcal'**
  String kcalValue(String value);

  /// No description provided for @ingredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get ingredients;

  /// No description provided for @nutritionValuePerPortion.
  ///
  /// In en, this message translates to:
  /// **'Nutrition facts (per portion)'**
  String get nutritionValuePerPortion;

  /// No description provided for @mainNutrients.
  ///
  /// In en, this message translates to:
  /// **'Main Nutrients'**
  String get mainNutrients;

  /// No description provided for @addOneMoreToMeal.
  ///
  /// In en, this message translates to:
  /// **'Add one more to meal'**
  String get addOneMoreToMeal;

  /// No description provided for @editRecipeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit recipe'**
  String get editRecipeTooltip;

  /// No description provided for @recommendedShort.
  ///
  /// In en, this message translates to:
  /// **'Rec'**
  String get recommendedShort;

  /// No description provided for @clearSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearchTooltip;

  /// No description provided for @deselect.
  ///
  /// In en, this message translates to:
  /// **'Deselect'**
  String get deselect;

  /// No description provided for @addMore.
  ///
  /// In en, this message translates to:
  /// **'Add more'**
  String get addMore;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;
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
