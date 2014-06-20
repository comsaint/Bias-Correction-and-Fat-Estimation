#ifndef LSDynaExport_h
#define LSDynaExport_h

#include <vtksys/Configure.h>
#include <string>
#include <iostream>

#include "vtkABI.h"

/* #undef BUILD_SHARED_LIBS */

// Now set up all of the export macros
#if defined(BUILD_SHARED_LIBS)
 #if defined(LSDyna_EXPORTS)
  #define LSDyna_EXPORT VTK_ABI_EXPORT
 #else
  #define LSDyna_EXPORT VTK_ABI_IMPORT
 #endif
#else
 #define LSDyna_EXPORT
#endif

#endif
