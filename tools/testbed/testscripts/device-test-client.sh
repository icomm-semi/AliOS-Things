#! /bin/bash
__version__=10
__local_name__=`basename $0`
__abs_local_name__=$(cd `dirname $0`; pwd)/$__local_name__
__remote_name__="device-test-client"

# 站点选择，shanghai | singapore
__endpoint__=shanghai

# 环境选择，daily | pre | online
__env__=online

# 租户Id，默认对应"certificate_test"账号, 仅FOTA测试需要
#__tenantId__="7D91631143584929B52CE55839E6D10F"
__tenantId__="B1234413DB514B22AF306634DEBC07C0"

# userId，默认对应"certificate_test"账号, 仅FOTA测试需要
#__uid__="1214925245209540"
__uid__="1194808133660814"

# 项目资源隔离Id，与项目对应，默认为 "认证测试专用项目", 仅FOTA测试需要
#__firmwareIsoId__="a103fqgzP1NrCugG"
__firmwareIsoId__="a103vlCA6HrJEk5e"

# 设备资源隔离id
#__isoId__="qI4mhhjklQDqaNKAZrxr00006c2b00"
__isoId__="a103PrdKDwMLsRau"

#################################################
# common functions
#################################################
get_os() {
    echo `uname`
}

check_support_os() {
    if [ "$(get_os)" != "Linux" ] && [ "$(get_os)" != "Darwin" ];then
        echo "Not Supported OS type!"
        exit
    fi
}

check_upgrade() {
    echo "$__local_name__ version $__version__.0"
    __url__="http://gitlab.alibaba-inc.com/shaofa.lsf/linkkit-channel-test/raw/master/client"
    new_version=`curl -s $__url__/`
    if [ -z "$new_version"  ];then
        echo "获取新版本失败"
        exit
    fi
    if [ $new_version -gt $__version__ ];then
        echo "新版本: $new_version, 尝试升级..."
        curl -s $__url__/$__remote_name__ -o $__abs_local_name__
        echo "升级结束!"
        exit
    fi
}

parse_json() {
    result=$(echo ${1//\"/} | sed "s/.*$2:\([^,}]*\).*/\1/")
    valid=`echo "$result" | grep -o "[{}]"`
    if [ -n "$valid" ];then
        echo ''
    else  
        echo "$result"
    fi
}

time_diff() {
    __time_from__=$1
    __time_to__=$2
    if [ -z "$__time_to__" ];then
        __time_to__=`date +%s`
    fi
    echo $(($__time_to__-$__time_from__))
}

utc_to_timestamp() {
    utc=$1
    check_support_os
    case $(get_os) in
        Linux)
            opt="-d @$utc";;
        Darwin)
            opt="-r $utc";;
    esac
    echo "$(date $opt '+%Y-%m-%d %H:%M:%S')"
}

__address__() {
    p_shanghai=19910; p_singapore=19913
    e_daily=0; e_pre=1; e_online=2
    case $__endpoint__ in
        shanghai | singapore)
            base=$((p_$__endpoint__))
            ;;
        *)
            echo "endpoint '$2' is not support, support list:"
            echo -e "* shangahi\n* singapore"
            exit
            ;;
    esac
    case $__env__ in
        daily | pre | online)
            diff=$((e_$__env__))
            ;;
        *)
            echo "env '$2' is not support, support list:"
            echo -e "* daily\n* pre\n* online"
            exit
            ;;
    esac
    echo "http://30.40.14.137:`expr $base + $diff`/test"
    # echo "127.0.0.1:19912/test"
}

__request__() {
    user=`whoami`
    random_path=~/.$__local_name__.random
    if [ -e $random_path ]; then
        random=`cat $random_path`
    else
        random=`date +%s%N`
        echo $random >$random_path
    fi
    cat=$random
    sub_body=$1
    body="'method':'$METHOD','tenantId':'$__tenantId__','isoId':'$__isoId__','uid':'$__uid__','cat':'$cat'"
    body="{$body,$sub_body}"
    address=`__address__`/$TYPE
    request=$body
    response=`curl -s -H "Content-Type:application/json" -X POST -d "$body" $address` 
    echo $response
}

