# Task App - Frontend

A modern, offline-first Task Management application built with Flutter.

## 🚀 Features

-   **User Authentication**: Secure login and signup.
-   **Task Management**: Create, Update, Delete, and Complete tasks.
-   **Offline Support**: Works without internet using SQLite. Automatically syncs with the backend when online.
-   **Smart Notifications**:
    -   Reminder 12 hours before the task is due.
    -   Notification at the exact due time.
    -   Overdue alert 1 hour after the deadline if the task is still incomplete.
-   **Theme Support**: Toggle between Light and Dark modes.
-   **Date-wise Filtering**: View tasks for specific dates using a horizontal date selector.
-   **Categorized Views**: Separate pages for All, Completed, and Incomplete tasks.

## 🛠️ Technical Details

-   **State Management**: Bloc/Cubit
-   **Local Database**: SQLite (`sqflite`)
-   **Remote API**: Node.js/MongoDB (via `http`)
-   **Notifications**: `flutter_local_notifications` with Timezone support.
-   **Icons**: Material Icons and custom Cera Pro fonts.

## 📖 User Manual

### 1. Getting Started
-   Upon launching the app, log in or create a new account.
-   The home screen displays your tasks for the current day.

### 2. Managing Tasks
-   **Add Task**: Tap the `+` button, enter the title, description, choose a color, and set a due date/time.
-   **Complete Task**: On the home screen, tap the `more_vert` (three dots) icon next to a task and select **Complete Task**. Alternatively, find it in the "Pending" tab and tap the check icon.
-   **Delete Task**: Tap the `more_vert` icon and select **Delete Task**, or use the delete icon in the "Completed" tab.
-   **View Details**: Tasks are color-coded based on your selection.

### 3. Notifications
-   The app automatically schedules reminders for every task you create.
-   Ensure you grant notification and exact alarm permissions when prompted for the best experience.
-   If a task is marked as completed, its pending notifications are automatically cancelled.

### 4. Offline Sync
-   You can add or modify tasks while offline.
-   The app will automatically sync your changes to the server once an active internet connection is detected.
-   The sync status is managed internally to ensure no data loss.

## ⚙️ Installation

1.  **Clone the repository**:
    ```bash
    git clone <repository-url>
    ```
2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```
3.  **Run the app**:
    ```bash
    flutter run
    ```

---
*Developed with ❤️ Anibesh & shubham*
