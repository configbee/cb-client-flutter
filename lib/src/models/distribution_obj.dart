import 'cb_types.dart';

class DistributionObjMeta {
  final String versionId;
  final String versionTs;

  DistributionObjMeta({
    required this.versionId,
    required this.versionTs,
  });

  factory DistributionObjMeta.fromJson(Map<String, dynamic> json) {
    return DistributionObjMeta(
      versionId: json['versionId'] as String,
      versionTs: json['versionTs'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'versionId': versionId,
        'versionTs': versionTs,
      };
}

class OptionData {
  final CbOptionType optionType;
  final dynamic value;

  OptionData({
    required this.optionType,
    required this.value,
  });

  bool? get flagValue =>
      optionType == CbOptionType.flag ? value as bool? : null;
  num? get numberValue =>
      optionType == CbOptionType.number ? value as num? : null;
  String? get textValue =>
      optionType == CbOptionType.text ? value as String? : null;
  Map<String, dynamic>? get jsonValue =>
      optionType == CbOptionType.json ? value as Map<String, dynamic>? : null;

  factory OptionData.fromJson(Map<String, dynamic> json) {
    final optionTypeStr = json['optionType'] as String;
    CbOptionType optionType;
    dynamic value;

    switch (optionTypeStr) {
      case 'FLAG':
        optionType = CbOptionType.flag;
        value = json['flagValue'];
        break;
      case 'NUMBER':
        optionType = CbOptionType.number;
        value = json['numberValue'];
        break;
      case 'TEXT':
        optionType = CbOptionType.text;
        value = json['textValue'];
        break;
      case 'JSON':
        optionType = CbOptionType.json;
        value = json['jsonValue'];
        break;
      default:
        throw Exception('Invalid optionType: $optionTypeStr');
    }

    return OptionData(optionType: optionType, value: value);
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    switch (optionType) {
      case CbOptionType.flag:
        json['optionType'] = 'FLAG';
        json['flagValue'] = value;
        break;
      case CbOptionType.number:
        json['optionType'] = 'NUMBER';
        json['numberValue'] = value;
        break;
      case CbOptionType.text:
        json['optionType'] = 'TEXT';
        json['textValue'] = value;
        break;
      case CbOptionType.json:
        json['optionType'] = 'JSON';
        json['jsonValue'] = value;
        break;
    }
    return json;
  }
}

class DistributionObjData {
  final String? key;
  final DistributionObjMeta meta;
  final Map<String, OptionData> content;

  DistributionObjData({
    required this.meta,
    required this.content,
    this.key,
  });

  factory DistributionObjData.fromJson(Map<String, dynamic> json) {
    final contentMap = <String, OptionData>{};
    final contentJson = json['content'] as Map<String, dynamic>;

    contentJson.forEach((key, value) {
      contentMap[key] = OptionData.fromJson(value as Map<String, dynamic>);
    });

    return DistributionObjData(
      key: json['key'] as String?,
      meta: DistributionObjMeta.fromJson(json['meta'] as Map<String, dynamic>),
      content: contentMap,
    );
  }

  Map<String, dynamic> toJson() => {
        if (key != null) 'key': key,
        'meta': meta.toJson(),
        'content': content.map((k, v) => MapEntry(k, v.toJson())),
      };
}

class SessionData {
  final String key;
  final String versionHash;

  SessionData({
    required this.key,
    required this.versionHash,
  });

  factory SessionData.fromJson(Map<String, dynamic> json) {
    return SessionData(
      key: json['key'] as String,
      versionHash: json['versionHash'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'versionHash': versionHash,
      };
}

class TargetingData {
  final List<String> distributionKeys;
  final Map<String, DistributionObjData> distributionData;

  TargetingData({
    required this.distributionKeys,
    required this.distributionData,
  });
}