#################################################
# pressure functions
#################################################
pressure_usage() {
    echo -n "Usage: $__local_name__ $TYPE "
    if [ $# -lt 1 ];then
        echo "{start|stop|progress|query} ..."
        echo "start:    启动压测任务"
        echo "stop:     停止压测任务"
        echo "progress: 查询压测进度"
        echo "query:    查询所有压测任务"
        exit
    fi
    case $1 in 
        start)
            echo "$1 {productKey} {deviceName} {identifier} {value} {frequency} {duration}"
            echo "启动压测任务"
            echo "productKey: product key"
            echo "deviceName: device name"
            echo "identifier: TSL属性标识符(必须为整型)"
            echo "value:      TSL属性值(必须为整型)"
            echo "frequency:  属性设置频率,单位Hz"
            echo "duration:   属性设置时长,单位秒"
            exit;;
        stop)
            echo "$1 {productKey} {deviceName}"
            echo "停止压测任务"
            echo "productKey: product key"
            echo "deviceName: device name"
            exit;;
        progress)
            echo "$1 {productKey} {deviceName}"
            echo "查询压测进度"
            echo "productKey: product key"
            echo "deviceName: device name"
            exit;;
        query)
            echo "查询所有压测任务"
    esac
}

pressure_entry() {
    METHOD=$1
    shift 1
    case $METHOD in
        start)
            if [ $# -lt 6 ];then
                ${TYPE}_usage $METHOD
            fi
            ;;
        stop | progress)
            if [ $# -lt 2 ];then
                ${TYPE}_usage $METHOD
            fi
            ;;
        query)
            ;;
        *)
            ${TYPE}_usage;;
    esac
    ${TYPE}_${METHOD} $@
}

