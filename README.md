# My Flutter App

A modern and feature-rich Flutter application designed to showcase a variety of native capabilities and provide a smooth user experience.

## ✨ Features

This application integrates several powerful packages to deliver a robust feature set:

-   **🌐 In-App Web Browser:** Utilizes `webview_flutter` to seamlessly display web content within the app.
-   **🔒 Runtime Permissions:** Employs `permission_handler` to gracefully request and handle necessary device permissions (e.g., camera, location, storage).
-   **📶 Connectivity Monitoring:** Uses `connectivity_plus` to monitor the device's network state and adapt the app's behavior accordingly.
-   **💾 Local Data Persistence:** Leverages `shared_preferences` to store simple key-value data locally, such as user settings or session information.
-   **📁 File Selection:** Integrates `file_picker` to allow users to easily select files from their device storage.

## 🚀 Getting Started

Follow these instructions to get a copy of the project up and running on your local machine for development and testing.

### Prerequisites

You need to have the Flutter SDK installed on your machine. For instructions on how to install Flutter, please see the [official Flutter documentation](https://docs.flutter.dev/get-started/install).

### Installation & Setup

1.  **Clone the repository** or download the source code.
2.  **Navigate to the project directory** in your terminal.
3.  **Install dependencies** by running the following command:
    ```bash
    flutter pub get
    ```

### Running the Application

To run the application, use the following command with a connected device or an open emulator:

```bash
flutter run
```

### `android_build.yml` (Manual Build)

This workflow is designed to build the Android application and generate a release-ready App Bundle (`.aab`).

-   **Trigger:** This workflow is triggered manually via the `workflow_dispatch` event from the GitHub Actions UI.
-   **Process:**
    1.  Sets up the build environment on an `ubuntu-latest` runner.
    2.  Builds the Android App Bundle using the `flutter build appbundle` command.
    3.  Uploads the generated `.aab` file as a build artifact, making it available for download and for publishing to the Google Play Store.

### `ios_build.yml` (Manual Build)

This workflow is responsible for building the iOS application.

-   **Trigger:** This workflow is also triggered manually using `workflow_dispatch`.
-   **Process:**
    1.  Sets up the build environment on a `macos-latest` runner, which is required for iOS builds.
    2.  Builds the iOS application using the `flutter build ios --release --no-codesign` command. The `--no-codesign` flag is used as code signing will typically be handled later in the distribution process (e.g., via Xcode or a dedicated CD service).
    3.  Uploads the resulting `Runner.app` directory as a build artifact.

## 📦 Core Packages

-   `flutter`
-   `webview_flutter`
-   `permission_handler`
-   `connectivity_plus`
-   `shared_preferences`
-   `file_picker`
-   `flutter_lints`
