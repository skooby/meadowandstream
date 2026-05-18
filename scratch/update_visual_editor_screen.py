import os
import re

filepath = r"c:\Development\Music\Project\lib\screens\visual_editor\visual_editor_screen.dart"

def title_case(s):
    # Some special casing if needed, else normal
    words = s.split()
    return " ".join([word.capitalize() for word in words])

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

def repl(m):
    id_str = m.group(1)
    uppercase_title = m.group(2)
    rest = m.group(3)
    
    # Example: 'PROJECT CONFIGURATION (FIXED)'
    if " (FIXED)" in uppercase_title:
        title_to_convert = uppercase_title.replace(" (FIXED)", "")
        new_title = title_case(title_to_convert.lower()) + " (Fixed)"
    else:
        new_title = title_case(uppercase_title.lower())
        
    return f"('{id_str}', '{new_title}',{rest}"

# Fixed the character class: a-z instead of a_z
new_content = re.sub(r"\('([a-z_]+)',\s*'([A-Z0-9\s\(\)]+)',(.*?)", repl, content)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(new_content)
print("Done!")
