#!/usr/bin/env python3

import redis, json, time, requests
from datetime import datetime

# === 配置 ===
REDIS_KEY = "alerts:pending"
REDIS_HOST = "127.0.0.1"
WEBHOOK_URL = "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=your-key"

def unix_to_str(ts):
    try:
        return datetime.fromtimestamp(int(ts)).strftime('%Y-%m-%d %H:%M:%S')
    except:
        return "-"

def fetch_all(r):
    alerts = []
    while True:
        item = r.lpop(REDIS_KEY)
        if not item:
            break
        try:
            alerts.append(json.loads(item))
        except:
            continue
    return alerts

def build_msg(alerts):
    if not alerts:
        return None

    lines = [f"### 🚨 聚合告警通知，共 {len(alerts)} 条\n"]
    for a in alerts:
        e = a.get("event", {})
        rule = e.get("rule_name", "-")
        host = e.get("target_ident", "-")
        val  = e.get("trigger_value", "-")
        t    = unix_to_str(e.get("last_eval_time", time.time()))
        region = e.get("tags_map", {}).get("region", "-")
        path   = e.get("tags_map", {}).get("path", "-")
        device = e.get("tags_map", {}).get("device", "-")

        lines.append(f"- **{rule}**\n  - 主机: `{host}`  \n  - 值: `{val}`  \n  - 时间: {t}  \n  - 区域: {region}  \n  - 设备: {device}  \n  - 路径: {path}\n")
    return "\n".join(lines)

def send_wechat(msg):
    payload = {
        "msgtype": "markdown",
        "markdown": {"content": msg}
    }
    requests.post(WEBHOOK_URL, json=payload, timeout=5)

def main():
    r = redis.Redis(host=REDIS_HOST, port=6379, db=0, decode_responses=True)
    alerts = fetch_all(r)
    if not alerts:
        return
    msg = build_msg(alerts)
    if msg:
        send_wechat(msg)

if __name__ == "__main__":
    main()