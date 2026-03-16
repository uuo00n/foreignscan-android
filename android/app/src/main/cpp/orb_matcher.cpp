#include "orb_matcher.h"

#include <algorithm>

#include <opencv2/core.hpp>
#include <opencv2/features2d.hpp>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/calib3d.hpp>

namespace {
constexpr int kDefaultDistanceThreshold = 50;
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
constexpr int kMaxLongerEdge = 1000;

void resize_if_needed(cv::Mat& img) {
  const int longer = std::max(img.cols, img.rows);
  if (longer <= kMaxLongerEdge) return;
  const double scale = static_cast<double>(kMaxLongerEdge) / longer;
  cv::resize(img, img, cv::Size(), scale, scale, cv::INTER_AREA);
}
}  // namespace

int orb_compare_images(const char* captured_path,
                       const char* reference_path,
                       int distance_threshold,
                       int max_features,
                       OrbScoreNative* out_score) {
  if (out_score == nullptr) {
    return 1;
  }

  out_score->good_matches = 0;
  out_score->keypoints_a = 0;
  out_score->keypoints_b = 0;
  out_score->similarity = 0.0F;
  out_score->inlier_count = 0;

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
    to_gray(captured_bgr, captured_gray);
    to_gray(reference_bgr, reference_gray);
    if (captured_gray.empty() || reference_gray.empty()) {
      return 4;
    }

    resize_if_needed(captured_gray);
    resize_if_needed(reference_gray);

    const int safe_max_features =
        max_features > 0 ? max_features : kDefaultMaxFeatures;
    auto orb = cv::ORB::create(safe_max_features, 1.2f, 8, 31, 0, 2,
                               cv::ORB::HARRIS_SCORE, 31, 31);

    std::vector<cv::KeyPoint> keypoints_a;
    std::vector<cv::KeyPoint> keypoints_b;
    cv::Mat descriptors_a;
    cv::Mat descriptors_b;

    orb->detectAndCompute(captured_gray, cv::noArray(), keypoints_a,
                          descriptors_a);
    orb->detectAndCompute(reference_gray, cv::noArray(), keypoints_b,
                          descriptors_b);

    out_score->keypoints_a = static_cast<int>(keypoints_a.size());
    out_score->keypoints_b = static_cast<int>(keypoints_b.size());

    if (descriptors_a.empty() || descriptors_b.empty()) {
      return 0;
    }

    cv::BFMatcher matcher(cv::NORM_HAMMING, true);
    std::vector<cv::DMatch> matches;
    matcher.match(descriptors_a, descriptors_b, matches);

    const int safe_distance_threshold =
        distance_threshold > 0 ? distance_threshold : kDefaultDistanceThreshold;

    int good_matches = 0;
    for (const auto& match : matches) {
      if (match.distance < safe_distance_threshold) {
        ++good_matches;
      }
    }

    out_score->good_matches = good_matches;

    out_score->inlier_count = good_matches; // 默认退化为距离过滤值

    if (good_matches >= 4) {
      std::vector<cv::Point2f> pts_a, pts_b;
      pts_a.reserve(good_matches);
      pts_b.reserve(good_matches);
      for (const auto& m : matches) {
        if (m.distance < safe_distance_threshold) {
          pts_a.push_back(keypoints_a[m.queryIdx].pt);
          pts_b.push_back(keypoints_b[m.trainIdx].pt);
        }
      }
      cv::Mat mask;
      cv::findHomography(pts_a, pts_b, cv::RANSAC, 3.0, mask);
      if (!mask.empty()) {
        out_score->inlier_count = cv::countNonZero(mask);
      }
    }

    const int denominator =
        std::max(1, std::min(out_score->keypoints_a, out_score->keypoints_b));
    const float raw_ratio =
        static_cast<float>(good_matches) / static_cast<float>(denominator);
    const float inlier_ratio =
        static_cast<float>(out_score->inlier_count) / static_cast<float>(denominator);
    out_score->similarity = 0.7f * inlier_ratio + 0.3f * raw_ratio;

    return 0;
  } catch (const cv::Exception&) {
    return 5;
  } catch (...) {
    return 6;
  }
}
