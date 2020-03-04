-include .options

LIBRARY:=./lib/libsurvive.so
STATIC_LIBRARY:=./lib/libsurvive.a

all : $(STATIC_LIBRARY) $(LIBRARY) data_recorder simple_pose_test plugins .options survive-cli api_example sensors-readout
	@echo "Built with defaults.  Type 'make help' for more info."

PREFIX?=/usr/local

.options:
	@echo "USE_ASAN?=$(USE_ASAN)" > .options
	@echo "LINUX_USE_HIDAPI?=$(LINUX_USE_HIDAPI)" >> .options
	@echo "MINIMAL?=$(MINIMAL)" >> .options
	@echo "OPT?=$(OPT)" >> .options

.PHONY : help clean buildfolders plugins all install uninstall .options

OBJDIR:=build
LIBDIR:=lib

CFLAGS += -Wall -Wno-unused-variable -Wno-switch -Wno-parentheses -Wno-missing-braces
OPT?=3


ifdef WINDOWS
	CFLAGS+=-Iinclude/libsurvive -g -O$(OPT) -Iredist -std=gnu99 -MD -DNOZLIB -DWINDOWS -DWIN32 -DHIDAPI
	LDFLAGS+=-L/usr/local/lib -lpthread -g -lm -lsetupapi -lkernel32 -ldbghelp -lgdi32
	LDFLAGS_TOOLS+=-Llib -lsurvive -Wl,-rpath,lib -lX11 $(LDFLAGS)
	LIBSURVIVE_CORE:=redist/puff.c redist/crc32.c redist/hid-windows.c winbuild/getdelim.c
	CC:=i686-w64-mingw32-gcc
else
	CFLAGS+=-Iinclude/libsurvive -fPIC -g -O$(OPT) -Iredist -std=gnu99 -MD -DHAVE_FOPENCOOKIE=1
	LDFLAGS+=-L/usr/local/lib -lpthread -lz -lm -g -llapacke  -lcblas -lm  -lusb-1.0 -ldl
	LDFLAGS_TOOLS+=-Llib -lsurvive -Wl,-rpath,lib -lX11 $(LDFLAGS)
endif

CC?=gcc

ifdef USE_ASAN
	CFLAGS+=-fsanitize=address -fsanitize=undefined -DSURVIVE_ASAN_CHECKS=1
endif

SBA:=redist/sba/sba_chkjac.c  redist/sba/sba_crsm.c  redist/sba/sba_lapack.c  redist/sba/sba_levmar.c  redist/sba/sba_levmar_wrap.c 
MPFIT:=redist/mpfit/mpfit.c
LIBSURVIVE_CORE+=src/survive.c src/survive_str.c src/survive_process.c src/survive_process_gen2.c src/ootx_decoder.c src/survive_driverman.c src/survive_default_devices.c src/survive_playback.c src/survive_config.c src/survive_cal.c src/poser.c src/survive_sensor_activations.c src/survive_disambiguator.c src/survive_imu.c src/survive_kalman.c src/survive_api.c src/survive_plugins.c src/poser_general_optimizer.c src/lfsr_lh2.c src/lfsr.c
MINIMAL_NEEDED+=src/survive_reproject.c src/survive_reproject_gen2.c redist/minimal_opencv.c 
AUX_NEEDED+=
PLUGINS+=driver_dummy driver_udp driver_vive disambiguator_turvey disambiguator_statebased disambiguator_charles poser_dummy poser_mpfit poser_epnp poser_sba poser_imu poser_charlesrefine driver_usbmon driver_simulator poser_barycentric_svd
POSERS:=
EXTRA_POSERS:=src/poser_daveortho.c src/poser_charlesslow.c src/poser_octavioradii.c src/poser_turveytori.c
REDISTS:=redist/json_helpers.c redist/linmath.c redist/jsmn.c
TEST_CASES:=src/test_cases/main.c src/test_cases/kalman.c src/test_cases/reproject.c src/test_cases/watchman.c

#----------
# Platform specific changes to CFLAGS/LDFLAGS
#----------
UNAME=$(shell uname)

