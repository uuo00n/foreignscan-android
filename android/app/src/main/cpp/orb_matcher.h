#ifndef ORB_MATCHER_H
#define ORB_MATCHER_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct OrbScoreNative {
  int good_matches;
  int keypoints_a;
  int keypoints_b;
  float similarity;
} OrbScoreNative;

int orb_compare_images(const char* captured_path,
                       const char* reference_path,
                       int distance_threshold,
                       int max_features,
                       OrbScoreNative* out_score);

#ifdef __cplusplus
}
#endif

#endif  // ORB_MATCHER_H
