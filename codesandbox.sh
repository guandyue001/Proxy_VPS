#!/bin/bash
export UUID=${UUID:-'fc44fe6a-f083-4591-9c03-f8d61dc3907f'}
export ARGO_DOMAIN=${ARGO_DOMAIN:-'codesandbox.201361.xyz'}          # 固定隧道域名，留空即启用临时隧道
export ARGO_AUTH=${ARGO_AUTH:-'eyJhIjoiODVhOGVmOTM0NjY5NDAyYjgwYzljNDk0NTA5Mjg4YWUiLCJ0IjoiYzQwNDY1ZDctZmVmZS00M2Y4LTg1MTYtZDUzZjczYTU1OWI2IiwicyI6Ik1XWmhZalU1TVRNdE9UbGxNUzAwWW1WakxXRTFORGN0WVRBMVptWTNOR1V5TWpNeiJ9'}             # 固定隧道json或token，留空即启用临时隧道
export CFIP=${CFIP:-'www.epicgames.com'}         # 优选域名或优选ip
export CFPORT=${CFPORT:-'443'}               # 优选域名或优选ip对应端口
export NAME=${NAME:-'Vls'}                 # 节点名称
export FILE_PATH=${FILE_PATH:-'./world'}        # 节点存放文件夹
export ARGO_PORT=${ARGO_PORT:-'8001'}          # Argo端口,使用固定隧道token需在cf后台设置的端口和这里一致

[ ! -d "${FILE_PATH}" ] && mkdir ${FILE_PATH}

rm -rf ${FILE_PATH}/boot.log ${FILE_PATH}/sub.txt ${FILE_PATH}/config.json ${FILE_PATH}/tunnel.json ${FILE_PATH}/tunnel.yml >/dev/null 2>&1

argo_configure() {
  if [[ -z $ARGO_AUTH || -z $ARGO_DOMAIN ]]; then
    echo -e "\e[1;32mARGO_DOMAIN or ARGO_AUTH variable is empty, use quick tunnels\e[0m"
    return
  fi

  if [[ $ARGO_AUTH =~ TunnelSecret ]]; then
    echo $ARGO_AUTH > ${FILE_PATH}/tunnel.json
    cat > ${FILE_PATH}/tunnel.yml << EOF
tunnel: $(cut -d\" -f12 <<< "$ARGO_AUTH")
credentials-file: ${FILE_PATH}/tunnel.json
protocol: http2

ingress:
  - hostname: $ARGO_DOMAIN
    service: http://localhost:$ARGO_PORT
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF
  else
    echo -e "\e[1;32mARGO_AUTH mismatch TunnelSecret,use token connect to tunnel\e[0m"
  fi
}
argo_configure
wait

generate_config() {
  cat > ${FILE_PATH}/config.json << EOF
{
  "log": { "access": "/dev/null", "error": "/dev/null", "loglevel": "none" },
  "inbounds": [
    {
      "port": $ARGO_PORT,
      "protocol": "vless",
      "settings": {
        "clients": [{ "id": "${UUID}", "flow": "xtls-rprx-vision" }],
        "decryption": "none",
        "fallbacks": [
          { "dest": 15841 }, { "path": "/vless-argo", "dest": 15842 },
          { "path": "/vmess-argo", "dest": 15843 }, { "path": "/trojan-argo", "dest": 15844 }
        ]
      },
      "streamSettings": { "network": "tcp" }
    },
    {
      "port": 15841, "listen": "127.0.0.1", "protocol": "vless",
      "settings": { "clients": [{ "id": "${UUID}" }], "decryption": "none" },
      "streamSettings": { "network": "ws", "security": "none" }
    },
    {
      "port": 15842, "listen": "127.0.0.1", "protocol": "vless",
      "settings": { "clients": [{ "id": "${UUID}", "level": 0 }], "decryption": "none" },
      "streamSettings": { "network": "ws", "security": "none", "wsSettings": { "path": "/vless-argo" } },
      "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"], "metadataOnly": false }
    },
    {
      "port": 15843, "listen": "127.0.0.1", "protocol": "vmess",
      "settings": { "clients": [{ "id": "${UUID}", "alterId": 0 }] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess-argo" } },
      "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"], "metadataOnly": false }
    }
  ],
  "dns": { "servers": ["https+local://8.8.8.8/dns-query"] },
  "outbounds": [ {"protocol": "freedom", "tag": "direct" },{"protocol": "blackhole","tag": "block" } ]
}
EOF
}
generate_config
wait

ARCH=$(uname -m) && DOWNLOAD_DIR="${FILE_PATH}" && mkdir -p "$DOWNLOAD_DIR" && FILE_INFO=()
if [ "$ARCH" == "arm" ] || [ "$ARCH" == "arm64" ] || [ "$ARCH" == "aarch64" ]; then
    FILE_INFO=("https://github.com/eooce/test/releases/download/arm64/bot13 bot" "https://github.com/eooce/test/releases/download/ARM/web web")
