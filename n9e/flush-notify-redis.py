#!/usr/bin/env python3

import redis
import os
import json
import time
import requests
import subprocess
import datetime
from collections import defaultdict

LOG_FILE = "/root/logs/flush-notify-redis.log"

def log(level, message):
    timestamp = datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3]
    with open(LOG_FILE, "a") as f:
        f.write(f"{timestamp} {level} - {message}\n")

REDIS_HOST = '127.0.0.1'
REDIS_DB = 0
VOICE_SCRIPT = "/data/n9e/etc/script/send-tx-voice.sh"
REDIS_KEYS = {
    'alerts:pending:s1': 'voice_wecom',
    'alerts:pending:s2': 'wecom',
    'alerts:pending:s3': 'wecom'
}

WECHAT_URL_TEMPLATE = "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key={token}"

def fetch_alerts(r, key):
    alerts = []
    while True:
        item = r.lpop(key)
        if not item:
            break
        try:
            alerts.append(json.loads(item))
        except Exception as e:
            continue
    return alerts

def unix_to_str(ts):
    try:
        return datetime.datetime.fromtimestamp(int(ts)).strftime('%Y-%m-%d %H:%M:%S')
    except:
        return "-"

def handle_voice(alerts):
    """
    按 rule_name 和 notify_groups_obj.name 聚合电话告警
    单条告警传主机名，聚合多条传主机数量
    """
    # 按 (rule_name, group_name) 聚合
    grouped = defaultdict(list)
    for alert in alerts:
        e = alert.get("event", {})
        rule = e.get("rule_name", "")
        groups = e.get("notify_groups_obj", [])
        if not groups:
            grouped[(rule, "-")].append(alert)
        else:
            for g in groups:
                group_name = g.get("name", "-")
                grouped[(rule, group_name)].append(alert)

    for (rule, group_name), items in grouped.items():
        # 收集所有手机号
        phones = set()
        for alert in items:
            e = alert.get("event", {})
            for u in e.get("notify_users_obj", []):
                phone = u.get("phone", "")
                if phone:
                    phones.add(phone)
        # 组织主机信息
        if len(items) == 1:
            host = items[0].get("event", {}).get("target_ident", "")
        else:
            host = f"检测到{len(items)}台设备"
        # 依次拨打
        for phone in phones:
            subprocess.call(
                [VOICE_SCRIPT, phone, host, rule],
                stdout=open(os.devnull, 'w'),
                stderr=open(os.devnull, 'w')
            )

def group_by_token_rule_region_recover(alerts):
    grouped = defaultdict(list)
    for alert in alerts:
        e = alert.get("event", {})
        rule = e.get("rule_name", "")
        region = e.get("tags_map", {}).get("region", "-")
        is_recovered = e.get("is_recovered", False)
        users = e.get("notify_users_obj", [])
        tokens = set(u.get("contacts", {}).get("qywx_robot_token") for u in users if u.get("contacts", {}).get("qywx_robot_token"))
        for token in tokens:
            key = f"{token}::{rule}::{region}::{is_recovered}"
            grouped[key].append(alert)
    return grouped

def build_markdown(alerts):
    if not alerts:
        return "无告警"

    e0 = alerts[0].get("event", {})
    severity = e0.get("severity", "-")
    rule = e0.get("rule_name", "-")
    t = unix_to_str(e0.get("last_eval_time", 0))
    region = e0.get("tags_map", {}).get("region", "-")
    group = e0.get("group_name", "-")
    is_recovered = e0.get("is_recovered", False)
    if is_recovered:
        notify_type = "恢复通知"
        icon = "✅"
    else:
        notify_type = "告警通知"
        icon = "🚨"

    text = f"### {icon} S{severity} {notify_type}（共 {len(alerts)} 条）\n\n"
    text += f"- **{rule}**\n"
    text += f"  - 时间: {t}  \n"
    text += f"  - 机房: {region}\n"
    text += f"  - 分组: {group}\n"
    text += f"  - 主机:\n"

    for a in alerts:
        e = a.get("event", {})
        host = e.get("target_ident", "-")
        val  = e.get("trigger_value", "-")
        text += f"    {host}  - 值: {val}\n"

    return text

def send_wecom(token, content):
    url = WECHAT_URL_TEMPLATE.format(token=token)
    payload = {
        "msgtype": "markdown",
        "markdown": {"content": content}
    }
    try:
        r = requests.post(url, json=payload, timeout=5)
        resp = r.json()
        if resp.get("errcode", -1) != 0:
            print(f"[ERROR] Failed to send to {token}: {resp.get('errmsg')}")
            log("ERROR", f"Failed to send to {token}: {resp.get('errmsg')}")
    except Exception as e:
        print(f"[ERROR] Exception during sending to {token}: {e}")
        log("ERROR", f"Exception during sending to {token}: {e}")

def main():
    log("INFO", "########## Starting flush-notify-redis script ##########")
    r = redis.Redis(host=REDIS_HOST, port=6379, db=REDIS_DB, decode_responses=True)

    for redis_key, notify_type in REDIS_KEYS.items():
        log("INFO", f"开始处理队列: {redis_key} 类型: {notify_type}")
        alerts = fetch_alerts(r, redis_key)
        if not alerts:
            log("INFO", f"队列: {redis_key} 无告警, 跳过")
            continue

        # s1级别既打电话又发微信
        if notify_type == 'voice_wecom':
            handle_voice(alerts)
            log("INFO", f"{redis_key} {len(alerts)} 条告警已完成电话通知")
            grouped = group_by_token_rule_region_recover(alerts)
            for group_key, items in grouped.items():
                token, _, _, _ = group_key.split("::", 3)
                content = build_markdown(items)
                send_wecom(token, content)
                log("INFO", f"{redis_key} 已发送微信通知到token: {token}, 共{len(alerts)}条")
        elif notify_type == 'wecom':
            grouped = group_by_token_rule_region_recover(alerts)
            for group_key, items in grouped.items():
                token, _, _, _ = group_key.split("::", 3)
                content = build_markdown(items)
                send_wecom(token, content)
                log("INFO", f"{redis_key} 已发送微信通知到token: {token}, 共{len(alerts)}条")
    log("INFO", "Finished processing all alerts")
    log("INFO", "")

if __name__ == "__main__":
    while True:
        main()
        time.sleep(20)