#!/bin/bash

text=''

while IFS= read -r line; do
  text+="$line"
done <"./informlog"

title="msg_from_cvwt"
token="$wxToken"

if [[ -z ${wxpushAPI} ]]; then
  echo "未配置微信推送API!!!"
else
  URL="$wxpushAPI"
  echo "URL:$URL"
  res=$(timeout 20s curl -s -X POST $URL \
  -d title=${title} --data-urlencode content="${text}" -d token="$token")

  if [ $? == 124 ]; then
    echo "发送消息超时"
    exit 1
  fi

 # 检查返回结果是否包含成功关键词
  if echo "$res" | grep -q -E "Successfully"; then
    echo "微信推送成功"
    echo "res:$res"
  else
    echo "微信推送失败, 返回结果: $res"
  fi

fi
