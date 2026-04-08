from PIL import Image
import os
import shutil

source_path = r"C:/Users/souna/.gemini/antigravity/brain/8556d265-8183-4270-8d35-5d754c2a7437/uploaded_media_1769602563591.jpg"
asset_path = r"c:/Users/souna/DEMANDY/ecommerce_app/assets/app_icon.png"
web_favicon_path = r"c:/Users/souna/DEMANDY/ecommerce_app/web/favicon.png"

try:
    img = Image.open(source_path)
    # Save as assets/app_icon.png
    img.save(asset_path, "PNG")
    print(f"Successfully saved {asset_path}")
    
    # Save as available favicon (resize if huge, but 512x512 is fine for modern favicons, usually they are 32x32 or 16x16, but flutter web uses consistent ones)
    # Let's resize for favicon just to be safe/standard
    img.resize((192, 192)).save(web_favicon_path, "PNG")
    print(f"Successfully saved {web_favicon_path}")
    
except Exception as e:
    print(f"Error processing image: {e}")
