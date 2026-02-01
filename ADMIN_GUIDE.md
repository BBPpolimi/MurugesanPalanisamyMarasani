# Admin Management Guide

This guide explains how to manage administrator access and moderation tools for the **Best Bike Paths** application.

## 🛡️ Security Overview

Access to admin features is controlled on three levels:
1.  **Firestore Rules (Server-side):** The database strictly prevents non-admins from creating/reading/updating restricted data (audit logs, blocked users).
2.  **AppUser Model (Logic-side):** The app checks the user's `role` field (`admin` vs `user`).
3.  **UI Checks (Client-side):** The Admin Panel is hidden and inaccessible to non-admin users.

## 👑 Promoting a User to Admin

Since there is no "super-admin" UI in the app itself (for security reasons), promoting a user to an Admin role must be done via the **Firebase Console**.

**Steps:**
1.  Go to the [Firebase Console](https://console.firebase.google.com/).
2.  Navigate to **Firestore Database**.
3.  Open the `users` collection.
4.  Find the document for the user you want to promote (using their User ID).
5.  Update the `role` field to `admin` (string).
    *   *If the field doesn't exist, add it.*
    *   **Field:** `role`
    *   **Value:** `admin`
6.  Ask the user to **restart the app**.

## 🚫 Demoting an Admin

To remove admin access:
1.  Find the user in the `users` collection in Firestore.
2.  Change the `role` field to `user` (or delete the field).
3.  The user will lose access immediately (server-side) and upon next app restart (client-side UI).

## 🛠️ Admin Features

Once a user is an admin, they can access the **Admin Review** panel to:
- **Flag/Remove Contributions**: Hide or delete inappropriate content.
- **Block Users**: Prevent specific users from contributing new content.
- **View Audit Logs**: See a history of all administrative actions.

## 🔒 Safety Measures

- **Self-Promotion Prevention**: Normal users CANNOT update their own `role` field to become admins. The database rules block this specific action.
- **Blocked Users**: Blocked users can still view public content but cannot add new paths, reports, or obstacles.
