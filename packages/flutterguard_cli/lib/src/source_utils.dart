import 'package:analyzer/source/line_info.dart';

int lineNumberForOffset(LineInfo lineInfo, int offset) =>
    lineInfo.getLocation(offset).lineNumber;
