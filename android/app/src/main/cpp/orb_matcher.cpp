#include "orb_matcher.h"

#include <algorithm>
#include <cmath>
#include <vector>

#include <opencv2/core.hpp>
#include <opencv2/features2d.hpp>
#include <opencv2/flann/miniflann.hpp>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

namespace {
constexpr double kDefaultRatioThreshold = 0.7;
constexpr int kDefaultMaxFeatures = 2000;

bool read_image_bgr(const char* path, cv::Mat& out) {
  if (path == nullptr || path[0] == '\0') {
    return false;
  }

  cv::Mat decoded = cv::imread(path, cv::IMREAD_UNCHANGED);
  if (decoded.empty()) {
    return false;
  }

  if (decoded.channels() == 4) {
    cv::cvtColor(decoded, out, cv::COLOR_BGRA2BGR);
    return true;
  }

  if (decoded.channels() == 3) {
    out = decoded;
    return true;
  }

  if (decoded.channels() == 1) {
    cv::cvtColor(decoded, out, cv::COLOR_GRAY2BGR);
    return true;
  }

  return false;
}

void to_gray(const cv::Mat& input, cv::Mat& out) {
  if (input.channels() == 1) {
    out = input;
    return;
  }

  if (input.channels() == 3) {
    cv::cvtColor(input, out, cv::COLOR_BGR2GRAY);
    return;
  }

  if (input.channels() == 4) {
    cv::cvtColor(input, out, cv::COLOR_BGRA2GRAY);
    return;
  }

  out = cv::Mat();
}

void resize_keep_ratio(const cv::Mat& input,
                       int target_width,
                       int target_height,
                       cv::Mat& out) {
  if (input.empty() || target_width <= 0 || target_height <= 0) {
    out = input.clone();
    return;
  }

  const double scale =
      std::min(static_cast<double>(target_width) / input.cols,
               static_cast<double>(target_height) / input.rows);
  if (scale <= 0.0) {
    out = input.clone();
    return;
  }

  const int resized_width = std::max(1, static_cast<int>(input.cols * scale));
  const int resized_height = std::max(1, static_cast<int>(input.rows * scale));
  cv::resize(input, out, cv::Size(resized_width, resized_height), 0.0, 0.0,
             cv::INTER_LINEAR);
}

void preprocess_reference(const cv::Mat& input, cv::Mat& out) {
  to_gray(input, out);
  if (out.empty()) return;
  cv::equalizeHist(out, out);
  cv::GaussianBlur(out, out, cv::Size(3, 3), 0.5);
}

void preprocess_captured(const cv::Mat& input,
                         int target_width,
                         int target_height,
                         cv::Mat& out) {
  cv::Mat gray;
  to_gray(input, gray);
  if (gray.empty()) {
    out = cv::Mat();
    return;
  }

  resize_keep_ratio(gray, target_width, target_height, out);
  if (out.empty()) return;
  cv::equalizeHist(out, out);
  cv::GaussianBlur(out, out, cv::Size(3, 3), 0.5);
}

float round_to_single_decimal(float value) {
  return std::round(value * 10.0f) / 10.0f;
}
}  // namespace

int feature_compare_images(const char* captured_path,
                       const char* reference_path,
                       double ratio_threshold,
                       int max_features,
                       FeatureScoreNative* out_score) {
  if (out_score == nullptr) {
    return 1;
  }

  out_score->matched_feature_count = 0;
  out_score->keypoints_a = 0;
  out_score->keypoints_b = 0;
  out_score->similarity_percent = 0.0F;

  if (captured_path == nullptr || reference_path == nullptr ||
      captured_path[0] == '\0' || reference_path[0] == '\0') {
    return 1;
  }

  try {
    cv::Mat captured_bgr;
    cv::Mat reference_bgr;
    if (!read_image_bgr(captured_path, captured_bgr)) {
      return 2;
    }
    if (!read_image_bgr(reference_path, reference_bgr)) {
      return 3;
    }

    cv::Mat captured_gray;
    cv::Mat reference_gray;
    preprocess_reference(reference_bgr, reference_gray);
    preprocess_captured(captured_bgr, reference_bgr.cols, reference_bgr.rows,
                        captured_gray);
    if (captured_gray.empty() || reference_gray.empty()) {
      return 4;
    }

    const int safe_max_features =
        max_features > 0 ? max_features : kDefaultMaxFeatures;
    const double safe_ratio_threshold =
        ratio_threshold > 0.0 ? ratio_threshold : kDefaultRatioThreshold;
    auto sift = cv::SIFT::create(safe_max_features);

    std::vector<cv::KeyPoint> keypoints_a;
    std::vector<cv::KeyPoint> keypoints_b;
    cv::Mat descriptors_a;
    cv::Mat descriptors_b;

    sift->detectAndCompute(captured_gray, cv::noArray(), keypoints_a,
                           descriptors_a);
    sift->detectAndCompute(reference_gray, cv::noArray(), keypoints_b,
                          descriptors_b);

    out_score->keypoints_a = static_cast<int>(keypoints_a.size());
    out_score->keypoints_b = static_cast<int>(keypoints_b.size());

    if (descriptors_a.empty() || descriptors_b.empty()) {
      return 0;
    }

    cv::FlannBasedMatcher matcher(
        cv::makePtr<cv::flann::KDTreeIndexParams>(10),
        cv::makePtr<cv::flann::SearchParams>(100));
    std::vector<std::vector<cv::DMatch>> knn_matches;
    matcher.knnMatch(descriptors_a, descriptors_b, knn_matches, 2);

    int matched_feature_count = 0;
    for (const auto& matches : knn_matches) {
      if (matches.size() < 2) {
        continue;
      }
      const auto& best = matches[0];
      const auto& second = matches[1];
      if (best.distance < safe_ratio_threshold * second.distance) {
        ++matched_feature_count;
      }
    }

    out_score->matched_feature_count = matched_feature_count;

    const int denominator = std::max(
        1, std::min(static_cast<int>(keypoints_a.size()),
                    static_cast<int>(keypoints_b.size())));
    const float raw_percent =
        static_cast<float>(matched_feature_count) /
        static_cast<float>(denominator) * 100.0f;
    out_score->similarity_percent =
        std::min(round_to_single_decimal(raw_percent), 100.0f);

    return 0;
  } catch (const cv::Exception&) {
    return 5;
  } catch (...) {
    return 6;
  }
}
