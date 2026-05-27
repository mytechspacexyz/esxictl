# vms commands handlers functions

# vms manage command handler
cmd_vms_manage() {

	log_debug "${FUNCNAME[0]} is called"

	local ACTION
	ACTION=$(
		fzf --cycle \
			--border=rounded \
			--border-label=" ESXi host's '${ESXI_HOSTNAME}' vms actions " \
            --preview-window=right:50% \
            --preview "cmd_vms_action_help {}" \
            --preview-window=hidden --bind 'ctrl-h:toggle-preview' \
			--header "Choose please an action for vm(s) | ctrl-h: help for an action" \
			--layout reverse \
			<<- ACTIONS
				list
				poweron
				poweroff
				suspend
				resume
				reset
				shutdown
				restart
				snapshot
				delete
				register
				unregister
				rename
				defragment
			ACTIONS
	)

	[[ -z "${ACTION}" ]] && return

	case "${ACTION}" in
		list)		cmd_vms_list		;;
		poweron)	cmd_vms_poweron		;;
		poweroff)	cmd_vms_poweroff	;;
		suspend)	cmd_vms_suspend		;;
		resume)		cmd_vms_poweron		;;
		reset)		cmd_vms_reset		;;
		shutdown)	cmd_vms_shutdown	;;
		restart)	cmd_vms_restart		;;
		snapshot)	cmd_vms_snapshot	;;
		delete)		cmd_vms_delete		;;
		register)	cmd_vms_register	;;
		unregister)	cmd_vms_unregister	;;
		rename)		cmd_vms_rename		;;
		defragment) cmd_vms_defragment	;;
		*)			cmd_vms_unknown "${ACTION}" ;; 
	esac

}

# vms action help handler
cmd_vms_action_help() {

	log_debug "${FUNCNAME[0]} is called"

	local ACTION
	ACTION="$1"

	[[ -z "${ACTION}" ]] && return
	
	case "${ACTION}" in
		list)
			echo "Lists vms that reside on the ESXI host"
			;;
		poweron)
			echo "Powers on vms"
			echo "Vms should be in powered off or suspended state"		
			;;
		poweroff)
			echo "Powers off vms without clean shutdown"
			;;
		suspend)
			echo "Suspends vms"
			echo "Vms should be in poweredon state"
			;;
		resume)
			echo "Resumes vms from suspended state"
			;;
		reset)
			echo "Resets vms without proper reboot/shutdown"
			;;
		shutdown)
			echo "Cleanly shuts down vms"
			echo "Vms should be in poweredon state"
			;;
		restart)
			echo "Cleanly shuts down vms then starts them"
			;;
		snapshot)
			echo "Vms' snapshots management: create, list, rename, delete, revert"
			;;
		delete)
			echo "Deletes vms completely with their configurations and disks"
			;;
		register)
			echo "Registers vms in the ESXI host vms inventory"
			;;
		unregister)
			echo "Unregisters vms in the ESXI host vms inventory"
			;;
		rename)
			echo "Renames vms in the ESXI host vms inventory"
			echo "Only vms' display names are changed"
			echo "No VMDKs disks files renaming occurs"
			;;
		defragment)
			echo "Defragments vms' disks"
			;;
		*)
			echo "Unknown action. No help available."
			;;
	esac

}
export -f cmd_vms_action_help

# vms fzf preview handler
cmd_vms_info() {

	log_debug "${FUNCNAME[0]} is called"

	VIEWED_VM="$1"
	ESXI_HOST="$2"

	[[ -z "${VIEWED_VM}" || -z "${ESXI_HOST}" ]] && return
	
	log_debug "function: ${FUNCNAME[0]}, VIEWED_VM=${VIEWED_VM}"
	log_debug "function: ${FUNCNAME[0]}, ESXI_HOST=${ESXI_HOST}"

	VIEWED_VMID=$(echo ${VIEWED_VM} | awk '{print $1}')

	local VMPROPERTIES_XML
	VMPROPERTIES_XML=$(
		cat <<- XML
			<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
					<RetrievePropertiesEx xmlns="urn:vim25">
						<_this type="PropertyCollector">ha-property-collector</_this>
						<specSet>
							<propSet>
								<type>VirtualMachine</type>
								<pathSet>name</pathSet>
								<pathSet>runtime.powerState</pathSet>
								<pathSet>config.hardware.numCPU</pathSet>
								<pathSet>config.hardware.numCoresPerSocket</pathSet>
								<pathSet>config.hardware.memoryMB</pathSet>
								<pathSet>guest.ipAddress</pathSet>
								<pathSet>guest.net</pathSet>
								<pathSet>summary.storage.committed</pathSet>
								<pathSet>summary.storage.uncommitted</pathSet>
								<pathSet>guest.guestState</pathSet>
								<pathSet>guest.toolsStatus</pathSet>
								<pathSet>config.guestFullName</pathSet>
								<pathSet>config.version</pathSet>
								<pathSet>config.uuid</pathSet>
								<pathSet>summary.quickStats.overallCpuUsage</pathSet>
								<pathSet>summary.quickStats.hostMemoryUsage</pathSet>
								<pathSet>summary.quickStats.guestMemoryUsage</pathSet>
							</propSet>
							<objectSet>
								<obj type="VirtualMachine">${VIEWED_VMID}</obj>
							</objectSet>
						</specSet>
						<options/>
					</RetrievePropertiesEx>
				</soapenv:Body>
			</soapenv:Envelope>
		XML
	)
    
	local RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${VMPROPERTIES_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)
    
	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g')
    
	local VIEWED_VM_NAME=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='name']/val)" - 2>/dev/null)
	local VIEWED_VM_POWERSTATE=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='runtime.powerState']/val)" - 2>/dev/null)
	local VIEWED_VM_VCPU_NUM=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='config.hardware.numCPU']/val)" - 2>/dev/null)
	local VIEWED_VM_CORES_PER_SOCKET=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='config.hardware.numCoresPerSocket']/val)" - 2>/dev/null)
	local VIEWED_VM_RAM=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='config.hardware.memoryMB']/val)" - 2>/dev/null)


	local VIEWED_VM_IP=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='guest.ipAddress']/val)" - 2>/dev/null)
	local VIEWED_VM_OS=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='config.guestFullName']/val)" - 2>/dev/null)
	local VIEWED_VM_TOOLS=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='guest.toolsStatus']/val)" - 2>/dev/null)
	local VIEWED_VM_DISK_BYTES=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='summary.storage.committed']/val)" - 2>/dev/null)
    local VIEWED_VM_DISK_GB=$(awk "BEGIN {printf \"%.2f\", ${VIEWED_VM_DISK_BYTES}/1024/1024/1024}")
	local VIEWED_VM_BIOS_UUID=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='config.uuid']/val)" - 2>/dev/null)

	local VIEWED_VM_CPU_MHZ=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='summary.quickStats.overallCpuUsage']/val)" - 2>/dev/null)
	local VIEWED_VM_HOST_MEM=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='summary.quickStats.hostMemoryUsage']/val)" - 2>/dev/null)
	local VIEWED_VM_GUEST_MEM=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='summary.quickStats.guestMemoryUsage']/val)" - 2>/dev/null)

# Formatting for the FZF preview

	echo -e "ESXi host ${ESXI_HOST} vm info:"
	echo -e "------------------------------------------------------------"
	echo
	echo -e "name: ${VIEWED_VM_NAME}"
	echo -e "power state: ${VIEWED_VM_POWERSTATE}"
	echo -e "cpu number: ${VIEWED_VM_VCPU_NUM}"
	echo -e "cores per socket: ${VIEWED_VM_CORES_PER_SOCKET}"
	echo -e "ram: ${VIEWED_VM_RAM} MB"
	echo -e "consumed host CPU: ${VIEWED_VM_CPU_MHZ:-0} MHz"
	echo -e "consumed host memory: ${VIEWED_VM_HOST_MEM:-0} MB"
	echo -e "active guest memory: ${VIEWED_VM_GUEST_MEM:-0} MB"
	echo -e "ip address: ${VIEWED_VM_IP:-N/A (tools not running?)}"
	echo -e "os: ${VIEWED_VM_OS}"
	echo -e "vm tools: ${VIEWED_VM_TOOLS}"
	echo -e "storage used: ${VIEWED_VM_DISK_GB} GB"
	echo -e "bios uuid: ${VIEWED_VM_BIOS_UUID}"

}
export -f cmd_vms_info

# vms list command handler
cmd_vms_list() {

	log_debug "${FUNCNAME[0]} is called"

	local LISTVMS_XML
	LISTVMS_XML=$(
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
								<type>VirtualMachine</type>
								<pathSet>name</pathSet>
								<pathSet>runtime.powerState</pathSet>
								<pathSet>config.hardware.numCPU</pathSet>
								<pathSet>config.hardware.memoryMB</pathSet>
							</propSet>
							<objectSet>
								<obj type="Folder">ha-folder-root</obj>
								<selectSet xsi:type="TraversalSpec">
									<name>traverseFolders</name>
									<type>Folder</type>
									<path>childEntity</path>
									<skip>false</skip>
									<selectSet>
										<name>traverseFolders</name>
									</selectSet>
									<selectSet xsi:type="TraversalSpec">
										<name>traverseDatacenter</name>
										<type>Datacenter</type>
										<path>vmFolder</path>
										<skip>false</skip>
										<selectSet>
											<name>traverseFolders</name>
										</selectSet>
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
	
	local RESPONSE
	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LISTVMS_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
	
	{
		echo -e "VMID\tNAME\tSTATUS\tCPU\tRAM"
		echo "${RESPONSE}" | xmllint --xpath "//objects" - 2>/dev/null | sed 's/<\/objects>/<\/objects>\n/g' | \
		while read -r vm_block
		do
	    
	    [[ -z "${vm_block}" ]] && continue
	
	    VMID=$(echo "${vm_block}" | xmllint --xpath "string(//obj)" - 2>/dev/null)
	    NAME=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='name']/val)" - 2>/dev/null)
	    STATUS=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='runtime.powerState']/val)" - 2>/dev/null)
	    CPU=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.numCPU']/val)" - 2>/dev/null)
	    RAM=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.memoryMB']/val)" - 2>/dev/null)
	
	    echo -e "${VMID}\t${NAME}\t${STATUS}\t${CPU}\t${RAM}MB"
	
		done
	} | column -t | \
	fzf --cycle \
              --border=rounded \
              --border-label=" ESXi host's '${ESXI_HOSTNAME}' vms " \
              --preview-window=right:50% \
              --preview "cmd_vms_info {} ${ESXI_HOSTNAME}" \
              --preview-window=hidden --bind 'ctrl-p:toggle-preview' \
              --bind 'ctrl-b:become(exit 2)' \
              --header-lines=1 \
              --header "Simple list of all the vms | ctrl-p: (un)toggle vm's info view" \
              --layout reverse

}

