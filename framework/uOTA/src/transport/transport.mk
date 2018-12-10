NAME := ota_transport

$(NAME)_MBINS_TYPE := kernel
$(NAME)_VERSION := 0.0.1
$(NAME)_SUMMARY := ota transport message on clould.

$(NAME)_SOURCES := ota_transport_mqtt.c

GLOBAL_INCLUDES += . ../../inc ../../hal ../verify ../verify/base64 ../verify/hash ../verify/rsa

