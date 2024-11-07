CUDA_PATH = /usr/local/cuda

LDFLAGS_COMMON = -L/opt/local/lib -lstdc++ -lpng -lz -ljpeg -lgomp
CFLAGS_COMMON = -g -c -Wall -I./ -I/opt/local/include -I./eigen/ -O3 -msse2 -std=c++11 -I${CUDA_PATH}/include -I${CUDA_PATH}/samples/common/inc -lgomp -Wno-unused-result
NVFLAGS = -c -I./ -I/opt/local/include -I./eigen/ -O3 -std=c++11 -I${CUDA_PATH}/include -I${CUDA_PATH}/samples/common/inc -lgomp --expt-relaxed-constexpr -arch=native

CC         = g++
NVCC       = ${CUDA_PATH}/bin/nvcc
CFLAGS     = ${CFLAGS_COMMON}
LDFLAGS    = ${LDFLAGS_COMMON}
EXECUTABLE = teraBunny 

SOURCES    = teraBunny.cpp \
	POLYNOMIAL_4D.cpp \
	MATRIX3.cpp \
	QUATERNION.cpp \
	FIELD_2D.cpp \
	FIELD_3D.cpp \
	TRIANGLE.cpp \
	SIMPLE_PARSER.cpp \
	TIMER.cpp \
	TRIANGLE_MESH.cpp 

OBJECTS = $(SOURCES:.cpp=.o) NONLINEAR_SLICE_CUDA.o

all: $(SOURCES) NONLINEAR_SLICE_CUDA.cu $(EXECUTABLE)
	
NONLINEAR_SLICE_CUDA.o:NONLINEAR_SLICE_CUDA.cu
	$(NVCC) $(NVFLAGS) -o $@ -c $<

$(EXECUTABLE): $(OBJECTS) 
	$(NVCC) $(OBJECTS) $(LDFLAGS) -o $@

.cpp.o:
	$(CC) $(CFLAGS) $< -o $@

clean:
	rm -f *.o
