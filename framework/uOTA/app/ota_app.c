/*
 * Copyright (C) 2015-2017 Alibaba Group Holding Limited
 */
#include "ota_service.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void usage(void)
{
    printf("usage:%s [OPTIONS] \n\n"
           "  $1, Product Key.\n"
           "  $2, Device Name.\n"
           "  $3, Device Secret.\n"
           "  $4, Transport Protcol:default:0--> MQTT 1-->COAP 2-->HTTP.\n"
           "  $5, Download Protcol:default:3--> HTTPS 1-->COAP 2-->HTTP.\n"
           "\n",
           UOTA_VERSION);
}


int main(int argc, char *argv[])
{
    if (argc <= 4) {
        usage();
        return 1;
    }
    ota_service_manager ctx = { 0 };
    strcpy(ctx.pk, argv[1]);
    strcpy(ctx.dn, argv[2]);
    strcpy(ctx.ds, argv[3]);
    if (argc > 4)
        ctx.trans_protcol = atoi(argv[4]);
    else
        ctx.trans_protcol = 0;
    if (argc > 5)
        ctx.dl_protcol = atoi(argv[5]);
    else
        ctx.dl_protcol = 3;

    printf("Hello OTA.\n");
    ota_service_init(&ctx);
    while (1) {
        IOT_MQTT_Yield((void *)mqtt_get_instance(), 200);
        sleep(1);
    };
    return 0;
}
