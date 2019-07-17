# coding: utf-8
import requests
###from utility.ding import dingtalk_fota
###from config import *
import base64
import time
import os
import hashlib
import re
import json
import sys, time
from autotest import Testcase

###env = get_env()
###__env__ = env['active']
###__host__ = env[__env__]['host']
###__hsf_version__ = env[__env__]['version']

__host__ = "https://iottestproxy.aliyun-inc.com/iotApi/genericCall"
__hsf_version__= "1.0.0.pre"

# 稳定性测试参数
__REQUEST_ID__ = 'proxy'
__TENANT_ID__ = 'internal'
__PROJECT_ID__ = 0
__SUITE_ID__ = 0
__TEST_TYPE__ = 4
__TEST_MODE__ = 1
__BIZ_TYPE__ = 1
required_devices = [ [1, 'general'] ]


def assemble_request(method, form):
    params = assembel_params(method, form)
    if not params:
        return None
    user_id = form['userId']
    return {
        'args': [
            __REQUEST_ID__,
            user_id,
            __TENANT_ID__,
            method,
            params
        ],
        'argsType': [
            'java.lang.String',
            'java.lang.String',
            'java.lang.String',
            'java.lang.String',
            'com.aliyun.iotx.test.vo.TaskRequestDO'
        ],
        'version': __hsf_version__,
        'group': 'HSF',
        'timeout': 10000,
        'method': 'taskManageRequest',
        'interfaceName': 'com.aliyun.iotx.test.open.TaskMgrServiceOpen'
    }


def assembel_params(method, form):
    userId = form['userId']
    userName = form['userId']
    if method in ['create']:
        count = int(form['count'])
        upgradeVersion = form['upgradeVersion']
        rollbackVersion = form['rollbackVersion']
        timeout = int(form['timeout'])
        interval = int(form['interval'])
        return {
            'projectId': __PROJECT_ID__,
            'groupId': userId,
            'suiteId': __SUITE_ID__,
            'taskName': 'FOTA压测-{}'.format(userId),
            'taskDescription': 'FOTA压测-{}'.format(userId),
            'testDevice': [
                {
                    'productKey': form['productKey'],
                    'deviceName': form['deviceName']
                }
            ],
            'testContext': {
                'testType': __TEST_TYPE__,
                'testMode': __TEST_MODE__,
                'bizType': __BIZ_TYPE__
            },
            'testConfig': {
                'count': count,
                'timeout': timeout,
                'fota': {
                    'interval': interval,
                    'upgradeVersion': upgradeVersion,
                    'rollbackVersion': rollbackVersion
                }
            }
        }
    if method in ['list']:
        return {
            'groupId': userId,
            'pageNum': form['pageNum'],
            'pageSize': form['pageSize'],
            'testContext': {
                'testType': __TEST_TYPE__,
                'bizType': __BIZ_TYPE__
            }
        }
    if method in ['start', 'list', 'stop', 'delete']:
        return {
            'groupId': userId,
            'projectId': __PROJECT_ID__,
            'id': int(form['id']),
            'testContext': {
                'testType': __TEST_TYPE__,
                'bizType': __BIZ_TYPE__
            }
        }
    if method in ['upload']:
        return {
            'gourpId': userId,
            'testDevice': [
                {
                    'productKey': form['productKey'],
                    'deviceName': form['deviceName']
                }
            ],
            'testConfig': {
                'url': form['url'],
                'size': form['size'],
                'md5': form['md5'],
                'version': form['version']
            },
            'testContext': {
                'bizType': 1,
                'testType': 4
            }
        }
    if method in ['query']:
        return {
            "id": form['id'],
            "projectId": __PROJECT_ID__,
            "groupId": userId,
            "testContext":{
                "testType": 4,
                "bizType": 1
            }
        }
    return None

def perform_get_respones(id, form):

    retry = 500
    recordcnt = 0
    while (retry > 0):
        time.sleep(10)
        retry -= 1
        request = assemble_request('query', {
            'id': id,
            'userId': form['userId']
        })

        response = requests.post(__host__, json=request)
        records = json.loads(response.content)['data']['records']
        print("the progress is " + str(records[0]['progress']))
        if records[0]['progress'] == 100:
            print(records)
            print("the progress is " + str(records[0]['progress']))
            print(records[0]['caseSuccessCount'])
            print(records[0]['caseFailCount'])
            return 1
    return 0

def perform_create_request(method, form):

    # 创建任务
    request = assemble_request(method, form)
    print(request)
    response = requests.post(__host__, json=request)
    data = json.loads(response.content)
    if data['code'] != 200:
        return data

    # 启动任务
    id = data['data']['id']
    request = assemble_request('start', {
        'id': id,
        'userId': form['userId']
    })
    print(request)
    response = requests.post(__host__, json=request)
    data = json.loads(response.content)
    if data['code'] == 200:
 ###       dingtalk_fota(id, form)
        elapsed_time = time.time()
        perform_get_respones(id, form)
        elapsed_time = time.time() - elapsed_time
        print "elapsed_time: {0}".format(elapsed_time)
        return data

    # 启动失败，则删除任务
    request = assemble_request('delete', {
        'id': id,
        'userId': form['userId']
    })
    print(request)
    requests.post(__host__, json=request)
    return data


