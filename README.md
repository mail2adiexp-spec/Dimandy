# E-Commerce App

A Flutter e-commerce app with Firebase integration: realtime product catalog from Firestore, multi-image uploads to Storage via an Admin Panel, and cart/checkout using Provider for state management.

## Features

- Home screen shows realtime products from Firestore
- Category filter chips and search by name/description
- Admin Panel to add products with 4–6 images (uploads to Firebase Storage)
- Gifts management (admin): create/edit/delete gift items with image, price, active flag, ordering
- Product details page with images, description, and INR price
- Add to Cart from product cards or details
- Cart screen with quantity controls (+/−), remove item, and total amount
- Checkout screen with basic address fields and “Place Order” flow (clears cart)
- Role-based dashboards (Seller, Service Provider, etc.)
- Partner request flow with service category assignment
- Admin user management: edit, role change, delete (Cloud Function + Firestore fallback)

## Tech

- Flutter (Material 3)
- Firebase (Core, Auth, Firestore, Storage, optional Cloud Functions)
- Provider for app state (`CartProvider`, `ProductProvider`) with SharedPreferences persistence

## Run locally

1. Install Flutter SDK and set it on your PATH.
2. From the project folder run:

```powershell
flutter pub get
flutter run
```

To run tests:

```powershell
flutter test
```

If you see a Flutter SDK not found error on Windows, add Flutter to PATH (Control Panel → System → Advanced System Settings → Environment Variables) and restart your terminal.

## Cloud Functions (optional advanced setup)

To enable full user deletion (Auth + Firestore) and secure role updates, deploy the callable functions in `functions/index.js`.

### 1. Prerequisites
Install Node.js (>= 18), Firebase CLI, and authenticate:
```powershell
npm install -g firebase-tools
firebase login
```

### 2. Initialize (if needed)
If the `functions/` folder wasn't created by `firebase init`:
```powershell
firebase init functions
```
Choose JavaScript and keep existing `index.js` (do not overwrite).

### 3. Set project & region
```powershell
firebase use your-project-id
```
Default region assumed: `us-central1`. If you deploy elsewhere, update the region in `admin_panel_screen.dart`.

### 4. Deploy
```powershell
firebase deploy --only functions:deleteUserAccount,functions:updateUserRole
```

### 5. Test via shell
```powershell
firebase functions:shell
```
Then:
```
deleteUserAccount({ userId: "UID", email: "user@example.com" })
```

### 6. Refresh custom claims
After role change to admin:
```dart
await FirebaseAuth.instance.currentUser?.getIdToken(true);
```

### 7. Fallback behavior
If the callable fails (UNIMPLEMENTED / permission / region mismatch), the app deletes Firestore documents only, leaving the Auth record.

### 8. Emulator (optional)
```powershell
firebase emulators:start --only functions,firestore,auth
```

### 9. Common errors
| Error | Cause | Fix |
|-------|-------|-----|
| UNIMPLEMENTED | Wrong region / not deployed | Deploy & match region |
| permission-denied | Missing admin claim | Assign role + refresh token |
| deadline-exceeded | Slow queries | Optimize / increase timeout |

### 10. Redeploy after changes
```powershell
firebase deploy --only functions
```

## Project structure

- `lib/models/product_model.dart` – Product data model (multi-image, categories, unit)
- `lib/providers/cart_provider.dart` – Cart state (items, qty, totals)
- `lib/providers/product_provider.dart` – Firestore realtime products + CRUD
- `lib/widgets/product_card.dart` – Product tile with Add to Cart
- `lib/screens/home_screen.dart` – Product grid and Cart badge
- `lib/screens/product_detail_screen.dart` – Product details and Add to Cart
- `lib/screens/cart_screen.dart` – Cart list, qty controls, total
- `lib/screens/checkout_screen.dart` – Checkout summary and place order
 - `lib/screens/admin_panel_screen.dart` – Admin Panel to add/edit products
 - `functions/index.js` – Callable Cloud Functions for privileged user deletion & role updates

## Changelog

- v1.3.6
	- Admin: Added Gifts tab with multi-image upload (4-6 images required, similar to products)
	- Gift model: Support for imageUrls array with backward compatibility
	- Gifts CRUD: Add/edit/delete with image grid picker, ordering, active toggle
	- Firestore/Storage rules: Restricted gifts collection write to admins only
	- Minor lint cleanup (removed unused imports, replaced MaterialStatePropertyAll with WidgetStatePropertyAll, print → debugPrint in gift_provider)

- v1.3.5
	- Admin: User delete flow now tries Cloud Function (Auth + Firestore) with automatic Firestore-only fallback when Functions are unavailable (desktop/dev).
	- Cloud Functions region fixed to `us-central1` in app call to avoid UNIMPLEMENTED errors.
	- Docs: Added complete Cloud Functions setup, deploy, and troubleshooting guide.

- v1.3.0
	- AppBar redesign: user icon left, centered app name, theme toggle + cart on right
	- Theme mode toggle with persistence via SharedPreferences
	- Search bar redesign: smaller, rounded, camera capture hook (rear camera)
	- Categories on Home from Firestore with images and ordering
	- Admin Panel: Categories tab with add/edit/delete, reorder, and image upload to Storage
	- Firebase rules guidance for dev (Firestore/Storage) to allow category management
	- Auth flow: after login/sign-up, returns to Home
	- UI polish for category grid (card sizing, label outside, larger bold text)
- v1.2.1
	- Home wired to Firestore-backed products via ProductProvider
	- Category filter chips and live search on Home
- v1.2.0
	- Admin Panel added with multi-image product upload (min 4 images)
	- Firestore integration for products with categories and units
	- Firebase Storage uploads and rules updates

Feel free to extend this app with real APIs, authentication, payments, and persistence.
