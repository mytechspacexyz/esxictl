# networks commands handlers functions

# networks manage command handler
cmd_networks_manage() {

	log_debug "${FUNCNAME[0]} is called"

	local ACTION
	ACTION=$(
		fzf --cycle \
			--border=rounded \
			--border-label=" ESXi host's '${ESXI_HOSTNAME}' networks actions " \
            --preview-window=right:50% \
            --preview "cmd_networks_action_help {}" \
            --preview-window=hidden --bind 'ctrl-h:toggle-preview' \
			--header "Choose please an action for network(s) | ctrl-h: help for an action" \
			--layout reverse \
			<<- ACTIONS
				list
			ACTIONS
	)

	[[ -z "${ACTION}" ]] && return

	case "${ACTION}" in
		list)		cmd_networks_list		;;
		*)			cmd_networks_unknown "${ACTION}" ;; 
	esac

}

# networks action help handler
cmd_networks_action_help() {

	log_debug "${FUNCNAME[0]} is called"

	local ACTION
	ACTION="$1"

	[[ -z "${ACTION}" ]] && return
	
	case "${ACTION}" in
		list)
			echo "Lists networks that the ESXI host has got available"
			;;
		*)
			echo "Unknown action. No help available."
			;;
	esac

}
export -f cmd_networks_action_help

