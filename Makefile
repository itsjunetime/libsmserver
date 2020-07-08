TARGET := iphone:clang:latest:7.0
INSTALL_TARGET_PROCESSES = MobileSMS, SpringBoard

ARCHS = arm64 arm64e

GO_EASY_ON_ME = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = libsmserver

libsmserver_FILES = Tweak.x
libsmserver_CFLAGS = -fobjc-arc

libsmserver_LIBRARIES = mryipc

include $(THEOS_MAKE_PATH)/tweak.mk

before-stage::
	find . -name ".DS_Store" -delete
