# coding: utf-8
import requests
import logging
###from utility.ding import dingtalk_stability
###from utility.log_tmp import *
###from config import *
###from utility.monitor import monitor
import json
import time
from autotest import Testcase

logging.basicConfig(level=logging.INFO)

###env = get_env()
###__env__ = env['active']
###__host__ = env[__env__]['host']
###__hsf_version__ = env[__env__]['version']


###logging.info('env: {}'.format(__env__))
###logging.info('host: {}'.format(__host__))
###logging.info('hsf version: {}'.format(__hsf_version__))

# 稳定性测试参数
__REQUEST_ID__ = 'proxy'
__TENANT_ID__ = 'internal'
__PROJECT_ID__ = 0
__GROUP_ID__ = ''
__SUITE_ID__ = 0
__TEST_TYPE__ = 1
__TEST_MODE__ = 1
__BIZ_TYPE__ = 1

required_devices = [ [1, 'general'] ]
__query_property_set = "PROPERTY_SETTING AND thing.service.property.set"
__query_property_set_reply = "PROPERTY_SETTING_REPLY AND thing.service.property.set.reply"
__query_service_call = "SERVICE_CALL AND thing.service.*"
__query_service_call_reply = "thing.service.invoke.reply"
__query_property_post = "PROPERTY_REPORT AND thing.event.property.post"
__query_property_post_reply = "thing.event.property.post.reply"
__query_offline = "(device offline and not downstream)"
__query_online = "device online"


__host__ = "https://iottestproxy.aliyun-inc.com/iotApi/genericCall"
__hsf_version__= "1.0.0.pre"

form = {
    "productKey":"a1yoMJ3Z34O",
    "deviceName":"mk3060_linkkit_test",
    "intervalMin":0.5,
    "intervalMax":0.5,
    "frequency":2,
    "duration":0.2,
    "userId":"148528"
}
method = "create"



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
    if method in ['create']:
        duration = int(form['duration'] * 3600)
        interval = 1 / float(form['frequency'])
        return {
            'projectId': __PROJECT_ID__,
            'groupId': userId,
            'suiteId': __SUITE_ID__,
            'taskName': '通道压测-{}'.format(userId),
            'taskDescription': '通道压测-{}'.format(userId),
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
                'duration': duration,
                'thing': {
                    'intervalMin': interval,
                    'intervalMax': interval
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
    if method in ['query']:
        return {
            "id": form['id'],
            "projectId": __PROJECT_ID__,
            "groupId": userId,
            "testContext":{
                "testType": __TEST_TYPE__,
                "bizType": __BIZ_TYPE__
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
        data = json.loads(response.content)
        records = json.loads(response.content)['data']['records']
        if records[0]['progress'] == 100:
            print(records)
            print("the progress is " + str(records[0]['progress']))
            return 1
    return 0

def perform_create_request(method, form):

    frequency = float(form['frequency'])
###    if monitor.is_burden(frequency):
###        return {
###            'code': 8000,
###            'message': '下行消息量太大，请稍后再试',
###            'success': False
###        }

    # 创建任务
    request = assemble_request(method, form)
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
    response = requests.post(__host__, json=request)
    data = json.loads(response.content)
    if data['code'] == 200:
###        dingtalk_stability(id, form)
        perform_get_respones(id, form)
        return data

    # 启动失败，则删除任务
    request = assemble_request('delete', {
        'id': id,
        'userId': form['userId']
    })
    requests.post(__host__, json=request)
    return data


def perform_log_request(method, form):
    data = {}
    product_key = form['productKey']
    device_name = form['deviceName']
    from_time = int(form['fromTime']) / 1000
    to_time = int(form['toTime']) / 1000
    if to_time <=0:
        to_time = int(time.time())
    if from_time == to_time:
        return data
    base_query = '({} and {} and {})'.format(product_key, device_name, 'success')

    query = '{} and {}'.format(base_query, __query_property_set)
    data['propertySet'] = get_count('属性设置', query, from_time, to_time)

    query = '{} and {}'.format(base_query, __query_property_set_reply)
    data['propertySetReply'] = get_count('属性设置reply', query, from_time, to_time)

    query = '{} and {}'.format(base_query, __query_property_post)
    data['propertyPost'] = get_count('属性上报', query, from_time, to_time)

    query = '{} and {}'.format(base_query, __query_property_post_reply)
    data['propertyPostReply'] = get_count('属性上报reply', query, from_time, to_time)

    query = '{} and {}'.format(base_query, __query_service_call)
    data['serviceCall'] = get_count('服务调用', query, from_time, to_time)

    query = '{} and {}'.format(base_query, __query_service_call_reply)
    data['serviceCallReply'] = get_count('服务调用reply', query, from_time, to_time)

    query = '{} and {}'.format(base_query, __query_offline)
    logs = get_log('离线次数', query, from_time, to_time)
    data['offlineTimes'] = len(logs)

    timeline = {}
    for item in logs:
        try:
            timestring = item.split(',')[0].split('.')[0]
            timestamp = time.mktime(time.strptime(timestring, "%Y-%m-%d %H:%M:%S"))
            timeline[timestamp] = 'OFFLINE'
        except Exception:
            pass

    query = '{} and {}'.format(base_query, __query_online)
    logs = get_log('上线次数', query, from_time, to_time)
    data['onlineTimes'] = len(logs)
    for item in logs:
        try:
            timestring = item.split(',')[0].split('.')[0]
            timestamp = time.mktime(time.strptime(timestring, "%Y-%m-%d %H:%M:%S"))
            timeline[timestamp] = 'ONLINE'
        except Exception:
            pass
    timeline = sorted(timeline.items(), key=lambda item: item[0])
    data['timeline'] = []
    for item in timeline:
        data['timeline'].append({'timestamp':int(item[0]*1000), 'action': item[1]})
    return data


def perform_request(method, form):


 

    if method == 'create':
        return perform_create_request(method, form)
    if method == 'log':
        return perform_log_request(method, form)
    request = assemble_request(method, form)
    if request:
        response = requests.post(__host__, json=request)
        if response.content:
            return json.loads(response.content)
    return None

def main():

    tc = Testcase('linkkit_stress_test')
    ap_ssid = tc.ap_ssid
    ap_pass = tc.ap_pass
    at = tc.at

    number, purpose = required_devices[0]
    [ret, result] = tc.start(number, purpose)
    if ret != 0:
        tc.stop()
        print '\nlinkkit connect test failed'
        return [ret, result]

    time.sleep(16)  #wait device boot up
    at.device_run_cmd('A', 'netmgr connect {0} {1}'.format(ap_ssid, ap_pass)) #connect device A to wifi
    time.sleep(10)
    perform_request(method, form)
    data = {}
    return data

if __name__ == '__main__':
    main()