pressure_start() {
    sub_body="'productKey':'$1','deviceName':'$2','identifier':'$3','value':$4,'frequency':$5,'duration':$6"
    response=$(__request__ $sub_body)
    code=$(parse_json "$response" "code")
    msg=$(parse_json "$response" "msg")
    echo "RESPONSE: "$response
    if [ "$code" = "200" ];then
        echo "启动压测成功, 使用'pressure progress'查看压测进度"
    else
        echo "启动压测失败($msg)"
        if [ "$code" = "10008" ];then
            value=$(parse_json "$response" "value")
            data=$(parse_json "$response" "data")
            data=${data//&&/ }
            index=0
            echo | awk '{printf "|%-4s|%-20s|%-12s|%-20s|%-10s|\n","No.","Cat","ProductKey","DeviceName","Status"}'
            echo "---------------------------------------------------------------------------"
            for ele in $data
            do
                index=`expr $index + 1`
                echo "$index ${ele//;/ }" | awk '{printf "|%-4s|%-20s|%-12s|%-20s|%-10s|\n",$1,$3,$4,$5,$2}'
            done
        fi
    fi
}

pressure_stop() {
    sub_body="'productKey':'$1','deviceName':'$2'"
    response=$(__request__ $sub_body)
    code=$(parse_json "$response" "code")
    msg=$(parse_json "$response" "msg")
    echo "RESPONSE: "$response
    if [ $code -eq 200 ];then
        echo "取消压测成功"
        pressure_progress_show $response
    else
        echo "取消压测失败($msg)"
    fi
}

pressure_progress() {
    sub_body="'productKey':'$1','deviceName':'$2'"
    response=$(__request__ $sub_body)
    code=$(parse_json "$response" "code")
    msg=$(parse_json "$response" "msg")
    echo "RESPONSE: "$response
    if [ "$code" = "200" ];then
        echo "查询进度成功" 
        pressure_progress_show $response
    else
        echo "查询进度失败($msg)"
    fi
}

pressure_query() {
    sub_body=""
    response=$(__request__ $sub_body)
    code=$(parse_json "$response" "code")
    msg=$(parse_json "$response" "msg")
    value=$(parse_json "$response" "value")
    data=$(parse_json "$response" "data")
    echo "任务数: $value"
    if [ $value -eq 0 ];then
        return
    fi
    if [ "$code" = "200" ];then
        data=${data//&&/ }
        index=0
        echo | awk '{printf "|%-4s|%-28s|%-12s|%-20s|%-10s|\n","No.","Cat","ProductKey","DeviceName","Status"}'
        echo "---------------------------------------------------------------------------"
        for ele in $data
        do
            index=`expr $index + 1`
            echo "$index ${ele//;/ }" | awk '{printf "|%-4s|%-28s|%-12s|%-20s|%-10s|\n",$1,$3,$4,$5,$2}'
        done
    fi
}


pressure_progress_show() {
    response=$1
    startTime=$(parse_json "$response" "startTime")
    finishTime=$(parse_json "$response" "finishTime")
    startTime=$(($startTime/1000))
    echo "压测进度: "$(parse_json "$response" "progress")%
    echo "压测频率: "$(parse_json "$response" "frequency")Hz
    echo "压测时长: "$(parse_json "$response" "duration")s
    echo "压测属性: "$(parse_json "$response" "identifier")
    echo "下行数量: "$(parse_json "$response" "downStream")
    echo "上行数量: "$(parse_json "$response" "upStream")
    echo "开始时间: "$(utc_to_timestamp $startTime)
    if [ $finishTime -lt $startTime ];then
        finishTime=$(date +%s)
    else
        finishTime=$(($finishTime/1000))
        echo "开始时间: "$(utc_to_timestamp $finishTime)
    fi
    echo "运行时间: "$(time_diff $startTime $finishTime)s
}

#################################################
# model functions
#################################################
model_usage() {
    echo "Usage: $__local_name__ $TYPE {prodcutKey} {deviceName}"
    echo "TSL模型测试，遍历设置所有属性、调用所有服务"
    echo "productKey: product key"
    echo "deviceName: device name"
    exit
}

model_entry() {
    if [ $# -lt 2 ];then
        ${TYPE}_usage
    fi
    ${TYPE}_start $@
}

model_start() {
    productKey=$1
    deviceName=$2
    sub_body="'productKey':'$productKey','deviceName':'$deviceName'"
    echo "正在遍历设置属性、调用服务..."
    start_time=`date +%s`
    response=$(__request__ $sub_body)
    code=$(parse_json "$response" "code")
    msg=$(parse_json "$response" "msg")
    echo "RESPONSE: "$response
    if [ "$code" = "200" ];then
        echo "模型测试完成, 耗时`time_diff $start_time`s"
        fails=$(echo ${response//\"/} | grep -P -o "\b\w+\b(?=:\[\])")
        if [ -n "$fails" ]; then
            echo "以下属性设置失败:"$fails
        fi
    else
        echo "模型测试失败($msg)"
    fi
}

#################################################
# FOTA functions
#################################################
fota_usage() {
    echo -n "Usage: $__local_name__ $TYPE "
    if [ $# -lt 1 ];then
        echo "{upload|query|upgrade|loop_upgrade|progress} ..."
        echo "upload:       上传本地固件到服务端"
        echo "query:        根据产品Key和版本号查询已上传的固件"
        echo "upgrade:      触发升级"
        echo "progress:     根据产品Key和版本号查询升级进度"
        echo "loop_upgrade: 循环多次升级,upgrade和progress的组合,实现V1->V2->V1"
        exit
    fi
    case $1 in
        upload)
            echo "$1 {productKey} {localPath} {firmwareVersion}"
            echo "上传本地固件到服务端"
            echo "productKey:      待上传固件所属产品"
            echo "localPath:       固件本地路径"
            echo "firmwareVersion: 固件版本号";;
        upgrade)
            echo "{productKey} {deviceName} {oldVersion} {newVersion}"
            echo "触发升级"
            echo "productKey:    待升级设备所属产品"
            echo "deviceName:    待升级设备名"
            echo "oldVersion:    当前设备版本号"
            echo "newVersion:    待升级版本号";;
        query)
            echo "{productKey} {firmwareVersion}"
            echo "根据产品Key和版本号查询固件"
            echo "productKey:      待查询固件所属产品"
            echo "firmwareVersion: 待查询固件版本号";;
        progress)
            echo "{prodictKey} {firmwareVersion}"
            echo "根据产品Key和版本号查询升级进度"
            echo "productKey:      待查询固件所属产品"
            echo "firmwareVersion: 待查询固件版本号";;
        loop_upgrade)
            echo "{productKey} {deviceName} {oldVersion} {newVersion} {fackVersion} [times=100]"
            echo "循环多次升级,upgrade和progress的组合,实现V1->V2->V1"
            echo "productKey:    待升级设备所属产品"
            echo "deviceName:    待升级设备名"
            echo "oldVersion:    当前设备版本号"
            echo "newVersion:    待升级版本号"
            echo "fackVersion:   回滚版本号，fackVersion>newVersion>oldVersion, fackVersion的固件真实版本号应该是oldVersion"
            echo "times:         循环次数，默认100次";;
        *)
            ;;
    esac
    exit;
}

