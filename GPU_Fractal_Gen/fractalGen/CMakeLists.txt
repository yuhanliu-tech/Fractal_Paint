set(headers
    "field.h"
    "julia.h"
    "MC.h"
    "mesh.h"
    "SETTINGS.h"
    "triangle.h"
    "Quaternion/POLYNOMIAL_4D.h"
    "Quaternion/QUATERNION.h"
    )

set(sources
    "triangle.cpp"
    "Quaternion/POLYNOMIAL_4D.cpp"
    "Quaternion/QUATERNION.cpp"
    )

list(SORT headers)
list(SORT sources)

source_group(Headers FILES ${headers})
source_group(Sources FILES ${sources})

add_library(fractalGen ${sources} ${headers})
if(CMAKE_VERSION VERSION_LESS "3.23.0")
    set_target_properties(fractalGen} PROPERTIES CUDA_ARCHITECTURES OFF)
elseif(CMAKE_VERSION VERSION_LESS "3.24.0")
    set_target_properties(fractalGen PROPERTIES CUDA_ARCHITECTURES all-major)
else()
    set_target_properties(fractalGen PROPERTIES CUDA_ARCHITECTURES native)
endif()
target_compile_options(fractalGen PRIVATE "$<$<AND:$<CONFIG:Debug,RelWithDebInfo>,$<COMPILE_LANGUAGE:CUDA>>:-G;-src-in-ptx>")
target_compile_options(fractalGen PRIVATE "$<$<AND:$<CONFIG:Release>,$<COMPILE_LANGUAGE:CUDA>>:-lineinfo;-src-in-ptx>")
