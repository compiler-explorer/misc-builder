diff --git a/cmake/OCL.cmake b/cmake/OCL.cmake
index 5869967f6a687db..fe45b26bfc380b9 100644
--- a/cmake/OCL.cmake
+++ b/cmake/OCL.cmake
@@ -39,17 +39,8 @@ if (WIN32)
   set(CLANG_OCL_FLAGS ${CLANG_OCL_FLAGS} -fshort-wchar)
 endif()
 
-# Disable code object version module flag if available.
-file(WRITE ${CMAKE_BINARY_DIR}/tmp.cl "")
-execute_process (
-  COMMAND ${LLVM_TOOLS_BINARY_DIR}/clang${EXE_SUFFIX} ${CLANG_OCL_FLAGS} -Xclang -mcode-object-version=none ${CMAKE_BINARY_DIR}/tmp.cl
-  RESULT_VARIABLE TEST_CODE_OBJECT_VERSION_NONE_RESULT
-  ERROR_QUIET
-)
-file(REMOVE ${CMAKE_BINARY_DIR}/tmp.cl)
-if (NOT TEST_CODE_OBJECT_VERSION_NONE_RESULT)
-  set(CLANG_OCL_FLAGS ${CLANG_OCL_FLAGS} -Xclang -mcode-object-version=none)
-endif()
+# Disable code object version module flag.
+set(CLANG_OCL_FLAGS ${CLANG_OCL_FLAGS} -Xclang -mcode-object-version=none)
 
 set (BC_EXT .bc)
 set (LIB_SUFFIX ".lib${BC_EXT}")