fota_entry() {
    METHOD=$1
    shift 1
    case $METHOD in 
        upload)
             if [ $# -lt 3 ];then
                ${TYPE}_usage $METHOD
            fi
            ;;
        upgrade)
            if [ $# -lt 4 ];then
                ${TYPE}_usage $METHOD
            fi
            ;;
        query)
            if [ $# -lt 2 ]; then
                ${TYPE}_usage $METHOD
            fi
            ;;
        progress)
            if [ $# -lt 2 ]; then
                ${TYPE}_usage $METHOD
            fi
            ;;
        loop_upgrade)
            if [ $# -lt 5 ];then
                ${TYPE}_usage $METHOD
            fi
            ;;
        *)
            ${TYPE}_usage;;
    esac
    ${TYPE}_${METHOD} $@
}

fota_upload() {
    METHOD=upload
    # check ossutil installed
    ossutil=~/.ossutil
    echo "check ossutil..."
    if [ ! -e $ossutil ];then
        if [ -z "$(ossutil -v | grep 'ossutil version')" ];then
            echo "ossutil is not installed, try to install..."
            check_support_os
            if [ "$(get_os)" = "Linux" ];then
                url=http://docs-aliyun.cn-hangzhou.oss.aliyun-inc.com/assets/attach/50452/cn_zh/1524643963683/ossutil64
            elif [ "$(get_os)" = "Darwin" ];then
                url=http://docs-aliyun.cn-hangzhou.oss.aliyun-inc.com/assets/attach/50452/cn_zh/1524644116085/ossutilmac64
            else
                echo "not supported OS!"
                exit
            fi
            wget $url -O $ossutil
        else
            echo "ossutil is already installed"
            ln -s `which ossutil` $ossutil
        fi
    fi
    chmod +x $ossutil

    productKey=$1
    local_path=$2
    version=$3
    oss_bucket="iot-test"
    oss_endpoint="oss-cn-hangzhou.aliyuncs.com"
    oss_path="iottest/aitc/ota_firmware"
    if [ ! -e $local_path ];then
        ehco "错误：'$local_path' 文件不存在!"
        exit
    fi
    if [ ! -f $local_path ];then
        echo "错误：'$local_path' 不是一个文件!"
        exit
    fi
    md5=$($ossutil hash --type=md5 $local_path | grep -o "[0-9A-Z]\{32\}")
    echo $md5
    size=$(ls -l $local_path | awk '{print $5}')
    name=`date +%s%N`.bin
    $ossutil config -e $oss_endpoint -i LTAI3lYobufB22x4 -k unTH25L5vMZPzdnf9FLhZO8ZylfYIl
    $ossutil cp $local_path "oss://$oss_bucket/$oss_path/$name"
    if [ $? -ne 0 ];then
        echo '上传固件到OSS失败!'
        exit
    fi
    url="http://$oss_bucket.$oss_endpoint/$oss_path/$name"
    sub_body="'productKey':'$productKey','version':'$version','url':'$url','md5':'$md5','size':$size,'firmwareIsoId':'$__firmwareIsoId__'"
    response=$(__request__ $sub_body)
    code=$(parse_json "$response" "code")
    msg=$(parse_json "$response" "msg")
    firmwareId=$(parse_json "$response" "firmwareId")
    echo "RESPONSE: "$response
    if [ "$code" != "200" ];then
        $ossutil rm $url
        echo -n "上传失败"
        if [ "$code" = "9136" ];then
            echo "('$productKey'产品下版本号为'$version'的固件已存在,firmwareId=$firmwareId)"
        fi
        exit
    else
        echo "上传固件成功,firmwareId=$firmwareId"
    fi
}

fota_upgrade() {
    METHOD=upgrade
    start_time=`date +%s`
    productKey=$1
    deviceName=$2
    oldVersion=$3
    newVersion=$4
    sub_body="'firmwareIsoId':'$__firmwareIsoId__','productKey':'$productKey','deviceName':'$deviceName','srcVersion':'$oldVersion','descVersion':'$newVersion'"
    response=$(__request__ $sub_body)
    code=$(parse_json "$response" "code")
    msg=$(parse_json "$response" "msg")
    #echo "RESPONSE: "$response
    if [ "$code" != "200" ];then
        echo -n "触发升级失败"
        if [ "$code" = "460" ];then
            echo ": '$productKey'产品下版本号为'$newVersion'的固件不存在,请确保固件已上传成功"
        else
            echo ": $msg"
        fi
        return 0
    fi

    while [ true ];
    do
        fota_progress $productKey $newVersion
        ret=$?
        case $ret in
            1 | 4)
                ;;
            2)
                return 2;;
            3)
                return 3;;
            0)
                echo "异常"
                return 10
        esac
        sleep 2
    done
}

