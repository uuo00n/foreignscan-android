import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foreignscan/core/providers/app_providers.dart';
import 'package:foreignscan/core/services/detection_service.dart';
import 'package:foreignscan/core/services/scene_service.dart';
import 'package:foreignscan/core/services/style_image_service.dart';
import 'package:foreignscan/core/theme/app_theme.dart';
import 'package:foreignscan/models/detection_result.dart';
import 'package:foreignscan/models/inspection_record.dart';
import 'package:foreignscan/models/scene_data.dart';
import 'package:foreignscan/models/style_image.dart';
import 'package:foreignscan/screens/fullscreen_image_page.dart';

part 'record_detail_fullscreen_action.dart';
part 'record_detail_header_card.dart';
part 'record_compare_section.dart';
part 'record_detection_detail_panel.dart';
part 'record_verification_info_panel.dart';
