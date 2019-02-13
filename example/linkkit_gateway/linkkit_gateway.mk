NAME := linkkit_gateway
$(NAME)_SOURCES := linkkit_sample_gateway.c \
                   linkkit_entry.c

$(NAME)_COMPONENTS += framework/protocol/linkkit/sdk \
                      framework/protocol/linkkit/hal \
                      framework/netmgr \
                      framework/common \
                      utility/cjson \
                      framework/uOTA

GLOBAL_CFLAGS += -DCONFIG_DM_DEVTYPE_GATEWAY  \
                 -DWIFI_PROVISION_ENABLED \
                 -DCONFIG_YWSS \
                 -DAWSS_SUPPORT_DEV_AP \
                 -DAWSS_SUPPORT_STATIS  \
                 -DMQTT_DIRECT \
                 -DOTA_ENABLED \
                 -DBUILD_AOS      

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
GLOBAL_DEFINES += FOTA_RAM_LIMIT_MODE
GLOBAL_DEFINES += ESP8266_CHIPSET
endif