def perform_upload_request(method, form, files):

    if 'version' not in form or \
            'productKey' not in form or \
            'deviceName' not in form:
        return {
            'code': 505,
            'message': 'productKey/deviceName/firmwareVersion can not be null',
        }
    product_key = form['productKey']
    device_name = form['deviceName']
    version = form['version']

    cfg = get_config('upload')
    file = files['firmware']
    file_name = '{}.bin'.format(time.time()*1000)
    file.save(file_name)
    f = open(file_name, 'rb')
    bytes = f.read()
    f.close()
    size = os.path.getsize(file_name)
    md5_obj = hashlib.md5()
    md5_obj.update(bytes)
    md5 = md5_obj.hexdigest()
    os.remove(file_name)

    # 上传OSS
    resp = requests.post(cfg['host'], json={
        'fileName':  '{}.bin'.format(int(time.time() * 1000)),
        'fileBytes': base64.b64encode(bytes)
    })
    response = json.loads(resp.content)
    if response['code'] != 200:
        return {
            'code': 506,
            'message': 'upload firmware fail',
        }
    url = response['data']
    request = assemble_request(method, {
        'url': url,
        'size': size,
        'md5': md5,
        'version': version,
        'productKey': product_key,
        'deviceName': device_name,
        'userId': form['userId']
    })
    print(request)
    if request:
        response = requests.post(__host__, json=request)
        if response.content:
            return json.loads(response.content)
    return {
        'code': 507,
        'message': 'add firmware fail'
    }

    # try:
    #     version = re.search(r'app-\d.\d.\d-\d{8}.\d{4}', str(bytes)).group(0)
    # except AttributeError:
    #     version = '1.0'
    #
    # response['data'] = {
    #     'url': url,
    #     'size': size,
    #     'md5': md5,
    #     'version': version
    # }
    # return response

# TODO
def perform_log_request(method, form):
    data = {}
    return data


def perform_request(method, form, **kwargs):
    if method == 'create':
        return perform_create_request(method, form)
    if method == 'upload':
        response = perform_upload_request(method, form, kwargs['files'])
        if 'data' not in response or not response['data']:
            response['data'] = {}
        if 'url' not in response['data']:
            response['data']['url'] = ''
        return response
    request = assemble_request(method, form)
    if request:
        response = requests.post(__host__, json=request)
        if response.content:
            return json.loads(response.content)
    return 0

def main():

    tc = Testcase('stress_test')

    script_path = os.path.dirname(os.path.abspath(__file__)) + '/device-test-client.sh'
    print script_path

    number, purpose = required_devices[0]
    [ret, result] = tc.start(number, purpose)
    if ret != 0:
        tc.stop()
        print '\nlinkkit connect test failed'
        return [ret, result]

    arg0 = 'fota upload'
    productKey = 'a1yoMJ3Z34O'
    localPath = tc.firmware
    print localPath
    firmwarename = tc.firmware.split('.')[0]
    rollbackversionfile = firmwarename + '.txt'
    print rollbackversionfile
    exist = os.path.exists(rollbackversionfile)
    if exist:
        f = open(rollbackversionfile, "r")
        line = f.readline()
        if line:
            line = line.split(' ')
            rollbackVersion = line[2].replace('1', '2', 1)
#            rollbackVersion = line[2]
            print rollbackVersion
            f.close()
        os.system(script_path + ' ' + arg0 + ' ' + productKey + ' ' + localPath + ' ' + rollbackVersion)
    else:
        print 'the file', rollbackversionfile, "is not exist"
        return 1

    localPath = tc.firmware.replace('A', 'B')
    print localPath
    upgradeversionfile = firmwarename.replace('A', 'B') + '.txt'
    print upgradeversionfile
    exist = os.path.exists(upgradeversionfile)
    if exist:
        f = open(upgradeversionfile, "r")
        line = f.readline()
        if line:
            line = line.split(' ')
            upgradeVersion = line[2]
            print upgradeVersion
        f.close()
        os.system(script_path + ' ' + arg0 + ' ' + productKey + ' ' + localPath + ' ' + upgradeVersion)
    else:
        print 'the file', upgradeversionfile, "is not exist"
        return 1

    ap_ssid = tc.ap_ssid
    ap_pass = tc.ap_pass
    at = tc.at

    time.sleep(10)  #wait device boot up
    at.device_run_cmd('A', 'netmgr connect {0} {1}'.format(ap_ssid, ap_pass)) #connect device A to wifi

    form = {
        "count":"5",
        "upgradeVersion":upgradeVersion,
        "rollbackVersion":rollbackVersion,
        "timeout":"300",
        "productKey":productKey,
        "deviceName":"esp32_ota_test",
        "interval":"20",
        "userId":"148528"
    }
    method = "create"

    perform_request(method, form)
    data = {}
    return 0


if __name__ == '__main__':
    ret = main()
    sys.exit(ret)
