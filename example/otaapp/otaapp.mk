NAME := otaapp
$(NAME)_SOURCES := otaapp.c \

$(NAME)_COMPONENTS += framework/protocol/linkkit/sdk \
    		      framework/protocol/linkkit/hal \
		      framework/netmgr \
		      framework/common \
		      utility/cjson \
		      tools/cli  \
		      uOTA   


GLOBAL_DEFINES += MQTT_DIRECT \
		  ALIOT_DEBUG \
		  IOTX_DEBUG \
		  USE_LPTHREAD \
	          CONFIG_AOS_CLI

ifeq ($(LWIP),1)
$(NAME)_COMPONENTS  += protocols.net
no_with_lwip := 0
endif

ifeq ($(loop),1)
$(NAME)_DEFINES      += TEST_LOOP
endif
