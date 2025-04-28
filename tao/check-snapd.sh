#!/bin/bash

# 检查是否具有 root 权限
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

# 如果snapd服务不正常、可以尝试snap install hello-world

# 检查 snapd 是否已安装
if dpkg -l | grep -q snapd; then
    echo "snapd is already installed."
    status=$(systemctl is-active snapd)
    if [[ $status == "active" ]]; then
        echo "snapd service is running."
    else
        echo "snapd service is not running. Starting it now..."
        systemctl unmask snapd
        systemctl enable snapd
        systemctl start snapd
        if [[ $? -eq 0 ]]; then
            echo "snapd service started successfully."
        else
            echo "Failed to start snapd service."
            exit 1
        fi
    fi
else
    echo "snapd is not installed. Installing snapd..."
    if ! apt update -y >/dev/null 2>&1; then
        echo "Failed to update package index."
        exit 1
    fi
    if ! apt install -y snapd >/dev/null 2>&1; then
        echo "Failed to install snapd."
        exit 1
    fi
    echo "snapd installed successfully."
fi

# 配置并启动 snapd 服务
echo "Configuring snapd service..."
if systemctl is-enabled --quiet snapd; then
    echo "snapd service is already enabled."
else
    systemctl unmask snapd
    systemctl enable snapd
    systemctl start snapd
    echo "snapd service enabled."
fi

if systemctl is-active --quiet snapd; then
    echo "snapd service is already running."
else
    systemctl start snapd
    echo "snapd service started."
fi

# 检查 snapd 服务状态
echo "Checking snapd service status..."
if systemctl status snapd >/dev/null 2>&1; then
    echo "snapd service is running properly."
else
    echo "snapd service is not running properly. Check the logs for details."
    exit 1
fi