import os
import re
import glob

panels_dir = r"c:\Development\Music\Project\lib\screens\visual_editor\panels"

def title_case(s):
    return " ".join([word.capitalize() for word in s.split()])

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content

    def repl_text_string(m):
        full_text = m.group(0)
        title_str = m.group(1)
        rest = m.group(2)
        formatted_title = title_case(title_str.lower())
        return f"Text(AppUIConfig.formatWindowTitle('{formatted_title}'){rest}"
        
    content = re.sub(r"Text\('([A-Z0-9\s&]+)'(,[\s]*style:[\s]*TextStyle\([\s]*color:[\s]*AppColors\.titleBarTextPrimary)", repl_text_string, content)

    def repl_getdef(m):
        getdef_code = m.group(1)
        rest = m.group(2)
        return f"Text(AppUIConfig.formatWindowTitle({getdef_code}){rest}"
        
    content = re.sub(r"Text\((AppToolWindows\.getDef\('[a-zA-Z_]+'\)\.name)\.toUpperCase\(\)(,[\s]*style:[\s]*TextStyle\([\s]*color:[\s]*AppColors\.titleBarTextPrimary)", repl_getdef, content)

    # I'll also do a general replace just in case some are Text('Note' ... instead of 'NOTE'
    # but the previous one did ([A-Z0-9\s&]+) which only matched ALL CAPS.
    def repl_text_string_any(m):
        title_str = m.group(1)
        rest = m.group(2)
        if "AppUIConfig.formatWindowTitle" in title_str:
            return m.group(0)
        formatted_title = title_case(title_str.lower())
        return f"Text(AppUIConfig.formatWindowTitle('{formatted_title}'){rest}"

    content = re.sub(r"Text\('([^']+)'(,[\s]*style:[\s]*TextStyle\([\s]*color:[\s]*AppColors\.titleBarTextPrimary)", repl_text_string_any, content)

    # For fontWeight, I already replaced fontWeight: FontWeight.bold to fontWeight: AppUIConfig.windowTitleFontWeight.
    # But just in case some files were missed because they didn't have bold, wait, the user said "Not working for Backup, Flow Editor, Assets..."
    # The title text wasn't changing because it still had `.toUpperCase()` or hardcoded uppercase!

    if content != original:
        print(f"Updated {os.path.basename(filepath)}")
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)

for filepath in glob.glob(os.path.join(panels_dir, "*.dart")):
    process_file(filepath)
