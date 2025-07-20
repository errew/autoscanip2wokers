#!/bin/bash

if [ $# -lt 1 ]; then
  echo "start.sh config_file_path [ipfile]"
  exit 0
fi

configfile=$1
ipfile=$2

echo "configfile:$configfile, ipfile:$ipfile"

ipzipfile="ip.zip"

#or test
rm -rf *.csv
if [[ -e $ipzipfile ]]; then
  rm -rf $ipzipfile
fi

if [[ -e informlog ]]; then
  rm -rf informlog
fi


echo "0.读取配置文件"
if [[ ! -e $configfile ]]; then
  echo "找不到$configfile配置文件!"
  exit 1
fi

pause=$(yq eval ".pause" $configfile)
clien=$(yq eval ".clien" $configfile)
multip=$(yq eval ".multip" $configfile)
CFST_URL=$(yq eval ".CFST_URL" $configfile)
CFST_N=$(yq eval ".CFST_N" $configfile)
CFST_T=$(yq eval ".CFST_T" $configfile)
CFST_DN=$(yq eval ".CFST_DN" $configfile)
CFST_TL=$(yq eval ".CFST_TL" $configfile)
CFST_TLL=$(yq eval ".CFST_TLL" $configfile)
CFST_SL=$(yq eval ".CFST_SL" $configfile)
CCFLAG=$(yq eval ".CCFLAG" $configfile)
CCODE=$(yq eval ".CCODE" $configfile)
CF_ADDR=$(yq eval ".CF_ADDR" $configfile)
telegramBotToken=$(yq eval ".telegramBotToken" $configfile)
telegramBotUserId=$(yq eval ".telegramBotUserId" $configfile)
sendType=$(yq eval ".sendType" $configfile)
sendKey=$(yq eval ".sendKey" $configfile)

ChkHostnameAndCoutryCode() {
  IFS=, read -r -a domains <<<"$hostname"
  IFS=, read -r -a countryCodes <<<"$CCODE"

  domain_num=${#domains[@]}
  countryCode_num=${#countryCodes[@]}

  if [ ${#domains[@]} -eq 0 ]; then
    echo "hostname must be set in config file!"
    return 1
  fi

  #检查域名和国家代码是否一一对应
  if [ "$CCFLAG" = "true" ]; then
    echo "domain_num:$domain_num, countryCode_num:$countryCode_num"
    if [ $domain_num -ne $countryCode_num ]; then
      echo "The name and country code must correspond one to one!"
      return 1
    fi
  fi
  return 0
}

GetProxName() {
  c=$1
  if [ "$c" = "6" ]; then
    CLIEN=bypass
  elif [ "$c" = "5" ]; then
    CLIEN=openclash
  elif [ "$c" = "4" ]; then
    CLIEN=clash
  elif [ "$c" = "3" ]; then
    CLIEN=shadowsocksr
  elif [ "$c" = "2" ]; then
    CLIEN=passwall2
  else
    CLIEN=passwall
  fi
  echo $CLIEN
}

handle_err() {
  if [ "$pause" = "true" ] ; then
    echo "Restore background process."
    proxy=$(GetProxName $clien)
    /etc/init.d/$proxy start
  fi
}

#trap handle_err EXIT
trap handle_err HUP INT TERM EXIT
CLIEN=$(GetProxName $clien)
ps -ef | grep $CLIEN | grep -v "grep" >/dev/null

if [ $? = 1 ]; then
  /etc/init.d/$CLIEN start
fi

if [ -z $ipfile ]; then
  echo "1.Download ip file."
  for i in {1..3}; do
    wget -O $ipzipfile https://zip.cm.edu.kg

    if [ $? != 0 ]; then
      echo "get ip file failed, try again"
      sleep 1
      continue
    else
      echo "downloaded."
      break
    fi
  done

  if [ -e $ipzipfile ]; then
    unzip -o $ipzipfile
  else
    echo "Can't download the ip zip file, Check whether the agent software is disabled."
  fi

  # echo "2.Select the ip address of the desired port."
#   port=$(yq eval ".CF_ADDR" $configfile)
#   if [ -z $port ]; then
#     port=443
#   fi

#   ip_file="./$port/ALL.txt"
#   # for file in $(find . -type f -name "*-[0-1]-$port.txt"); do
#   #   echo "handling: $file"
#   #   cat "$file" >>tmp.txt
#   # done

#   if [ -e "$ip_file" ]; then
#     cat "$ip_file" | sort -u >ip.txt
#   fi
fi

echo "Run scripts to test speed and update dns records."
CFST_P=$CFST_DN
#判断工作模式
if [ "$IP_ADDR" = "ipv6" ]; then
  if [ ! -f "ipv6.txt" ]; then
    echo "当前工作模式为ipv6，但该目录下没有【ipv6.txt】，请配置【ipv6.txt】。下载地址：https://github.com/XIU2/CloudflareSpeedTest/releases"
    exit 2
  else
    echo "当前工作模式为ipv6"
  fi
else
  echo "当前工作模式为ipv4"
fi

#读取配置文件中的客户端
CLIEN=$(GetProxName $clien)

#判断是否停止科学上网服务
if [ "$pause" = "false" ]; then
  echo "按要求未停止科学上网服务"
else
  /etc/init.d/$CLIEN stop
  echo "已停止$CLIEN"
fi

#判断是否配置测速地址
if [[ "$CFST_URL" == http* ]]; then
  CFST_URL_R="-url $CFST_URL"
else
  CFST_URL_R=""
fi

#判断是否使用国家代码来筛选
if [[ "$CCFLAG" == "true" ]]; then
  USECC="-c "
else
  USECC=""
fi

if [ ! -z "$CCODE" ]; then
  CCODE_IS="-cc $CCODE "
else
  CCODE_IS=""
fi

if [ ! -z "$CF_ADDR" ]; then
  CF_ADDR=" -tp $CF_ADDR"
else
  CF_ADDR=" -tp 443"
fi

# 定义测速函数
run_speedtest() {
  local ip_file=$1
  local output=$2
  local cmd_args="$CFST_URL_R -t $CFST_T -n $CFST_N -dn $CFST_DN -tl $CFST_TL -tll $CFST_TLL -sl $CFST_SL -p $CFST_P"
  
  if [ ! -z "$ip_file" ]; then
    cmd_args="$cmd_args -f $ip_file"
  fi
  
  if [ ! -z "$output" ]; then
    cmd_args="$cmd_args -o $output"
  fi
  
  if [ "$IP_ADDR" != "ipv6" ] && [ ! -z "$CF_ADDR" ]; then
    cmd_args="$cmd_args $CF_ADDR"
  fi
  
  if [ ! -z "$USECC" ] && [ ! -z "$CCODE_IS" ]; then
    cmd_args="$cmd_args $USECC $CCODE_IS"
  fi
  
  echo "./CloudflareST $cmd_args"
  ./CloudflareST $cmd_args
}

if [ -z "$ipfile" ]; then
  ipflag=""
  port=$(yq eval ".CF_ADDR" $configfile)
  if [ -z $port ]; then
    port=443
  fi
  
  if [ ! -z "$CCODE" ]; then
    # 如果配置了CCODE，按逗号分割为数组，循环每个国家代码进行测速
    IFS=',' read -ra cc_arr <<< "$CCODE"
    echo "国家代码列表: ${cc_arr[*]}"
    CCODE_IS=""
    USECC=""
    for cc in "${cc_arr[@]}"; do
      cc=$(echo $cc | xargs)  # 去除可能的空格
      echo "处理国家代码: $cc"
      ipfile_path="./$port/${cc}.txt"
      output_file="${cc}.csv"
      
      if [ -f "$ipfile_path" ]; then
        echo "找到IP文件: $ipfile_path"
        run_speedtest "$ipfile_path" "$output_file"
      else
        echo "警告: IP文件 $ipfile_path 不存在，跳过此国家代码"
      fi
    done
  else
    run_speedtest "$ipfile" "result.csv"
  fi
else
  # 使用用户指定的IP文件进行测速
  run_speedtest "$ipfile" "result.csv"
fi



echo "测速完毕"
if [ "$pause" = "false" ]; then
  echo "按要求未重启科学上网服务"
  sleep 3s
else
  /etc/init.d/$CLIEN restart
  echo "已重启$CLIEN"
  echo "为保证cloudflareAPI连接正常 将在3秒后开始更新域名解析"
  sleep 3s
fi

if yq eval 'has("cloudflare")' $configfile; then

  length=$(yq eval '.cloudflare | length' $configfile)

  echo "length:$length"
  for ((li = 0; li < $length; li++)); 
  do
    echo "Configuration Group $((li + 1)):"
    x_email=$(yq eval ".cloudflare[$li].x_email" $configfile)
    echo "x_email: $x_email"
    hostname=$(yq eval ".cloudflare[$li].hostname" $configfile)
    echo "hostname: $hostname"
    zone_id=$(yq eval ".cloudflare[$li].zone_id" $configfile)
    #echo "zone_id:$zone_id"
    api_key=$(yq eval ".cloudflare[$li].api_key" $configfile)
    #echo "api_key:$api_key"
    ChkHostnameAndCoutryCode
    if [ $? -eq 1 ]; then
      echo "ChkHostnameAndCoutryCode() error!"
      exit 1
    fi

    source ./ddns/cf_ddns
  done

fi

#会生成一个名为informlog的临时文件作为推送的内容。
pushmessage=$(cat informlog)
echo $pushmessage

if [ ! -z "$sendType" ]; then
  if [[ $sendType -eq 1 ]]; then
    source ./msg/cf_push
  elif [[ $sendType -eq 2 ]]; then
    source ./msg/wxsend_jiang.sh
  elif [[ $sendType -eq 3 ]]; then
    source ./msg/cf_push
    source ./msg/wxsend_jiang.sh
  else
    echo "$sendType is invalid type!"
  fi
fi
