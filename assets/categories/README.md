# Category Images

Category icons ko images se replace karne ke liye yahan par images add karein:

## Required Images (PNG format, 512x512 ya 256x256 recommended):

1. `all.png` - All categories icon
2. `cold_drinks.png` - Cold drinks category
3. `snacks.png` - Snacks category
4. `daily_needs.png` - Daily needs category
5. `customer_choice.png` - Customer choice category
6. `hot_deals.png` - Hot deals category
7. `rice_ata.png` - Rice & Ata category
8. `cooking_oils.png` - Cooking oils category
9. `fast_food.png` - Fast food category

## Image Guidelines:
- Format: PNG with transparent background
- Size: 256x256 or 512x512 pixels
- File size: Keep under 100KB each for fast loading
- Style: Simple, flat design icons that match your app theme

## Steps to Add Images:

1. Create/download 9 category images
2. Save them in: `ecommerce_app/assets/categories/`
3. Name them exactly as listed above
4. Run: `flutter pub get`
5. Run your app

## Temporary Fallback:
If images are not found, app will show default icon (no error).
