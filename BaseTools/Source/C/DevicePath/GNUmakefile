## @file
# GNU/Linux makefile for 'DevicePath' module build.
#
# Copyright (c) 2017, Intel Corporation. All rights reserved.<BR>
# SPDX-License-Identifier: BSD-2-Clause-Patent
#
ARCH ?= IA32
MAKEROOT ?= ..

APPNAME = DevicePath

OBJECTS = DevicePath.o UefiDevicePathLib.o DevicePathFromText.o  DevicePathUtilities.o

include $(MAKEROOT)/Makefiles/app.makefile

# gcc 12 trips over device path handling
BUILD_CFLAGS += -Wno-error=stringop-overflow

LIBS = -lCommon
ifeq ($(CYGWIN), CYGWIN)
  LIBS += -L/lib/e2fsprogs -luuid
endif

ifeq ($(LINUX), Linux)
  LIBS += -luuid
endif

