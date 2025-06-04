#!/usr/bin/env python3

import redis
import json
import requests
import subprocess
from collections import defaultdict
from datetime import datetime

REDIS_HOST = '127.0.0.1'
REDIS_DB = 0
VOICE_SCRIPT = "/data/n9e/etc/script/send-tx-voice.sh"
REDIS_KEYS = {
    'alerts:pending:s1': 'voice',
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
        return datetime.fromtimestamp(int(ts)).strftime('%Y-%m-%d %H:%M:%S')
    except:
        return "-"

def handle_voice(alerts):
    for alert in alerts:
        e = alert.get("event", {})
        host = e.get("target_ident", "")
        rule = e.get("rule_name", "")
        for u in e.get("notify_users_obj", []):
            phone = u.get("phone", "")
            if phone:
                subprocess.call([VOICE_SCRIPT, phone, host, rule])

def group_by_token_and_rule(alerts):
    grouped = defaultdict(list)
    for alert in alerts:
        e = alert.get("event", {})
        rule = e.get("rule_name", "")
        users = e.get("notify_users_obj", [])
        tokens = set(u.get("contacts", {}).get("wecom_robot_token") for u in users if u.get("contacts", {}).get("wecom_robot_token"))
        for token in tokens:
            key = f"{token}::{rule}"
            grouped[key].append(alert)
    return grouped

def build_markdown(alerts):
    text = f"### 🚨 告警通知（共 {len(alerts)} 条）\n\n"
    for a in alerts:
        e = a.get("event", {})
        rule = e.get("rule_name", "-")
        host = e.get("target_ident", "-")
        val  = e.get("trigger_value", "-")
        t    = unix_to_str(e.get("last_eval_time", 0))
        region = e.get("tags_map", {}).get("region", "-")
        path   = e.get("tags_map", {}).get("path", "-")
        device = e.get("tags_map", {}).get("device", "-")

        text += f"- **{rule}**\n  - 主机: `{host}`  \n  - 值: `{val}`  \n  - 时间: {t}  \n  - 区域: {region}  \n  - 设备: {device}  \n  - 路径: {path}\n\n"
    return text

def send_wecom(token, content):
    url = WECHAT_URL_TEMPLATE.format(token=token)
    payload = {
        "msgtype": "markdown",
        "markdown": {"content": content}
    }
    try:
        r = requests.post(url, json=payload, timeout=5)
        if r.status_code != 200:
            print(f"[ERROR] Failed to send to {token}: {r.text}")
    except Exception as e:
        print(f"[ERROR] Exception during sending to {token}: {e}")

def main():
    r = redis.Redis(host=REDIS_HOST, port=6379, db=REDIS_DB, decode_responses=True)

    for redis_key, notify_type in REDIS_KEYS.items():
        alerts = fetch_alerts(r, redis_key)
        if not alerts:
            continue

        if notify_type == 'voice':
            handle_voice(alerts)
        elif notify_type == 'wecom':
            grouped = group_by_token_and_rule(alerts)
            for group_key, items in grouped.items():
                token, _ = group_key.split("::", 1)
                content = build_markdown(items)
                send_wecom(token, content)

if __name__ == "__main__":
    main()