ifeq ($(UNAME), Darwin) # Mac OSX
	CFLAGS:=$(CFLAGS) -DRASTERIZER -DHIDAPI -I/usr/local/include -x objective-c
	LDFLAGS:=$(LDFLAGS) -framework OpenGL -framework Cocoa -framework IOKit
	DRAWFUNCTIONS=redist/CNFGFunctions.c redist/CNFGCocoaNSImageDriver.m
	GRAPHICS_LOFI:=redist/CNFGFunctions.c redist/CNFGCocoaNSImageDriver.c
	REDISTS:=$(REDISTS) redist/hid-osx.c
else                    # Linux / FreeBSD
	LDFLAGS:=$(LDFLAGS)
	DRAWFUNCTIONS=redist/CNFGFunctions.c redist/CNFGXDriver.c redist/CNFG3D.c
	GRAPHICS_LOFI:=redist/CNFGFunctions.c redist/CNFGXDriver.c
endif

ifdef LINUX_USE_HIDAPI
	CFLAGS:=$(CFLAGS) -DHIDAPI
    #TODO why doesn't the redist version work
	#REDISTS:=$(REDISTS) redist/hid-linux.c
	LDFLAGS:=$(LDFLAGS) -ludev -lhidapi-libusb
endif

ifdef MINIMAL
	LIBSURVIVE_C:=$(REDISTS) $(LIBSURVIVE_CORE) $(MINIMAL_NEEDED)
else
	LIBSURVIVE_C:=$(POSERS) $(REDISTS) $(LIBSURVIVE_CORE) $(MINIMAL_NEEDED) $(AUX_NEEDED)
endif


#Actually make object and dependency lists.
LIBSURVIVE_O:=$(LIBSURVIVE_C:%.c=$(OBJDIR)/%.o)
LIBSURVIVE_D:=$(LIBSURVIVE_C:%.c=$(OBJDIR)/%.d)
LIBSURVIVE_PLUGINS:=$(PLUGINS:%=./lib/plugins/%.so)

plugins: $(LIBSURVIVE_PLUGINS)