elif [ "$ARCH" == "amd64" ] || [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "x86" ]; then
    FILE_INFO=("https://github.com/eooce/test/releases/download/amd64/bot bot" "https://github.com/eooce/test/releases/download/123/web web")
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi
for entry in "${FILE_INFO[@]}"; do
    URL=$(echo "$entry" | cut -d ' ' -f 1)
    NEW_FILENAME=$(echo "$entry" | cut -d ' ' -f 2)
    FILENAME="$DOWNLOAD_DIR/$NEW_FILENAME"
    if [ -e "$FILENAME" ]; then
        echo -e "\e[1;32m$FILENAME already exists,Skipping download\e[0m"
    else
        curl -L -sS -o "$FILENAME" "$URL"
        echo -e "\e[1;32mDownloading $FILENAME\e[0m"
    fi
done
wait

run() {
  if [ -e "${FILE_PATH}/web" ]; then
    chmod 777 "${FILE_PATH}/web"
    nohup ${FILE_PATH}/web -c ${FILE_PATH}/config.json >/dev/null 2>&1 &
	  sleep 2
    pgrep -x "web" > /dev/null && echo -e "\e[1;32mweb is running\e[0m" || { echo -e "\e[1;35mweb is not running, restarting...\e[0m"; pkill -x "web" && nohup "${FILE_PATH}/web" -c ${FILE_PATH}/config.json >/dev/null 2>&1 & sleep 2; echo -e "\e[1;32mweb restarted\e[0m"; }
  fi

  if [ -e "${FILE_PATH}/bot" ]; then
    chmod 777 "${FILE_PATH}/bot"
    if [[ $ARGO_AUTH =~ ^[A-Z0-9a-z=]{120,250}$ ]]; then
      args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 run --token ${ARGO_AUTH}"
    elif [[ $ARGO_AUTH =~ TunnelSecret ]]; then
      args="tunnel --edge-ip-version auto --config ${FILE_PATH}/tunnel.yml run"
    else
      args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 --logfile ${FILE_PATH}/boot.log --loglevel info --url http://localhost:$ARGO_PORT"
    fi
    nohup ${FILE_PATH}/bot $args >/dev/null 2>&1 &
    sleep 2
    pgrep -x "bot" > /dev/null && echo -e "\e[1;32mbot is running\e[0m" || { echo -e "\e[1;35mbot is not running, restarting...\e[0m"; pkill -x "bot" && nohup "${FILE_PATH}/bot" $args >/dev/null 2>&1 & sleep 2; echo -e "\e[1;32mbot restarted\e[0m"; }
  fi
} 
run
sleep 2

get_argodomain() {
  if [[ -n $ARGO_AUTH ]]; then
    echo "$ARGO_DOMAIN"
  else
    local retry=0
    local max_retries=6
    local argodomain=""
    while [[ $retry -lt $max_retries ]]; do
      ((retry++))
      argodomain=$(sed -n 's|.*https://\([^/]*trycloudflare\.com\).*|\1|p' "${FILE_PATH}/boot.log") 
      if [[ -n $argodomain ]]; then
        break
      fi
      sleep 1
    done
    echo "$argodomain"
  fi
}

generate_links() {
  argodomain=$(get_argodomain)
  echo -e "\e[1;32mArgoDomain:\e[1;35m${argodomain}\e[0m"
  sleep 2

  isp=$(curl -s https://speed.cloudflare.com/meta | awk -F\" '{print $26"-"$18}' | sed -e 's/ /_/g')
  sleep 2

  VMESS="{ \"v\": \"2\", \"ps\": \"${NAME}-${isp}\", \"add\": \"${CFIP}\", \"port\": \"${CFPORT}\", \"id\": \"${UUID}\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"${argodomain}\", \"path\": \"/vmess-argo?ed=2048\", \"tls\": \"tls\", \"sni\": \"${argodomain}\", \"alpn\": \"\" }"

  cat > ${FILE_PATH}/list.txt <<EOF
vless://${UUID}@${CFIP}:${CFPORT}?encryption=none&security=tls&sni=${argodomain}&type=ws&host=${argodomain}&path=%2Fvless-argo%3Fed%3D2048#${NAME}-${isp}

vmess://$(echo "$VMESS" | base64 -w0)

EOF

  base64 -w0 ${FILE_PATH}/list.txt > ${FILE_PATH}/sub.txt
  cat ${FILE_PATH}/sub.txt
  echo -e "\n\e[1;32m${FILE_PATH}/sub.txt saved successfully\e[0m"
  sleep 5  
#  rm -rf ${FILE_PATH}/list.txt ${FILE_PATH}/boot.log ${FILE_PATH}/config.json ${FILE_PATH}/tunnel.json ${FILE_PATH}/tunnel.yml ${FILE_PATH}/web ${FILE_PATH}/bot
}
generate_links
echo -e "\e[1;96mRunning done!\e[0m"
echo -e "\e[1;96mThank you for using this script,enjoy!\e[0m"
sleep 60
clear