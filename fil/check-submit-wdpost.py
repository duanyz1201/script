#!/usr/bin/python3.9

import requests,sys,json,time,pymongo

node_list = [
    {"miner_id":"f02125293","deadline_0_start_at":"14:00:00","double_partition":[],"active_deadlines":[0,1,2,3,4,5,6,7,9,10,11,12,13,14,15,16,19,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47]},
    {"miner_id":"f02131865","deadline_0_start_at":"15:26:30","double_partition":[],"active_deadlines":[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22]},
    {"miner_id":"f02173949","deadline_0_start_at":"04:18:30","double_partition":[],"active_deadlines":[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36]},
    {"miner_id":"f02309036","deadline_0_start_at":"23:08:30","double_partition":[],"active_deadlines":[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29]},
    {"miner_id":"f02290991","deadline_0_start_at":"17:05:00","double_partition":[],"active_deadlines":[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28]},
 #   {"miner_id":"f02047841","deadline_0_start_at":"04:24:00","double_partition":[],"active_deadlines":[0,1,2,3]},
    {"miner_id":"f01159754","deadline_0_start_at":"11:03:00","double_partition":[5,10],"active_deadlines":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42]},
    {"miner_id":"f03156722","deadline_0_start_at":"12:59:30","double_partition":[],"active_deadlines":[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47]}
]

period_submit_wdpost_minutes = 20

def log(s):
    #print(s)
    #return
    dt = time.strftime("%F %T",time.localtime(time.time()))
    # filePath = "/data/logs/check-wdpost.log"
    filePath = "/root/godaner/logs/check-submit-wdpost.log"
    with open(filePath, 'a') as f:
        f.write(json.dumps({"dt": dt, "msg": s}, ensure_ascii=False)+'\n')

def send_message(message:str,call:bool):
    chs = ["wecom"]
    if call:
        chs = ["wecom", "mobile"]
    data ={
        "rule_name": message,
        "severity": 1,
        "notify_channels": chs,
        "single_event": True,
        "notify_groups_obj": [{"name":"godaner"}],
    }

    url = "http://172.28.56.66:10086/notify/outer"
    headers = {"Content-Type": "application/json"}

    try:
        r = requests.post(url=url, data=json.dumps(data),headers=headers, timeout=5)
        log(r.text)
    except Exception as err:
        log("failed to send message! err=%s" %err)

    #sys.exit(1)

def get_latest_submit_wdpost_ts(miner:str,deadlines:int,partitions:int) -> int:
    try:
        client = pymongo.MongoClient("172.28.56.102", 20023, username="chihua", password="leUgqL4hvceQ0uO",
                             authSource="filecoin_chain_all")
        db = client.filecoin_chain_all
        col = db["message"]

        r = col.find({"md":50,"to":miner,"ec":0},{"ts":1}).sort([("ht",-1)]).limit(partitions)
        # 默认返回最近一条提交的时间 如果有2个partition 返回时间最小的一条
        result = []
        for i in r:
            result.append(i["ts"])
        if partitions > 1:
            log("%s:%d:%d double partition submit at %s" %(miner,deadlines,partitions," ".join([str(i) for i in result])))
        result.sort()

        client.close()
        return result[0]
    except Exception as err:
        log("failed to get_latest_wdpost_ts err=%s" % err)
        send_message("获取最新wdpost时间失败:%s" % miner, False)

today = time.strftime("%F")
log("################################# split line #################################")

for node in node_list:
    miner_id = node["miner_id"]
    start_time = node["deadline_0_start_at"]
    deadline_0_start_at_ts = int(time.mktime(time.strptime("%s %s"%(today,start_time),"%Y-%m-%d %H:%M:%S")))
    now = int(time.time())
    if now < deadline_0_start_at_ts:
        deadline_0_start_at_ts-=86400
    current_deadline = int((now-deadline_0_start_at_ts)/1800)
    current_deadline_open = deadline_0_start_at_ts + current_deadline*1800
    current_deadline_used_seconds = (now-deadline_0_start_at_ts)%1800
    # print(miner_id,start_time,deadline_0_start_at_ts,now,current_deadline,current_deadline_open,current_deadline_used_seconds)

    if current_deadline not in node["active_deadlines"]:
        log("%s:%d (open: %s) not active deadline. skipped"
            %(miner_id,current_deadline,time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(current_deadline_open)))
        )
        continue

    partition = 1
    if current_deadline in node["double_partition"]:
        partition = 2

    if current_deadline_used_seconds < period_submit_wdpost_minutes*60:
        # print(current_deadline_used_seconds,period_submit_wdpost_minutes*60)
        log("%s:%d:%d (open: %s) open %d minutes, less than period %d minutes. skipped"
            %(miner_id,current_deadline,partition,time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(current_deadline_open)),
              int(current_deadline_used_seconds/60),period_submit_wdpost_minutes)
        )
        continue

    latest_submit_ts = get_latest_submit_wdpost_ts(miner_id,current_deadline,partition)

    # 如果最新提交时间 小于 当前deadline开始时间 代表当前deadline未提交
    if latest_submit_ts < current_deadline_open:
        log("%s:%d:%d (open: %s ｜ %d:%d) open %d minutes, current deadline not submit, remaining %d minutes!"
            % (miner_id, current_deadline,partition,time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(current_deadline_open)),
               latest_submit_ts,current_deadline_open,int(current_deadline_used_seconds / 60), 30 - int(current_deadline_used_seconds / 60))
        )
        send_message("wdpost消息未提交%s" %miner_id, True)
        continue

    log("%s:%d:%d (open: %s) open %d minutes, submited wdpost took %d minutes."
        % (miner_id, current_deadline,partition,time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(current_deadline_open)),
           int(current_deadline_used_seconds / 60),int((latest_submit_ts-current_deadline_open)/60))
    )