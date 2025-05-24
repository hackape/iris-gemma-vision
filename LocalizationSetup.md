 # Internationalization (i18n) Setup Guide

## How to complete the setup in Xcode

### 1. Add Localization Support to Your Project

1. Open your project in Xcode
2. Select the project root in the navigator
3. Select your app target
4. Go to the "Info" tab
5. Under "Localizations", click the "+" button
6. Add:
   - **English** (if not already added)
   - **Chinese (Simplified)** 

### 2. Add the Localizable.strings files to your project

1. In Xcode, right-click on your `Iris` folder
2. Select "Add Files to 'Iris'"
3. Add both:
   - `Iris/en.lproj/Localizable.strings`
   - `Iris/zh-Hans.lproj/Localizable.strings`

### 3. Verify localization setup

1. In Xcode, select `Localizable.strings` in the navigator
2. In the File Inspector (right panel), you should see "Localization" section
3. Make sure both English and Chinese (Simplified) are checked

## How VoiceOver will now work

- **Automatic language detection**: VoiceOver will use the user's system language preference
- **No hardcoded languages**: The app respects whatever language the user has set
- **Proper pronunciation**: VoiceOver will automatically use the correct speech synthesizer based on the localized text

## Testing different languages

1. **Change device language**:
   - Settings → General → Language & Region → iPhone Language
   - Select Chinese (Simplified) or English
   - Restart the app

2. **Test VoiceOver**:
   - Enable VoiceOver in Settings → Accessibility → VoiceOver
   - Navigate through your app
   - VoiceOver should read text in the correct language with proper pronunciation

## Adding more languages

To add support for more languages (e.g., Japanese, Spanish):

1. Create new `.lproj` folders:
   - `ja.lproj/Localizable.strings` (Japanese)
   - `es.lproj/Localizable.strings` (Spanish)

2. Copy the English strings file and translate the values

3. Add the languages to your Xcode project localization settings

## Key Benefits

- ✅ **Universal**: Works with any language the user prefers
- ✅ **Automatic**: No manual language detection needed
- ✅ **VoiceOver friendly**: Proper pronunciation for all supported languages
- ✅ **Maintainable**: Easy to add new languages
- ✅ **iOS standard**: Uses Apple's recommended i18n approach