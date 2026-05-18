import os
import re
import glob

panels_dir = r"c:\Development\Music\Project\lib\screens\visual_editor\panels"

# Patterns to match Text('TITLE' or Text(AppToolWindows.getDef('id').name.toUpperCase()
# and fontWeight: FontWeight.bold

def title_case(s):
    # simple title casing
    return " ".join([word.capitalize() for word in s.split()])

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content

    # Replace hardcoded 'UPPERCASE STRING' in Text widget before titleBarTextPrimary
    # e.g. Text('AGENTS', style: TextStyle(color: AppColors.titleBarTextPrimary
    def repl_text_string(m):
        full_text = m.group(0)
        title_str = m.group(1) # 'AGENTS'
        rest = m.group(2)
        
        # Convert 'AGENTS' to 'Agents'
        formatted_title = title_case(title_str.lower())
        
        return f"Text(AppUIConfig.formatWindowTitle('{formatted_title}'){rest}"
        
    content = re.sub(r"Text\('([A-Z0-9\s&]+)'(,[\s]*style:[\s]*TextStyle\([\s]*color:[\s]*AppColors\.titleBarTextPrimary)", repl_text_string, content)

    # Replace AppToolWindows.getDef('id').name.toUpperCase()
    def repl_getdef(m):
        getdef_code = m.group(1) # AppToolWindows.getDef('id').name
        rest = m.group(2)
        return f"Text(AppUIConfig.formatWindowTitle({getdef_code}){rest}"
        
    content = re.sub(r"Text\((AppToolWindows\.getDef\('[a_z_]+'\)\.name)\.toUpperCase\(\)(,[\s]*style:[\s]*TextStyle\([\s]*color:[\s]*AppColors\.titleBarTextPrimary)", repl_getdef, content)

    # Now replace fontWeight: FontWeight.bold to fontWeight: AppUIConfig.windowTitleFontWeight
    # ONLY inside the TextStyle that has titleBarTextPrimary.
    # We can do a more general replace around AppColors.titleBarTextPrimary
    
    def repl_fontweight(m):
        prefix = m.group(1)
        return f"{prefix}fontWeight: AppUIConfig.windowTitleFontWeight"
        
    content = re.sub(r"(color:[\s]*AppColors\.titleBarTextPrimary.*?)(?:fontWeight:[\s]*FontWeight\.bold)", repl_fontweight, content, flags=re.DOTALL)

    if content != original:
        print(f"Updated {os.path.basename(filepath)}")
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)

for filepath in glob.glob(os.path.join(panels_dir, "*.dart")):
    process_file(filepath)
