# Trackingapp

Trackingapp is a Flutter app that shows how much of the current year has passed.
It includes a progress view, a calendar view, and settings for switching between
the normal calendar year and a custom one-year cycle.

## Features

- Animated year completion progress bar
- Calendar view for the active year cycle
- Toggle between the standard calendar year and a custom start date
- Material 3 interface with a dark theme

## Screens

- Progress: shows the percentage of the active year cycle that has elapsed
- Calendar: displays the months in the active cycle and scrolls toward the current month
- Settings: lets you choose a normal or custom year start date

## Requirements

- Flutter SDK
- Dart SDK
- A configured device or emulator for the target platform

## Run Locally

```bash
flutter pub get
flutter run
```

## Test

```bash
flutter test
flutter analyze
```

## Project Structure

```text
lib/main.dart        Main application UI and year-cycle logic
test/widget_test.dart    Widget tests for progress, calendar, and settings flows
```

## Notes

- The default mode tracks January 1 through December 31.
- Custom mode starts on a chosen date and ends on the same date in the following year.
