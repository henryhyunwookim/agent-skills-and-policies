import os
import sys
import re

def natural_sort_key(s):
    """
    Key function for natural sorting (numerical sorting).
    Splits string into numeric and non-numeric components to compare them appropriately.
    For example: 'img10.png' -> ['img', 10, '.png']
    """
    # Extract only the filename base to perform sorting, avoiding directory path interference
    filename = os.path.basename(s)
    return [int(text) if text.isdigit() else text.lower() for text in re.split(r'(\d+)', filename)]

def main():
    # Force stdout to output UTF-8 to handle non-ASCII directory paths correctly on Windows
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')
        
    if len(sys.argv) < 2:
        print("Usage: python sort_images.py <directory_path>", file=sys.stderr)
        sys.exit(1)
        
    directory = sys.argv[1]
    if not os.path.isdir(directory):
        print(f"Error: Directory '{directory}' does not exist.", file=sys.stderr)
        sys.exit(1)
        
    # Standard image extensions to scan for
    image_extensions = ('.png', '.jpg', '.jpeg', '.webp', '.bmp', '.tiff', '.gif')
    image_files = []
    
    try:
        for filename in os.listdir(directory):
            if filename.lower().endswith(image_extensions):
                image_files.append(filename)
    except Exception as e:
        print(f"Error reading directory: {e}", file=sys.stderr)
        sys.exit(1)
            
    # Sort files naturally
    image_files.sort(key=natural_sort_key)
    
    # Print the sorted absolute paths
    for filename in image_files:
        full_path = os.path.abspath(os.path.join(directory, filename))
        # Use forward slashes for cross-platform/JSON/agent compatibility
        normalized_path = full_path.replace(os.sep, '/')
        print(normalized_path)

if __name__ == '__main__':
    main()
