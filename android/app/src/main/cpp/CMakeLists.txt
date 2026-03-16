cmake_minimum_required(VERSION 3.22.1)
project(orb_matcher)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(OpenCV REQUIRED)

add_library(orb_matcher SHARED orb_matcher.cpp)

target_include_directories(orb_matcher PRIVATE ${OpenCV_INCLUDE_DIRS})

target_link_libraries(orb_matcher ${OpenCV_LIBS} log)