# networks info command handler
cmd_networks_info() {

	log_debug "${FUNCNAME[0]} is called"

	local NETWORKID
	NETWORKID=$(echo "${1}" | cut -f1 | xargs)
	[[ -z "${NETWORKID}" ]] && return

	local NETNAME
	NETNAME=$(echo "${1}" | cut -f2 | xargs)

	log_debug "function: ${FUNCNAME[0]}, NETWORKID=${NETWORKID}"

	local GETCONFIGMGRXML
	GETCONFIGMGRXML=$(
		cat <<- XML
			<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
					<RetrievePropertiesEx xmlns="urn:vim25">
						<_this type="PropertyCollector">ha-property-collector</_this>
						<specSet>
							<propSet>
								<type>HostSystem</type>
								<pathSet>configManager.networkSystem</pathSet>
							</propSet>
							<objectSet>
								<obj type="HostSystem">ha-host</obj>
							</objectSet>
						</specSet>
						<options/>
					</RetrievePropertiesEx>
				</soapenv:Body>
			</soapenv:Envelope>
		XML
	)

	local RESPONSE
	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${GETCONFIGMGRXML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)
	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/ xsi:type="[^"]*"//g')

	local NETWORKSYSTEMMOREF
	NETWORKSYSTEMMOREF=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='configManager.networkSystem']/val)" - 2>/dev/null)
	[[ -z "${NETWORKSYSTEMMOREF}" ]] && {
		log_error "function: ${FUNCNAME[0]}, ✗ failed to get HostNetworkSystem MoRef"
		return 1
	}

	local GETNETINFOXML
	GETNETINFOXML=$(
		cat <<- XML
			<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
					<RetrievePropertiesEx xmlns="urn:vim25">
						<_this type="PropertyCollector">ha-property-collector</_this>
						<specSet>
							<propSet>
								<type>HostNetworkSystem</type>
								<pathSet>networkInfo</pathSet>
							</propSet>
							<objectSet>
								<obj type="HostNetworkSystem">${NETWORKSYSTEMMOREF}</obj>
							</objectSet>
						</specSet>
						<options/>
					</RetrievePropertiesEx>
				</soapenv:Body>
			</soapenv:Envelope>
		XML
	)

	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${GETNETINFOXML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)
	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/ xsi:type="[^"]*"//g')
	log_debug "function: ${FUNCNAME[0]}, networkInfo RESPONSE=${RESPONSE}"

	local k=1
	local PGVSWITCH PGVLANID PGVSWITCHKEY
	while true
	do
		local PGNAME
		PGNAME=$(echo "${RESPONSE}" | xmllint --xpath "string(//portgroup[${k}]/spec/name)" - 2>/dev/null)
		[[ -z "${PGNAME}" ]] && break
		if [[ "${PGNAME}" == "${NETNAME}" ]]; then
			PGVSWITCH=$(echo "${RESPONSE}"    | xmllint --xpath "string(//portgroup[${k}]/spec/vswitchName)" - 2>/dev/null)
			PGVLANID=$(echo "${RESPONSE}"     | xmllint --xpath "string(//portgroup[${k}]/spec/vlanId)" - 2>/dev/null)
			PGVSWITCHKEY=$(echo "${RESPONSE}" | xmllint --xpath "string(//portgroup[${k}]/vswitch)" - 2>/dev/null)
			break
		fi
		(( k++ ))
	done

	local i=1
	local VSNAME VSMTU VSNUMPORTS VSNUMPORTSAVAIL VSPNIC VSPOLICY VSBEACON
	while true; do
		local VSKEY
		VSKEY=$(echo "${RESPONSE}" | xmllint --xpath "string(//vswitch[${i}]/key)" - 2>/dev/null)
		[[ -z "${VSKEY}" ]] && break
		if [[ "${VSKEY}" == "${PGVSWITCHKEY}" ]]; then
			VSNAME=$(echo "${RESPONSE}"          | xmllint --xpath "string(//vswitch[${i}]/name)" - 2>/dev/null)
			VSMTU=$(echo "${RESPONSE}"           | xmllint --xpath "string(//vswitch[${i}]/mtu)" - 2>/dev/null)
			VSNUMPORTS=$(echo "${RESPONSE}"      | xmllint --xpath "string(//vswitch[${i}]/spec/numPorts)" - 2>/dev/null)
			VSNUMPORTSAVAIL=$(echo "${RESPONSE}" | xmllint --xpath "string(//vswitch[${i}]/numPortsAvailable)" - 2>/dev/null)
			VSPNIC=$(echo "${RESPONSE}"          | xmllint --xpath "string(//vswitch[${i}]/pnic)" - 2>/dev/null)
			VSPOLICY=$(echo "${RESPONSE}"        | xmllint --xpath "string(//vswitch[${i}]/spec/policy/nicTeaming/policy)" - 2>/dev/null)
			VSBEACON=$(echo "${RESPONSE}"        | xmllint --xpath "string(//vswitch[${i}]/spec/bridge/beacon/interval)" - 2>/dev/null)
			break
		fi
		(( i++ ))
	done

	local PNICDEVICE PNICMAC PNICDRIVER PNICSPEED PNICDUPLEX
	if [[ -n "${VSPNIC}" ]]; then
		local p=1
		while true; do
			local PNICKEY
			PNICKEY=$(echo "${RESPONSE}" | xmllint --xpath "string(//pnic[${p}]/key)" - 2>/dev/null)
			[[ -z "${PNICKEY}" ]] && break
			if [[ "${PNICKEY}" == "${VSPNIC}" ]]; then
				PNICDEVICE=$(echo "${RESPONSE}" | xmllint --xpath "string(//pnic[${p}]/device)" - 2>/dev/null)
				PNICMAC=$(echo "${RESPONSE}"    | xmllint --xpath "string(//pnic[${p}]/mac)" - 2>/dev/null)
				PNICDRIVER=$(echo "${RESPONSE}" | xmllint --xpath "string(//pnic[${p}]/driver)" - 2>/dev/null)
				PNICSPEED=$(echo "${RESPONSE}"  | xmllint --xpath "string(//pnic[${p}]/linkSpeed/speedMb)" - 2>/dev/null)
				PNICDUPLEX=$(echo "${RESPONSE}" | xmllint --xpath "string(//pnic[${p}]/linkSpeed/duplex)" - 2>/dev/null)
				break
			fi
			(( p++ ))
		done
	fi

	printf "\n"
	printf " %-24s %s\n" "Port Group:"       "${NETNAME}"
	printf " %-24s %s\n" "VLAN ID:"          "${PGVLANID}"
	printf "\n"
	printf " %-24s %s\n" "vSwitch:"          "${VSNAME}"
	printf " %-24s %s\n" "MTU:"              "${VSMTU}"
	printf " %-24s %s\n" "Total Ports:"      "${VSNUMPORTS}"
	printf " %-24s %s\n" "Available Ports:"  "${VSNUMPORTSAVAIL}"
	printf " %-24s %s\n" "NIC Teaming:"      "${VSPOLICY}"
	printf " %-24s %s\n" "Beacon Probing:"  "${VSBEACON}s"
	printf "\n"
	if [[ -n "${PNICDEVICE}" ]]; then
		printf " %-24s %s\n" "Physical NIC:"     "${PNICDEVICE}"
		printf " %-24s %s\n" "MAC:"              "${PNICMAC}"
		printf " %-24s %s\n" "Driver:"           "${PNICDRIVER}"
		printf " %-24s %s\n" "Link Speed:"       "${PNICSPEED} Mbps"
		printf " %-24s %s\n" "Duplex:"           "${PNICDUPLEX}"
	fi
	printf "\n"
}
export -f cmd_networks_info

