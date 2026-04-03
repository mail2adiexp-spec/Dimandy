import sys
import re

file_path = r'c:\Users\souna\DEMANDY\ecommerce_app\lib\widgets\shared_products_tab.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Pattern to find the uploadImages function
pattern = r'Future<List<String>> uploadImages\(String productId\) async \{.*?return imageUrls;\s*\}'

# New implementation for the function
replacement = """Future<List<String>> uploadImages(String productId) async {
    List<String> imageUrls = [];
    for (int i = 0; i < _selectedImages.length; i++) {
        final ref = FirebaseStorage.instance.ref().child('products').child(productId).child('image_$i.jpg');
        await ref.putData(_selectedImages[i], SettableMetadata(contentType: 'image/jpeg'));
        final url = await ref.getDownloadURL();
        imageUrls.add(url);
    }
    return imageUrls;
  }"""

new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)

if new_content != content:
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("Successfully updated uploadImages function.")
else:
    print("Could not find or update the function.")
