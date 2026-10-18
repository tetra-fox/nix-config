cmake_minimum_required(VERSION 3.22)
project(kwin-meta-click LANGUAGES CXX)

# kwin's headers use c++23, same as kwin itself
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(ECM 6.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

find_package(KF6CoreAddons REQUIRED)
# KWin::kwin links Qt6::Widgets and Qt6::DBus but KWinConfig.cmake.in never finds them
# TODO: drop once kwin's config adds the find_dependency calls
find_package(Qt6 REQUIRED COMPONENTS Widgets DBus)
find_package(KWin REQUIRED)

kcoreaddons_add_plugin(metaclick INSTALL_NAMESPACE "kwin/plugins")
target_sources(metaclick PRIVATE metaclick.cpp)
target_link_libraries(metaclick PRIVATE KWin::kwin)