# vms poweron command handler
cmd_vms_poweron() {

	log_debug "${FUNCNAME[0]} is called"

	local LISTVMS_XML
	LISTVMS_XML=$(
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
								<type>VirtualMachine</type>
								<pathSet>name</pathSet>
								<pathSet>runtime.powerState</pathSet>
								<pathSet>config.hardware.numCPU</pathSet>
								<pathSet>config.hardware.memoryMB</pathSet>
							</propSet>
							<objectSet>
								<obj type="Folder">ha-folder-root</obj>
								<selectSet xsi:type="TraversalSpec">
									<name>traverseFolders</name>
									<type>Folder</type>
									<path>childEntity</path>
									<skip>false</skip>
									<selectSet>
										<name>traverseFolders</name>
									</selectSet>
									<selectSet xsi:type="TraversalSpec">
										<name>traverseDatacenter</name>
										<type>Datacenter</type>
										<path>vmFolder</path>
										<skip>false</skip>
										<selectSet>
											<name>traverseFolders</name>
										</selectSet>
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
	
	local RESPONSE
	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LISTVMS_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
	
	VMS_SELECTED=$(
		{	
			echo -e "VMID\tNAME\tSTATUS\tCPU\tRAM"
			echo "${RESPONSE}" | xmllint --xpath "//objects" - 2>/dev/null | sed 's/<\/objects>/<\/objects>\n/g' | \
			while read -r vm_block
			do
		    
			    [[ -z "${vm_block}" ]] && continue
			
			    VMID=$(echo "${vm_block}" | xmllint --xpath "string(//obj)" - 2>/dev/null)
			    NAME=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='name']/val)" - 2>/dev/null)
			    STATUS=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='runtime.powerState']/val)" - 2>/dev/null)
			    CPU=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.numCPU']/val)" - 2>/dev/null)
			    RAM=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.memoryMB']/val)" - 2>/dev/null)
			
			    echo -e "${VMID}\t${NAME}\t${STATUS}\t${CPU}\t${RAM}MB"
		
			done
		} | column -t \
		| fzf --cycle \
			  --border=rounded \
			  --border-label=" ESXi host's '${ESXI_HOSTNAME}' vms " \
			  --preview-window=right:50% \
			  --preview "cmd_vms_info {} ${ESXI_HOSTNAME}" \
			  --preview-window=hidden --bind 'ctrl-p:toggle-preview' \
			  --bind 'ctrl-a:select-all' \
			  --bind 'ctrl-d:deselect-all'  \
			  --bind 'ctrl-b:become(exit 2)' \
			  --header-lines=1 \
			  --header "Select vms to power on or resume | ctrl-p: (un)toggle vm's info view | ctrl-a/d: select/deselect all vms" \
			  --layout reverse -m
	)

	local fzf_exit_code=$?
	[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
	[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
	[[ -z "${VMS_SELECTED}" ]] && return

	while IFS= read -r line
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

		local VMID=$(echo "${line}" | awk '{print $1}')
		[[ -z "${VMID}" ]] && continue

		log_debug "function: ${FUNCNAME[0]}, powering on the vm ${VMID}"

		local POWERONVM_XML
		POWERONVM_XML=$(
			cat <<- XML
				<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:vim25">
					<soapenv:Body>
						<PowerOnVM_Task xmlns="urn:vim25">
							<_this type="VirtualMachine">${VMID}</_this>
						</PowerOnVM_Task>
					</soapenv:Body>
				</soapenv:Envelope>
			XML
		)

		local HTTP_CODE
		HTTP_CODE=$(
			curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_vms_poweron" -X POST \
				-H "Content-Type: text/xml; charset=UTF-8" \
				-H "SOAPAction: \"urn:vim25/8.0\"" \
				-d "${POWERONVM_XML}" \
				-b "${COOKIE_FILE}" \
				"https://${ESXI_HOSTNAME}/sdk" \
				2>&1
		)

		if [[ "${HTTP_CODE}" == "200" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, ✓ power on for the vm with vmid=${VMID} is successful (HTTP CODE ${HTTP_CODE})"
			log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_poweron")"

			local TASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' "${BASHAPP_TMPDIR}/cmd_vms_poweron")

			if [[ -n "${TASKID}" ]]
			then
				log_debug "function: ${FUNCNAME[0]}, powering on vm task created: ${TASKID}"
        
				if cmd_tasks_monitor "${TASKID}" 60 true "powering on vm ${VMID}"
				then
					log_debug "function: ${FUNCNAME[0]}, ✓ vm with VMID ${VMID} has been powered on successfully"
				else
					log_error "function: ${FUNCNAME[0]}, ✗ has failed to power on the vm with vmid=${VMID}"
				fi

			else
				log_error "function: ${FUNCNAME[0]}, no TASK ID returned"
			fi

		else
			log_error "function: ${FUNCNAME[0]}, ✗ has failed to power on the vm with vmid=${VMID} (HTTP CODE ${HTTP_CODE})"
			log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_poweron") (HTTP CODE ${HTTP_CODE})"
		fi

	done <<< "${VMS_SELECTED}"

	# delay to show results
	sleep 2

}

# vms poweroff command handler
cmd_vms_poweroff() {

	log_debug "${FUNCNAME[0]} is called"

	local LISTVMS_XML
	LISTVMS_XML=$(
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
								<type>VirtualMachine</type>
								<pathSet>name</pathSet>
								<pathSet>runtime.powerState</pathSet>
								<pathSet>config.hardware.numCPU</pathSet>
								<pathSet>config.hardware.memoryMB</pathSet>
							</propSet>
							<objectSet>
								<obj type="Folder">ha-folder-root</obj>
								<selectSet xsi:type="TraversalSpec">
									<name>traverseFolders</name>
									<type>Folder</type>
									<path>childEntity</path>
									<skip>false</skip>
									<selectSet>
										<name>traverseFolders</name>
									</selectSet>
									<selectSet xsi:type="TraversalSpec">
										<name>traverseDatacenter</name>
										<type>Datacenter</type>
										<path>vmFolder</path>
										<skip>false</skip>
										<selectSet>
											<name>traverseFolders</name>
										</selectSet>
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
	
	local RESPONSE
	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LISTVMS_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
	
	VMS_SELECTED=$(
		{	
			echo -e "VMID\tNAME\tSTATUS\tCPU\tRAM"
			echo "${RESPONSE}" | xmllint --xpath "//objects" - 2>/dev/null | sed 's/<\/objects>/<\/objects>\n/g' | \
			while read -r vm_block
			do
		    
			    [[ -z "${vm_block}" ]] && continue
			
			    VMID=$(echo "${vm_block}" | xmllint --xpath "string(//obj)" - 2>/dev/null)
			    NAME=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='name']/val)" - 2>/dev/null)
			    STATUS=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='runtime.powerState']/val)" - 2>/dev/null)
			    CPU=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.numCPU']/val)" - 2>/dev/null)
			    RAM=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.memoryMB']/val)" - 2>/dev/null)
			
			    echo -e "${VMID}\t${NAME}\t${STATUS}\t${CPU}\t${RAM}MB"
		
			done
		} | column -t \
		| fzf --cycle \
			  --border=rounded \
			  --border-label=" ESXi host's '${ESXI_HOSTNAME}' vms " \
			  --preview-window=right:50% \
			  --preview "cmd_vms_info {} ${ESXI_HOSTNAME}" \
			  --preview-window=hidden --bind 'ctrl-p:toggle-preview' \
			  --bind 'ctrl-a:select-all' \
			  --bind 'ctrl-d:deselect-all'  \
			  --bind 'ctrl-b:become(exit 2)' \
			  --header-lines=1 \
			  --header "Select vms to power off | ctrl-p: (un)toggle vm's info view | ctrl-a/d: select/deselect all vms" \
			  --layout reverse -m
	)

	local fzf_exit_code=$?
	[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
	[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
	[[ -z "${VMS_SELECTED}" ]] && return

	while IFS= read -r line
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

		local VMID=$(echo "${line}" | awk '{print $1}')
		[[ -z "${VMID}" ]] && continue

		log_debug "function: ${FUNCNAME[0]}, powering off the vm ${VMID}"

		local POWEROFFVM_XML 
		POWEROFFVM_XML=$(
			cat <<- XML
				<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:vim25">
					<soapenv:Body>
						<PowerOffVM_Task xmlns="urn:vim25">
							<_this type="VirtualMachine">${VMID}</_this>
						</PowerOffVM_Task>
					</soapenv:Body>
				</soapenv:Envelope>
			XML
		)

		local HTTP_CODE
		HTTP_CODE=$(
			curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_vms_poweroff" -X POST \
				-H "Content-Type: text/xml; charset=UTF-8" \
				-H "SOAPAction: \"urn:vim25/8.0\"" \
				-d "${POWEROFFVM_XML}" \
				-b "${COOKIE_FILE}" \
				"https://${ESXI_HOSTNAME}/sdk" \
				2>&1
		)

		if [[ "${HTTP_CODE}" == "200" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, ✓ power off for the vm with vmid=${VMID} is successful (HTTP CODE ${HTTP_CODE})"
			log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_poweroff")"

			local TASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' "${BASHAPP_TMPDIR}/cmd_vms_poweroff")

			if [[ -n "${TASKID}" ]]
			then
				log_debug "function: ${FUNCNAME[0]}, powering off vm task created: ${TASKID}"
        
				if cmd_tasks_monitor "${TASKID}" 60 true "powering off vm ${VMID}"
				then
					log_debug "function: ${FUNCNAME[0]}, ✓ vm with VMID ${VMID} has been powered off successfully"
				else
					log_error "function: ${FUNCNAME[0]}, ✗ has failed to power off the vm with vmid=${VMID}"
				fi

			else
				log_error "function: ${FUNCNAME[0]}, no TASK ID returned"
			fi


		else
			log_error "function: ${FUNCNAME[0]}, ✗ has failed to power off the vm with vmid=${VMID} (HTTP CODE ${HTTP_CODE})"
			log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_poweroff") (HTTP CODE ${HTTP_CODE})"
		fi

	done <<< "${VMS_SELECTED}"

	# delay to show results
	sleep 2

}

# vms suspend command handler
cmd_vms_suspend() {

	log_debug "${FUNCNAME[0]} is called"

	local LISTVMS_XML
	LISTVMS_XML=$(
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
								<type>VirtualMachine</type>
								<pathSet>name</pathSet>
								<pathSet>runtime.powerState</pathSet>
								<pathSet>config.hardware.numCPU</pathSet>
								<pathSet>config.hardware.memoryMB</pathSet>
							</propSet>
							<objectSet>
								<obj type="Folder">ha-folder-root</obj>
								<selectSet xsi:type="TraversalSpec">
									<name>traverseFolders</name>
									<type>Folder</type>
									<path>childEntity</path>
									<skip>false</skip>
									<selectSet>
										<name>traverseFolders</name>
									</selectSet>
									<selectSet xsi:type="TraversalSpec">
										<name>traverseDatacenter</name>
										<type>Datacenter</type>
										<path>vmFolder</path>
										<skip>false</skip>
										<selectSet>
											<name>traverseFolders</name>
										</selectSet>
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
	
	local RESPONSE
	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LISTVMS_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
	
	VMS_SELECTED=$(
		{	
			echo -e "VMID\tNAME\tSTATUS\tCPU\tRAM"
			echo "${RESPONSE}" | xmllint --xpath "//objects" - 2>/dev/null | sed 's/<\/objects>/<\/objects>\n/g' | \
			while read -r vm_block
			do
		    
			    [[ -z "${vm_block}" ]] && continue
			
			    VMID=$(echo "${vm_block}" | xmllint --xpath "string(//obj)" - 2>/dev/null)
			    NAME=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='name']/val)" - 2>/dev/null)
			    STATUS=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='runtime.powerState']/val)" - 2>/dev/null)
			    CPU=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.numCPU']/val)" - 2>/dev/null)
			    RAM=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.memoryMB']/val)" - 2>/dev/null)
			
			    echo -e "${VMID}\t${NAME}\t${STATUS}\t${CPU}\t${RAM}MB"
		
			done
		} | column -t \
		| fzf --cycle \
			  --border=rounded \
			  --border-label=" ESXi host's '${ESXI_HOSTNAME}' vms " \
			  --preview-window=right:50% \
			  --preview "cmd_vms_info {} ${ESXI_HOSTNAME}" \
			  --preview-window=hidden --bind 'ctrl-p:toggle-preview' \
			  --bind 'ctrl-a:select-all' \
			  --bind 'ctrl-d:deselect-all'  \
			  --bind 'ctrl-b:become(exit 2)' \
			  --header-lines=1 \
			  --header "Select vms to suspend | ctrl-p: (un)toggle vm's info view | ctrl-a/d: select/deselect all vms" \
			  --layout reverse -m
	)

	local fzf_exit_code=$?
	[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
	[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
	[[ -z "${VMS_SELECTED}" ]] && return

	while IFS= read -r line
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

		local VMID=$(echo "${line}" | awk '{print $1}')
		[[ -z "${VMID}" ]] && continue

		log_debug "function: ${FUNCNAME[0]}, suspending the vm ${VMID}"

		local SUSPENDVM_XML
		SUSPENDVM_XML=$(
			cat <<- XML
				<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:vim25">
					<soapenv:Body>
						<SuspendVM_Task xmlns="urn:vim25">
							<_this type="VirtualMachine">${VMID}</_this>
						</SuspendVM_Task>
					</soapenv:Body>
				</soapenv:Envelope>
			XML
		)

		local HTTP_CODE
		HTTP_CODE=$(
			curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_vms_suspend" -X POST \
				-H "Content-Type: text/xml; charset=UTF-8" \
				-H "SOAPAction: \"urn:vim25/8.0\"" \
				-d "${SUSPENDVM_XML}" \
				-b "${COOKIE_FILE}" \
				"https://${ESXI_HOSTNAME}/sdk" \
				2>&1
		)

		if [[ "${HTTP_CODE}" == "200" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, ✓ suspending the vm with vmid=${VMID} is successful (HTTP CODE ${HTTP_CODE})"
			log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_suspend")"

			local TASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' "${BASHAPP_TMPDIR}/cmd_vms_suspend")

			if [[ -n "${TASKID}" ]]
			then
				log_debug "function: ${FUNCNAME[0]}, suspending vm task created: ${TASKID}"
        
				if cmd_tasks_monitor "${TASKID}" 300 true "suspending vm ${VMID}"
				then
					log_debug "function: ${FUNCNAME[0]}, ✓ vm with VMID ${VMID} has been suspended successfully"
				else
					log_error "function: ${FUNCNAME[0]}, ✗ has failed to suspend the vm with vmid=${VMID}"
				fi

			else
				log_error "function: ${FUNCNAME[0]}, no TASK ID returned"
			fi

		else
			log_error "function: ${FUNCNAME[0]}, ✗ has failed to suspend the vm with vmid=${VMID} (HTTP CODE ${HTTP_CODE})"
			log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_suspend") (HTTP CODE ${HTTP_CODE})"
		fi

	done <<< "${VMS_SELECTED}"

	# delay to show results
	sleep 2

}

# vms reset command handler
cmd_vms_reset() {

	log_debug "${FUNCNAME[0]} is called"

	local LISTVMS_XML
	LISTVMS_XML=$(
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
								<type>VirtualMachine</type>
								<pathSet>name</pathSet>
								<pathSet>runtime.powerState</pathSet>
								<pathSet>config.hardware.numCPU</pathSet>
								<pathSet>config.hardware.memoryMB</pathSet>
							</propSet>
							<objectSet>
								<obj type="Folder">ha-folder-root</obj>
								<selectSet xsi:type="TraversalSpec">
									<name>traverseFolders</name>
									<type>Folder</type>
									<path>childEntity</path>
									<skip>false</skip>
									<selectSet>
										<name>traverseFolders</name>
									</selectSet>
									<selectSet xsi:type="TraversalSpec">
										<name>traverseDatacenter</name>
										<type>Datacenter</type>
										<path>vmFolder</path>
										<skip>false</skip>
										<selectSet>
											<name>traverseFolders</name>
										</selectSet>
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
	
	local RESPONSE
	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LISTVMS_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
	
	VMS_SELECTED=$(
		{	
			echo -e "VMID\tNAME\tSTATUS\tCPU\tRAM"
			echo "${RESPONSE}" | xmllint --xpath "//objects" - 2>/dev/null | sed 's/<\/objects>/<\/objects>\n/g' | \
			while read -r vm_block
			do
		    
			    [[ -z "${vm_block}" ]] && continue
			
			    VMID=$(echo "${vm_block}" | xmllint --xpath "string(//obj)" - 2>/dev/null)
			    NAME=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='name']/val)" - 2>/dev/null)
			    STATUS=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='runtime.powerState']/val)" - 2>/dev/null)
			    CPU=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.numCPU']/val)" - 2>/dev/null)
			    RAM=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.memoryMB']/val)" - 2>/dev/null)
			
			    echo -e "${VMID}\t${NAME}\t${STATUS}\t${CPU}\t${RAM}MB"
		
			done
		} | column -t \
		| fzf --cycle \
			  --border=rounded \
			  --border-label=" ESXi host's '${ESXI_HOSTNAME}' vms " \
			  --preview-window=right:50% \
			  --preview "cmd_vms_info {} ${ESXI_HOSTNAME}" \
			  --preview-window=hidden --bind 'ctrl-p:toggle-preview' \
			  --bind 'ctrl-a:select-all' \
			  --bind 'ctrl-d:deselect-all'  \
			  --bind 'ctrl-b:become(exit 2)' \
			  --header-lines=1 \
			  --header "Select vms to reset | ctrl-p: (un)toggle vm's info view | ctrl-a/d: select/deselect all vms" \
			  --layout reverse -m
	)

	local fzf_exit_code=$?
	[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
	[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
	[[ -z "${VMS_SELECTED}" ]] && return

	while IFS= read -r line
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

		local VMID=$(echo "${line}" | awk '{print $1}')
		[[ -z "${VMID}" ]] && continue

		log_debug "function: ${FUNCNAME[0]}, resetting the vm ${VMID}"

		local RESETVM_XML
		RESETVM_XML=$(
			cat <<- XML
				<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:vim25">
					<soapenv:Body>
						<ResetVM_Task xmlns="urn:vim25">
							<_this type="VirtualMachine">${VMID}</_this>
						</ResetVM_Task>
					</soapenv:Body>
				</soapenv:Envelope>
			XML
		)

		local HTTP_CODE
		HTTP_CODE=$(
			curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_vms_reset" -X POST \
				-H "Content-Type: text/xml; charset=UTF-8" \
				-H "SOAPAction: \"urn:vim25/8.0\"" \
				-d "${RESETVM_XML}" \
				-b "${COOKIE_FILE}" \
				"https://${ESXI_HOSTNAME}/sdk" \
				2>&1
		)

		if [[ "${HTTP_CODE}" == "200" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, ✓ resetting the vm with vmid=${VMID} is successful (HTTP CODE ${HTTP_CODE})"
			log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_reset")"

			local TASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' "${BASHAPP_TMPDIR}/cmd_vms_reset")

			if [[ -n "${TASKID}" ]]
			then
				log_debug "function: ${FUNCNAME[0]}, resetting vm task created: ${TASKID}"
        
				if cmd_tasks_monitor "${TASKID}" 60 true "resetting vm ${VMID}"
				then
					log_debug "function: ${FUNCNAME[0]}, ✓ vm with VMID ${VMID} has been reset successfully"
				else
					log_error "function: ${FUNCNAME[0]}, ✗ has failed to reset the vm with vmid=${VMID}"
				fi

			else
				log_error "function: ${FUNCNAME[0]}, no TASK ID returned"
			fi


		else
			log_error "function: ${FUNCNAME[0]}, ✗ has failed to reset the vm with vmid=${VMID} (HTTP CODE ${HTTP_CODE})"
			log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_reset") (HTTP CODE ${HTTP_CODE})"
		fi

	done <<< "${VMS_SELECTED}"

	# delay to show results
	sleep 2

}

# vms shutdown command handler
cmd_vms_shutdown() {

	log_debug "${FUNCNAME[0]} is called"

	local LISTVMS_XML
	LISTVMS_XML=$(
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
								<type>VirtualMachine</type>
								<pathSet>name</pathSet>
								<pathSet>runtime.powerState</pathSet>
								<pathSet>config.hardware.numCPU</pathSet>
								<pathSet>config.hardware.memoryMB</pathSet>
							</propSet>
							<objectSet>
								<obj type="Folder">ha-folder-root</obj>
								<selectSet xsi:type="TraversalSpec">
									<name>traverseFolders</name>
									<type>Folder</type>
									<path>childEntity</path>
									<skip>false</skip>
									<selectSet>
										<name>traverseFolders</name>
									</selectSet>
									<selectSet xsi:type="TraversalSpec">
										<name>traverseDatacenter</name>
										<type>Datacenter</type>
										<path>vmFolder</path>
										<skip>false</skip>
										<selectSet>
											<name>traverseFolders</name>
										</selectSet>
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
	
	local RESPONSE
	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LISTVMS_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
	
	VMS_SELECTED=$(
		{	
			echo -e "VMID\tNAME\tSTATUS\tCPU\tRAM"
			echo "${RESPONSE}" | xmllint --xpath "//objects" - 2>/dev/null | sed 's/<\/objects>/<\/objects>\n/g' | \
			while read -r vm_block
			do
		    
			    [[ -z "${vm_block}" ]] && continue
			
			    VMID=$(echo "${vm_block}" | xmllint --xpath "string(//obj)" - 2>/dev/null)
			    NAME=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='name']/val)" - 2>/dev/null)
			    STATUS=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='runtime.powerState']/val)" - 2>/dev/null)
			    CPU=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.numCPU']/val)" - 2>/dev/null)
			    RAM=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.memoryMB']/val)" - 2>/dev/null)
			
			    echo -e "$VMID\t$NAME\t$STATUS\t$CPU\t${RAM}MB"
		
			done
		} | column -t \
		| fzf --cycle \
			  --border=rounded \
			  --border-label=" ESXi host's '${ESXI_HOSTNAME}' vms " \
			  --preview-window=right:50% \
			  --preview "cmd_vms_info {} ${ESXI_HOSTNAME}" \
			  --preview-window=hidden --bind 'ctrl-p:toggle-preview' \
			  --bind 'ctrl-a:select-all' \
			  --bind 'ctrl-d:deselect-all'  \
			  --bind 'ctrl-b:become(exit 2)' \
			  --header-lines=1 \
			  --header "Select vms to shutdown | ctrl-p: (un)toggle vm's info view | ctrl-a/d: select/deselect all vms" \
			  --layout reverse -m
	)

	local fzf_exit_code=$?
	[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
	[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
	[[ -z "${VMS_SELECTED}" ]] && return

	while IFS= read -r line
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

		local VMID=$(echo "${line}" | awk '{print $1}')
		[[ -z "${VMID}" ]] && continue

		log_debug "function: ${FUNCNAME[0]}, shutting down the vm ${VMID}"

		local SHUTDOWNVM_XML
		SHUTDOWNVM_XML=$(
			cat <<- XML
				<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:vim25">
					<soapenv:Body>
						<ShutdownGuest xmlns="urn:vim25">
							<_this type="VirtualMachine">${VMID}</_this>
						</ShutdownGuest>
					</soapenv:Body>
				</soapenv:Envelope>
			XML
		)

		local GREEN='\033[0;32m'
		local RED='\033[0;31m'
		local BOLD='\033[1m'
		local NC='\033[0m'

		local HTTP_CODE
		HTTP_CODE=$(
			curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_vms_shutdown" -X POST \
				-H "Content-Type: text/xml; charset=UTF-8" \
				-H "SOAPAction: \"urn:vim25/8.0\"" \
				-d "${SHUTDOWNVM_XML}" \
				-b "${COOKIE_FILE}" \
				"https://${ESXI_HOSTNAME}/sdk" \
				2>&1
		)

		if [[ "${HTTP_CODE}" == "200" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, ✓ shutting down the vm with vmid=${VMID} is successful (HTTP CODE ${HTTP_CODE})"
			log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_shutdown")"

			local TASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' "${BASHAPP_TMPDIR}/cmd_vms_shutdown")

			if [[ -n "${TASKID}" ]]
			then
				log_debug "function: ${FUNCNAME[0]}, shutdown vm task created: ${TASKID}"
        
				if cmd_tasks_monitor "${TASKID}" 60 true "shutting down vm ${VMID}"
				then
					log_debug "function: ${FUNCNAME[0]}, ✓ vm with VMID ${VMID} has been shut down successfully"
				else
					log_error "function: ${FUNCNAME[0]}, ✗ has failed to shut down the vm with vmid=${VMID}"
				fi

			else
				log_error "function: ${FUNCNAME[0]}, no TASK ID returned"
            	printf "\r\033[K${GREEN}✔${NC} ${BOLD}shutting down vm ${VMID} Done!${NC}\n"
			fi

		else
			log_error "function: ${FUNCNAME[0]}, ✗ has failed to shutdown the vm with vmid=${VMID} (HTTP CODE ${HTTP_CODE})"
			log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_shutdown") (HTTP CODE ${HTTP_CODE})"
            printf "\r\033[K${RED}✗${NC} ${BOLD}shutting down vm ${VMID} Failed!${NC}\n"
		fi

	done <<< "${VMS_SELECTED}"
	
	# delay to show results
	sleep 2

}


# vms restart command handler
cmd_vms_restart() {

	log_debug "${FUNCNAME[0]} is called"

	local LISTVMS_XML
	LISTVMS_XML=$(
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
								<type>VirtualMachine</type>
								<pathSet>name</pathSet>
								<pathSet>runtime.powerState</pathSet>
								<pathSet>config.hardware.numCPU</pathSet>
								<pathSet>config.hardware.memoryMB</pathSet>
							</propSet>
							<objectSet>
								<obj type="Folder">ha-folder-root</obj>
								<selectSet xsi:type="TraversalSpec">
									<name>traverseFolders</name>
									<type>Folder</type>
									<path>childEntity</path>
									<skip>false</skip>
									<selectSet>
										<name>traverseFolders</name>
									</selectSet>
									<selectSet xsi:type="TraversalSpec">
										<name>traverseDatacenter</name>
										<type>Datacenter</type>
										<path>vmFolder</path>
										<skip>false</skip>
										<selectSet>
											<name>traverseFolders</name>
										</selectSet>
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
	
	local RESPONSE
	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LISTVMS_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
	
	VMS_SELECTED=$(
		{	
			echo -e "VMID\tNAME\tSTATUS\tCPU\tRAM"
			echo "${RESPONSE}" | xmllint --xpath "//objects" - 2>/dev/null | sed 's/<\/objects>/<\/objects>\n/g' | \
			while read -r vm_block
			do
		    
			    [[ -z "${vm_block}" ]] && continue
			
			    VMID=$(echo "${vm_block}" | xmllint --xpath "string(//obj)" - 2>/dev/null)
			    NAME=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='name']/val)" - 2>/dev/null)
			    STATUS=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='runtime.powerState']/val)" - 2>/dev/null)
			    CPU=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.numCPU']/val)" - 2>/dev/null)
			    RAM=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.memoryMB']/val)" - 2>/dev/null)
			
			    echo -e "${VMID}\t${NAME}\t${STATUS}\t${CPU}\t${RAM}MB"
		
			done
		} | column -t \
		| fzf --cycle \
			  --border=rounded \
			  --border-label=" ESXi host's '${ESXI_HOSTNAME}' vms " \
			  --preview-window=right:50% \
			  --preview "cmd_vms_info {} ${ESXI_HOSTNAME}" \
			  --preview-window=hidden --bind 'ctrl-p:toggle-preview' \
			  --bind 'ctrl-a:select-all' \
			  --bind 'ctrl-d:deselect-all'  \
			  --bind 'ctrl-b:become(exit 2)' \
			  --header-lines=1 \
			  --header "Select vms to restart | ctrl-p: (un)toggle vm's info view | ctrl-a/d: select/deselect all vms" \
			  --layout reverse -m
	)

	local fzf_exit_code=$?
	[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
	[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
	[[ -z "${VMS_SELECTED}" ]] && return

	while IFS= read -r line
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

		local VMID=$(echo "${line}" | awk '{print $1}')
		[[ -z "${VMID}" ]] && continue

		log_debug "function: ${FUNCNAME[0]}, restarting the vm ${VMID}"

		local RESTARTVM_XML 
		RESTARTVM_XML=$(
			cat <<- XML
				<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:vim25">
					<soapenv:Body>
						<RebootGuest xmlns="urn:vim25">
							<_this type="VirtualMachine">${VMID}</_this>
						</RebootGuest>
					</soapenv:Body>
				</soapenv:Envelope>
			XML
		)

		local HTTP_CODE
		HTTP_CODE=$(
			curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_vms_restart" -X POST \
				-H "Content-Type: text/xml; charset=UTF-8" \
				-H "SOAPAction: \"urn:vim25/8.0\"" \
				-d "${RESTARTVM_XML}" \
				-b "${COOKIE_FILE}" \
				"https://${ESXI_HOSTNAME}/sdk" \
				2>&1
		)

		if [[ "${HTTP_CODE}" == "200" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, ✓ restarting the vm with vmid=${VMID} is successful (HTTP CODE ${HTTP_CODE})"
			log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_restart")"

			local TASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' "${BASHAPP_TMPDIR}/cmd_vms_restart")

			if [[ -n "${TASKID}" ]]
			then
				log_debug "function: ${FUNCNAME[0]}, restarting vm task created: ${TASKID}"
        
				if cmd_tasks_monitor "${TASKID}" 60 true "restarting vm ${VMID}"
				then
					log_debug "function: ${FUNCNAME[0]}, ✓ vm with VMID ${VMID} has been restarted successfully"
				else
					log_error "function: ${FUNCNAME[0]}, ✗ has failed to restart the vm with vmid=${VMID}"
				fi

			else
				log_error "function: ${FUNCNAME[0]}, no TASK ID returned"
			fi

		else
			log_error "function: ${FUNCNAME[0]}, ✗ has failed to restart the vm with vmid=${VMID} (HTTP CODE ${HTTP_CODE})"
			log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_restart") (HTTP CODE ${HTTP_CODE})"
		fi

	done <<< "${VMS_SELECTED}"

	# delay to show results
	sleep 2

}


# vms snapshot command handler
cmd_vms_snapshot() {

	log_debug "${FUNCNAME[0]} is called"

	local ACTION
	ACTION=$(
		echo -e "list\ncreate\nremove\nrevert\nrename" | \
		fzf --cycle \
			--border=rounded \
			--border-label=" ESXi host's '${ESXI_HOSTNAME}' snapshots actions " \
			--header "Choose please an action for snapshots:" \
			--layout reverse
	)

	[[ -z "${ACTION}" ]] && return

	case "${ACTION}" in
		list)		cmd_vms_snapshot_list	;;
		create)		cmd_vms_snapshot_create	;;
		remove)		cmd_vms_snapshot_remove	;;
		revert)		cmd_vms_snapshot_revert	;;
		rename)		cmd_vms_snapshot_rename	;;
		*)			log_error "function: ${FUNCNAME[0]}, unknown snapshots' action: ${ACTION}" ;;
	esac

}

# vms snapshot list command handler
cmd_vms_snapshot_list() {

	log_debug "${FUNCNAME[0]} is called"

	local LISTVMS_XML
	LISTVMS_XML=$(
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
								<type>VirtualMachine</type>
								<pathSet>name</pathSet>
								<pathSet>runtime.powerState</pathSet>
								<pathSet>config.hardware.numCPU</pathSet>
								<pathSet>config.hardware.memoryMB</pathSet>
							</propSet>
							<objectSet>
								<obj type="Folder">ha-folder-root</obj>
								<selectSet xsi:type="TraversalSpec">
									<name>traverseFolders</name>
									<type>Folder</type>
									<path>childEntity</path>
									<skip>false</skip>
									<selectSet>
										<name>traverseFolders</name>
									</selectSet>
									<selectSet xsi:type="TraversalSpec">
										<name>traverseDatacenter</name>
										<type>Datacenter</type>
										<path>vmFolder</path>
										<skip>false</skip>
										<selectSet>
											<name>traverseFolders</name>
										</selectSet>
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
	
	local RESPONSE
	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LISTVMS_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
	
	VMS_SELECTED=$(
		{	
			echo -e "VMID\tNAME\tSTATUS\tCPU\tRAM"
			echo "${RESPONSE}" | xmllint --xpath "//objects" - 2>/dev/null | sed 's/<\/objects>/<\/objects>\n/g' | \
			while read -r vm_block
			do
		    
			    [[ -z "${vm_block}" ]] && continue
			
			    VMID=$(echo "${vm_block}" | xmllint --xpath "string(//obj)" - 2>/dev/null)
			    NAME=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='name']/val)" - 2>/dev/null)
			    STATUS=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='runtime.powerState']/val)" - 2>/dev/null)
			    CPU=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.numCPU']/val)" - 2>/dev/null)
			    RAM=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.memoryMB']/val)" - 2>/dev/null)
			
			    echo -e "${VMID}\t${NAME}\t${STATUS}\t${CPU}\t${RAM}MB"
		
			done
		} | column -t \
		| fzf --cycle \
			  --border=rounded \
			  --border-label=" ESXi host's '${ESXI_HOSTNAME}' vms " \
			  --preview-window=right:50% \
			  --preview "cmd_vms_info {} ${ESXI_HOSTNAME}" \
			  --preview-window=hidden --bind 'ctrl-p:toggle-preview' \
			  --bind 'ctrl-a:select-all' \
			  --bind 'ctrl-d:deselect-all'  \
			  --bind 'ctrl-b:become(exit 2)' \
			  --header-lines=1 \
			  --header "Select vms to get their snapshots | ctrl-p: (un)toggle vm's info view | ctrl-a/d: select/deselect all vms" \
			  --layout reverse -m
	)

	local fzf_exit_code=$?
	[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
	[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
	[[ -z "${VMS_SELECTED}" ]] && return

	while IFS= read -r line
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

		local VMID=$(echo "${line}" | awk '{print $1}')
		[[ -z "${VMID}" ]] && continue

		log_debug "function: ${FUNCNAME[0]}, listing the vm's snapshots ${VMID}"

		local LISTVMSNAPSHOTS_XML
		LISTVMSNAPSHOTS_XML=$(
			cat <<- XML
				<soapenv:Envelope 
					xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" 
					xmlns:urn="urn:vim25">
					<soapenv:Body>
						<RetrievePropertiesEx xmlns="urn:vim25">
							<_this type="PropertyCollector">ha-property-collector</_this>
							<specSet>
								<propSet>
									<type>VirtualMachine</type>
									<pathSet>snapshot</pathSet>
								</propSet>
								<objectSet>
									<obj type="VirtualMachine">${VMID}</obj>
								</objectSet>
							</specSet>
							<options/>
						</RetrievePropertiesEx>
					</soapenv:Body>
				</soapenv:Envelope>
			XML
		)

		local HTTP_CODE
		HTTP_CODE=$(
			curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_vms_snapshot_list" -X POST \
				-H "Content-Type: text/xml; charset=UTF-8" \
				-H "SOAPAction: \"urn:vim25/8.0\"" \
				-d "${LISTVMSNAPSHOTS_XML}" \
				-b "${COOKIE_FILE}" \
				"https://${ESXI_HOSTNAME}/sdk" \
				2>&1
		)

		if [[ "${HTTP_CODE}" == "200" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, ✓ listing the vm's with vmid=${VMID} snapshots is successful (HTTP CODE ${HTTP_CODE})"
			log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_snapshot_list")"

			RESPONSE=$(cat "${BASHAPP_TMPDIR}/cmd_vms_snapshot_list" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
			
			CURRENT_SNAPSHOT=$(echo "$RESPONSE" | xmllint --xpath "string(//currentSnapshot)" - 2>/dev/null)
			
			# Get count of all snapshots
			SNAPSHOT_COUNT=$(echo "$RESPONSE" | xmllint --xpath "count(//snapshot[@type='VirtualMachineSnapshot'])" - 2>/dev/null)
			
			SNAPSHOTS_SELECTED=$(
				{	
					echo -e "SNAPSHOTID\tNAME\tDESCRIPTION\tCREATE_TIME\tSTATE\tCURRENT_MARK"
					for i in $(seq 1 ${SNAPSHOT_COUNT%.*})
					do
						
						log_debug "function: ${FUNCNAME[0]}, for loop"
						
					    SNAPSHOTID=$(
							echo "$RESPONSE" | \
							xmllint --xpath "string((//snapshot[@type='VirtualMachineSnapshot'])[$i])" - 2>/dev/null
						)

					    NAME=$(
							echo "$RESPONSE" | \
							xmllint --xpath "string((//snapshot[@type='VirtualMachineSnapshot'])[$i]/../name)" - 2>/dev/null
						)

					    DESCRIPTION=$(
							echo "$RESPONSE" | \
							xmllint --xpath "string((//snapshot[@type='VirtualMachineSnapshot'])[$i]/../description)" - 2>/dev/null
						)

					    CREATE_TIME=$(
							echo "$RESPONSE" | \
							xmllint --xpath "string((//snapshot[@type='VirtualMachineSnapshot'])[$i]/../createTime)" - 2>/dev/null
						)

					    STATE=$(
							echo "$RESPONSE" | \
							xmllint --xpath "string((//snapshot[@type='VirtualMachineSnapshot'])[$i]/../state)" - 2>/dev/null
						)
					    
					    CURRENT_MARK=""
					    [[ "${SNAPSHOTID}" == "${CURRENT_SNAPSHOT}" ]] && CURRENT_MARK="current"
					    
					    echo -e "${SNAPSHOTID}\t${NAME}\t${DESCRIPTION}\t${CREATE_TIME}\t${STATE}\t${CURRENT_MARK}"

					done
				} | column -t -s $'\t' \
				| fzf --cycle \
					  --border=rounded \
					  --border-label=" ESXi host's '${ESXI_HOSTNAME}' vm's with VMID ${VMID} snapshots list " \
					  --bind 'ctrl-b:become(exit 2)' \
					  --header-lines=1 \
					  --header "VM's with VMID ${VMID} snapshots list" \
					  --layout reverse
			)

			local fzf_exit_code=$?
			[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
			[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
			[[ -z "${SNAPSHOTS_SELECTED}" ]] && return

		else
			log_error "function: ${FUNCNAME[0]}, ✗ has failed to list the vm's with vmid=${VMID} snapshots (HTTP CODE ${HTTP_CODE})"
			log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_snapshot_list") (HTTP CODE ${HTTP_CODE})"
		fi

	done <<< "${VMS_SELECTED}"

}

# vms snapshot create command handler
cmd_vms_snapshot_create() {

	log_debug "${FUNCNAME[0]} is called"

	local LISTVMS_XML
	LISTVMS_XML=$(
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
								<type>VirtualMachine</type>
								<pathSet>name</pathSet>
								<pathSet>runtime.powerState</pathSet>
								<pathSet>config.hardware.numCPU</pathSet>
								<pathSet>config.hardware.memoryMB</pathSet>
							</propSet>
							<objectSet>
								<obj type="Folder">ha-folder-root</obj>
								<selectSet xsi:type="TraversalSpec">
									<name>traverseFolders</name>
									<type>Folder</type>
									<path>childEntity</path>
									<skip>false</skip>
									<selectSet>
										<name>traverseFolders</name>
									</selectSet>
									<selectSet xsi:type="TraversalSpec">
										<name>traverseDatacenter</name>
										<type>Datacenter</type>
										<path>vmFolder</path>
										<skip>false</skip>
										<selectSet>
											<name>traverseFolders</name>
										</selectSet>
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
	
	local RESPONSE
	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LISTVMS_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
	
	VMS_SELECTED=$(
		{	
			echo -e "VMID\tNAME\tSTATUS\tCPU\tRAM"
			echo "${RESPONSE}" | xmllint --xpath "//objects" - 2>/dev/null | sed 's/<\/objects>/<\/objects>\n/g' | \
			while read -r vm_block
			do
		    
			    [[ -z "${vm_block}" ]] && continue
			
			    VMID=$(echo "${vm_block}" | xmllint --xpath "string(//obj)" - 2>/dev/null)
			    NAME=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='name']/val)" - 2>/dev/null)
			    STATUS=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='runtime.powerState']/val)" - 2>/dev/null)
			    CPU=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.numCPU']/val)" - 2>/dev/null)
			    RAM=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.memoryMB']/val)" - 2>/dev/null)
			
			    echo -e "${VMID}\t${NAME}\t${STATUS}\t${CPU}\t${RAM}MB"
		
			done
		} | column -t \
		| fzf --cycle \
			  --border=rounded \
			  --border-label=" ESXi host's '${ESXI_HOSTNAME}' vms " \
			  --preview-window=right:50% \
			  --preview "cmd_vms_info {} ${ESXI_HOSTNAME}" \
			  --preview-window=hidden --bind 'ctrl-p:toggle-preview' \
			  --bind 'ctrl-a:select-all' \
			  --bind 'ctrl-d:deselect-all'  \
			  --bind 'ctrl-b:become(exit 2)' \
			  --header-lines=1 \
			  --header "Select vms to create snapshots | ctrl-p: (un)toggle vm's info view | ctrl-a/d: select/deselect all vms" \
			  --layout reverse -m
	)

	local fzf_exit_code=$?
	[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
	[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
	[[ -z "${VMS_SELECTED}" ]] && return

	while IFS= read -r line
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

		local VMID=$(echo "${line}" | awk '{print $1}')
		[[ -z "${VMID}" ]] && continue

		local SNAPSHOT_NAME
		read -e -r -p "Enter snapshot name (default: ${VMID}-snap-'date'): " SNAPSHOT_NAME < /dev/tty
		SNAPSHOT_NAME=${SNAPSHOT_NAME:-"${VMID}-snap-$(date '+%Y%m%d%H%M%S')"}

		log_debug "function: ${FUNCNAME[0]}, snapshot name is ${SNAPSHOT_NAME}"

		read -e -r -p "Enter a snapshot description for the new VM ${VMID} (default: vm ${VMID} snapshot taken 'date'): " SNAPSHOT_DESC < /dev/tty
		[[ -z "${SNAPSHOT_DESC}" ]] && local SNAPSHOT_DESC="vm ${VMID} snapshot taken $(date '+%Y%m%d%H%M%S')"

		log_debug "function: ${FUNCNAME[0]}, snapshot description is ${SNAPSHOT_DESC}"

		# set to true if the vm's live ram is needed to snapshot as well
		local SNAPSHOT_RAM="false"
		# typically is set to false when the SNAPSHOT_RAM="true"
		local QUIESCE="true"
		local CREATEVMSNAPSHOT_XML
		CREATEVMSNAPSHOT_XML=$(
			cat <<- XML
				<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:vim25">
					<soapenv:Body>
						<CreateSnapshotEx_Task xmlns="urn:vim25">
							<_this type="VirtualMachine">${VMID}</_this>
							<name>${SNAPSHOT_NAME}</name>
							<description>${SNAPSHOT_DESC}</description>
							<memory>${SNAPSHOT_RAM}</memory>
							<quiesceSpec>${QUIESCE}</quiesceSpec>
						</CreateSnapshotEx_Task>
					</soapenv:Body>
				</soapenv:Envelope>				
			XML
		)

		log_debug "function: ${FUNCNAME[0]}, creating a snapshot of the vm's with VMID ${VMID}"

		RESPONSE=$(
			curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_vms_snapshot_create" -X POST \
				-H "Content-Type: text/xml; charset=UTF-8" \
				-H "SOAPAction: \"urn:vim25/8.0\"" \
				-d "${CREATEVMSNAPSHOT_XML}" \
				-b "${COOKIE_FILE}" \
				"https://${ESXI_HOSTNAME}/sdk" \
				2>&1
		)

		log_debug "function: ${FUNCNAME[0]}, RESPONSE=${RESPONSE}"
		log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_snapshot_create")"

		if [[ "${RESPONSE}" == "200" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, ✓ a snapshot of the vm with VMID ${VMID} has been created successfully"

			local TASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' "${BASHAPP_TMPDIR}/cmd_vms_snapshot_create")

			if [[ -n "${TASKID}" ]]
			then
				log_debug "function: ${FUNCNAME[0]}, creating vm snapshot task created: ${TASKID}"
        
				if cmd_tasks_monitor "${TASKID}" 600 true "snapshotting vm ${VMID}"
				then
					log_debug "function: ${FUNCNAME[0]}, ✓ a snapshot of the vm with VMID ${VMID} has been created successfully"
				else
					log_error "function: ${FUNCNAME[0]}, ✗ has failed to create snapshot of the vm with vmid=${VMID}"
				fi

			else
				log_error "function: ${FUNCNAME[0]}, no TASK ID returned"
			fi

		else
			log_error "function: ${FUNCNAME[0]}, has failed to create a snapshot of the vm with vmid=${VMID}"
		fi

	done <<< "${VMS_SELECTED}"

	# delay to show results
	sleep 2

}

# vms snapshot remove command handler
cmd_vms_snapshot_remove() {

	log_debug "${FUNCNAME[0]} is called"

	local LISTVMS_XML
	LISTVMS_XML=$(
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
								<type>VirtualMachine</type>
								<pathSet>name</pathSet>
								<pathSet>runtime.powerState</pathSet>
								<pathSet>config.hardware.numCPU</pathSet>
								<pathSet>config.hardware.memoryMB</pathSet>
							</propSet>
							<objectSet>
								<obj type="Folder">ha-folder-root</obj>
								<selectSet xsi:type="TraversalSpec">
									<name>traverseFolders</name>
									<type>Folder</type>
									<path>childEntity</path>
									<skip>false</skip>
									<selectSet>
										<name>traverseFolders</name>
									</selectSet>
									<selectSet xsi:type="TraversalSpec">
										<name>traverseDatacenter</name>
										<type>Datacenter</type>
										<path>vmFolder</path>
										<skip>false</skip>
										<selectSet>
											<name>traverseFolders</name>
										</selectSet>
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
	
	local RESPONSE
	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LISTVMS_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
	
	VMS_SELECTED=$(
		{	
			echo -e "VMID\tNAME\tSTATUS\tCPU\tRAM"
			echo "${RESPONSE}" | xmllint --xpath "//objects" - 2>/dev/null | sed 's/<\/objects>/<\/objects>\n/g' | \
			while read -r vm_block
			do
		    
			    [[ -z "${vm_block}" ]] && continue
			
			    VMID=$(echo "${vm_block}" | xmllint --xpath "string(//obj)" - 2>/dev/null)
			    NAME=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='name']/val)" - 2>/dev/null)
			    STATUS=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='runtime.powerState']/val)" - 2>/dev/null)
			    CPU=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.numCPU']/val)" - 2>/dev/null)
			    RAM=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.memoryMB']/val)" - 2>/dev/null)
			
			    echo -e "${VMID}\t${NAME}\t${STATUS}\t${CPU}\t${RAM}MB"
		
			done
		} | column -t \
		| fzf --cycle \
			  --border=rounded \
			  --border-label=" ESXi host's '${ESXI_HOSTNAME}' vms " \
			  --preview-window=right:50% \
			  --preview "cmd_vms_info {} ${ESXI_HOSTNAME}" \
			  --preview-window=hidden --bind 'ctrl-p:toggle-preview' \
			  --bind 'ctrl-a:select-all' \
			  --bind 'ctrl-d:deselect-all'  \
			  --bind 'ctrl-b:become(exit 2)' \
			  --header-lines=1 \
			  --header "Select vms to remove their snapshots | ctrl-p: (un)toggle vm's info view | ctrl-a/d: select/deselect all vms" \
			  --layout reverse -m
	)

	local fzf_exit_code=$?
	[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
	[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
	[[ -z "${VMS_SELECTED}" ]] && return

	while IFS= read -r line
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

		local VMID=$(echo "${line}" | awk '{print $1}')
		[[ -z "${VMID}" ]] && continue

		log_debug "function: ${FUNCNAME[0]}, listing the vm's snapshots ${VMID}"

		local LISTVMSNAPSHOTS_XML
		LISTVMSNAPSHOTS_XML=$(
			cat <<- XML
				<soapenv:Envelope 
					xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" 
					xmlns:urn="urn:vim25">
					<soapenv:Body>
						<RetrievePropertiesEx xmlns="urn:vim25">
							<_this type="PropertyCollector">ha-property-collector</_this>
							<specSet>
								<propSet>
									<type>VirtualMachine</type>
									<pathSet>snapshot</pathSet>
								</propSet>
								<objectSet>
									<obj type="VirtualMachine">${VMID}</obj>
								</objectSet>
							</specSet>
							<options/>
						</RetrievePropertiesEx>
					</soapenv:Body>
				</soapenv:Envelope>
			XML
		)

		local HTTP_CODE
		HTTP_CODE=$(
			curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_vms_snapshot_remove" -X POST \
				-H "Content-Type: text/xml; charset=UTF-8" \
				-H "SOAPAction: \"urn:vim25/8.0\"" \
				-d "${LISTVMSNAPSHOTS_XML}" \
				-b "${COOKIE_FILE}" \
				"https://${ESXI_HOSTNAME}/sdk" \
				2>&1
		)

		if [[ "${HTTP_CODE}" == "200" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, ✓ listing the vm's with vmid=${VMID} snapshots is successful (HTTP CODE ${HTTP_CODE})"
			log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_snapshot_remove")"

			RESPONSE=$(cat "${BASHAPP_TMPDIR}/cmd_vms_snapshot_remove" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
			
			CURRENT_SNAPSHOT=$(echo "$RESPONSE" | xmllint --xpath "string(//currentSnapshot)" - 2>/dev/null)
			
			# Get count of all snapshots
			SNAPSHOT_COUNT=$(echo "$RESPONSE" | xmllint --xpath "count(//snapshot[@type='VirtualMachineSnapshot'])" - 2>/dev/null)
			
			SNAPSHOTS_SELECTED=$(
				{	
					echo -e "SNAPSHOTID\tNAME\tDESCRIPTION\tCREATE_TIME\tSTATE\tCURRENT_MARK"
					for i in $(seq 1 ${SNAPSHOT_COUNT%.*})
					do
						
						log_debug "function: ${FUNCNAME[0]}, for loop"
						
					    SNAPSHOTID=$(
							echo "$RESPONSE" | \
							xmllint --xpath "string((//snapshot[@type='VirtualMachineSnapshot'])[$i])" - 2>/dev/null
						)

					    NAME=$(
							echo "$RESPONSE" | \
							xmllint --xpath "string((//snapshot[@type='VirtualMachineSnapshot'])[$i]/../name)" - 2>/dev/null
						)

					    DESCRIPTION=$(
							echo "$RESPONSE" | \
							xmllint --xpath "string((//snapshot[@type='VirtualMachineSnapshot'])[$i]/../description)" - 2>/dev/null
						)

					    CREATE_TIME=$(
							echo "$RESPONSE" | \
							xmllint --xpath "string((//snapshot[@type='VirtualMachineSnapshot'])[$i]/../createTime)" - 2>/dev/null
						)

					    STATE=$(
							echo "$RESPONSE" | \
							xmllint --xpath "string((//snapshot[@type='VirtualMachineSnapshot'])[$i]/../state)" - 2>/dev/null
						)
					    
					    CURRENT_MARK=""
					    [[ "$SNAPSHOTID" == "$CURRENT_SNAPSHOT" ]] && CURRENT_MARK="current"
					    
					    echo -e "${SNAPSHOTID}\t${NAME}\t${DESCRIPTION}\t${CREATE_TIME}\t${STATE}\t${CURRENT_MARK}"

					done
				} | column -t -s $'\t' \
				| fzf --cycle \
					  --border=rounded \
					  --border-label=" ESXi host's '${ESXI_HOSTNAME}' vm's with VMID ${VMID} snapshots list " \
					  --bind 'ctrl-a:select-all' \
					  --bind 'ctrl-d:deselect-all'  \
					  --bind 'ctrl-b:become(exit 2)' \
					  --header-lines=1 \
					  --header "Select snapshots of the vm's with VMID ${VMID} to remove | ctrl-p: (un)toggle vm's info view | ctrl-a/d: select/deselect all vms" \
					  --layout reverse -m
			)

			local fzf_exit_code=$?
			[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
			[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
			[[ -z "${SNAPSHOTS_SELECTED}" ]] && return

			local CONFIRM
			read -e -r -p "vm ${VMID} snapshots number is ${SNAPSHOT_COUNT}. Confirm the removal of them all (YES/NO)? : " CONFIRM < /dev/tty
			CONFIRM=${CONFIRM^^}
			[[ "${CONFIRM}" != "YES" ]] && { log_debug "function: ${FUNCNAME[0]}, cancelling snapshots removal"; continue; }

			while IFS= read -r line
			do
		
				log_debug "function: ${FUNCNAME[0]}, while loop"
		
				local SNAPSHOTID=$(echo "${line}" | awk '{print $1}')
				[[ -z "${SNAPSHOTID}" ]] && continue

				local REMOVE_CHILDREN="false"
				local REMOVEVMSNAPSHOT_XML
				REMOVEVMSNAPSHOT_XML=$(
					cat <<- XML
						<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:vim25">
							<soapenv:Body>
								<RemoveSnapshot_Task xmlns="urn:vim25">
									<_this type="VirtualMachineSnapshot">${SNAPSHOTID}</_this>
									<removeChildren>${REMOVE_CHILDREN}</removeChildren>
								</RemoveSnapshot_Task>
							</soapenv:Body>
						</soapenv:Envelope>				
					XML
				)
		
				log_debug "function: ${FUNCNAME[0]}, removing the vm's with VMID ${VMID} snapshot ${SNAPSHOTID}"

				RESPONSE=$(
					curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_vms_snapshot_remove" -X POST \
						-H "Content-Type: text/xml; charset=UTF-8" \
						-H "SOAPAction: \"urn:vim25/8.0\"" \
						-d "${REMOVEVMSNAPSHOT_XML}" \
						-b "${COOKIE_FILE}" \
						"https://${ESXI_HOSTNAME}/sdk" \
						2>&1
				)
	
				log_debug "function: ${FUNCNAME[0]}, RESPONSE=${RESPONSE}"
				log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_snapshot_remove")"

				if [[ "${RESPONSE}" == "200" ]]
				then
					log_debug "function: ${FUNCNAME[0]}, snapshot ${SNAPSHOTID} has been removed successfully"
		
					local TASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' "${BASHAPP_TMPDIR}/cmd_vms_snapshot_remove")
		
					if [[ -n "${TASKID}" ]]
					then
						log_debug "function: ${FUNCNAME[0]}, removing vm snapshot task created: ${TASKID}"
		        
						if cmd_tasks_monitor "${TASKID}" 300 true "removing vm ${VMID} snapshot ${SNAPSHOTID}"
						then
							log_debug "function: ${FUNCNAME[0]}, ✓ the snapshot ${SNAPSHOTID} of the vm with VMID ${VMID} has been removed successfully"
						else
							log_error "function: ${FUNCNAME[0]}, ✗ has failed to remove the snapshot ${SNAPSHOTID} of the vm with vmid=${VMID}"
						fi
		
					else
						log_error "function: ${FUNCNAME[0]}, no TASK ID returned"
					fi

				else
					log_error "function: ${FUNCNAME[0]}, has failed to remove the snapshot ${SNAPSHOTID}"
				fi
				
			done <<< "${SNAPSHOTS_SELECTED}"

		else
			log_error "function: ${FUNCNAME[0]}, ✗ has failed to list the vm's with vmid=${VMID} snapshots (HTTP CODE ${HTTP_CODE})"
			log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_snapshot_remove") (HTTP CODE ${HTTP_CODE})"
		fi

	done <<< "${VMS_SELECTED}"

	# delay to show results
	sleep 2

}

# vms snapshot revert command handler
cmd_vms_snapshot_revert() {

	log_debug "${FUNCNAME[0]} is called"

	local LISTVMS_XML
	LISTVMS_XML=$(
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
								<type>VirtualMachine</type>
								<pathSet>name</pathSet>
								<pathSet>runtime.powerState</pathSet>
								<pathSet>config.hardware.numCPU</pathSet>
								<pathSet>config.hardware.memoryMB</pathSet>
							</propSet>
							<objectSet>
								<obj type="Folder">ha-folder-root</obj>
								<selectSet xsi:type="TraversalSpec">
									<name>traverseFolders</name>
									<type>Folder</type>
									<path>childEntity</path>
									<skip>false</skip>
									<selectSet>
										<name>traverseFolders</name>
									</selectSet>
									<selectSet xsi:type="TraversalSpec">
										<name>traverseDatacenter</name>
										<type>Datacenter</type>
										<path>vmFolder</path>
										<skip>false</skip>
										<selectSet>
											<name>traverseFolders</name>
										</selectSet>
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
	
	local RESPONSE
	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LISTVMS_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
	
	VMS_SELECTED=$(
		{	
			echo -e "VMID\tNAME\tSTATUS\tCPU\tRAM"
			echo "${RESPONSE}" | xmllint --xpath "//objects" - 2>/dev/null | sed 's/<\/objects>/<\/objects>\n/g' | \
			while read -r vm_block
			do
		    
			    [[ -z "${vm_block}" ]] && continue
			
			    VMID=$(echo "${vm_block}" | xmllint --xpath "string(//obj)" - 2>/dev/null)
			    NAME=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='name']/val)" - 2>/dev/null)
			    STATUS=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='runtime.powerState']/val)" - 2>/dev/null)
			    CPU=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.numCPU']/val)" - 2>/dev/null)
			    RAM=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.memoryMB']/val)" - 2>/dev/null)
			
			    echo -e "${VMID}\t${NAME}\t${STATUS}\t${CPU}\t${RAM}MB"
		
			done
		} | column -t \
		| fzf --cycle \
			  --border=rounded \
			  --border-label=" ESXi host's '${ESXI_HOSTNAME}' vms " \
			  --preview-window=right:50% \
			  --preview "cmd_vms_info {} ${ESXI_HOSTNAME}" \
			  --preview-window=hidden --bind 'ctrl-p:toggle-preview' \
			  --bind 'ctrl-a:select-all' \
			  --bind 'ctrl-d:deselect-all'  \
			  --bind 'ctrl-b:become(exit 2)' \
			  --header-lines=1 \
			  --header "Select vms to revert to their snapshots | ctrl-p: (un)toggle vm's info view | ctrl-a/d: select/deselect all vms" \
			  --layout reverse -m
	)

	local fzf_exit_code=$?
	[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
	[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
	[[ -z "${VMS_SELECTED}" ]] && return

	while IFS= read -r line
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

		local VMID=$(echo "${line}" | awk '{print $1}')
		[[ -z "${VMID}" ]] && continue

		log_debug "function: ${FUNCNAME[0]}, listing the vm's snapshots ${VMID}"

		local LISTVMSNAPSHOTS_XML
		LISTVMSNAPSHOTS_XML=$(
			cat <<- XML
				<soapenv:Envelope 
					xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" 
					xmlns:urn="urn:vim25">
					<soapenv:Body>
						<RetrievePropertiesEx xmlns="urn:vim25">
							<_this type="PropertyCollector">ha-property-collector</_this>
							<specSet>
								<propSet>
									<type>VirtualMachine</type>
									<pathSet>snapshot</pathSet>
								</propSet>
								<objectSet>
									<obj type="VirtualMachine">${VMID}</obj>
								</objectSet>
							</specSet>
							<options/>
						</RetrievePropertiesEx>
					</soapenv:Body>
				</soapenv:Envelope>
			XML
		)

		local HTTP_CODE
		HTTP_CODE=$(
			curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_vms_snapshot_revert" -X POST \
				-H "Content-Type: text/xml; charset=UTF-8" \
				-H "SOAPAction: \"urn:vim25/8.0\"" \
				-d "${LISTVMSNAPSHOTS_XML}" \
				-b "${COOKIE_FILE}" \
				"https://${ESXI_HOSTNAME}/sdk" \
				2>&1
		)

		if [[ "${HTTP_CODE}" == "200" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, ✓ listing the vm's with vmid=${VMID} snapshots is successful (HTTP CODE ${HTTP_CODE})"
			log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_snapshot_revert")"

			RESPONSE=$(cat "${BASHAPP_TMPDIR}/cmd_vms_snapshot_revert" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
			
			CURRENT_SNAPSHOT=$(echo "$RESPONSE" | xmllint --xpath "string(//currentSnapshot)" - 2>/dev/null)
			
			# Get count of all snapshots
			SNAPSHOT_COUNT=$(echo "$RESPONSE" | xmllint --xpath "count(//snapshot[@type='VirtualMachineSnapshot'])" - 2>/dev/null)
			
			SNAPSHOTS_SELECTED=$(
				{	
					echo -e "SNAPSHOTID\tNAME\tDESCRIPTION\tCREATE_TIME\tSTATE\tCURRENT_MARK"
					for i in $(seq 1 ${SNAPSHOT_COUNT%.*})
					do
						
						log_debug "function: ${FUNCNAME[0]}, for loop"
						
					    SNAPSHOTID=$(
							echo "$RESPONSE" | \
							xmllint --xpath "string((//snapshot[@type='VirtualMachineSnapshot'])[$i])" - 2>/dev/null
						)

					    NAME=$(
							echo "$RESPONSE" | \
							xmllint --xpath "string((//snapshot[@type='VirtualMachineSnapshot'])[$i]/../name)" - 2>/dev/null
						)

					    DESCRIPTION=$(
							echo "$RESPONSE" | \
							xmllint --xpath "string((//snapshot[@type='VirtualMachineSnapshot'])[$i]/../description)" - 2>/dev/null
						)

					    CREATE_TIME=$(
							echo "$RESPONSE" | \
							xmllint --xpath "string((//snapshot[@type='VirtualMachineSnapshot'])[$i]/../createTime)" - 2>/dev/null
						)

					    STATE=$(
							echo "$RESPONSE" | \
							xmllint --xpath "string((//snapshot[@type='VirtualMachineSnapshot'])[$i]/../state)" - 2>/dev/null
						)
					    
					    CURRENT_MARK=""
					    [[ "$SNAPSHOTID" == "$CURRENT_SNAPSHOT" ]] && CURRENT_MARK="current"
					    
					    echo -e "${SNAPSHOTID}\t${NAME}\t${DESCRIPTION}\t${CREATE_TIME}\t${STATE}\t${CURRENT_MARK}"

					done
				} | column -t -s $'\t' \
				| fzf --cycle \
					  --border=rounded \
					  --border-label=" ESXi host's '${ESXI_HOSTNAME}' vm's with VMID ${VMID} snapshots list " \
					  --bind 'ctrl-a:select-all' \
					  --bind 'ctrl-d:deselect-all'  \
					  --bind 'ctrl-b:become(exit 2)' \
					  --header-lines=1 \
					  --header "Select a snapshot of the vm's with VMID ${VMID} to revert to | ctrl-p: (un)toggle vm's info view" \
					  --layout reverse 
			)

			local fzf_exit_code=$?
			[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
			[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
			[[ -z "${SNAPSHOTS_SELECTED}" ]] && return

		
			local SNAPSHOTID=$(echo "${SNAPSHOTS_SELECTED}" | awk '{print $1}')
			[[ -z "${SNAPSHOTID}" ]] && continue

			local REVERTVMTOSNAPSHOT_XML
			REVERTVMTOSNAPSHOT_XML=$(
				cat <<- XML
					<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:vim25">
						<soapenv:Body>
							<RevertToSnapshot_Task xmlns="urn:vim25">
								<_this type="VirtualMachineSnapshot">${SNAPSHOTID}</_this>
							</RevertToSnapshot_Task>
						</soapenv:Body>
					</soapenv:Envelope>				
				XML
			)
	
			log_debug "function: ${FUNCNAME[0]}, reverting the vm's with VMID ${VMID} to the snapshot ${SNAPSHOTID}"

			RESPONSE=$(
				curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_vms_snapshot_revert" -X POST \
					-H "Content-Type: text/xml; charset=UTF-8" \
					-H "SOAPAction: \"urn:vim25/8.0\"" \
					-d "${REVERTVMTOSNAPSHOT_XML}" \
					-b "${COOKIE_FILE}" \
					"https://${ESXI_HOSTNAME}/sdk" \
					2>&1
			)

			log_debug "function: ${FUNCNAME[0]}, RESPONSE=${RESPONSE}"
			log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_snapshot_revert")"

			if [[ "${RESPONSE}" == "200" ]]
			then
				log_debug "function: ${FUNCNAME[0]}, the vm with VMID ${VMID} has been reverted to the snapshot ${SNAPSHOTID} successfully"
	
				local TASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' "${BASHAPP_TMPDIR}/cmd_vms_snapshot_revert")
	
				if [[ -n "${TASKID}" ]]
				then
					log_debug "function: ${FUNCNAME[0]}, reverting to vm's snapshot task created: ${TASKID}"
	        
					if cmd_tasks_monitor "${TASKID}" 300 true "reverting ${VMID} to snapshot ${SNAPSHOTID}"
					then
						log_debug "function: ${FUNCNAME[0]}, ✓ has been reverted to the snapshot ${SNAPSHOTID} successfully"
					else
						log_error "function: ${FUNCNAME[0]}, ✗ has failed to revert to the snapshot ${SNAPSHOTID}"
					fi
	
				else
					log_error "function: ${FUNCNAME[0]}, no TASK ID returned"
				fi

			else
				log_error "function: ${FUNCNAME[0]}, has failed to revert the vm with VMID ${VMID} to the snapshot ${SNAPSHOTID}"
			fi

		else
			log_error "function: ${FUNCNAME[0]}, ✗ has failed to list the vm's with vmid=${VMID} snapshots (HTTP CODE ${HTTP_CODE})"
			log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_snapshot_revert") (HTTP CODE ${HTTP_CODE})"
		fi

	done <<< "${VMS_SELECTED}"

	# delay to show results
	sleep 2

}

# vms snapshot rename command handler
cmd_vms_snapshot_rename() {

	log_debug "${FUNCNAME[0]} is called"

	local LISTVMS_XML
	LISTVMS_XML=$(
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
								<type>VirtualMachine</type>
								<pathSet>name</pathSet>
								<pathSet>runtime.powerState</pathSet>
								<pathSet>config.hardware.numCPU</pathSet>
								<pathSet>config.hardware.memoryMB</pathSet>
							</propSet>
							<objectSet>
								<obj type="Folder">ha-folder-root</obj>
								<selectSet xsi:type="TraversalSpec">
									<name>traverseFolders</name>
									<type>Folder</type>
									<path>childEntity</path>
									<skip>false</skip>
									<selectSet>
										<name>traverseFolders</name>
									</selectSet>
									<selectSet xsi:type="TraversalSpec">
										<name>traverseDatacenter</name>
										<type>Datacenter</type>
										<path>vmFolder</path>
										<skip>false</skip>
										<selectSet>
											<name>traverseFolders</name>
										</selectSet>
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
	
	local RESPONSE
	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LISTVMS_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
	
	VMS_SELECTED=$(
		{	
			echo -e "VMID\tNAME\tSTATUS\tCPU\tRAM"
			echo "${RESPONSE}" | xmllint --xpath "//objects" - 2>/dev/null | sed 's/<\/objects>/<\/objects>\n/g' | \
			while read -r vm_block
			do
		    
			    [[ -z "${vm_block}" ]] && continue
			
			    VMID=$(echo "${vm_block}" | xmllint --xpath "string(//obj)" - 2>/dev/null)
			    NAME=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='name']/val)" - 2>/dev/null)
			    STATUS=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='runtime.powerState']/val)" - 2>/dev/null)
			    CPU=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.numCPU']/val)" - 2>/dev/null)
			    RAM=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.memoryMB']/val)" - 2>/dev/null)
			
			    echo -e "${VMID}\t${NAME}\t${STATUS}\t${CPU}\t${RAM}MB"
		
			done
		} | column -t \
		| fzf --cycle \
			  --border=rounded \
			  --border-label=" ESXi host's '${ESXI_HOSTNAME}' vms " \
			  --preview-window=right:50% \
			  --preview "cmd_vms_info {} ${ESXI_HOSTNAME}" \
			  --preview-window=hidden --bind 'ctrl-p:toggle-preview' \
			  --bind 'ctrl-a:select-all' \
			  --bind 'ctrl-d:deselect-all'  \
			  --bind 'ctrl-b:become(exit 2)' \
			  --header-lines=1 \
			  --header "Select vms to get their snapshots | ctrl-p: (un)toggle vm's info view | ctrl-a/d: select/deselect all vms" \
			  --layout reverse -m
	)

	local fzf_exit_code=$?
	[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
	[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
	[[ -z "${VMS_SELECTED}" ]] && return

	while IFS= read -r line
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

		local VMID=$(echo "${line}" | awk '{print $1}')
		[[ -z "${VMID}" ]] && continue

		log_debug "function: ${FUNCNAME[0]}, listing the vm's snapshots ${VMID}"

		local LISTVMSNAPSHOTS_XML
		LISTVMSNAPSHOTS_XML=$(
			cat <<- XML
				<soapenv:Envelope 
					xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" 
					xmlns:urn="urn:vim25">
					<soapenv:Body>
						<RetrievePropertiesEx xmlns="urn:vim25">
							<_this type="PropertyCollector">ha-property-collector</_this>
							<specSet>
								<propSet>
									<type>VirtualMachine</type>
									<pathSet>snapshot</pathSet>
								</propSet>
								<objectSet>
									<obj type="VirtualMachine">${VMID}</obj>
								</objectSet>
							</specSet>
							<options/>
						</RetrievePropertiesEx>
					</soapenv:Body>
				</soapenv:Envelope>
			XML
		)

		local HTTP_CODE
		HTTP_CODE=$(
			curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_vms_snapshot_rename" -X POST \
				-H "Content-Type: text/xml; charset=UTF-8" \
				-H "SOAPAction: \"urn:vim25/8.0\"" \
				-d "${LISTVMSNAPSHOTS_XML}" \
				-b "${COOKIE_FILE}" \
				"https://${ESXI_HOSTNAME}/sdk" \
				2>&1
		)

		if [[ "${HTTP_CODE}" == "200" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, ✓ listing the vm's with vmid=${VMID} snapshots is successful (HTTP CODE ${HTTP_CODE})"
			log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_snapshot_rename")"

			RESPONSE=$(cat "${BASHAPP_TMPDIR}/cmd_vms_snapshot_rename" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
			
			CURRENT_SNAPSHOT=$(echo "$RESPONSE" | xmllint --xpath "string(//currentSnapshot)" - 2>/dev/null)
			
			# Get count of all snapshots
			SNAPSHOT_COUNT=$(echo "$RESPONSE" | xmllint --xpath "count(//snapshot[@type='VirtualMachineSnapshot'])" - 2>/dev/null)
			
			SNAPSHOTS_SELECTED=$(
				{	
					echo -e "SNAPSHOTID\tNAME\tDESCRIPTION\tCREATE_TIME\tSTATE\tCURRENT_MARK"
					for i in $(seq 1 ${SNAPSHOT_COUNT%.*})
					do
						
						log_debug "function: ${FUNCNAME[0]}, for loop"
						
					    SNAPSHOTID=$(
							echo "$RESPONSE" | \
							xmllint --xpath "string((//snapshot[@type='VirtualMachineSnapshot'])[$i])" - 2>/dev/null
						)

					    NAME=$(
							echo "$RESPONSE" | \
							xmllint --xpath "string((//snapshot[@type='VirtualMachineSnapshot'])[$i]/../name)" - 2>/dev/null
						)

					    DESCRIPTION=$(
							echo "$RESPONSE" | \
							xmllint --xpath "string((//snapshot[@type='VirtualMachineSnapshot'])[$i]/../description)" - 2>/dev/null
						)

					    CREATE_TIME=$(
							echo "$RESPONSE" | \
							xmllint --xpath "string((//snapshot[@type='VirtualMachineSnapshot'])[$i]/../createTime)" - 2>/dev/null
						)

					    STATE=$(
							echo "$RESPONSE" | \
							xmllint --xpath "string((//snapshot[@type='VirtualMachineSnapshot'])[$i]/../state)" - 2>/dev/null
						)
					    
					    CURRENT_MARK=""
					    [[ "$SNAPSHOTID" == "$CURRENT_SNAPSHOT" ]] && CURRENT_MARK="current"
					    
					    echo -e "${SNAPSHOTID}\t${NAME}\t${DESCRIPTION}\t${CREATE_TIME}\t${STATE}\t${CURRENT_MARK}"

					done
				} | column -t -s $'\t' \
				| fzf --cycle \
					  --border=rounded \
					  --border-label=" ESXi host's '${ESXI_HOSTNAME}' vm's with VMID ${VMID} snapshots list " \
					  --bind 'ctrl-a:select-all' \
					  --bind 'ctrl-d:deselect-all'  \
					  --bind 'ctrl-b:become(exit 2)' \
					  --header-lines=1 \
					  --header "Select snapshots of the vm's with VMID ${VMID} to rename | ctrl-p: (un)toggle snapshot's info view | ctrl-a/d: select/deselect all snapshots" \
					  --layout reverse -m
			)

			local fzf_exit_code=$?
			[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
			[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
			[[ -z "${SNAPSHOTS_SELECTED}" ]] && return

			while IFS= read -r line
			do
		
				log_debug "function: ${FUNCNAME[0]}, while loop"
		
				local SNAPSHOTID=$(echo "${line}" | awk '{print $1}')
				[[ -z "${SNAPSHOTID}" ]] && continue
				local SNAPSHOTNAME=$(echo "${line}" | awk '{print $2}')
				[[ -z "${SNAPSHOTNAME}" ]] && continue
				local SNAPSHOTDESCRIPTION=$(echo "${line}" | awk '{print $3}')

				local NEW_SNAPSHOT_NAME
				read -e -r -p "Enter new snapshot name (default: renamed-${VMID}-snap-'date'): " NEW_SNAPSHOT_NAME < /dev/tty
				NEW_SNAPSHOT_NAME=${NEW_SNAPSHOT_NAME:-"renamed-${VMID}-snap-$(date '+%Y%m%d%H%M%S')"}
		
				log_debug "function: ${FUNCNAME[0]}, new snapshot name is ${NEW_SNAPSHOT_NAME}"
		
				read -e -r -p \
					"Enter a renamed snapshot description for the VM ${VMID} (default: renamed-${VMID}-snap-'date'): " \
					NEW_SNAPSHOT_DESCRIPTION < /dev/tty
				[[ -z "${NEW_SNAPSHOT_DESCRIPTION}" ]] && local NEW_SNAPSHOT_DESCRIPTION="renamed-${VMID}-snap-$(date '+%Y%m%d%H%M%S')"
		
				log_debug "function: ${FUNCNAME[0]}, renamed snapshot description is ${NEW_SNAPSHOT_DESCRIPTION}"

				local RENAMEVMSNAPSHOT_XML
				RENAMEVMSNAPSHOT_XML=$(
					cat <<- XML
						<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:vim25">
							<soapenv:Body>
								<RenameSnapshot xmlns="urn:vim25">
									<_this type="VirtualMachineSnapshot">${SNAPSHOTID}</_this>
									<name>${NEW_SNAPSHOT_NAME}</name>
									<description>${NEW_SNAPSHOT_DESCRIPTION}</description>
								</RenameSnapshot>
							</soapenv:Body>
						</soapenv:Envelope>				
					XML
				)
		
				log_debug "function: ${FUNCNAME[0]}, renaming the vm's with VMID ${VMID} snapshot ${SNAPSHOTID}"

				RESPONSE=$(
					curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_vms_snapshot_rename" -X POST \
						-H "Content-Type: text/xml; charset=UTF-8" \
						-H "SOAPAction: \"urn:vim25/8.0\"" \
						-d "${RENAMEVMSNAPSHOT_XML}" \
						-b "${COOKIE_FILE}" \
						"https://${ESXI_HOSTNAME}/sdk" \
						2>&1
				)
	
				log_debug "function: ${FUNCNAME[0]}, RESPONSE=${RESPONSE}"
				log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_snapshot_rename")"

				if [[ "${RESPONSE}" == "200" ]]
				then
					log_debug "function: ${FUNCNAME[0]}, snapshot ${SNAPSHOTID} has been renamed successfully"
		
					local TASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' "${BASHAPP_TMPDIR}/cmd_vms_snapshot_rename")
		
					if [[ -n "${TASKID}" ]]
					then
						log_debug "function: ${FUNCNAME[0]}, renaming vm snapshot task created: ${TASKID}"
		        
						if cmd_tasks_monitor "${TASKID}" 60 true "renaming vm ${VMID} snapshot ${SNAPSHOTID}"
						then
							log_debug "function: ${FUNCNAME[0]}, ✓ the snapshot ${SNAPSHOTID} of the vm with VMID ${VMID} has been renamed successfully"
						else
							log_error "function: ${FUNCNAME[0]}, ✗ has failed to rename the snapshot ${SNAPSHOTID} of the vm with vmid=${VMID}"
						fi
		
					else
						log_error "function: ${FUNCNAME[0]}, no TASK ID returned"
					fi

				else
					log_error "function: ${FUNCNAME[0]}, has failed to rename the snapshot ${SNAPSHOTID}"
				fi
				
			done <<< "${SNAPSHOTS_SELECTED}"

		else
			log_error "function: ${FUNCNAME[0]}, ✗ has failed to list the vm's with vmid=${VMID} snapshots (HTTP CODE ${HTTP_CODE})"
			log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_snapshot_rename") (HTTP CODE ${HTTP_CODE})"
		fi

	done <<< "${VMS_SELECTED}"

	# delay to show results
	sleep 2

}

# vms delete command handler
cmd_vms_delete() {

	log_debug "${FUNCNAME[0]} is called"

	local LISTVMS_XML
	LISTVMS_XML=$(
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
								<type>VirtualMachine</type>
								<pathSet>name</pathSet>
								<pathSet>runtime.powerState</pathSet>
								<pathSet>config.hardware.numCPU</pathSet>
								<pathSet>config.hardware.memoryMB</pathSet>
							</propSet>
							<objectSet>
								<obj type="Folder">ha-folder-root</obj>
								<selectSet xsi:type="TraversalSpec">
									<name>traverseFolders</name>
									<type>Folder</type>
									<path>childEntity</path>
									<skip>false</skip>
									<selectSet>
										<name>traverseFolders</name>
									</selectSet>
									<selectSet xsi:type="TraversalSpec">
										<name>traverseDatacenter</name>
										<type>Datacenter</type>
										<path>vmFolder</path>
										<skip>false</skip>
										<selectSet>
											<name>traverseFolders</name>
										</selectSet>
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
	
	local RESPONSE
	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LISTVMS_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
	
	VMS_SELECTED=$(
		{	
			echo -e "VMID\tNAME\tSTATUS\tCPU\tRAM"
			echo "${RESPONSE}" | xmllint --xpath "//objects" - 2>/dev/null | sed 's/<\/objects>/<\/objects>\n/g' | \
			while read -r vm_block
			do
		    
			    [[ -z "${vm_block}" ]] && continue
			
			    VMID=$(echo "${vm_block}" | xmllint --xpath "string(//obj)" - 2>/dev/null)
			    NAME=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='name']/val)" - 2>/dev/null)
			    STATUS=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='runtime.powerState']/val)" - 2>/dev/null)
			    CPU=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.numCPU']/val)" - 2>/dev/null)
			    RAM=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.memoryMB']/val)" - 2>/dev/null)
			
			    echo -e "${VMID}\t${NAME}\t${STATUS}\t${CPU}\t${RAM}MB"
		
			done
		} | column -t \
		| fzf --cycle \
			  --border=rounded \
			  --border-label=" ESXi host's '${ESXI_HOSTNAME}' vms " \
			  --preview-window=right:50% \
			  --preview "cmd_vms_info {} ${ESXI_HOSTNAME}" \
			  --preview-window=hidden --bind 'ctrl-p:toggle-preview' \
			  --bind 'ctrl-a:select-all' \
			  --bind 'ctrl-d:deselect-all'  \
			  --bind 'ctrl-b:become(exit 2)' \
			  --header-lines=1 \
			  --header "Select vms to delete | ctrl-p: (un)toggle vm's info view | ctrl-a/d: select/deselect all vms" \
			  --layout reverse -m
	)

	local fzf_exit_code=$?
	[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
	[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
	[[ -z "${VMS_SELECTED}" ]] && return

	while IFS= read -r line
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

		local VMID=$(echo "${line}" | awk '{print $1}')
		[[ -z "${VMID}" ]] && continue

        local CONFIRM
        read -e -r -p "Proceed with deleting the vm ${VMID}? (yes/no): " CONFIRM < /dev/tty
        CONFIRM=${CONFIRM^^}
        [[ "${CONFIRM}" != "YES" ]] && { log_debug "function: ${FUNCNAME[0]}, vm deletion aborted by user. skipping ..."; continue; }

		log_debug "function: ${FUNCNAME[0]}, deleting the vm ${VMID}"

		local DELETEVM_XML
		DELETEVM_XML=$(
			cat <<- XML
				<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:vim25">
					<soapenv:Body>
						<Destroy_Task xmlns="urn:vim25">
							<_this type="VirtualMachine">${VMID}</_this>
						</Destroy_Task>
					</soapenv:Body>
				</soapenv:Envelope>
			XML
		)

		local HTTP_CODE
		HTTP_CODE=$(
			curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_vms_delete" -X POST \
				-H "Content-Type: text/xml; charset=UTF-8" \
				-H "SOAPAction: \"urn:vim25/8.0\"" \
				-d "${DELETEVM_XML}" \
				-b "${COOKIE_FILE}" \
				"https://${ESXI_HOSTNAME}/sdk" \
				2>&1
		)

		if [[ "${HTTP_CODE}" == "200" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, ✓ deleting the vm with vmid=${VMID} is successful (HTTP CODE ${HTTP_CODE})"
			log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_delete")"

			local TASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' "${BASHAPP_TMPDIR}/cmd_vms_delete")

			if [[ -n "${TASKID}" ]]
			then
				log_debug "function: ${FUNCNAME[0]}, deleting vm task created: ${TASKID}"
        
				if cmd_tasks_monitor "${TASKID}" 300 true "deleting vm ${VMID}"
				then
					log_debug "function: ${FUNCNAME[0]}, ✓ vm with VMID ${VMID} has been deleted successfully"
				else
					log_error "function: ${FUNCNAME[0]}, ✗ has failed to delete the vm with vmid=${VMID}"
				fi

			else
				log_error "function: ${FUNCNAME[0]}, no TASK ID returned"
			fi

		else
			log_error "function: ${FUNCNAME[0]}, ✗ has failed to delete the vm with vmid=${VMID} (HTTP CODE ${HTTP_CODE})"
			log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_delete") (HTTP CODE ${HTTP_CODE})"
		fi

	done <<< "${VMS_SELECTED}"

	# delay to show results
	sleep 2

}

# vms register command handler
cmd_vms_register() {

	# step 1: list and select datastore to browse
	# step 2: get datastore browser moref
	# step 3: main browser loop

	log_debug "${FUNCNAME[0]} is called"

	# step 1: list and select datastore to browse
	local LISTDATASTORES_XML
	LISTDATASTORES_XML=$(
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
								<type>Datastore</type>
								<pathSet>name</pathSet>
								<pathSet>summary.capacity</pathSet>
								<pathSet>summary.freeSpace</pathSet>
								<pathSet>summary.type</pathSet>
								<pathSet>summary.accessible</pathSet>
							</propSet>
							<objectSet>
								<obj type="Datacenter">ha-datacenter</obj>
								<selectSet xsi:type="TraversalSpec">
									<name>traverseDatacenter</name>
									<type>Datacenter</type>
									<path>datastoreFolder</path>
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
	
	local RESPONSE
	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LISTDATASTORES_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
	
	log_debug "function: ${FUNCNAME[0]}, RESPONSE for the datastores list is: \n ${RESPONSE}"

	local DSSELECTED
	DSSELECTED=$(
		{
			echo -e "DATASTOREID\tNAME\tCAPACITY\tFREESPACE\tTYPE\tACCESSIBLE"
			echo "${RESPONSE}" | xmllint --xpath "//objects" - 2>/dev/null | sed 's/<\/objects>/<\/objects>\n/g' | \
			while read -r line
			do
		    
		    [[ -z "${line}" ]] && continue
		
		    DATASTOREID=$(echo "${line}" | xmllint --xpath "string(//obj)" - 2>/dev/null)
		    NAME=$(echo "${line}" | xmllint --xpath "string(//propSet[name='name']/val)" - 2>/dev/null)
		    CAPACITY=$(echo "${line}" | xmllint --xpath "string(//propSet[name='summary.capacity']/val)" - 2>/dev/null)
		    FREESPACE=$(echo "${line}" | xmllint --xpath "string(//propSet[name='summary.freeSpace']/val)" - 2>/dev/null)
		    TYPE=$(echo "${line}" | xmllint --xpath "string(//propSet[name='summary.type']/val)" - 2>/dev/null)
		    ACCESSIBLE=$(echo "${line}" | xmllint --xpath "string(//propSet[name='summary.accessible']/val)" - 2>/dev/null)
		
		    echo -e "${DATASTOREID}\t${NAME}\t$((CAPACITY/1073741824))GB\t$((FREESPACE/1073741824))GB\t${TYPE}\t${ACCESSIBLE}"
		
			done
		} | column -t -s $'\t' -o $'\t' | \
		fzf --cycle \
	              --border=rounded \
	              --border-label=" ESXi host's '${ESXI_HOSTNAME}' datastores " \
	              --preview-window=right:50% \
	              --preview "cmd_datastores_info {} ${ESXI_HOSTNAME}" \
	              --preview-window=hidden --bind 'ctrl-p:toggle-preview' \
	              --bind 'ctrl-b:become(exit 2)' \
	              --header-lines=1 \
	              --header "Select datastore to browse to the vm's folder to register | ctrl-p: (un)toggle datastore's info view" \
	              --layout reverse
	)

	local fzf_exit_code=$?
	[[ "${fzf_exit_code}" -eq 130 ]] && return
	[[ "${fzf_exit_code}" -eq 2 ]] && return
	[[ -z "${DSSELECTED}" ]] && return

	local DATASTOREID DATASTORENAME
	DATASTOREID=$(echo "${DSSELECTED}"   | cut -f1 | xargs)
	DATASTORENAME=$(echo "${DSSELECTED}" | cut -f2 | xargs)

	log_debug "function: ${FUNCNAME[0]}, DATASTOREID=${DATASTOREID}"
	log_debug "function: ${FUNCNAME[0]}, DATASTORENAME=${DATASTORENAME}"

	# step 2: get datastore browser moref
	local GETBROWSER_XML
	GETBROWSER_XML=$(
		cat <<- XML
			<soapenv:Envelope
				xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
				xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
				<soapenv:Body>
					<RetrievePropertiesEx xmlns="urn:vim25">
						<_this type="PropertyCollector">ha-property-collector</_this>
						<specSet>
							<propSet>
								<type>Datastore</type>
								<pathSet>browser</pathSet>
							</propSet>
							<objectSet>
								<obj type="Datastore">${DATASTOREID}</obj>
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
			-d "${GETBROWSER_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)
	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')

	local BROWSER_MOREF
	BROWSER_MOREF=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='browser']/val)" - 2>/dev/null)

	[[ -z "${BROWSER_MOREF}" ]] && {
		log_error "function: ${FUNCNAME[0]}, failed to get browser MoRef for ${DATASTORENAME}"
		return 1
	}

	log_debug "function: ${FUNCNAME[0]}, BROWSER_MOREF=${BROWSER_MOREF}"

	# step 3: main browser loop
	local CURRENT_PATH="[${DATASTORENAME}]"

	while true
	do
		# search current path
		local SEARCHDS_XML
		SEARCHDS_XML=$(
			cat <<- XML
				<soapenv:Envelope
					xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
					xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
					<soapenv:Body>
						<SearchDatastore_Task xmlns="urn:vim25">
							<_this type="HostDatastoreBrowser">${BROWSER_MOREF}</_this>
							<datastorePath>${CURRENT_PATH}</datastorePath>
							<searchSpec>
								<details>
									<fileType>true</fileType>
									<fileSize>true</fileSize>
									<modification>true</modification>
									<fileOwner>true</fileOwner>
								</details>
								<sortFoldersFirst>true</sortFoldersFirst>
							</searchSpec>
						</SearchDatastore_Task>
					</soapenv:Body>
				</soapenv:Envelope>
			XML
		)

		RESPONSE=$(
			curl ${CURL_OPTS} ${CACERT} -X POST \
				-H "Content-Type: text/xml; charset=UTF-8" \
				-H "SOAPAction: \"urn:vim25/8.0\"" \
				-d "${SEARCHDS_XML}" \
				-b "${COOKIE_FILE}" \
				"https://${ESXI_HOSTNAME}/sdk" \
				2>&1
		)

		RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')

		log_debug "function: ${FUNCNAME[0]}, RESPONSE=${RESPONSE}"

		local SEARCHTASKID
		SEARCHTASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' <<< "${RESPONSE}")

		log_debug "function: ${FUNCNAME[0]}, SEARCHTASKID=${SEARCHTASKID}"

		# poll until complete
		local TASK_STATE=""
		while [[ "${TASK_STATE}" != "success" ]]
		do
			local TASKPOLL_XML
			TASKPOLL_XML=$(
				cat <<- XML
					<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
						<soapenv:Body>
							<RetrievePropertiesEx xmlns="urn:vim25">
								<_this type="PropertyCollector">ha-property-collector</_this>
								<specSet>
									<propSet>
										<type>Task</type>
										<pathSet>info.state</pathSet>
										<pathSet>info.result</pathSet>
									</propSet>
									<objectSet>
										<obj type="Task">${SEARCHTASKID}</obj>
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
					-d "${TASKPOLL_XML}" \
					-b "${COOKIE_FILE}" \
					"https://${ESXI_HOSTNAME}/sdk" \
					2>&1
			)
			RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi://g')

			log_debug "function: ${FUNCNAME[0]}, RESPONSE=${RESPONSE}"

			TASK_STATE=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='info.state']/val)" - 2>/dev/null)
		done

		# parse results into listing file
		local RESULTS_XML
		RESULTS_XML=$(echo "${RESPONSE}" | xmllint --xpath "//propSet[name='info.result']" - 2>/dev/null)

		log_debug "function: ${FUNCNAME[0]}, RESULTS_XML=${RESULTS_XML}"

		local LISTING_FILE="${BASHAPP_TMPDIR}/cmd_datastores_browse_listing"
		{
			echo -e "TYPE\tNAME\tSIZE\tMODIFIED"
			# current and parent directory entries
			echo -e "📁\t.\t-\t-"
			[[ "${CURRENT_PATH}" != "[${DATASTORENAME}]" ]] && echo -e "📁\t..\t-\t-"

			local FILE_COUNT
			FILE_COUNT=$(echo "${RESULTS_XML}" | xmllint --xpath "count(//file)" - 2>/dev/null)
			
			local i
			for (( i=1; i<=FILE_COUNT; i++ ))
			do
				local FTYPE FNAME FSIZE FMOD
				FTYPE=$(echo "${RESULTS_XML}" | xmllint --xpath "string(//file[${i}]/@type)" - 2>/dev/null)
				FNAME=$(echo "${RESULTS_XML}" | xmllint --xpath "string(//file[${i}]/path)" - 2>/dev/null)
				FSIZE=$(echo "${RESULTS_XML}" | xmllint --xpath "string(//file[${i}]/fileSize)" - 2>/dev/null)
				FMOD=$(echo "${RESULTS_XML}" | xmllint --xpath "string(//file[${i}]/modification)" - 2>/dev/null)
				[[ -z "${FNAME}" ]] && continue

				local FSIZE_HR
				if [[ "${FSIZE}" -ge 1073741824 ]]; then
					FSIZE_HR="$((FSIZE/1073741824))GB"
				elif [[ "${FSIZE}" -ge 1048576 ]]; then
					FSIZE_HR="$((FSIZE/1048576))MB"
				elif [[ "${FSIZE}" -ge 1024 ]]; then
					FSIZE_HR="$((FSIZE/1024))KB"
				else
					FSIZE_HR="${FSIZE}B"
				fi

				if [[ "${FTYPE}" == *"Folder"* ]]
				then
					echo -e "📁\t${FNAME}\t${FSIZE_HR}\t${FMOD}"
				else
					echo -e "📄\t${FNAME}\t${FSIZE_HR}\t${FMOD}"
				fi
			done

		} | column -t -s $'\t' -o $'\t' > "${LISTING_FILE}"

		# files/folders actions using fzf and its bind
		local SELECTED
		SELECTED=$(
			cat "${LISTING_FILE}" | \
			fzf --cycle \
				--border=rounded \
				--border-label=" ${CURRENT_PATH} " \
				--header-lines=1 \
				--header "Enter: select the vm's vmx file for registering | ctrl-u: go up | ctrl-q or esc: quit datastore browsing" \
				--layout reverse \
				--expect=ctrl-u,ctrl-q,esc,enter
		)

		local FZF_KEY FZF_LINE
		FZF_KEY=$(echo "${SELECTED}" | head -1)
		FZF_LINE=$(echo "${SELECTED}" | tail -1)

		local SELECTED_NAME SELECTED_TYPE
		SELECTED_NAME=$(echo "${FZF_LINE}" | cut -f2 | xargs)
		SELECTED_TYPE=$(echo "${FZF_LINE}" | cut -f1 | xargs)

		# fzf actions handler block
		case "${FZF_KEY}" in

			ctrl-q|esc)

				log_debug "function: ${FUNCNAME[0]}, ctrl-q pressed"				

				break
				;;

			ctrl-u)

				log_debug "function: ${FUNCNAME[0]}, ctrl-u pressed"

				log_debug "function: ${FUNCNAME[0]}, CURRENT_PATH=${CURRENT_PATH}"

				if [[ "${CURRENT_PATH}" == */* ]]
				then
					# deeper level — strip last /component
					CURRENT_PATH="${CURRENT_PATH%/*}"
				else
					# one level down from root — go back to root
					CURRENT_PATH="[${DATASTORENAME}]"
				fi
				continue
				;;

			enter)

				log_debug "function: ${FUNCNAME[0]}, enter pressed"
			
				log_debug "function: ${FUNCNAME[0]}, CURRENT_PATH=${CURRENT_PATH}"

				[[ -z "${SELECTED_NAME}" ]] && continue

				if [[ "${SELECTED_NAME}" == ".." ]]
				then
					if [[ "${CURRENT_PATH}" == */* ]]
					then
						CURRENT_PATH="${CURRENT_PATH%/*}"
					else
						CURRENT_PATH="[${DATASTORENAME}]"
					fi
				elif [[ "${SELECTED_NAME}" == "." ]]
				then
					# stay — do nothing
					: 
				elif [[ "${SELECTED_TYPE}" == "📁" ]]
				then
					if [[ "${CURRENT_PATH}" == "[${DATASTORENAME}]" ]]
					then
						CURRENT_PATH="[${DATASTORENAME}] ${SELECTED_NAME}"
					else
						CURRENT_PATH="${CURRENT_PATH}/${SELECTED_NAME}"
					fi
				elif [[ "${SELECTED_TYPE}" == "📄" && "${SELECTED_NAME}" == *.vmx ]]
				then
					local VMX_PATH
					if [[ "${CURRENT_PATH}" == "[${DATASTORENAME}]" ]]
					then
						VMX_PATH="[${DATASTORENAME}] ${SELECTED_NAME}"
					else
						VMX_PATH="${CURRENT_PATH}/${SELECTED_NAME}"
					fi

					log_debug "function: ${FUNCNAME[0]}, CURRENT_PATH=${CURRENT_PATH}"
					log_debug "function: ${FUNCNAME[0]}, VMX_PATH=${VMX_PATH}"

					local VMNAME VMNAME_DEFAULT
					VMNAME_DEFAULT=$(basename "${SELECTED_NAME}" .vmx)
					read -e -r -p "Enter a vm's name to register [${VMNAME_DEFAULT}]: " VMNAME
					[[ -z "${VMNAME}" ]] && VMNAME="${VMNAME_DEFAULT}"

					local REGISTERVM_XML
					REGISTERVM_XML=$(
						cat <<- XML
							<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:vim25">
								<soapenv:Body>
									<RegisterVM_Task xmlns="urn:vim25">
										<_this type="Folder">ha-folder-vm</_this>
										<path>${VMX_PATH}</path>
										<name>${VMNAME}</name>
										<asTemplate>false</asTemplate>
										<pool type="ResourcePool">ha-root-pool</pool>
									</RegisterVM_Task>
								</soapenv:Body>
							</soapenv:Envelope>
						XML
					)

					local HTTP_CODE
					HTTP_CODE=$(
						curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_vms_register" -X POST \
							-H "Content-Type: text/xml; charset=UTF-8" \
							-H "SOAPAction: \"urn:vim25/8.0\"" \
							-d "${REGISTERVM_XML}" \
							-b "${COOKIE_FILE}" \
							"https://${ESXI_HOSTNAME}/sdk" \
							2>&1
					)
	
					if [[ "${HTTP_CODE}" == "200" ]]
					then
						local TASKID
						TASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' "${BASHAPP_TMPDIR}/cmd_vms_register")
						[[ -z "${TASKID}" ]] && {
							log_error "function: ${FUNCNAME[0]}, ✗ no task ID returned for ${VMNAME}"
							return 1
						}
						cmd_tasks_monitor "${TASKID}" 60 true "registering ${VMNAME}"
						return	
					else
						log_error "function: ${FUNCNAME[0]}, ✗ has failed to register the vm ${VMNAME} (HTTP ${HTTP_CODE})"
						log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_register")"
						return 1
					fi

				fi
				continue
				;;

		esac

	done

	# delay to show results
	sleep 2

}

# vms unregister command handler
cmd_vms_unregister() {

	log_debug "${FUNCNAME[0]} is called"

	local LISTVMS_XML
	LISTVMS_XML=$(
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
								<type>VirtualMachine</type>
								<pathSet>name</pathSet>
								<pathSet>runtime.powerState</pathSet>
								<pathSet>config.hardware.numCPU</pathSet>
								<pathSet>config.hardware.memoryMB</pathSet>
							</propSet>
							<objectSet>
								<obj type="Folder">ha-folder-root</obj>
								<selectSet xsi:type="TraversalSpec">
									<name>traverseFolders</name>
									<type>Folder</type>
									<path>childEntity</path>
									<skip>false</skip>
									<selectSet>
										<name>traverseFolders</name>
									</selectSet>
									<selectSet xsi:type="TraversalSpec">
										<name>traverseDatacenter</name>
										<type>Datacenter</type>
										<path>vmFolder</path>
										<skip>false</skip>
										<selectSet>
											<name>traverseFolders</name>
										</selectSet>
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
	
	local RESPONSE
	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LISTVMS_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')

	local VMS_SELECTED	
	VMS_SELECTED=$(
		{	
			echo -e "VMID\tNAME\tSTATUS\tCPU\tRAM"
			echo "${RESPONSE}" | xmllint --xpath "//objects" - 2>/dev/null | sed 's/<\/objects>/<\/objects>\n/g' | \
			while read -r vm_block
			do
		    
			    [[ -z "${vm_block}" ]] && continue
			
			    VMID=$(echo "${vm_block}" | xmllint --xpath "string(//obj)" - 2>/dev/null)
			    NAME=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='name']/val)" - 2>/dev/null)
			    STATUS=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='runtime.powerState']/val)" - 2>/dev/null)
			    CPU=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.numCPU']/val)" - 2>/dev/null)
			    RAM=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.memoryMB']/val)" - 2>/dev/null)
			
			    echo -e "${VMID}\t${NAME}\t${STATUS}\t${CPU}\t${RAM}MB"
		
			done
		} | column -t \
		| fzf --cycle \
			  --border=rounded \
			  --border-label=" ESXi host's '${ESXI_HOSTNAME}' vms " \
			  --preview-window=right:50% \
			  --preview "cmd_vms_info {} ${ESXI_HOSTNAME}" \
			  --preview-window=hidden --bind 'ctrl-p:toggle-preview' \
			  --bind 'ctrl-a:select-all' \
			  --bind 'ctrl-d:deselect-all'  \
			  --bind 'ctrl-b:become(exit 2)' \
			  --header-lines=1 \
			  --header "Select vms to unregister | ctrl-p: (un)toggle vm's info view | ctrl-a/d: select/deselect all vms" \
			  --layout reverse -m
	)

	local fzf_exit_code=$?
	[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
	[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
	[[ -z "${VMS_SELECTED}" ]] && return

	while IFS= read -r line
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

		local VMID=$(echo "${line}" | awk '{print $1}')
		[[ -z "${VMID}" ]] && continue

		log_debug "function: ${FUNCNAME[0]}, unregistering the vm ${VMID}"

		local UNREGISTERVM_XML
		UNREGISTERVM_XML=$(
			cat <<- XML
				<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:vim25">
					<soapenv:Body>
						<UnregisterVM xmlns="urn:vim25">
							<_this type="VirtualMachine">${VMID}</_this>
						</UnregisterVM>
					</soapenv:Body>
				</soapenv:Envelope>
			XML
		)

		local HTTP_CODE
		HTTP_CODE=$(
			curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_vms_unregister" -X POST \
				-H "Content-Type: text/xml; charset=UTF-8" \
				-H "SOAPAction: \"urn:vim25/8.0\"" \
				-d "${UNREGISTERVM_XML}" \
				-b "${COOKIE_FILE}" \
				"https://${ESXI_HOSTNAME}/sdk" \
				2>&1
		)

		if [[ "${HTTP_CODE}" == "200" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, ✓ unregistering the vm with vmid=${VMID} is successful (HTTP CODE ${HTTP_CODE})"
			log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_unregister")"

			local TASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' "${BASHAPP_TMPDIR}/cmd_vms_unregister")

			if [[ -n "${TASKID}" ]]
			then
				log_debug "function: ${FUNCNAME[0]}, unregistering vm task created: ${TASKID}"
        
				if cmd_tasks_monitor "${TASKID}" 60 true "unregistering vm ${VMID}"
				then
					log_debug "function: ${FUNCNAME[0]}, ✓ vm with VMID ${VMID} has been unregistered successfully"
				else
					log_error "function: ${FUNCNAME[0]}, ✗ has failed to unregister the vm with vmid=${VMID}"
				fi

			else
				log_error "function: ${FUNCNAME[0]}, no TASK ID returned"
			fi

		else
			log_error "function: ${FUNCNAME[0]}, ✗ has failed to unregister the vm with vmid=${VMID} (HTTP CODE ${HTTP_CODE})"
			log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_unregister") (HTTP CODE ${HTTP_CODE})"
		fi

	done <<< "${VMS_SELECTED}"

	# delay to show results
	sleep 2

}

# vms rename command handler
cmd_vms_rename() {

	log_debug "${FUNCNAME[0]} is called"

	local LISTVMS_XML
	LISTVMS_XML=$(
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
								<type>VirtualMachine</type>
								<pathSet>name</pathSet>
								<pathSet>runtime.powerState</pathSet>
								<pathSet>config.hardware.numCPU</pathSet>
								<pathSet>config.hardware.memoryMB</pathSet>
							</propSet>
							<objectSet>
								<obj type="Folder">ha-folder-root</obj>
								<selectSet xsi:type="TraversalSpec">
									<name>traverseFolders</name>
									<type>Folder</type>
									<path>childEntity</path>
									<skip>false</skip>
									<selectSet>
										<name>traverseFolders</name>
									</selectSet>
									<selectSet xsi:type="TraversalSpec">
										<name>traverseDatacenter</name>
										<type>Datacenter</type>
										<path>vmFolder</path>
										<skip>false</skip>
										<selectSet>
											<name>traverseFolders</name>
										</selectSet>
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
	
	local RESPONSE
	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LISTVMS_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/ xsi:type="[^"]*"//g')
	
	local VMS_SELECTED
	VMS_SELECTED=$(
		{	
			echo -e "VMID\tNAME\tSTATUS\tCPU\tRAM"
			echo "${RESPONSE}" | xmllint --xpath "//objects" - 2>/dev/null | sed 's/<\/objects>/<\/objects>\n/g' | \
			while read -r vm_block
			do
		    
			    [[ -z "${vm_block}" ]] && continue
			
			    VMID=$(echo "${vm_block}" | xmllint --xpath "string(//obj)" - 2>/dev/null)
			    VMNAME=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='name']/val)" - 2>/dev/null)
			    STATUS=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='runtime.powerState']/val)" - 2>/dev/null)
			    CPU=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.numCPU']/val)" - 2>/dev/null)
			    RAM=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.memoryMB']/val)" - 2>/dev/null)
			
			    echo -e "${VMID}\t${VMNAME}\t${STATUS}\t${CPU}\t${RAM}MB"
		
			done
		} | column -t -s $'\t' -o $'\t' \
		| fzf --cycle \
			  --border=rounded \
			  --border-label=" ESXi host's '${ESXI_HOSTNAME}' vms " \
			  --preview-window=right:50% \
			  --preview "cmd_vms_info {} ${ESXI_HOSTNAME}" \
			  --preview-window=hidden --bind 'ctrl-p:toggle-preview' \
			  --bind 'ctrl-a:select-all' \
			  --bind 'ctrl-d:deselect-all'  \
			  --bind 'ctrl-b:become(exit 2)' \
			  --header-lines=1 \
			  --header "Select vms to rename | ctrl-p: (un)toggle vm's info view | ctrl-a/d: select/deselect all vms | ctrl-b: cancel" \
			  --layout reverse -m
	)

	local fzf_exit_code=$?
	[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
	[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
	[[ -z "${VMS_SELECTED}" ]] && return

	while IFS= read -r line
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

		local VMID VMNAME
		VMID=$(echo "${line}"   | cut -f1 | xargs)
		VMNAME=$(echo "${line}" | cut -f2 | xargs)
		[[ -z "${VMID}" ]] && continue

		log_debug "function: ${FUNCNAME[0]}, renaming the vm ${VMNAME} with vmid ${VMID}"

		local NEW_VMNAME
		read -e -r -p "Enter new name for the vm ${VMNAME} (Press Enter to skip renaming): " NEW_VMNAME < /dev/tty
		NEW_VMNAME=$(echo "${NEW_VMNAME}" | xargs)
		[[ -z "${NEW_VMNAME}" ]] && { log_error "function: ${FUNCNAME[0]}, no name entered for VM '${VMNAME}', skipping ..."; continue; }
		log_debug "function: ${FUNCNAME[0]}, NEW_VMNAME=${NEW_VMNAME}"

		local RENAMEXML
		RENAMEXML=$(
			cat <<- XML
				<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
					<soapenv:Body>
						<Rename_Task xmlns="urn:vim25">
							<_this type="VirtualMachine">${VMID}</_this>
							<newName>${NEW_VMNAME}</newName>
						</Rename_Task>
					</soapenv:Body>
				</soapenv:Envelope>
			XML
		)

		local HTTP_CODE
		HTTP_CODE=$(
			curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_vms_rename" -X POST \
				-H "Content-Type: text/xml; charset=UTF-8" \
				-H "SOAPAction: \"urn:vim25/8.0\"" \
				-d "${RENAMEXML}" \
				-b "${COOKIE_FILE}" \
				"https://${ESXI_HOSTNAME}/sdk" \
				2>&1
		)

		if [[ "${HTTP_CODE}" == "200" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, ✓ renaming for the vm ${VMNAME} with vmid=${VMID} is successful (HTTP CODE ${HTTP_CODE})"
			log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_rename")"

			local TASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' "${BASHAPP_TMPDIR}/cmd_vms_rename")

			if [[ -n "${TASKID}" ]]
			then
				log_debug "function: ${FUNCNAME[0]}, renaming vm task created: ${TASKID}"
        
				if cmd_tasks_monitor "${TASKID}" 60 true "renaming the vm ${VMNAME} with vmid ${VMID}"
				then
					log_debug "function: ${FUNCNAME[0]}, ✓ vm ${VMNAME} with VMID ${VMID} has been renamed successfully to ${NEW_VMNAME}"
				else
					log_error "function: ${FUNCNAME[0]}, ✗ has failed to rename the vm ${VMNAME} with vmid ${VMID}"
				fi

			else
				log_error "function: ${FUNCNAME[0]}, no TASK ID returned"
			fi

		else
			log_error "function: ${FUNCNAME[0]}, ✗ has failed to rename the vm ${VMNAME} with vmid ${VMID} (HTTP CODE ${HTTP_CODE})"
			log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_rename") (HTTP CODE ${HTTP_CODE})"
		fi

	done <<< "${VMS_SELECTED}"

	# delay to show results
	sleep 2

}

# vms defragment command handler
cmd_vms_defragment() {

	log_debug "${FUNCNAME[0]} is called"

	local LISTVMS_XML
	LISTVMS_XML=$(
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
								<type>VirtualMachine</type>
								<pathSet>name</pathSet>
								<pathSet>runtime.powerState</pathSet>
								<pathSet>config.hardware.numCPU</pathSet>
								<pathSet>config.hardware.memoryMB</pathSet>
							</propSet>
							<objectSet>
								<obj type="Folder">ha-folder-root</obj>
								<selectSet xsi:type="TraversalSpec">
									<name>traverseFolders</name>
									<type>Folder</type>
									<path>childEntity</path>
									<skip>false</skip>
									<selectSet>
										<name>traverseFolders</name>
									</selectSet>
									<selectSet xsi:type="TraversalSpec">
										<name>traverseDatacenter</name>
										<type>Datacenter</type>
										<path>vmFolder</path>
										<skip>false</skip>
										<selectSet>
											<name>traverseFolders</name>
										</selectSet>
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
	
	local RESPONSE
	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LISTVMS_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')

	local VMS_SELECTED	
	VMS_SELECTED=$(
		{	
			echo -e "VMID\tNAME\tSTATUS\tCPU\tRAM"
			echo "${RESPONSE}" | xmllint --xpath "//objects" - 2>/dev/null | sed 's/<\/objects>/<\/objects>\n/g' | \
			while read -r vm_block
			do
		    
			    [[ -z "${vm_block}" ]] && continue
			
			    VMID=$(echo "${vm_block}" | xmllint --xpath "string(//obj)" - 2>/dev/null)
			    NAME=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='name']/val)" - 2>/dev/null)
			    STATUS=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='runtime.powerState']/val)" - 2>/dev/null)
			    CPU=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.numCPU']/val)" - 2>/dev/null)
			    RAM=$(echo "${vm_block}" | xmllint --xpath "string(//propSet[name='config.hardware.memoryMB']/val)" - 2>/dev/null)
			
			    echo -e "${VMID}\t${NAME}\t${STATUS}\t${CPU}\t${RAM}MB"
		
			done
		} | column -t \
		| fzf --cycle \
			  --border=rounded \
			  --border-label=" ESXi host's '${ESXI_HOSTNAME}' vms " \
			  --preview-window=right:50% \
			  --preview "cmd_vms_info {} ${ESXI_HOSTNAME}" \
			  --preview-window=hidden --bind 'ctrl-p:toggle-preview' \
			  --bind 'ctrl-a:select-all' \
			  --bind 'ctrl-d:deselect-all'  \
			  --bind 'ctrl-b:become(exit 2)' \
			  --header-lines=1 \
			  --header "Select vms to defragment their disks | ctrl-p: (un)toggle vm's info view | ctrl-a/d: select/deselect all vms" \
			  --layout reverse -m
	)

	local fzf_exit_code=$?
	[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
	[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
	[[ -z "${VMS_SELECTED}" ]] && return

	while IFS= read -r line
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

		local VMID=$(echo "${line}" | awk '{print $1}')
		[[ -z "${VMID}" ]] && continue

		log_debug "function: ${FUNCNAME[0]}, defragmenting the vm's ${VMID} disks"

		local DEFRAGMENTVM_XML
		DEFRAGMENTVM_XML=$(
			cat <<- XML
				<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:vim25">
					<soapenv:Body>
						<DefragmentAllDisks xmlns="urn:vim25">
							<_this type="VirtualMachine">${VMID}</_this>
						</DefragmentAllDisks>
					</soapenv:Body>
				</soapenv:Envelope>
			XML
		)

		local HTTP_CODE
		HTTP_CODE=$(
			curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_vms_defragment" -X POST \
				-H "Content-Type: text/xml; charset=UTF-8" \
				-H "SOAPAction: \"urn:vim25/8.0\"" \
				-d "${DEFRAGMENTVM_XML}" \
				-b "${COOKIE_FILE}" \
				"https://${ESXI_HOSTNAME}/sdk" \
				2>&1
		)

		if [[ "${HTTP_CODE}" == "200" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, ✓ defragmenting the vm with vmid=${VMID} disks is successful (HTTP CODE ${HTTP_CODE})"
			log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_defragment")"

			local TASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' "${BASHAPP_TMPDIR}/cmd_vms_defragment")

			if [[ -n "${TASKID}" ]]
			then
				log_debug "function: ${FUNCNAME[0]}, defragmenting vm's disks task created: ${TASKID}"
        
				if cmd_tasks_monitor "${TASKID}" 300 true "defragmenting vm's ${VMID} disks"
				then
					log_debug "function: ${FUNCNAME[0]}, ✓ vm with VMID ${VMID} disks have been defragmented successfully"
				else
					log_error "function: ${FUNCNAME[0]}, ✗ has failed to defragment the vm with vmid=${VMID} disks"
				fi

			else
				log_error "function: ${FUNCNAME[0]}, no TASK ID returned"
			fi

		else
			log_error "function: ${FUNCNAME[0]}, ✗ has failed to defragment the vm with vmid=${VMID} disks (HTTP CODE ${HTTP_CODE})"
			log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_vms_defragment") (HTTP CODE ${HTTP_CODE})"
		fi

	done <<< "${VMS_SELECTED}"

	# delay to show results
	sleep 2

}

# vms unknown command handler
cmd_vms_unknown() {

	log_debug "${FUNCNAME[0]} is called"

	local ACTION="$1"

	log_error "function: ${FUNCNAME[0]}, unknown command '${ACTION}' for vms action."

	echo "Unknown vms command: ${ACTION}"
	echo "Use '${BASHAPP_NAME}' help or/and documentation for the correct usage information"

	# delay to show results
	sleep 2

}
