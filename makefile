#SRCFILE=linear-algebra/kernels/gemm/gemm.c
#PROGNAME=linear-algebra/kernels/gemm/gemm

# no trailing "/"
SOURCEFOLDERPATH=datamining/correlation
SRCFILENAME=correlation.c

SRCFILEPATH=$(SOURCEFOLDERPATH)/$(SRCFILENAME)
PROGNAME=$(SOURCEFOLDERPATH)/$(shell echo $(SRCFILENAME) | sed -e 's/\.c//g')

INCLUDEDIRS=-Iutilities/ -I/usr/local/cuda/include
LIBDIRS=-L/usr/local/cudalib
LIBS=-lcudart -lstdc++ -lGPURuntime -ldl -lOpenCL -Wl,-rpath=/home/bollu/llvm/llvm_build/lib -lm
CC=clang -O3 -g
CREATELL="./create_ll.sh"

.PHONY: build-utils built-utils-polly-gpu-managed build-naive build-polly-cpu build-polly-gpu-managed build-polly-gpu-unmanaged

bench: run-naive run-polly-cpu run-polly-gpu-unmanaged run-polly-gpu-managed 

build-utils:
	$(CC) $(INCLUDEDIRS) -DPOLYBENCH_TIME -DPOLYBENCH_CYCLE_ACCURATE_TIMER utilities/polybench.c -c  -o utilities.o

build-utils-polly-gpu-managed:
	$(CC) $(INCLUDEDIRS) -DPOLYBENCH_CUDA_MANAGED_MEMORY -DPOLYBENCH_TIME -DPOLYBENCH_CYCLE_ACCURATE_TIMER utilities/polybench.c -c  -o utilities.o


build-naive: build-utils
	$(CC) $(INCLUDEDIRS) $(LIBS) $(LIBDIRS) -O3  -DPOLYBENCH_TIME -DPOLYBENCH_CYCLE_ACCURATE_TIMER $(SRCFILEPATH) utilities.o -o $(PROGNAME).naive.out

build-polly-cpu: build-utils
	$(CC) $(INCLUDEDIRS) $(LIBS) $(LIBDIRS) -O3 -mllvm -polly -DPOLYBENCH_TIME -DPOLYBENCH_CYCLE_ACCURATE_TIMER $(SRCFILEPATH) utilities.o -o $(PROGNAME).polly-cpu.out

build-polly-gpu-managed: build-utils-polly-gpu-managed
	$(CREATELL) $(SRCFILEPATH) -DPOLYBENCH_CUDA_MANAGED_MEMORY
	opt -S  -polly-target=gpu  -polly-codegen-ppcg -polly-acc-codegen-managed-memory $(PROGNAME).ll > $(PROGNAME)-opt.ll
	llc $(PROGNAME)-opt.ll -o $(PROGNAME)-opt.s
	clang $(LIBDIRS) $(LIBS)  $(PROGNAME)-opt.s  utilities.o  -o $(PROGNAME).polly.gpu.managed.out

build-polly-gpu-unmanaged: build-utils
	$(CREATELL) $(SRCFILEPATH) 
	opt -S  -polly-target=gpu  -polly-codegen-ppcg  $(PROGNAME).ll > $(PROGNAME)-opt.ll
	llc $(PROGNAME)-opt.ll -o $(PROGNAME)-opt.s
	clang $(LIBDIRS) $(LIBS)  $(PROGNAME)-opt.s  utilities.o  -o $(PROGNAME).polly.gpu.unmanaged.out


run-polly-cpu: build-polly-cpu
	@echo
	@echo "@@@running $(PROGNAME).polly-cpu.out...@@@"
	./$(PROGNAME).polly-cpu.out
	@echo


run-naive: build-naive
	@echo
	@echo "@@@running $(PROGNAME).naive.out...@@@"
	./$(PROGNAME).naive.out
	@echo
run-polly-gpu-unmanaged: build-polly-gpu-unmanaged
	@echo
	@echo "@@@running $(PROGNAME).polly.gpu.ummanaged.out...@@@"
	./$(PROGNAME).polly.gpu.unmanaged.out
	@echo


run-polly-gpu-managed: build-polly-gpu-managed
	@echo
	@echo "@@@running $(PROGNAME).polly.gpu.managed.out...@@@"
	./$(PROGNAME).polly.gpu.managed.out
	@echo

clean:
	- rm $(SOURCEFOLDERPATH)/*.ll
	- rm $(SOURCEFOLDERPATH)/*.out
	- rm $(SOURCEFOLDERPATH)/*.s