fota_loop_upgrade() {
    METHOD=loop_upgrade
    time_consume=0
    upgrade_interval=5
    counter=0
    times=$6
    if [ -z "$times" ]; then
        times=100
    fi
    while [ $counter -lt $times ]
    do
        let counter=$counter+1
        productKey=$1
        deviceName=$2
        oldVersion=$3
        newVersion=$4
        fackVersion=$5
        echo "###### 反复升级${times}次,第${counter}次开始 ######"

        echo "###### step 1.触发正常升级, [$oldVersion] -> [$newVersion]"
        start_time=`date +%s`
        fota_upgrade $productKey $deviceName $oldVersion $newVersion
        ret=$?
        this_time_consume=`time_diff $start_time`
        let time_consume=$time_consume+this_time_consume
        if [ $ret -ne 2 ];then
            echo "###### 反复升级${times}次,第${counter}次结束, 共耗时${time_consume}s ######"
            break 
        fi
        echo "###### 本次正常升级耗时 ${this_time_consume}s"

        echo "###### 休眠 ${upgrade_interval}s, 准备回滚..."
        sleep $upgrade_interval

        echo "###### step 2.触发回滚, [$newVersion] -> [$fackVersion]($oldVersion)"
        start_time=`date +%s`
        fota_upgrade $productKey $deviceName $newVersion $fackVersion
        ret=$?
        this_time_consume=`time_diff $start_time`
        let time_consume=$time_consume+this_time_consume
        if [ $ret -ne 3 ];then
            echo "###### 反复升级${times}次,第${counter}次结束, 共耗时${time_consume}s ######"
            break
        fi
        echo "###### 本次回滚耗时 ${this_time_consume}s"
        echo "###### 反复升级${times}次,第${counter}次结束, 共耗时${time_consume}s ######"
        if [ $counter -eq $times ];then
            break;
        fi
        echo "###### 休眠 ${upgrade_interval}s, 准备下次升级..."
        sleep $upgrade_interval
    done
}

fota_query() {
    METHOD=query
    productKey=$1
    version=$2
    sub_body="'firmwareIsoId':'$__firmwareIsoId__','productKey':'$productKey','version':'$version'"
    echo "查询 [${version}] 固件..."
    response=$(__request__ $sub_body)
    code=$(parse_json "$response" "code")
    msg=$(parse_json "$response" "msg")
    firmwareId=$(parse_json "$response" "firmwareId")
    firmwareName=$(parse_json "$response" "firmwareName")
    echo "RESPONSE: "$response
    if [ "$code" != 200 ];then
        echo "查询失败: $msg"
        exit
    else
        echo "查询成功: 固件名=$firmwareName, 固件Id=$firmwareId"
    fi
}

fota_progress() {
    METHOD=progress
    productKey=$1
    version=$2
    sub_body="'firmwareIsoId':'$__firmwareIsoId__','descVersion':'$version','productKey':'$productKey'"
    response=$(__request__ $sub_body)
    code=$(parse_json "$response" "code")
    msg=$(parse_json "$response" "msg")
    status=$(parse_json "$response" "status")
    result=$(parse_json "$response" "result")
    progress=$(parse_json "$response" "progress")
    if [ "$code" != 200 ];then
        echo "查询失败:$msg"
        return 0
    else
        if [ "$status" = "RUNNING" ];then
            echo "$progress% 升级中...($status, $result)"
            return 1 
        fi 
        if [ "$status" = "FINISHED" ];then
            if [ "$result" = "SUCCESS" ];then
                echo "$progress% 升级成功...($status, $result)"
                return 2 
            else
                echo "$progress% 升级失败...($status, $result)"
                return 3
            fi
        fi
        if [ "$status" = "WAITING" ];then
            echo "$progress% 等待中...($status, $result)"
            return 4
        fi 
        echo "$progress% 异常...($status, $result)"
        return 5 
    fi
}

check_support_os
#check_upgrade
if [ $# -ge 1 ];then
    TYPE=$1
    shift 1
    case $TYPE in 
        pressure | fota | model)
            ${TYPE}_entry $@
            exit;;
        *)
            ;;
    esac
fi
echo "Usage: $__local_name__ {pressure|fota|model} ..."
echo "pressure:   通道压测"
echo "fota:       FOTA压测"
echo "model:      TSL模型测试,遍历下行所有属性、服务"

