import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/control_type_model.dart';

class ControlTypeRegistry extends ChangeNotifier {
  static final ControlTypeRegistry instance = ControlTypeRegistry._();

  List<CustomControlType> _types = [];
  List<CustomControlType> get types => List.unmodifiable(_types);

  ControlTypeRegistry._();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('custom_control_types');
    if (data != null) {
      try {
        final List list = jsonDecode(data);
        _types = list.map((e) => CustomControlType.fromJson(e)).toList();
      } catch (e) {
        _loadDefaults();
      }
    } else {
      _loadDefaults();
    }
    notifyListeners();
  }

  void _loadDefaults() {
    _types = [
      // Base Types
      CustomControlType(id: 'text_input', label: 'Text Input', icon: Icons.text_fields, constraintKeys: ['maxLength']),
      CustomControlType(id: 'text_input_single', label: 'Single Line Text', icon: Icons.short_text, parentType: 'text_input', constraintKeys: ['maxLength']),
      CustomControlType(id: 'text_input_multi', label: 'Multi Line Text', icon: Icons.notes, parentType: 'text_input', constraintKeys: ['maxLength']),
      CustomControlType(id: 'text_input_password', label: 'Password', icon: Icons.password, parentType: 'text_input', constraintKeys: ['maxLength']),

      CustomControlType(id: 'number_input', label: 'Number Input', icon: Icons.numbers, constraintKeys: ['min', 'max']),
      CustomControlType(id: 'number_field', label: 'Number Field', icon: Icons.pin, parentType: 'number_input', constraintKeys: ['min', 'max']),
      CustomControlType(id: 'slider', label: 'Slider', icon: Icons.linear_scale, parentType: 'number_input', constraintKeys: ['min', 'max']),
      CustomControlType(id: 'stepper', label: 'Stepper', icon: Icons.unfold_more, parentType: 'number_input', constraintKeys: ['min', 'max']),

      CustomControlType(id: 'toggle', label: 'Toggle/Checkbox', icon: Icons.check_box),
      CustomControlType(id: 'checkbox', label: 'Checkbox', icon: Icons.check_box_outline_blank, parentType: 'toggle'),
      CustomControlType(id: 'switch', label: 'Switch', icon: Icons.toggle_on, parentType: 'toggle'),
      CustomControlType(id: 'radio', label: 'Radio Button', icon: Icons.radio_button_checked, parentType: 'toggle'),

      CustomControlType(id: 'dropdown', label: 'Dropdown', icon: Icons.arrow_drop_down_circle),
      CustomControlType(id: 'select', label: 'Select', icon: Icons.arrow_drop_down, parentType: 'dropdown'),
      CustomControlType(id: 'multi_select', label: 'Multi-Select', icon: Icons.list, parentType: 'dropdown'),

      CustomControlType(id: 'button', label: 'Button', icon: Icons.touch_app),
      CustomControlType(id: 'button_submit', label: 'Submit Button', icon: Icons.send, parentType: 'button'),
      CustomControlType(id: 'button_signup', label: 'Sign Up Button', icon: Icons.person_add, parentType: 'button'),
      CustomControlType(id: 'button_close', label: 'Close Button', icon: Icons.close, parentType: 'button'),
      CustomControlType(id: 'button_okay', label: 'Okay Button', icon: Icons.check, parentType: 'button'),

      // Extended Types using parentType
      CustomControlType(id: 'email_input', label: 'Email Input', icon: Icons.email, parentType: 'text_input', constraintKeys: ['maxLength']),
      CustomControlType(id: 'phone_input', label: 'Phone Input', icon: Icons.phone, parentType: 'text_input', constraintKeys: ['maxLength']),
      CustomControlType(id: 'color_picker', label: 'Color Picker', icon: Icons.color_lens, parentType: 'text_input'),
      CustomControlType(id: 'color_picker_hex', label: 'Hex String', icon: Icons.tag, parentType: 'color_picker'),
      CustomControlType(id: 'color_picker_rgba', label: 'RGBA', icon: Icons.palette, parentType: 'color_picker'),

      CustomControlType(id: 'date_picker', label: 'Date Picker', icon: Icons.calendar_today, parentType: 'text_input'),
      CustomControlType(id: 'date_only', label: 'Date Only', icon: Icons.today, parentType: 'date_picker'),
      CustomControlType(id: 'date_time', label: 'Date & Time', icon: Icons.schedule, parentType: 'date_picker'),

      CustomControlType(id: 'percentage_slider', label: 'Percentage', icon: Icons.percent, parentType: 'number_input', constraintKeys: ['min', 'max']),
      
      CustomControlType(id: 'rating_stars', label: 'Star Rating', icon: Icons.star, parentType: 'number_input', constraintKeys: ['max']),
      CustomControlType(id: 'rating_5', label: '5 Stars', icon: Icons.star_half, parentType: 'rating_stars', constraintKeys: ['max']),
      CustomControlType(id: 'rating_10', label: '10 Stars', icon: Icons.stars, parentType: 'rating_stars', constraintKeys: ['max']),

      // Structural Types
      CustomControlType(id: 'layout', label: 'Layout Element', icon: Icons.dashboard),
      CustomControlType(id: 'sidebar', label: 'Sidebar', icon: Icons.view_sidebar, parentType: 'layout'),
      CustomControlType(id: 'navigation_bar', label: 'Navigation bar', icon: Icons.space_dashboard, parentType: 'layout'),
      CustomControlType(id: 'header', label: 'Header', icon: Icons.vertical_align_top, parentType: 'layout'),
      CustomControlType(id: 'footer', label: 'Footer', icon: Icons.vertical_align_bottom, parentType: 'layout'),

      CustomControlType(id: 'container', label: 'Container', icon: Icons.crop_square),
      CustomControlType(id: 'image_placeholder', label: 'Image placeholder', icon: Icons.image, parentType: 'container'),
      CustomControlType(id: 'text_block', label: 'Text block', icon: Icons.article, parentType: 'container'),
      CustomControlType(id: 'content_card', label: 'Content card', icon: Icons.branding_watermark, parentType: 'container'),

      CustomControlType(id: 'navigational', label: 'Navigational Component', icon: Icons.explore),
      CustomControlType(id: 'breadcrumb', label: 'Breadcrumb', icon: Icons.linear_scale, parentType: 'navigational'),
      CustomControlType(id: 'nav_slider', label: 'Slider', icon: Icons.slideshow, parentType: 'navigational'),
      CustomControlType(id: 'search_bar', label: 'Search bar', icon: Icons.search, parentType: 'navigational'),
      CustomControlType(id: 'pagination', label: 'Pagination', icon: Icons.last_page, parentType: 'navigational'),
      CustomControlType(id: 'menu_icon', label: 'Menu icon', icon: Icons.menu, parentType: 'navigational'),
      
      // Decorative / Static Types
      CustomControlType(id: 'info', label: 'Info Box', icon: Icons.info_outline),
      CustomControlType(id: 'note', label: 'Note / Comment', icon: Icons.edit_note),
      CustomControlType(id: 'divider', label: 'Divider', icon: Icons.horizontal_rule),
      CustomControlType(id: 'gap', label: 'Gap (Empty Space)', icon: Icons.height),
    ];
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_control_types', jsonEncode(_types.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  void addType(CustomControlType type) {
    _types.add(type);
    save();
  }

  void updateType(CustomControlType type) {
    final idx = _types.indexWhere((t) => t.id == type.id);
    if (idx != -1) {
      _types[idx] = type;
      save();
    }
  }

  void deleteType(String id) {
    _types.removeWhere((t) => t.id == id);
    save();
  }

  CustomControlType? getType(String id) {
    try {
      return _types.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  void reparentType(String sourceId, String? newParentId) {
    if (sourceId == newParentId) return;
    final sourceIdx = _types.indexWhere((t) => t.id == sourceId);
    if (sourceIdx != -1) {
      _types[sourceIdx].parentType = newParentId;
      save();
    }
  }

  void reorderType(String sourceId, String targetId, bool insertAbove) {
    if (sourceId == targetId) return;
    
    final sourceIdx = _types.indexWhere((t) => t.id == sourceId);
    final targetIdx = _types.indexWhere((t) => t.id == targetId);
    
    if (sourceIdx != -1 && targetIdx != -1) {
      final sourceItem = _types.removeAt(sourceIdx);
      
      // Since we removed an item, target index might have shifted
      final newTargetIdx = _types.indexWhere((t) => t.id == targetId);
      
      // Update parent type to match target's parent type
      sourceItem.parentType = _types[newTargetIdx].parentType;
      
      if (insertAbove) {
        _types.insert(newTargetIdx, sourceItem);
      } else {
        _types.insert(newTargetIdx + 1, sourceItem);
      }
      
      save();
    }
  }
}
