from PIL import Image
import os

# Paths
source_icon_path = r"c:/Users/souna/DEMANDY/ecommerce_app/assets/app_icon.png"
web_icons_dir = r"c:/Users/souna/DEMANDY/ecommerce_app/web/icons"

# Target sizes for maskable icons
targets = [
    (192, "Icon-maskable-192.png"),
    (512, "Icon-maskable-512.png")
]

def create_maskable_icon(source_path, output_path, target_size, padding_percent=0.25):
    """
    Creates a maskable icon by adding padding around the source image.
    padding_percent: 0.25 means 25% padding on each side (image becomes 50% of canvas).
                     Standard recommendation is ensuring logo is within safe zone (d * 0.8).
                     So reducing image to ~60-70% of canvas is usually safe.
    """
    try:
        # Open source
        img = Image.open(source_path).convert("RGBA")
        
        # Calculate new image size based on padding (keeping aspect ratio)
        # We want the content to fit within a 'safe zone'.
        # For maskable icons, the safe zone is a circle with diameter 80% of the canvas.
        # So we resize the image to fit entirely within that 80% circle.
        # Let's resize the image to be 70% of the canvas size to be super safe and look good.
        
        content_scale = 0.70
        new_width = int(target_size * content_scale)
        new_height = int(target_size * content_scale)
        
        img_resized = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
        
        # Create a white canvas
        canvas = Image.new("RGBA", (target_size, target_size), "WHITE")
        
        # Calculate position to center the image
        x = (target_size - new_width) // 2
        y = (target_size - new_height) // 2
        
        # Paste the resized image onto the canvas
        canvas.paste(img_resized, (x, y), img_resized)
        
        # Save
        canvas.save(output_path, "PNG")
        print(f"Generated {output_path}")
        
    except Exception as e:
        print(f"Error creating {output_path}: {e}")

# Run generation
if os.path.exists(source_icon_path):
    for size, filename in targets:
        output_full_path = os.path.join(web_icons_dir, filename)
        create_maskable_icon(source_icon_path, output_full_path, size)
else:
    print(f"Source file not found: {source_icon_path}")
