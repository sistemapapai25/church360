import 'package:flutter/material.dart';

/// Símbolos compartilhados por ação, independentes do módulo consumidor.
/// Mantém IconData constante para permitir tree shaking no build web.
abstract final class AppIcons {
  static const search = Icons.search;
  static const searchEmpty = Icons.search_off;
  static const sort = Icons.swap_vert;
  static const expand = Icons.keyboard_arrow_down;
  static const back = Icons.arrow_back;
  static const close = Icons.close;
  static const more = Icons.more_vert;
  static const edit = Icons.edit_outlined;
  static const delete = Icons.delete_outline;
  static const message = Icons.chat_outlined;
  static const group = Icons.groups_2_outlined;
  static const student = Icons.school_outlined;
  static const addPerson = Icons.person_add_alt;
  static const status = Icons.flag_outlined;
  static const link = Icons.link;
  static const public = Icons.public;
  static const calendar = Icons.calendar_today_outlined;
  static const check = Icons.check;
  static const completed = Icons.task_alt;
  static const checklist = Icons.checklist_outlined;
  static const error = Icons.error_outline;
  static const dashboard = Icons.dashboard_outlined;
  static const admin = Icons.admin_panel_settings_outlined;
  static const church = Icons.church_outlined;
  static const book = Icons.menu_book_outlined;
  static const event = Icons.event_outlined;
  static const favorite = Icons.favorite_border;
  static const finance = Icons.account_balance_wallet_outlined;
  static const analytics = Icons.analytics_outlined;
  static const darkMode = Icons.dark_mode_outlined;
  static const label = Icons.label_outline;
  static const notifications = Icons.notifications_outlined;
  static const logout = Icons.logout;
  static const settings = Icons.settings_outlined;
  static const menu = Icons.menu;
  static const widgets = Icons.widgets_outlined;
  static const refresh = Icons.refresh;
}
