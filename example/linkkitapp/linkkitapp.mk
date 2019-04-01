NAME := linkkitapp
$(NAME)_SOURCES :=   app_entry.c

$(NAME)_COMPONENTS += framework/protocol/linkkit/sdk \
                      framework/protocol/linkkit/hal \
                      framework/netmgr \
                      framework/common \
                      utility/cjson \
                      framework/uOTA

$(NAME)_INCLUDES += ../../framework/protocol/linkkit/include \
                    ../../framework/protocol/linkkit/include/imports \
                    ../../framework/protocol/linkkit/include/exports \

GLOBAL_CFLAGS += -DCONFIG_DM_DEVTYPE_SINGLE  \
                 -DMQTT_DIRECT \
                 -DCONFIG_YWSS \
                 -DWIFI_PROVISION_ENABLED \
                 -DAWSS_SUPPORT_DEV_AP \
                 -DOTA_ENABLED \
                 -DBUILD_AOS \
                 -DAWSS_SUPPORT_STATIS



ifeq ($(case),sched)
ifneq ($(deprecated),)
$(NAME)_SOURCES += deprecated/sched.c
GLOBAL_CFLAGS += -DDEPRECATED_LINKKIT
else
$(NAME)_SOURCES += linkkit_example_sched.c
endif
else ifeq ($(case),cntdown)
ifneq ($(deprecated),)
$(NAME)_SOURCES += deprecated/cntdown.c
GLOBAL_CFLAGS += -DDEPRECATED_LINKKIT
else
$(NAME)_SOURCES += linkkit_example_cntdown.c
endif
else
ifneq ($(deprecated),)
$(NAME)_SOURCES += deprecated/solo.c
GLOBAL_CFLAGS += -DDEPRECATED_LINKKIT
else
$(NAME)_SOURCES += linkkit_example_solo.c
endif
endif

ifeq ($(LWIP),1)
$(NAME)_COMPONENTS  += protocols.net
no_with_lwip := 0
endif

ifeq ($(print_heap),1)
$(NAME)_DEFINES += CONFIG_PRINT_HEAP
endif

ifneq ($(HOST_MCU_FAMILY),esp8266)
$(NAME)_COMPONENTS  += cli
GLOBAL_DEFINES += CONFIG_AOS_CLI
else
GLOBAL_DEFINES += ESP8266_CHIPSET
endif

GLOBAL_INCLUDES += ./
