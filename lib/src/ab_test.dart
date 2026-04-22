/// A/B Testing models for RiviumPush SDK

/// Represents a variant in an A/B test
class ABTestVariant {
  final String testId;
  final String variantId;
  final String variantName;
  final bool isControlGroup;
  final ABTestContent? content;

  ABTestVariant({
    required this.testId,
    required this.variantId,
    required this.variantName,
    this.isControlGroup = false,
    this.content,
  });

  factory ABTestVariant.fromMap(Map<dynamic, dynamic> map) {
    return ABTestVariant(
      testId: map['testId'] as String? ?? '',
      variantId: map['variantId'] as String? ?? '',
      variantName: map['variantName'] as String? ?? '',
      isControlGroup: map['isControlGroup'] as bool? ?? false,
      content: map['content'] != null
          ? ABTestContent.fromMap(Map<String, dynamic>.from(map['content'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'testId': testId,
      'variantId': variantId,
      'variantName': variantName,
      'isControlGroup': isControlGroup,
      'content': content?.toMap(),
    };
  }

  @override
  String toString() {
    return 'ABTestVariant(testId: $testId, variantId: $variantId, variantName: $variantName, isControlGroup: $isControlGroup)';
  }
}

/// Content configuration for an A/B test variant
class ABTestContent {
  final String? title;
  final String? body;
  final String? imageUrl;
  final String? deepLink;
  final Map<String, dynamic>? data;
  final List<ABTestAction>? actions;

  ABTestContent({
    this.title,
    this.body,
    this.imageUrl,
    this.deepLink,
    this.data,
    this.actions,
  });

  factory ABTestContent.fromMap(Map<String, dynamic> map) {
    return ABTestContent(
      title: map['title'] as String?,
      body: map['body'] as String?,
      imageUrl: map['imageUrl'] as String?,
      deepLink: map['deepLink'] as String?,
      data: map['data'] != null
          ? Map<String, dynamic>.from(map['data'] as Map)
          : null,
      actions: map['actions'] != null
          ? (map['actions'] as List)
              .map((e) => ABTestAction.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'deepLink': deepLink,
      'data': data,
      'actions': actions?.map((e) => e.toMap()).toList(),
    };
  }
}

/// Action button for an A/B test variant
class ABTestAction {
  final String id;
  final String title;
  final String action;

  ABTestAction({
    required this.id,
    required this.title,
    required this.action,
  });

  factory ABTestAction.fromMap(Map<String, dynamic> map) {
    return ABTestAction(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      action: map['action'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'action': action,
    };
  }
}

/// Summary information for an A/B test
class ABTestSummary {
  final String id;
  final String name;
  final int variantCount;
  final bool hasControlGroup;

  ABTestSummary({
    required this.id,
    required this.name,
    this.variantCount = 0,
    this.hasControlGroup = false,
  });

  factory ABTestSummary.fromMap(Map<dynamic, dynamic> map) {
    return ABTestSummary(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      variantCount: map['variantCount'] as int? ?? 0,
      hasControlGroup: map['hasControlGroup'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'variantCount': variantCount,
      'hasControlGroup': hasControlGroup,
    };
  }

  @override
  String toString() {
    return 'ABTestSummary(id: $id, name: $name, variantCount: $variantCount, hasControlGroup: $hasControlGroup)';
  }
}

/// Statistical results for an A/B test
class ABTestStatistics {
  final bool isSignificant;
  final double confidenceLevel;
  final double pValue;
  final double lift;
  final int? sampleSizeRecommendation;

  ABTestStatistics({
    required this.isSignificant,
    required this.confidenceLevel,
    required this.pValue,
    required this.lift,
    this.sampleSizeRecommendation,
  });

  factory ABTestStatistics.fromMap(Map<String, dynamic> map) {
    return ABTestStatistics(
      isSignificant: map['isSignificant'] as bool? ?? false,
      confidenceLevel: (map['confidenceLevel'] as num?)?.toDouble() ?? 0.0,
      pValue: (map['pValue'] as num?)?.toDouble() ?? 1.0,
      lift: (map['lift'] as num?)?.toDouble() ?? 0.0,
      sampleSizeRecommendation: map['sampleSizeRecommendation'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isSignificant': isSignificant,
      'confidenceLevel': confidenceLevel,
      'pValue': pValue,
      'lift': lift,
      'sampleSizeRecommendation': sampleSizeRecommendation,
    };
  }
}

/// Confidence interval for a metric
class ConfidenceInterval {
  final double lower;
  final double upper;

  ConfidenceInterval({
    required this.lower,
    required this.upper,
  });

  factory ConfidenceInterval.fromMap(Map<String, dynamic> map) {
    return ConfidenceInterval(
      lower: (map['lower'] as num?)?.toDouble() ?? 0.0,
      upper: (map['upper'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lower': lower,
      'upper': upper,
    };
  }
}

/// Variant statistics with confidence intervals
class ABTestVariantStats {
  final String id;
  final String name;
  final bool isControlGroup;
  final int trafficPercentage;
  final int sentCount;
  final int deliveredCount;
  final int openedCount;
  final int clickedCount;
  final int convertedCount;
  final int failedCount;
  final double deliveryRate;
  final double openRate;
  final double clickRate;
  final double conversionRate;
  final ConfidenceInterval? confidenceInterval;
  final double? improvementVsControl;
  final bool? isSignificantVsControl;
  final double? pValueVsControl;

  ABTestVariantStats({
    required this.id,
    required this.name,
    this.isControlGroup = false,
    required this.trafficPercentage,
    required this.sentCount,
    required this.deliveredCount,
    required this.openedCount,
    required this.clickedCount,
    this.convertedCount = 0,
    required this.failedCount,
    required this.deliveryRate,
    required this.openRate,
    required this.clickRate,
    this.conversionRate = 0.0,
    this.confidenceInterval,
    this.improvementVsControl,
    this.isSignificantVsControl,
    this.pValueVsControl,
  });

  factory ABTestVariantStats.fromMap(Map<String, dynamic> map) {
    return ABTestVariantStats(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      isControlGroup: map['isControlGroup'] as bool? ?? false,
      trafficPercentage: map['trafficPercentage'] as int? ?? 0,
      sentCount: map['sentCount'] as int? ?? 0,
      deliveredCount: map['deliveredCount'] as int? ?? 0,
      openedCount: map['openedCount'] as int? ?? 0,
      clickedCount: map['clickedCount'] as int? ?? 0,
      convertedCount: map['convertedCount'] as int? ?? 0,
      failedCount: map['failedCount'] as int? ?? 0,
      deliveryRate: (map['deliveryRate'] as num?)?.toDouble() ?? 0.0,
      openRate: (map['openRate'] as num?)?.toDouble() ?? 0.0,
      clickRate: (map['clickRate'] as num?)?.toDouble() ?? 0.0,
      conversionRate: (map['conversionRate'] as num?)?.toDouble() ?? 0.0,
      confidenceInterval: map['confidenceInterval'] != null
          ? ConfidenceInterval.fromMap(Map<String, dynamic>.from(map['confidenceInterval'] as Map))
          : null,
      improvementVsControl: (map['improvementVsControl'] as num?)?.toDouble(),
      isSignificantVsControl: map['isSignificantVsControl'] as bool?,
      pValueVsControl: (map['pValueVsControl'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isControlGroup': isControlGroup,
      'trafficPercentage': trafficPercentage,
      'sentCount': sentCount,
      'deliveredCount': deliveredCount,
      'openedCount': openedCount,
      'clickedCount': clickedCount,
      'convertedCount': convertedCount,
      'failedCount': failedCount,
      'deliveryRate': deliveryRate,
      'openRate': openRate,
      'clickRate': clickRate,
      'conversionRate': conversionRate,
      'confidenceInterval': confidenceInterval?.toMap(),
      'improvementVsControl': improvementVsControl,
      'isSignificantVsControl': isSignificantVsControl,
      'pValueVsControl': pValueVsControl,
    };
  }
}

/// Event types for A/B test tracking
enum ABTestEvent {
  impression,
  opened,
  clicked,
  converted,
}
