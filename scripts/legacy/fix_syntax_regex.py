import sys
import re

file_path = r'c:\Users\souna\DEMANDY\ecommerce_app\lib\widgets\shared_products_tab.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix Add Product: Look for 'Product added successfully' followed by some braces and then 'setState' with '$e'
pattern_add = r'(ScaffoldMessenger\.of\(context\)\.showSnackBar\(const SnackBar\(content: Text\(\'Product added successfully\'\)\)\);\s*\}\s*)\s*(setState\(\(\) => isLoading = false\);\s*if \(mounted\) ScaffoldMessenger\.of\(context\)\.showSnackBar\(SnackBar\(content: Text\(\'Error: \$e\'\)\)\);\s*\})'
replacement_add = r'\1} catch (e) {\2'

# Fix Bulk Edit: Look for '_isProductSelectionMode = false;' followed by some braces and then 'if' with '$e'
pattern_bulk = r'(_isProductSelectionMode = false;\s*\}\s*)\s*(if \(mounted\) ScaffoldMessenger\.of\(context\)\.showSnackBar\(SnackBar\(content: Text\(\'Error: \$e\'\)\)'
replacement_bulk = r'\1} catch (e) {\2'

new_content = re.sub(pattern_add, replacement_add, content)
new_content = re.sub(pattern_bulk, replacement_bulk, new_content)

if new_content != content:
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("Fixed syntax in shared_products_tab.dart using regex.")
else:
    print("Regex could not find the target patterns.")
