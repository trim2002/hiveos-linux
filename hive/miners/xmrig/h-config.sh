#!/usr/bin/env bash


function miner_ver() {
	echo $MINER_LATEST_VER
}


function miner_config_echo() {
	local MINER_VER=`miner_ver`
	miner_echo_config_file "/hive/miners/$MINER_NAME/$MINER_VER/config.json"
}


function miner_config_gen() {
	local MINER_CONFIG="$MINER_DIR/$MINER_VER/config.json"
	mkfile_from_symlink $MINER_CONFIG

	conf=`cat $MINER_DIR/$MINER_VER/config_global.json | envsubst`
	userconf='{}'
	#merge user config options into main config
	if [[ ! -z $XMRIG_USER_CONFIG ]]; then
		while read -r line; do
			[[ -z $line ]] && continue
			conf=$(jq -s '.[0] * .[1]' <<< "$conf {$line}")
		done <<< "$XMRIG_USER_CONFIG"
	fi

	#merge pools into main config
	pools='[]'
	tls=$(jq -r .tls <<< "$conf")
	[[ -z $tls || $tls == "null" ]] && tls="false"
	tls_fp=$(jq -r '."tls-fingerprint"' <<< "$conf")
	[[ -z $tls_fp || $tls_fp == "null" ]] && tls_fp="null"
	variant=$(jq -r '."variant"' <<< "$conf")
	[[ -z $variant= || $variant= == "null" ]] && variant=-1
	rig_id=$(jq -r '."rig_id"' <<< "$conf")
	[[ -z $rig_id= || $rig_id= == "null" ]] && rig_id=""
	for url in $XMRIG_URL; do
		grep -q "nicehash.com" <<< $XMRIG_URL
		[[ $? -eq 0 ]] && nicehash="true" || nicehash="false"
		pool=$(cat <<EOF
					{"url": "$url", "user": "$XMRIG_TEMPLATE", "pass": "$XMRIG_PASS", "rig_id": "$rig_id", "use_nicehash": $nicehash, "tls": $tls, "tls-fingerprint": $tls_fp, "variant": $variant, "keepalive": true }
EOF
)
		pools=`jq --null-input --argjson pools "$pools" --argjson pool "$pool" '$pools + [$pool]'`
	done


	if [[ -z $pools || $pools == '[]' || $pools == 'null' ]]; then
		echo -e "${RED}No pools configured, using default${NOCOLOR}"
	else
		#pass can also contain %var%
		#Don't remove until Hive 1 is gone
#		[[ -z $EWAL && -z $ZWAL && -z $DWAL ]] && echo -e "${RED}No WAL address is set${NOCOLOR}"
		[[ ! -z $EWAL ]] && pools=$(sed "s/%EWAL%/$EWAL/g" <<< $pools) #|| echo "${RED}EWAL not set${NOCOLOR}"
		[[ ! -z $DWAL ]] && pools=$(sed "s/%DWAL%/$DWAL/g" <<< $pools) #|| echo "${RED}DWAL not set${NOCOLOR}"
		[[ ! -z $ZWAL ]] && pools=$(sed "s/%ZWAL%/$ZWAL/g" <<< $pools) #|| echo "${RED}ZWAL not set${NOCOLOR}"
		[[ ! -z $EMAIL ]] && pools=$(sed "s/%EMAIL%/$EMAIL/g" <<< $pools)
		[[ ! -z $WORKER_NAME ]] && pools=$(sed "s/%WORKER_NAME%/$WORKER_NAME/g" <<< $pools) #|| echo "${RED}WORKER_NAME not set${NOCOLOR}"

		pools=`jq --null-input --argjson pools "$pools" '{"pools": $pools}'`
		conf=$(jq -s '.[0] * .[1]' <<< "$conf $pools")
	fi


	echo "$conf" | jq . > $MINER_CONFIG
}