import sys
import os

file_path = r'c:\Users\souna\DEMANDY\ecommerce_app\lib\widgets\shared_products_tab.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    # Fix Add Product area
    if 'Product added successfully' in line and i + 2 < len(lines) and 'setState(() => isLoading = false)' in lines[i+3]:
        new_lines.append(line)
        new_lines.append('                               }\n')
        new_lines.append('                             } catch (e) {\n')
        i += 2 # Skip the mangled gap
    # Fix Bulk Edit area
    elif '_isProductSelectionMode = false;' in line and i + 3 < len(lines) and 'if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(\'Error: $e\')' in lines[i+3]:
        new_lines.append(line)
        new_lines.append('                                   });\n')
        new_lines.append('                               } catch (e) {\n')
        i += 3 # Skip the mangled gap
    else:
        new_lines.append(line)
    i += 1

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("Fixed mangled try-catch blocks in shared_products_tab.dart")
