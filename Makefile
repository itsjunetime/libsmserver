ARCHS = armv7 arm64 arm64e

PREFIX=$(THEOS)/toolchain/Xcode.xctoolchain/usr/bin/

TARGET := iphone:clang:latest:10.0:10.0
INSTALL_TARGET_PROCESSES = MobileSMS, SpringBoard

GO_EASY_ON_ME = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = libsmserver

libsmserver_FILES = Tweak.xm
libsmserver_CFLAGS = -fobjc-arc
libsmserver_LIBRARIES = mryipc

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

SYSROOT = $(THEOS)/sdks/iPhoneOS13.1.sdk

internal-stage::
	mkdir -p lib
	cp $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/libsmserver.dylib lib/libsmserver.dylib

before-stage::
	find . -name ".DS_Store" -delete

after-install::
	install.exec "killall -9 imagent"
