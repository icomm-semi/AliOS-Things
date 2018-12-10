NAME := ota_hal

$(NAME)_MBINS_TYPE := kernel
$(NAME)_VERSION := 0.0.1
$(NAME)_SUMMARY := ota porting HAL APIs

#default gcc
ifeq ($(COMPILER),)
$(NAME)_CFLAGS      += -Wall
else ifeq ($(COMPILER),gcc)
$(NAME)_CFLAGS      += -Wall
endif

$(NAME)_SOURCES := \
    ota_hal_module.c \
    ota_hal_os.c \

ifneq (,$(filter linux,$(HOST_MCU_FAMILY)))
$(NAME)_SOURCES += \
    ota_hal_host.c
else
$(NAME)_SOURCES += \
    ota_hal_rda.c
endif

GLOBAL_INCLUDES += . \
    ../inc \
    ../src/verify/crc \
    ../src/2nd_boot \