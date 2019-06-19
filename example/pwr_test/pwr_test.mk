NAME := pwr_test

$(NAME)_SOURCES := pwr_test.c

GLOBAL_DEFINES += AOS_NO_WIFI

$(NAME)_COMPONENTS :=cli pwrmgmt

GLOBAL_CFLAGS += -DPWRMGMT_CONFIG_LOG_ENTERSLEEP=1

$(NAME)_COMPONENTS += framework/netmgr \
                      framework/protocol/linkkit/hal \
                      framework/protocol/linkkit/sdk

GLOBAL_INCLUDES += ./
