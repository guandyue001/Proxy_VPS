#!/bin/bash

# ✅ 获取 hyp 变量：从环境变量 HYP 或第一个参数 $1 中取
hyp="${HYP:-$1}"

# 检查是否设置了 hyp
if [ -z "$hyp" ]; then
  echo "错误：未提供 hyp 端口号，请通过 HYP 环境变量或脚本参数传入"
  exit 1
fi

# ✅ 创建 .mpm 文件夹（如果不存在）
mkdir -p .npm
cd .npm || exit 1

# ✅ 下载 hy 最新版本，并命名为 hy
curl -L -o npm https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64

# ✅ 授予执行权限
chmod +x npm

# ✅ 写入 config.yaml 文件
cat > config.yaml <<EOF
listen: :$hyp

tls:
  cert: cert.pem
  key: private.key
  alpn:
    - h3

auth:
  type: password
  password: 0ff0350e-c001-495b-a6a1-13b962590375

masquerade:
  type: proxy
  proxy:
    url: https://bing.com
    rewriteHost: true
EOF


# ✅ 写入 cert.pem 文件
cat > cert.pem <<EOF
-----BEGIN CERTIFICATE-----
MIIBezCCASGgAwIBAgIUC3S5wh4fbyM2ma1AR9U440une14wCgYIKoZIzj0EAwIw
EzERMA8GA1UEAwwIYmluZy5jb20wHhcNMjUwNDIxMDUyMDIxWhcNMzUwNDE5MDUy
MDIxWjATMREwDwYDVQQDDAhiaW5nLmNvbTBZMBMGByqGSM49AgEGCCqGSM49AwEH
A0IABDvAkACytTncW6NLzo9tj6UWbzNYjZM8IM4//dp/qgMGw7T6AWP2Nr9bisNL
/82v0GcqpFTINvYvvyu5doSTQdCjUzBRMB0GA1UdDgQWBBRe98JAp2m/z7u5fCPc
wBSLkTfQuzAfBgNVHSMEGDAWgBRe98JAp2m/z7u5fCPcwBSLkTfQuzAPBgNVHRMB
Af8EBTADAQH/MAoGCCqGSM49BAMCA0gAMEUCIEaMrLQARBhmwz7wJH284Jjo0ZEG
iF+K6vzB+XdVs/CgAiEArZFTAE/HhV60b1TEacNAsr2s6tKa9G0DHk0iMFZJyc0=
-----END CERTIFICATE-----
EOF


# ✅ 写入 private.key 文件
cat > private.key <<EOF
-----BEGIN EC PARAMETERS-----
BggqhkjOPQMBBw==
-----END EC PARAMETERS-----
-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIHpptrtUUKlmyc/l0PdqRTjrTwUiyoihmcgR0o1vya94oAoGCCqGSM49
AwEHoUQDQgAEO8CQALK1Odxbo0vOj22PpRZvM1iNkzwgzj/92n+qAwbDtPoBY/Y2
v1uKw0v/za/QZyqkVMg29i+/K7l2hJNB0A==
-----END EC PRIVATE KEY-----
EOF


nohup ./npm server >/dev/null 2>&1 &

sleep 1
clear

# 删除文件
rm npm
rm config.yaml
rm cert.pem
rm private.key

# 删除自身
rm -- "$0"