# networks list command handler
cmd_networks_list() {

	log_debug "${FUNCNAME[0]} is called"

	local LISTNETWORKS_XML
	LISTNETWORKS_XML=$(
		cat <<- XML
			<soapenv:Envelope 
				xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" 
				xmlns:urn="urn:vim25" 
				xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
				<soapenv:Body>
					<RetrievePropertiesEx xmlns="urn:vim25">
						<_this type="PropertyCollector">ha-property-collector</_this>
						<specSet>
							<propSet>
								<type>Network</type>
								<pathSet>name</pathSet>
								<pathSet>summary.accessible</pathSet>
							</propSet>
							<objectSet>
								<obj type="Datacenter">ha-datacenter</obj>
								<selectSet xsi:type="TraversalSpec">
									<name>traverseDatacenter</name>
									<type>Datacenter</type>
									<path>networkFolder</path>
									<skip>false</skip>
									<selectSet xsi:type="TraversalSpec">
										<name>traverseFolders</name>
										<type>Folder</type>
										<path>childEntity</path>
										<skip>false</skip>
									</selectSet>
								</selectSet>
							</objectSet>
						</specSet>
						<options/>
					</RetrievePropertiesEx>
				</soapenv:Body>
			</soapenv:Envelope>
		XML
	)

	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LISTNETWORKS_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')

	log_debug "function: ${FUNCNAME[0]}, RESPONSE=${RESPONSE}"

	local NETWORKFORVM
	NETWORKFORVM=$(
		{
			echo -e "NETWORKID\tNAME\tACCESSIBLE"
			echo "${RESPONSE}" | xmllint --xpath "//objects" - 2>/dev/null | sed 's/<\/objects>/<\/objects>\n/g' | \
			while read -r net_block
			do
				[[ -z "${net_block}" ]] && continue
				local NETID=$(echo "${net_block}" | xmllint --xpath "string(//obj)" - 2>/dev/null)
				local NETNAME=$(echo "${net_block}" | xmllint --xpath "string(//propSet[name='name']/val)" - 2>/dev/null)
				local NETACCESSIBLE=$(echo "${net_block}" | xmllint --xpath "string(//propSet[name='summary.accessible']/val)" - 2>/dev/null)
				echo -e "${NETID}\t${NETNAME}\t${NETACCESSIBLE}"
			done
		} | column -t -s $'\t' -o $'\t'| \
		fzf --cycle \
			--border=rounded \
			--border-label=" ESXi host's '${ESXI_HOSTNAME}' networks " \
			--preview-window=right:50% \
			--preview "cmd_networks_info {} ${ESXI_HOSTNAME}" \
			--preview-window=hidden --bind 'ctrl-p:toggle-preview' \
			--bind 'ctrl-b:become(exit 2)' \
			--header-lines=1 \
			--header "Simple list of all the networks | ctrl-p: (un)toggle network's info view" \
			--layout reverse
	)

}

# networks unknown command handler
cmd_networks_unknown() {

	log_debug "${FUNCNAME[0]} is called"

	local ACTION="$1"

	log_error "function: ${FUNCNAME[0]}, unknown command '${ACTION}' for networks action."

	echo "Unknown networks command: ${ACTION}"
	echo "Use '${BASHAPP_NAME}' help or/and documentation for the correct usage information"

	# delay to show results
	sleep 2

}
