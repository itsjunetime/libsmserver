ARCHS = arm64 arm64e

TARGET := iphone:clang:latest:13.1
INSTALL_TARGET_PROCESSES = MobileSMS, SpringBoard

GO_EASY_ON_ME = 1
FOR_RELEASE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = libsmserver

libsmserver_FILES = Tweak.xm
libsmserver_CFLAGS = -fobjc-arc

libsmserver_LIBRARIES = mryipc

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

before-stage::
	find . -name ".DS_Store" -delete
