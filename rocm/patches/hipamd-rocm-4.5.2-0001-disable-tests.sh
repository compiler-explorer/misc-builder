diff --git a/CMakeLists.txt b/CMakeLists.txt
index b1ab39e7..0b2132ba 100755
--- a/CMakeLists.txt
+++ b/CMakeLists.txt
@@ -484,35 +484,6 @@ if(CLANGFORMAT_EXE)
         WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
 endif()
 
-#############################
-# Testing steps
-#############################
-# HIT is not compatible with Windows
-if(NOT WIN32)
-set(HIP_ROOT_DIR ${CMAKE_CURRENT_BINARY_DIR})
-set(HIP_SRC_PATH ${CMAKE_CURRENT_SOURCE_DIR})
-if(HIP_PLATFORM STREQUAL "nvidia")
-    execute_process(COMMAND "${CMAKE_COMMAND}" -E copy_directory "${HIP_SRC_PATH}/include" "${HIP_ROOT_DIR}/include" RESULT_VARIABLE RUN_HIT ERROR_QUIET)
-endif()
-execute_process(COMMAND "${CMAKE_COMMAND}" -E copy_directory "${HIP_COMMON_INCLUDE_DIR}/hip/" "${HIP_ROOT_DIR}/include/hip/" RESULT_VARIABLE RUN_HIT ERROR_QUIET)
-execute_process(COMMAND "${CMAKE_COMMAND}" -E copy_directory "${HIP_COMMON_DIR}/cmake" "${HIP_ROOT_DIR}/cmake" RESULT_VARIABLE RUN_HIT ERROR_QUIET)
-if(${RUN_HIT} EQUAL 0)
-    execute_process(COMMAND "${CMAKE_COMMAND}" -E copy_directory "${HIP_COMMON_BIN_DIR}" "${HIP_ROOT_DIR}/bin" RESULT_VARIABLE RUN_HIT ERROR_QUIET)
-endif()
-if(HIP_CATCH_TEST EQUAL "1")
-    enable_testing()
-    add_subdirectory(${HIP_COMMON_DIR}/tests/catch ${PROJECT_BINARY_DIR}/catch)
-else()
-    if(${RUN_HIT} EQUAL 0)
-        set(CMAKE_MODULE_PATH "${HIP_ROOT_DIR}/cmake" ${CMAKE_MODULE_PATH})
-        include(${HIP_COMMON_DIR}/tests/hit/HIT.cmake)
-        include(${HIP_COMMON_DIR}/tests/Tests.cmake)
-    else()
-        message(STATUS "Testing targets will not be available. To enable them please ensure that the HIP installation directory is writeable. Use -DCMAKE_INSTALL_PREFIX to specify a suitable location")
-    endif()
-endif()
-endif()
-
 #############################
 # Code analysis
 #############################