install: all $(PREFIX)
	mkdir -p $(PREFIX)/lib/libsurvive/plugins
	mkdir -p $(PREFIX)/include/libsurvive/redist
	cp -R ./include/libsurvive $(PREFIX)/include/libsurvive
	cp ./redist/*.h $(PREFIX)/include/libsurvive/redist
	cp $(LIBRARY) $(PREFIX)/lib/libsurvive
	rm -f $(PREFIX)/lib/libsurvive.so
	ln -s $(PREFIX)/lib/libsurvive/libsurvive.so $(PREFIX)/lib/libsurvive.so
	cp $(LIBSURVIVE_PLUGINS) $(PREFIX)/lib/libsurvive/plugins

uninstall:
	rm -rf $(PREFIX)/include/libsurvive
	rm -rf $(PREFIX)/lib/libsurvive
	rm -f $(PREFIX)/lib/libsurvive.so

#Include all dependencies so if header files change, it updates.
-include $(LIBSURVIVE_D)

#### Tools

testCocoa : testCocoa.c $(LIBRARY)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS_TOOLS)

test : test.c $(LIBRARY)
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS_TOOLS)

simple_pose_test : simple_pose_test.c $(DRAWFUNCTIONS) $(LIBRARY)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS_TOOLS)

data_recorder : data_recorder.c $(LIBRARY)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS_TOOLS)

survive-cli : survive-cli.c $(LIBRARY)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS_TOOLS)

api_example : api_example.c $(LIBRARY)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS_TOOLS)

sensors-readout : sensors-readout.c $(LIBRARY)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS_TOOLS)

calibrate :  calibrate.c $(DRAWFUNCTIONS) $(LIBRARY)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS_TOOLS)

calibrate_client :  calibrate_client.c $(GRAPHICS_LOFI) $(LIBRARY)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS_TOOLS)


#### Testers.

./redist/dclhelpers_debuggable.c : ./redist/dclhelpers.c ./redist/dclhelpers.h ./redist/dclapack.h
	gcc -E ./redist/dclhelpers.c  > ./redist/dclhelpers_debuggable.c
	clang-format -i ./redist/dclhelpers_debuggable.c
	sed -i 's/#/\/\/#/g' ./redist/dclhelpers_debuggable.c

test_dcl: ./redist/test_dcl.c ./redist/dclhelpers.c ./redist/dclhelpers.h ./redist/dclapack.h ./redist/minimal_opencv.c ./src/epnp/epnp.c
	$(CC) -o $@ $^ $(LDFLAGS_TOOLS) $(CFLAGS) -DFLT=double

test_dcl_debug: ./redist/test_dcl.c ./redist/dclhelpers_debuggable.c ./redist/dclhelpers.h ./redist/dclapack.h redist/os_generic.c
	$(CC) -o $@ $^ $(LDFLAGS_TOOLS) $(CFLAGS) -DFLT=double -fsanitize=address -fsanitize=undefined

test_minimal_cv: ./src/epnp/test_minimal_cv.c $(LIBRARY)
	$(CC) -o $@ $^ $(LDFLAGS_TOOLS) $(CFLAGS)

test_epnp: ./src/epnp/test_epnp.c $(LIBRARY)
	$(CC) -o $@ $^ $(LDFLAGS_TOOLS) $(CFLAGS)

test_epnp_ocv: ./src/epnp/test_epnp.c ./src/epnp/epnp.c
	$(CC) -o $@ $^ -DWITH_OPENCV -lpthread -lz -lm -flto -g -lX11 -lusb-1.0 -Iinclude/libsurvive -fPIC -g -O4 -Iredist -flto -std=gnu99 -rdynamic -fsanitize=address -fsanitize=undefined   -llapack -lm -lopencv_core $(LDFLAGS_TOOLS)

test_cases: $(TEST_CASES) $(LIBRARY) ./src/driver_vive.c
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS_TOOLS) 

#### Actual build system.

$(OBJDIR) $(LIBDIR):
	mkdir -p lib
	mkdir -p lib/plugins
	mkdir -p $(OBJDIR)
	mkdir -p $(OBJDIR)/winbuild
	mkdir -p $(OBJDIR)/src
	mkdir -p $(OBJDIR)/redist
	mkdir -p $(OBJDIR)/redist/sba
	mkdir -p $(OBJDIR)/redist/mpfit
	mkdir -p $(OBJDIR)/src/epnp

$(LIBRARY): $(LIBSURVIVE_O) $(OBJDIR)
	$(CC) $(CFLAGS) -shared -o $@ $(LIBSURVIVE_O) $(LDFLAGS)

LDFLAGS_PLUGINS=$(LDFLAGS) -L./lib/plugins

./lib/plugins/poser_sba.so: ./src/poser_sba.c $(SBA)
	$(CC) $(CFLAGS) -shared -o $@ $^ $(LDFLAGS_PLUGINS)

./lib/plugins/driver_vive.so: ./src/driver_vive.c ./src/survive_usb.c
	$(CC) $(CFLAGS) -shared -o $@ $^ $(LDFLAGS_PLUGINS)

./lib/plugins/poser_epnp.so: ./src/poser_epnp.c src/epnp/epnp.c ./redist/minimal_opencv.c
	$(CC) $(CFLAGS) -shared -o $@ $^ $(LDFLAGS_PLUGINS)

./lib/plugins/poser_barycentric_svd.so: ./src/poser_barycentric_svd.c src/barycentric_svd/barycentric_svd.c ./redist/minimal_opencv.c
	$(CC) $(CFLAGS) -shared -o $@ $^ $(LDFLAGS_PLUGINS)

./lib/plugins/poser_mpfit.so: src/poser_mpfit.c ./src/survive_optimizer.c $(MPFIT)
	$(CC) $(CFLAGS) -shared -o $@ $^ $(LDFLAGS_PLUGINS)

./lib/plugins/driver_usbmon.so: src/driver_usbmon.c ./lib/plugins/driver_vive.so
	$(CC) $(CFLAGS) -shared -o $@ $< $(LDFLAGS_PLUGINS) -lpcap 2> /dev/null || (echo "Could not build plug-in for usbmon -- likely you don't have lpcap installed.")

./lib/plugins/%.so: ./src/%.c $($%_C) 
	$(CC) $(CFLAGS) -shared -o $@ $^ $(LDFLAGS_PLUGINS)

$(STATIC_LIBRARY) : $(LIBSURVIVE_O) $(LIBDIR) 
	ar rcs --plugin=$$(gcc --print-file-name=liblto_plugin.so) ./lib/libsurvive.a $(LIBSURVIVE_O)

$(OBJDIR)/%.o : %.c $(OBJDIR)
	$(CC) $(CFLAGS) -c $< -o $@

calibrate_tcc : $(LIBSURVIVE_C)
	tcc -DRUNTIME_SYMNUM $(CFLAGS) -o $@ $^ $(LDFLAGS) calibrate.c $(DRAWFUNCTIONS) redist/symbol_enumerator.c

clean :
	rm -rf $(OBJDIR) *.d lib/libsurvive.a *~ src/*~ test simple_pose_test data_recorder calibrate testCocoa lib/libsurvive.so test_minimal_cv test_epnp test_epnp_ocv calibrate_client redist/*.o redist/*~ tools/data_server/data_server tools/lighthousefind/lighthousefind tools/lighthousefind_tori/lighthousefind-tori tools/plot_lighthouse/plot_lighthouse tools/process_rawcap/process_to_points redist/jsmntest redist/lintest ./lib survive-cli

.test_redist:
	cd redist && make .run_tests;

.run_tests: .test_redist


#To do this, you probably want to  `make tccbatch MINIMAL=1 WINDOWS=1`

tccbatch :
	echo "@echo off" >  winbuild/build_tcc.bat
	echo "set TCC=C:\\\\tcc\\\\tcc.exe" >> winbuild/build_tcc.bat
	echo "echo USing %TCC%" >> winbuild/build_tcc.bat
	echo "set EXEC=calibrate.c redist\\\\CNFGWinDriver.c redist\\\\CNFGFunctions.c" >> winbuild/build_tcc.bat
	echo "set SOURCES=$(subst "/","\\",$(LIBSURVIVE_C))" >> winbuild/build_tcc.bat
	echo "set CFLAGS=-DTCC $(CFLAGS)" >> winbuild/build_tcc.bat
	echo "set LDFLAGS=-lkernel32 -lgdi32 -luser32" >> winbuild/build_tcc.bat
	echo "@echo on" >> winbuild/build_tcc.bat
	echo "%TCC% -v %CFLAGS% %SOURCES% %REDIST% %EXEC% %LDFLAGS% winbuild/tcc_stubs.c -o calibrate.exe" >> winbuild/build_tcc.bat

help :
	@echo "Usage: make [flags]"
	@echo "  Build-system flags:"
	@echo "    MINIMAL=1          Buld a minimal build, geared for embedded systems."
	@echo "    LINUX_USE_HIDAPI=1 Build with HIDAPI in Linux instead of just libusb."
	@echo "    EXTRA_WARNINGS=1   Provide many mor warnings for build system."
	@echo "    WINDOWS=1          Cross-target Windows (EXPERIMENTAL)"
	@echo "    CFLAGS=            Specify additional CFLAGS."
	@echo "    LDFLAGS=           Specify additional LDFLAGS."
	@echo "    CC=                Specify a different C compiler."
	@echo "  Useful Preprocessor Directives (For CFLAGS):"
	@echo "    -DUSE_FLOAT        Use float instead of double for most operations."
	@echo "    -DNOZLIB           Use puff.c"
	@echo "    -DTCC              Various things needed for TCC."
	@echo "    -DWINDOWS -DWIN32  Building for Windows."
	@echo "    -DRUNTIME_SYMNUM   Don't assume __attribute__((constructor)) works.  Instead comb for anything starting with REGISTER."
	@echo "    -flto              Do link-time optimizations.  This significantly increases period of time to link but improves performance.."
	@echo "  Useful build targets:"
	@echo "    all                Build libsurvive.so and tools."
	@echo "    clean              Erase build and incremental files."
	@echo "    buildfolders       Produce build file structure."
	@echo "    $(LIBRARY)  Produce libsurvive.so"
