#ifndef ORB_MATCHER_H
#define ORB_MATCHER_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct FeatureScoreNative {
  int matched_feature_count;
  int keypoints_a;
  int keypoints_b;
  float similarity_percent;
} FeatureScoreNative;

int feature_compare_images(const char* captured_path,
                       const char* reference_path,
                       double ratio_threshold,
                       int max_features,
                       FeatureScoreNative* out_score);

#ifdef __cplusplus
}
#endif

#endif  // ORB_MATCHER_H
