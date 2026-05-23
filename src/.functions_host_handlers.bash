# host commands handlers functions

# host manage command handler
cmd_host_manage() {

	log_debug "${FUNCNAME[0]} is called"

	local ACTION
	ACTION=$(
		fzf --cycle \
			--border=rounded \
			--border-label=" ESXi host's '${ESXI_HOSTNAME}' actions " \
            --preview-window=right:50% \
            --preview "cmd_host_action_help {}" \
            --preview-window=hidden --bind 'ctrl-h:toggle-preview' \
			--header "Choose please an action for this ESXi host | ctrl-h: help for an action" \
			--layout reverse \
			<<- ACTIONS
				maintenance
				shutdown
				reboot
				services
			ACTIONS
	)

	[[ -z "${ACTION}" ]] && return

	case "${ACTION}" in
		maintenance)	cmd_host_maintenance		;;
		shutdown)		cmd_host_shutdown			;;
		reboot)			cmd_host_reboot				;;
		services)		cmd_host_services_manage	;;
		*)				cmd_host_unknown "${ACTION}" ;; 
	esac

}

# host action help handler
cmd_host_action_help() {

	log_debug "${FUNCNAME[0]} is called"

	local ACTION
	ACTION="$1"

	[[ -z "${ACTION}" ]] && return
	
	case "${ACTION}" in
		maintenance)
			echo "Enters or exits the host maintenance mode"
			;;
		shutdown)
			echo "Shuts the host down checking"
			echo "if in maintenance mode already or not"
			;;
		reboot)
			echo "Reboots the host"
			;;
		services)
			echo "Shows the host's services management menu"
			;;
		*)
			echo "Unknown action. No help available."
			;;
	esac

}
export -f cmd_host_action_help

# host maintenance command handler
cmd_host_maintenance() {

	log_debug "${FUNCNAME[0]} is called"

	# a standalone ESXi host MOR
	# always static and set to the below value
	HOST_MOR="ha-host"

	local GETHOSTINFO_XML 
	GETHOSTINFO_XML=$(
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
								<type>HostSystem</type>
								<pathSet>runtime.inMaintenanceMode</pathSet>
							</propSet>
							<objectSet>
								<obj type="HostSystem">${HOST_MOR}</obj>
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
			-d "${GETHOSTINFO_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')

	log_debug "function: ${FUNCNAME[0]}, the response is: ${RESPONSE}"

	INMAINTENANCE=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='runtime.inMaintenanceMode']/val)" - 2>/dev/null)

	log_debug "function: ${FUNCNAME[0]}, INMAINTENANCE is ${INMAINTENANCE}"

	if [[ "${INMAINTENANCE}" == "true" ]]
	then

		read -e -r -p "Exit maintenance mode? (YES/NO): " confirm < /dev/tty
		# turning yes, Yes, yEs etc to YES
		# the same with no, No --> NO
		confirm=${confirm^^}
		
		if [[ "${confirm}" == "YES" ]]
		then

			local EXITMAINTENANCE_XML 
			EXITMAINTENANCE_XML=$(
				cat <<- XML
					<soapenv:Envelope 
						xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" 
						xmlns:urn="urn:vim25">
						<soapenv:Body>
							<ExitMaintenanceMode_Task xmlns="urn:vim25">
								<_this type="HostSystem">ha-host</_this>
								<timeout>0</timeout>
							</ExitMaintenanceMode_Task>
						</soapenv:Body>
					</soapenv:Envelope>
				XML
			)

			RESPONSE=$(
				curl ${CURL_OPTS} ${CACERT} -X POST \
					-H "Content-Type: text/xml; charset=UTF-8" \
					-H "SOAPAction: \"urn:vim25/8.0\"" \
					-d "${EXITMAINTENANCE_XML}" \
					-b "${COOKIE_FILE}" \
					"https://${ESXI_HOSTNAME}/sdk" \
					2>&1
			)

			log_debug "function: ${FUNCNAME[0]}, exiting maintenance mode status:\n${RESPONSE}"

		elif [[ "${confirm}" == "NO" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, skipping exiting maintenance mode"
		else
			log_error "function: ${FUNCNAME[0]}, invalid answer, has to be YES or NO"
		fi

	elif [[ "${INMAINTENANCE}" == "false" ]]
	then

		read -e -r -p "Enter maintenance mode? (YES/NO): " confirm < /dev/tty
		# turning yes, Yes, yEs etc to YES
		# the same with no, No --> NO
		confirm=${confirm^^}
		
		if [[ "${confirm}" == "YES" ]]
		then

			local ENTERMAINTENANCE_XML
			ENTERMAINTENANCE_XML=$(
				cat <<- XML
					<soapenv:Envelope 
						xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" 
						xmlns:urn="urn:vim25">
						<soapenv:Body>
							<EnterMaintenanceMode_Task xmlns="urn:vim25">
								<_this type="HostSystem">ha-host</_this>
								<timeout>0</timeout>
								<evacuatePoweredOffVms>false</evacuatePoweredOffVms>
							</EnterMaintenanceMode_Task>
						</soapenv:Body>
					</soapenv:Envelope>
				XML
			)
			
			RESPONSE=$(
				curl ${CURL_OPTS} ${CACERT} -X POST \
					-H "Content-Type: text/xml; charset=UTF-8" \
					-H "SOAPAction: \"urn:vim25/8.0\"" \
					-d "${ENTERMAINTENANCE_XML}" \
					-b "${COOKIE_FILE}" \
					"https://${ESXI_HOSTNAME}/sdk" \
					2>&1
			)

			log_debug "function: ${FUNCNAME[0]}, entering maintenance mode status:\n${RESPONSE}"

		elif [[ "${confirm}" == "NO" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, skipping entering maintenance mode"
		else
			log_error "function: ${FUNCNAME[0]}, invalid answer, has to be YES or NO"
		fi

	else
		log_error "function: ${FUNCNAME[0]}, the ESXi host maintenance mode cannot be determined"
	fi

}

# host shutdown command handler
cmd_host_shutdown() {

	log_debug "${FUNCNAME[0]} is called"

	# a standalone ESXi host MOR
	# always static and set to the below value
	HOST_MOR="ha-host"

	local GETHOSTINFO_XML
	GETHOSTINFO_XML=$(
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
								<type>HostSystem</type>
								<pathSet>runtime.inMaintenanceMode</pathSet>
							</propSet>
							<objectSet>
								<obj type="HostSystem">${HOST_MOR}</obj>
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
			-d "${GETHOSTINFO_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')

	log_debug "function: ${FUNCNAME[0]}, the response is: ${RESPONSE}"

	INMAINTENANCE=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='runtime.inMaintenanceMode']/val)" - 2>/dev/null)

	log_debug "function: ${FUNCNAME[0]}, INMAINTENANCE is ${INMAINTENANCE}"

	if [[ "${INMAINTENANCE}" == "true" ]]
	then

		read -e -r -p "Shut down the host (it is already in maintenance mode)? (YES/NO): " confirm < /dev/tty
		# turning yes, Yes, yEs etc to YES
		# the same with no, No --> NO
		confirm=${confirm^^}
		
		if [[ "${confirm}" == "YES" ]]
		then

			local SHUTDOWN_XML 
			SHUTDOWN_XML=$(
				cat <<- XML
					<soapenv:Envelope 
						xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" 
						xmlns:urn="urn:vim25">
						<soapenv:Body>
							<ShutdownHost_Task xmlns="urn:vim25">
								<_this type="HostSystem">ha-host</_this>
								<force>false</force>
							</ShutdownHost_Task>
						</soapenv:Body>
					</soapenv:Envelope>
				XML
			)

			RESPONSE=$(
				curl ${CURL_OPTS} ${CACERT} -X POST \
					-H "Content-Type: text/xml; charset=UTF-8" \
					-H "SOAPAction: \"urn:vim25/8.0\"" \
					-d "${SHUTDOWN_XML}" \
					-b "${COOKIE_FILE}" \
					"https://${ESXI_HOSTNAME}/sdk" \
					2>&1
			)

			log_debug "function: ${FUNCNAME[0]}, shutdown task status:\n${RESPONSE}"

			echo "The host ${ESXI_HOSTNAME} is being shut down ..."

			# clean up and exit as there's nothing to do anymore
			# the host is shut down
			cleanup_and_exit

		elif [[ "${confirm}" == "NO" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, exit without shutting down the host"
		else
			log_error "function: ${FUNCNAME[0]}, invalid answer, has to be YES or NO"
		fi

	elif [[ "${INMAINTENANCE}" == "false" ]]
	then

		read -e -r -p "The host is NOT in Maintenance mode! Shut down anyway? (YES/NO): " confirm < /dev/tty
		# turning yes, Yes, yEs etc to YES
		# the same with no, No --> NO
		confirm=${confirm^^}
		
		if [[ "${confirm}" == "YES" ]]
		then

			local SHUTDOWN_XML
			SHUTDOWN_XML=$(
				cat <<- XML
					<soapenv:Envelope 
						xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" 
						xmlns:urn="urn:vim25">
						<soapenv:Body>
							<ShutdownHost_Task xmlns="urn:vim25">
								<_this type="HostSystem">ha-host</_this>
								<force>true</force>
							</ShutdownHost_Task>
						</soapenv:Body>
					</soapenv:Envelope>
				XML
			)

			RESPONSE=$(
				curl ${CURL_OPTS} ${CACERT} -X POST \
					-H "Content-Type: text/xml; charset=UTF-8" \
					-H "SOAPAction: \"urn:vim25/8.0\"" \
					-d "${SHUTDOWN_XML}" \
					-b "${COOKIE_FILE}" \
					"https://${ESXI_HOSTNAME}/sdk" \
					2>&1
			)

			log_debug "function: ${FUNCNAME[0]}, forceful shutdown task status:\n${RESPONSE}"

			echo "The host is being shut down forcefully ..."

			# clean up and exit as there's nothing to do anymore
			# the host is shut down
			cleanup_and_exit

		elif [[ "${confirm}" == "NO" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, exit without forcefully shutting down the host"
		else
			log_error "function: ${FUNCNAME[0]}, invalid answer, has to be YES or NO"
		fi

	else
		log_error "function: ${FUNCNAME[0]}, the ESXi host maintenance mode cannot be determined"
	fi

}

# host reboot command handler
cmd_host_reboot() {

	log_debug "${FUNCNAME[0]} is called"

	# a standalone ESXi host MOR
	# always static and set to the below value
	HOST_MOR="ha-host"

	local GETHOSTINFO_XML
	GETHOSTINFO_XML=$(
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
								<type>HostSystem</type>
								<pathSet>runtime.inMaintenanceMode</pathSet>
							</propSet>
							<objectSet>
								<obj type="HostSystem">${HOST_MOR}</obj>
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
			-d "${GETHOSTINFO_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')

	log_debug "function: ${FUNCNAME[0]}, the response is: ${RESPONSE}"

	INMAINTENANCE=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='runtime.inMaintenanceMode']/val)" - 2>/dev/null)

	log_debug "function: ${FUNCNAME[0]}, INMAINTENANCE is ${INMAINTENANCE}"

	if [[ "${INMAINTENANCE}" == "true" ]]
	then

		read -e -r -p "Reboot the host (it is already in maintenance mode)? (YES/NO): " confirm < /dev/tty
		# turning yes, Yes, yEs etc to YES
		# the same with no, No --> NO
		confirm=${confirm^^}
		
		if [[ "${confirm}" == "YES" ]]
		then

			local REBOOT_XML 
			REBOOT_XML=$(
				cat <<- XML
					<soapenv:Envelope 
						xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" 
						xmlns:urn="urn:vim25">
						<soapenv:Body>
							<RebootHost_Task xmlns="urn:vim25">
								<_this type="HostSystem">ha-host</_this>
								<force>false</force>
							</RebootHost_Task>
						</soapenv:Body>
					</soapenv:Envelope>
				XML
			)

			RESPONSE=$(
				curl ${CURL_OPTS} ${CACERT} -X POST \
					-H "Content-Type: text/xml; charset=UTF-8" \
					-H "SOAPAction: \"urn:vim25/8.0\"" \
					-d "${REBOOT_XML}" \
					-b "${COOKIE_FILE}" \
					"https://${ESXI_HOSTNAME}/sdk" \
					2>&1
			)

			log_debug "function: ${FUNCNAME[0]}, reboot task status:\n${RESPONSE}"

			echo "The host ${ESXI_HOSTNAME} is being rebooted ..."

			# clean up and exit as there's nothing to do anymore
			# the host is shut down
			cleanup_and_exit

		elif [[ "${confirm}" == "NO" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, exit without rebooting the host"
		else
			log_error "function: ${FUNCNAME[0]}, invalid answer, has to be YES or NO"
		fi

	elif [[ "${INMAINTENANCE}" == "false" ]]
	then

		read -e -r -p "The host is NOT in Maintenance mode! Reboot anyway? (YES/NO): " confirm < /dev/tty
		# turning yes, Yes, yEs etc to YES
		# the same with no, No --> NO
		confirm=${confirm^^}
		
		if [[ "${confirm}" == "YES" ]]
		then

			local REBOOT_XML
			REBOOT_XML=$(
				cat <<- XML
					<soapenv:Envelope 
						xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" 
						xmlns:urn="urn:vim25">
						<soapenv:Body>
							<RebootHost_Task xmlns="urn:vim25">
								<_this type="HostSystem">ha-host</_this>
								<force>true</force>
							</RebootHost_Task>
						</soapenv:Body>
					</soapenv:Envelope>
				XML
			)

			RESPONSE=$(
				curl ${CURL_OPTS} ${CACERT} -X POST \
					-H "Content-Type: text/xml; charset=UTF-8" \
					-H "SOAPAction: \"urn:vim25/8.0\"" \
					-d "${REBOOT_XML}" \
					-b "${COOKIE_FILE}" \
					"https://${ESXI_HOSTNAME}/sdk" \
					2>&1
			)

			log_debug "function: ${FUNCNAME[0]}, forceful reboot task status:\n${RESPONSE}"

			echo "The host is being rebooted forcefully ..."

			# clean up and exit as there's nothing to do anymore
			# the host is shut down
			cleanup_and_exit


		elif [[ "${confirm}" == "NO" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, exit without forcefully rebooting the host"
		else
			log_error "function: ${FUNCNAME[0]}, invalid answer, has to be YES or NO"
		fi

	else
		log_error "function: ${FUNCNAME[0]}, the ESXi host maintenance mode cannot be determined"
	fi

}

# host services manage command handler
cmd_host_services_manage() {

	log_debug "${FUNCNAME[0]} is called"

	local ACTION
	ACTION=$(
		echo -e "list\nstart\nstop\nrestart\nrefresh\nuninstall\nenable\ndisable\nauto" | \
		fzf --cycle \
			--border=rounded \
			--border-label=" ESXi host's '${ESXI_HOSTNAME}' services actions " \
            --preview-window=right:50% \
            --preview "cmd_host_services_action_help {}" \
            --preview-window=hidden --bind 'ctrl-h:toggle-preview' \
			--header "Choose please an action for service(s) to apply on this ESXi host | ctrl-h: help for an action" \
			--layout reverse
	)

	[[ -z "${ACTION}" ]] && return

	case "${ACTION}" in
		list)			cmd_host_services_list		;;
		start)			cmd_host_services_start		;;
		stop)			cmd_host_services_stop		;;
		restart)		cmd_host_services_restart	;;
		refresh)		cmd_host_services_refresh	;;
		uninstall)		cmd_host_services_uninstall	;;
		enable)			cmd_host_services_enable	;;
		disable)		cmd_host_services_disable	;;
		auto)			cmd_host_services_auto		;;
		*)				cmd_host_services_unknown "${ACTION}" ;; 
	esac

}

# host services action help handler
cmd_host_services_action_help() {

	log_debug "${FUNCNAME[0]} is called"

	local ACTION
	ACTION="$1"

	[[ -z "${ACTION}" ]] && return
	
	case "${ACTION}" in
		list)
			echo "Lists host's services"
			;;
		start)
			echo "Starts host's service(s)"
			;;
		stop)
			echo "Stops host's service(s)"
			;;
		restart)
			echo "Restarts host's service(s)"
			;;
		refresh)
			echo "Refreshes host's service(s)"
			;;
		uninstall)
			echo "Uninstalls host's 3rd party service(s) "
			;;
		enable)
			echo "Enables host's service(s)"
			;;
		disable)
			echo "Disables host's service(s)"
			;;
		auto)
			echo "Adds automatic start of host's service(s)"
			;;
		*)
			echo "Unknown action. No help available."
			;;
	esac

}
export -f cmd_host_services_action_help

# host services list command handler
cmd_host_services_list() {

	log_debug "${FUNCNAME[0]} is called"

	local LISTSERVICES_XML=$(
		cat <<- XML
			<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
					<RetrievePropertiesEx xmlns="urn:vim25">
						<_this type="PropertyCollector">ha-property-collector</_this>
						<specSet>
							<propSet>
								<type>HostSystem</type>
								<pathSet>config.service.service</pathSet>
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
			-d "${LISTSERVICES_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)


	log_debug "function: ${FUNCNAME[0]}, ${RESPONSE}"

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
	
	{
		echo -e "SVCID\tNAME\tRUNNING\tPOLICY\tREQUIRED"
		echo "${RESPONSE}" | grep -oP '<HostService.*?</HostService>' | \
		while read -r svc_block
		do
	    
		    [[ -z "$svc_block" ]] && continue
		
		    SVCID=$(echo "$svc_block" | xmllint --xpath "string(//key)" - 2>/dev/null)
		    NAME=$(echo "$svc_block" | xmllint --xpath "string(//label)" - 2>/dev/null)
		    RUNNING=$(echo "$svc_block" | xmllint --xpath "string(//running)" - 2>/dev/null)
		    POLICY=$(echo "$svc_block" | xmllint --xpath "string(//policy)" - 2>/dev/null)
		    REQUIRED=$(echo "$svc_block" | xmllint --xpath "string(//required)" - 2>/dev/null)
	
	    echo -e "${SVCID}\t${NAME}\t${RUNNING}\t${POLICY}\t${REQUIRED}"
	
		done
	} | column -t -s $'\t' | \
	fzf --cycle \
              --border=rounded \
              --border-label=" ESXi host's '${ESXI_HOSTNAME}' services " \
              --preview-window=right:50% \
              --preview "echo 'Service ID: {1}';
						 echo 'Service name: {2..-4}';
						 echo 'Service running: {-3}';
						 echo 'Policy: {-2}';
						 echo 'Service required: {-1}';" \
              --preview-window=hidden --bind 'ctrl-p:toggle-preview' \
			  --bind 'ctrl-a:select-all' \
			  --bind 'ctrl-d:deselect-all'  \
              --bind 'ctrl-b:become(exit 2)' \
              --header-lines=1 \
              --header "Simple list of all the esxi host services | ctrl-p: (un)toggle service's info view | ctrl-a/d: select/deselect all services" \
              --layout reverse -m

}

# host services start command handler
cmd_host_services_start() {

	log_debug "${FUNCNAME[0]} is called"

	local SERVICESYSTEM_XML=$(
		cat <<- XML
			<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
					<RetrievePropertiesEx xmlns="urn:vim25">
						<_this type="PropertyCollector">ha-property-collector</_this>
						<specSet>
							<propSet>
								<type>HostSystem</type>
								<pathSet>configManager.serviceSystem</pathSet>
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
			-d "${SERVICESYSTEM_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	log_debug "function: ${FUNCNAME[0]}, ${RESPONSE}"
    
	RESPONSE=$(echo "$RESPONSE" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g')
	local SERVICESYSTEM_MOREF=$(echo "${RESPONSE}" | xmllint --xpath "string(//val)" - 2>/dev/null)
    
	[[ -z "${SERVICESYSTEM_MOREF}" ]] && { log_error "function: ${FUNCNAME[0]}, failed to get service system MoRef"; return 1; }
    
    log_debug "function: ${FUNCNAME[0]}, host service system MoRef: ${SERVICESYSTEM_MOREF}"

	local LISTSERVICES_XML=$(
		cat <<- XML
			<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
					<RetrievePropertiesEx xmlns="urn:vim25">
						<_this type="PropertyCollector">ha-property-collector</_this>
						<specSet>
							<propSet>
								<type>HostSystem</type>
								<pathSet>config.service.service</pathSet>
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

	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LISTSERVICES_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	log_debug "function: ${FUNCNAME[0]}, ${RESPONSE}"

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
	
	SVCS_SELECTED=$(
		{
			echo -e "SVCID\tNAME\tRUNNING\tPOLICY\tREQUIRED"
			echo "${RESPONSE}" | grep -oP '<HostService.*?</HostService>' | \
			while read -r svc_block
			do
		    
			    [[ -z "${svc_block}" ]] && continue
			
			    SVCID=$(echo "${svc_block}" | xmllint --xpath "string(//key)" - 2>/dev/null)
			    NAME=$(echo "${svc_block}" | xmllint --xpath "string(//label)" - 2>/dev/null)
			    RUNNING=$(echo "${svc_block}" | xmllint --xpath "string(//running)" - 2>/dev/null)
			    POLICY=$(echo "${svc_block}" | xmllint --xpath "string(//policy)" - 2>/dev/null)
			    REQUIRED=$(echo "${svc_block}" | xmllint --xpath "string(//required)" - 2>/dev/null)
		
		    echo -e "${SVCID}\t${NAME}\t${RUNNING}\t${POLICY}\t${REQUIRED}"
		
			done
		} | column -t -s $'\t' | \
		fzf --cycle \
	              --border=rounded \
	              --border-label=" ESXi host's '${ESXI_HOSTNAME}' services " \
	              --preview-window=right:50% \
	              --preview "echo 'Service ID: {1}';
							 echo 'Service name: {2..-4}';
							 echo 'Service running: {-3}';
							 echo 'Policy: {-2}';
							 echo 'Service required: {-1}';" \
	              --preview-window=hidden --bind 'ctrl-p:toggle-preview' \
				  --bind 'ctrl-a:select-all' \
				  --bind 'ctrl-d:deselect-all'  \
	              --bind 'ctrl-b:become(exit 2)' \
	              --header-lines=1 \
	              --header "Select esxi host services to start | ctrl-p: (un)toggle service's info view | ctrl-a/d: select/deselect all services" \
	              --layout reverse -m
	)

	local fzf_exit_code=$?
	[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
	[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
	[[ -z "${SVCS_SELECTED}" ]] && return

	while IFS= read -r line
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

		local SVCID=$(echo "${line}" | awk '{print $1}')
		[[ -z "${SVCID}" ]] && continue

		log_debug "function: ${FUNCNAME[0]}, starting the service ${SVCID}"

		local STARTSERVICE_XML 
		STARTSERVICE_XML=$(
			cat <<- XML
				<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
					<soapenv:Body>
						<StartService xmlns="urn:vim25">
							<_this type="HostServiceSystem">${SERVICESYSTEM_MOREF}</_this>
							<id>${SVCID}</id>
						</StartService>
					</soapenv:Body>
				</soapenv:Envelope>
			XML
		)

		local HTTP_CODE
		HTTP_CODE=$(
			curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_host_services_start" -X POST \
				-H "Content-Type: text/xml; charset=UTF-8" \
				-H "SOAPAction: \"urn:vim25/8.0\"" \
				-d "${STARTSERVICE_XML}" \
				-b "${COOKIE_FILE}" \
				"https://${ESXI_HOSTNAME}/sdk" \
				2>&1
		)

		if [[ "${HTTP_CODE}" == "200" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, ✓ start of the service with SVCID ${SVCID} is successful (HTTP CODE ${HTTP_CODE})"
			log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_host_services_start")"

			local TASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' "${BASHAPP_TMPDIR}/cmd_host_services_start")

			if [[ -n "${TASKID}" ]]
			then
				log_debug "function: ${FUNCNAME[0]}, starting service task created: ${TASKID}"
        
				if cmd_tasks_monitor "${TASKID}"
				then
					log_debug "function: ${FUNCNAME[0]}, ✓ service with SVCID ${SVCID} has been started successfully"
				else
					log_error "function: ${FUNCNAME[0]}, ✗ has failed to start the service with SVCID ${SVCID}"
				fi

			else
				log_error "function: ${FUNCNAME[0]}, no TASK ID returned"
			fi

		else
			log_error "function: ${FUNCNAME[0]}, ✗ has failed to start of the service with SVCID ${SVCID} (HTTP CODE ${HTTP_CODE})"
			log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_host_services_start") (HTTP CODE ${HTTP_CODE})"
		fi

	done <<< "${SVCS_SELECTED}"

}

# host services stop command handler
cmd_host_services_stop() {

	log_debug "${FUNCNAME[0]} is called"

	local SERVICESYSTEM_XML=$(
		cat <<- XML
			<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
					<RetrievePropertiesEx xmlns="urn:vim25">
						<_this type="PropertyCollector">ha-property-collector</_this>
						<specSet>
							<propSet>
								<type>HostSystem</type>
								<pathSet>configManager.serviceSystem</pathSet>
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
			-d "${SERVICESYSTEM_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	log_debug "function: ${FUNCNAME[0]}, ${RESPONSE}"
    
	RESPONSE=$(echo "$RESPONSE" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g')
	local SERVICESYSTEM_MOREF=$(echo "${RESPONSE}" | xmllint --xpath "string(//val)" - 2>/dev/null)
    
	[[ -z "${SERVICESYSTEM_MOREF}" ]] && { log_error "function: ${FUNCNAME[0]}, failed to get service system MoRef"; return 1; }
    
    log_debug "function: ${FUNCNAME[0]}, host service system MoRef: ${SERVICESYSTEM_MOREF}"

	local LISTSERVICES_XML=$(
		cat <<- XML
			<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
					<RetrievePropertiesEx xmlns="urn:vim25">
						<_this type="PropertyCollector">ha-property-collector</_this>
						<specSet>
							<propSet>
								<type>HostSystem</type>
								<pathSet>config.service.service</pathSet>
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

	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LISTSERVICES_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	log_debug "function: ${FUNCNAME[0]}, ${RESPONSE}"

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
	
	SVCS_SELECTED=$(
		{
			echo -e "SVCID\tNAME\tRUNNING\tPOLICY\tREQUIRED"
			echo "${RESPONSE}" | grep -oP '<HostService.*?</HostService>' | \
			while read -r svc_block
			do
		    
			    [[ -z "${svc_block}" ]] && continue
			
			    SVCID=$(echo "${svc_block}" | xmllint --xpath "string(//key)" - 2>/dev/null)
			    NAME=$(echo "${svc_block}" | xmllint --xpath "string(//label)" - 2>/dev/null)
			    RUNNING=$(echo "${svc_block}" | xmllint --xpath "string(//running)" - 2>/dev/null)
			    POLICY=$(echo "${svc_block}" | xmllint --xpath "string(//policy)" - 2>/dev/null)
			    REQUIRED=$(echo "${svc_block}" | xmllint --xpath "string(//required)" - 2>/dev/null)
		
		    echo -e "${SVCID}\t${NAME}\t${RUNNING}\t${POLICY}\t${REQUIRED}"
		
			done
		} | column -t -s $'\t' | \
		fzf --cycle \
	              --border=rounded \
	              --border-label=" ESXi host's '${ESXI_HOSTNAME}' services " \
	              --preview-window=right:50% \
	              --preview "echo 'Service ID: {1}';
							 echo 'Service name: {2..-4}';
							 echo 'Service running: {-3}';
							 echo 'Policy: {-2}';
							 echo 'Service required: {-1}';" \
	              --preview-window=hidden --bind 'ctrl-p:toggle-preview' \
				  --bind 'ctrl-a:select-all' \
				  --bind 'ctrl-d:deselect-all'  \
	              --bind 'ctrl-b:become(exit 2)' \
	              --header-lines=1 \
	              --header "Select esxi host services to stop | ctrl-p: (un)toggle service's info view | ctrl-a/d: select/deselect all services" \
	              --layout reverse -m
	)

	local fzf_exit_code=$?
	[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
	[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
	[[ -z "${SVCS_SELECTED}" ]] && return

	while IFS= read -r line
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

		local SVCID=$(echo "${line}" | awk '{print $1}')
		[[ -z "${SVCID}" ]] && continue

		log_debug "function: ${FUNCNAME[0]}, stopping the service ${SVCID}"

		local STOPSERVICE_XML 
		STOPSERVICE_XML=$(
			cat <<- XML
				<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
					<soapenv:Body>
						<StopService xmlns="urn:vim25">
							<_this type="HostServiceSystem">${SERVICESYSTEM_MOREF}</_this>
							<id>${SVCID}</id>
						</StopService>
					</soapenv:Body>
				</soapenv:Envelope>
			XML
		)

		local HTTP_CODE
		HTTP_CODE=$(
			curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_host_services_stop" -X POST \
				-H "Content-Type: text/xml; charset=UTF-8" \
				-H "SOAPAction: \"urn:vim25/8.0\"" \
				-d "${STOPSERVICE_XML}" \
				-b "${COOKIE_FILE}" \
				"https://${ESXI_HOSTNAME}/sdk" \
				2>&1
		)

		if [[ "${HTTP_CODE}" == "200" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, ✓ stop of the service with SVCID ${SVCID} is successful (HTTP CODE ${HTTP_CODE})"
			log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_host_services_stop")"

			local TASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' "${BASHAPP_TMPDIR}/cmd_host_services_stop")

			if [[ -n "${TASKID}" ]]
			then
				log_debug "function: ${FUNCNAME[0]}, stopping service task created: ${TASKID}"
        
				if cmd_tasks_monitor "${TASKID}"
				then
					log_debug "function: ${FUNCNAME[0]}, ✓ service with SVCID ${SVCID} has been stopped successfully"
				else
					log_error "function: ${FUNCNAME[0]}, ✗ has failed to stop the service with SVCID ${SVCID}"
				fi

			else
				log_error "function: ${FUNCNAME[0]}, no TASK ID returned"
			fi

		else
			log_error "function: ${FUNCNAME[0]}, ✗ has failed to stop of the service with SVCID ${SVCID} (HTTP CODE ${HTTP_CODE})"
			log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_host_services_stop") (HTTP CODE ${HTTP_CODE})"
		fi

	done <<< "${SVCS_SELECTED}"

}

# host services restart command handler
cmd_host_services_restart() {

	log_debug "${FUNCNAME[0]} is called"

	local SERVICESYSTEM_XML=$(
		cat <<- XML
			<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
					<RetrievePropertiesEx xmlns="urn:vim25">
						<_this type="PropertyCollector">ha-property-collector</_this>
						<specSet>
							<propSet>
								<type>HostSystem</type>
								<pathSet>configManager.serviceSystem</pathSet>
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
			-d "${SERVICESYSTEM_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	log_debug "function: ${FUNCNAME[0]}, ${RESPONSE}"
    
	RESPONSE=$(echo "$RESPONSE" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g')
	local SERVICESYSTEM_MOREF=$(echo "${RESPONSE}" | xmllint --xpath "string(//val)" - 2>/dev/null)
    
	[[ -z "${SERVICESYSTEM_MOREF}" ]] && { log_error "function: ${FUNCNAME[0]}, failed to get service system MoRef"; return 1; }
    
    log_debug "function: ${FUNCNAME[0]}, host service system MoRef: ${SERVICESYSTEM_MOREF}"

	local LISTSERVICES_XML=$(
		cat <<- XML
			<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
					<RetrievePropertiesEx xmlns="urn:vim25">
						<_this type="PropertyCollector">ha-property-collector</_this>
						<specSet>
							<propSet>
								<type>HostSystem</type>
								<pathSet>config.service.service</pathSet>
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

	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LISTSERVICES_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	log_debug "function: ${FUNCNAME[0]}, ${RESPONSE}"

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
	
	SVCS_SELECTED=$(
		{
			echo -e "SVCID\tNAME\tRUNNING\tPOLICY\tREQUIRED"
			echo "${RESPONSE}" | grep -oP '<HostService.*?</HostService>' | \
			while read -r svc_block
			do
		    
			    [[ -z "${svc_block}" ]] && continue
			
			    SVCID=$(echo "${svc_block}" | xmllint --xpath "string(//key)" - 2>/dev/null)
			    NAME=$(echo "${svc_block}" | xmllint --xpath "string(//label)" - 2>/dev/null)
			    RUNNING=$(echo "${svc_block}" | xmllint --xpath "string(//running)" - 2>/dev/null)
			    POLICY=$(echo "${svc_block}" | xmllint --xpath "string(//policy)" - 2>/dev/null)
			    REQUIRED=$(echo "${svc_block}" | xmllint --xpath "string(//required)" - 2>/dev/null)
		
		    echo -e "${SVCID}\t${NAME}\t${RUNNING}\t${POLICY}\t${REQUIRED}"
		
			done
		} | column -t -s $'\t' | \
		fzf --cycle \
	              --border=rounded \
	              --border-label=" ESXi host's '${ESXI_HOSTNAME}' services " \
	              --preview-window=right:50% \
	              --preview "echo 'Service ID: {1}';
							 echo 'Service name: {2..-4}';
							 echo 'Service running: {-3}';
							 echo 'Policy: {-2}';
							 echo 'Service required: {-1}';" \
	              --preview-window=hidden --bind 'ctrl-p:toggle-preview' \
				  --bind 'ctrl-a:select-all' \
				  --bind 'ctrl-d:deselect-all'  \
	              --bind 'ctrl-b:become(exit 2)' \
	              --header-lines=1 \
	              --header "Select esxi host services to restart | ctrl-p: (un)toggle service's info view | ctrl-a/d: select/deselect all services" \
	              --layout reverse -m
	)

	local fzf_exit_code=$?
	[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
	[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
	[[ -z "${SVCS_SELECTED}" ]] && return

	while IFS= read -r line
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

		local SVCID=$(echo "${line}" | awk '{print $1}')
		[[ -z "${SVCID}" ]] && continue

		log_debug "function: ${FUNCNAME[0]}, restarting the service ${SVCID}"

		local RESTARTSERVICE_XML 
		RESTARTSERVICE_XML=$(
			cat <<- XML
				<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
					<soapenv:Body>
						<RestartService xmlns="urn:vim25">
							<_this type="HostServiceSystem">${SERVICESYSTEM_MOREF}</_this>
							<id>${SVCID}</id>
						</RestartService>
					</soapenv:Body>
				</soapenv:Envelope>
			XML
		)

		local HTTP_CODE
		HTTP_CODE=$(
			curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_host_services_restart" -X POST \
				-H "Content-Type: text/xml; charset=UTF-8" \
				-H "SOAPAction: \"urn:vim25/8.0\"" \
				-d "${RESTARTSERVICE_XML}" \
				-b "${COOKIE_FILE}" \
				"https://${ESXI_HOSTNAME}/sdk" \
				2>&1
		)

		if [[ "${HTTP_CODE}" == "200" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, ✓ restart of the service with SVCID ${SVCID} is successful (HTTP CODE ${HTTP_CODE})"
			log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_host_services_restart")"

			local TASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' "${BASHAPP_TMPDIR}/cmd_host_services_restart")

			if [[ -n "${TASKID}" ]]
			then
				log_debug "function: ${FUNCNAME[0]}, restarting service task created: ${TASKID}"
        
				if cmd_tasks_monitor "${TASKID}"
				then
					log_debug "function: ${FUNCNAME[0]}, ✓ service with SVCID ${SVCID} has been restarted successfully"
				else
					log_error "function: ${FUNCNAME[0]}, ✗ has failed to restart the service with SVCID ${SVCID}"
				fi

			else
				log_error "function: ${FUNCNAME[0]}, no TASK ID returned"
			fi

		else
			log_error "function: ${FUNCNAME[0]}, ✗ has failed to restart of the service with SVCID ${SVCID} (HTTP CODE ${HTTP_CODE})"
			log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_host_services_restart") (HTTP CODE ${HTTP_CODE})"
		fi

	done <<< "${SVCS_SELECTED}"

}

# host services refresh command handler
cmd_host_services_refresh() {

	log_debug "${FUNCNAME[0]} is called"

	local SERVICESYSTEM_XML=$(
		cat <<- XML
			<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
					<RetrievePropertiesEx xmlns="urn:vim25">
						<_this type="PropertyCollector">ha-property-collector</_this>
						<specSet>
							<propSet>
								<type>HostSystem</type>
								<pathSet>configManager.serviceSystem</pathSet>
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
			-d "${SERVICESYSTEM_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	log_debug "function: ${FUNCNAME[0]}, ${RESPONSE}"
    
	RESPONSE=$(echo "$RESPONSE" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g')
	local SERVICESYSTEM_MOREF=$(echo "${RESPONSE}" | xmllint --xpath "string(//val)" - 2>/dev/null)
    
	[[ -z "${SERVICESYSTEM_MOREF}" ]] && { log_error "function: ${FUNCNAME[0]}, failed to get service system MoRef"; return 1; }
    
    log_debug "function: ${FUNCNAME[0]}, host service system MoRef: ${SERVICESYSTEM_MOREF}"

	local REFRESHSERVICES_XML 
	REFRESHSERVICES_XML=$(
		cat <<- XML
			<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
					<RefreshServices xmlns="urn:vim25">
						<_this type="HostServiceSystem">${SERVICESYSTEM_MOREF}</_this>
					</RefreshServices>
				</soapenv:Body>
			</soapenv:Envelope>
		XML
	)

	local HTTP_CODE
	HTTP_CODE=$(
		curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_host_services_refresh" -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${REFRESHSERVICES_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	if [[ "${HTTP_CODE}" == "200" ]]
	then
		log_debug "function: ${FUNCNAME[0]}, ✓ refreshing the services is successful (HTTP CODE ${HTTP_CODE})"
		log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_host_services_refresh")"
	else
		log_error "function: ${FUNCNAME[0]}, ✗ has failed to refresh the services (HTTP CODE ${HTTP_CODE})"
		log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_host_services_refresh") (HTTP CODE ${HTTP_CODE})"
	fi

}

# host services uninstall command handler
cmd_host_services_uninstall() {

	log_debug "${FUNCNAME[0]} is called"

	local SERVICESYSTEM_XML=$(
		cat <<- XML
			<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
					<RetrievePropertiesEx xmlns="urn:vim25">
						<_this type="PropertyCollector">ha-property-collector</_this>
						<specSet>
							<propSet>
								<type>HostSystem</type>
								<pathSet>configManager.serviceSystem</pathSet>
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
			-d "${SERVICESYSTEM_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	log_debug "function: ${FUNCNAME[0]}, ${RESPONSE}"
    
	RESPONSE=$(echo "$RESPONSE" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g')
	local SERVICESYSTEM_MOREF=$(echo "${RESPONSE}" | xmllint --xpath "string(//val)" - 2>/dev/null)
    
	[[ -z "${SERVICESYSTEM_MOREF}" ]] && { log_error "function: ${FUNCNAME[0]}, failed to get service system MoRef"; return 1; }
    
    log_debug "function: ${FUNCNAME[0]}, host service system MoRef: ${SERVICESYSTEM_MOREF}"

	local LISTSERVICES_XML=$(
		cat <<- XML
			<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
					<RetrievePropertiesEx xmlns="urn:vim25">
						<_this type="PropertyCollector">ha-property-collector</_this>
						<specSet>
							<propSet>
								<type>HostSystem</type>
								<pathSet>config.service.service</pathSet>
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

	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LISTSERVICES_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	log_debug "function: ${FUNCNAME[0]}, ${RESPONSE}"

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
	
	SVCS_SELECTED=$(
		{
			echo -e "SVCID\tNAME\tRUNNING\tPOLICY\tREQUIRED\tUNINSTALLLABLE"
			echo "${RESPONSE}" | grep -oP '<HostService.*?</HostService>' | \
			while read -r svc_block
			do
		    
			    [[ -z "${svc_block}" ]] && continue
			
			    SVCID=$(echo "${svc_block}" | xmllint --xpath "string(//key)" - 2>/dev/null)
			    NAME=$(echo "${svc_block}" | xmllint --xpath "string(//label)" - 2>/dev/null)
			    RUNNING=$(echo "${svc_block}" | xmllint --xpath "string(//running)" - 2>/dev/null)
			    POLICY=$(echo "${svc_block}" | xmllint --xpath "string(//policy)" - 2>/dev/null)
			    REQUIRED=$(echo "${svc_block}" | xmllint --xpath "string(//required)" - 2>/dev/null)
			    UNINSTALLLABLE=$(echo "${svc_block}" | xmllint --xpath "string(//uninstallable)" - 2>/dev/null)
				
		
		    echo -e "${SVCID}\t${NAME}\t${RUNNING}\t${POLICY}\t${REQUIRED}\t${UNINSTALLLABLE}"
		
			done
		} | column -t -s $'\t' | \
		fzf --cycle \
	              --border=rounded \
	              --border-label=" ESXi host's '${ESXI_HOSTNAME}' services " \
	              --preview-window=right:50% \
	              --preview "echo 'Service ID: {1}';
							 echo 'Service name: {2..-5}';
							 echo 'Service running: {-4}';
							 echo 'Policy: {-3}';
							 echo 'Service required: {-2}';
							 echo 'Uninstallable: {-1}';" \
	              --preview-window=hidden --bind 'ctrl-p:toggle-preview' \
				  --bind 'ctrl-a:select-all' \
				  --bind 'ctrl-d:deselect-all'  \
	              --bind 'ctrl-b:become(exit 2)' \
	              --header-lines=1 \
	              --header "Select esxi host services to uninstall | ctrl-p: (un)toggle service's info view | ctrl-a/d: select/deselect all services" \
	              --layout reverse -m
	)

	local fzf_exit_code=$?
	[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
	[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
	[[ -z "${SVCS_SELECTED}" ]] && return

	while IFS= read -r line
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

		local SVCID=$(echo "${line}" | awk '{print $1}')
		[[ -z "${SVCID}" ]] && continue
		local UNINSTALL=$(echo "${line}" | awk '{print $NF}')
		

		if [[ "${UNINSTALL}" == "true" ]]
		then

			log_debug "function: ${FUNCNAME[0]}, UNINSTALL=${UNINSTALL}"
			log_debug "function: ${FUNCNAME[0]}, uninstalling the service ${SVCID}"
	
			local UNINSTALLSERVICE_XML 
			UNINSTALLSERVICE_XML=$(
				cat <<- XML
					<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
						<soapenv:Body>
							<UninstallService xmlns="urn:vim25">
								<_this type="HostServiceSystem">${SERVICESYSTEM_MOREF}</_this>
								<id>${SVCID}</id>
							</UninstallService>
						</soapenv:Body>
					</soapenv:Envelope>
				XML
			)
	
			local HTTP_CODE
			HTTP_CODE=$(
				curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_host_services_uninstall" -X POST \
					-H "Content-Type: text/xml; charset=UTF-8" \
					-H "SOAPAction: \"urn:vim25/8.0\"" \
					-d "${UNINSTALLSERVICE_XML}" \
					-b "${COOKIE_FILE}" \
					"https://${ESXI_HOSTNAME}/sdk" \
					2>&1
			)
	
			if [[ "${HTTP_CODE}" == "200" ]]
			then
				log_debug "function: ${FUNCNAME[0]}, ✓ uninstall of the service with SVCID ${SVCID} is successful (HTTP CODE ${HTTP_CODE})"
				log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_host_services_uninstall")"
	
				local TASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' "${BASHAPP_TMPDIR}/cmd_host_services_uninstall")
	
				if [[ -n "${TASKID}" ]]
				then
					log_debug "function: ${FUNCNAME[0]}, uninstalling service task created: ${TASKID}"
	        
					if cmd_tasks_monitor "${TASKID}"
					then
						log_debug "function: ${FUNCNAME[0]}, ✓ service with SVCID ${SVCID} has been uninstalled successfully"
					else
						log_error "function: ${FUNCNAME[0]}, ✗ has failed to uninstall the service with SVCID ${SVCID}"
					fi
	
				else
					log_error "function: ${FUNCNAME[0]}, no TASK ID returned"
				fi
	
			else
				log_error "function: ${FUNCNAME[0]}, ✗ has failed to uninstall the service with SVCID ${SVCID} (HTTP CODE ${HTTP_CODE})"
				log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_host_services_uninstall") (HTTP CODE ${HTTP_CODE})"
			fi
		else

			log_debug "function: ${FUNCNAME[0]}, the service ${SVCID} cannot be uninstalled. defined as non-uninstallable in the system."
	
		fi

	done <<< "${SVCS_SELECTED}"

}


# host services enable command handler
cmd_host_services_enable() {

	log_debug "${FUNCNAME[0]} is called"

	local SERVICESYSTEM_XML=$(
		cat <<- XML
			<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
					<RetrievePropertiesEx xmlns="urn:vim25">
						<_this type="PropertyCollector">ha-property-collector</_this>
						<specSet>
							<propSet>
								<type>HostSystem</type>
								<pathSet>configManager.serviceSystem</pathSet>
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
			-d "${SERVICESYSTEM_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	log_debug "function: ${FUNCNAME[0]}, ${RESPONSE}"
    
	RESPONSE=$(echo "$RESPONSE" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g')
	local SERVICESYSTEM_MOREF=$(echo "${RESPONSE}" | xmllint --xpath "string(//val)" - 2>/dev/null)
    
	[[ -z "${SERVICESYSTEM_MOREF}" ]] && { log_error "function: ${FUNCNAME[0]}, failed to get service system MoRef"; return 1; }
    
    log_debug "function: ${FUNCNAME[0]}, host service system MoRef: ${SERVICESYSTEM_MOREF}"

	local LISTSERVICES_XML=$(
		cat <<- XML
			<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
					<RetrievePropertiesEx xmlns="urn:vim25">
						<_this type="PropertyCollector">ha-property-collector</_this>
						<specSet>
							<propSet>
								<type>HostSystem</type>
								<pathSet>config.service.service</pathSet>
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

	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LISTSERVICES_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	log_debug "function: ${FUNCNAME[0]}, ${RESPONSE}"

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
	
	SVCS_SELECTED=$(
		{
			echo -e "SVCID\tNAME\tRUNNING\tPOLICY\tREQUIRED"
			echo "${RESPONSE}" | grep -oP '<HostService.*?</HostService>' | \
			while read -r svc_block
			do
		    
			    [[ -z "${svc_block}" ]] && continue
			
			    SVCID=$(echo "${svc_block}" | xmllint --xpath "string(//key)" - 2>/dev/null)
			    NAME=$(echo "${svc_block}" | xmllint --xpath "string(//label)" - 2>/dev/null)
			    RUNNING=$(echo "${svc_block}" | xmllint --xpath "string(//running)" - 2>/dev/null)
			    POLICY=$(echo "${svc_block}" | xmllint --xpath "string(//policy)" - 2>/dev/null)
			    REQUIRED=$(echo "${svc_block}" | xmllint --xpath "string(//required)" - 2>/dev/null)
		
		    echo -e "${SVCID}\t${NAME}\t${RUNNING}\t${POLICY}\t${REQUIRED}"
		
			done
		} | column -t -s $'\t' | \
		fzf --cycle \
	              --border=rounded \
	              --border-label=" ESXi host's '${ESXI_HOSTNAME}' services " \
	              --preview-window=right:50% \
	              --preview "echo 'Service ID: {1}';
							 echo 'Service name: {2..-4}';
							 echo 'Service running: {-3}';
							 echo 'Policy: {-2}';
							 echo 'Service required: {-1}';" \
	              --preview-window=hidden --bind 'ctrl-p:toggle-preview' \
				  --bind 'ctrl-a:select-all' \
				  --bind 'ctrl-d:deselect-all'  \
	              --bind 'ctrl-b:become(exit 2)' \
	              --header-lines=1 \
	              --header "Select esxi host services to enable | ctrl-p: (un)toggle service's info view | ctrl-a/d: select/deselect all services" \
	              --layout reverse -m
	)

	local fzf_exit_code=$?
	[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
	[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
	[[ -z "${SVCS_SELECTED}" ]] && return

	while IFS= read -r line
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

		local SVCID=$(echo "${line}" | awk '{print $1}')
		[[ -z "${SVCID}" ]] && continue

		log_debug "function: ${FUNCNAME[0]}, enabling the service ${SVCID}"

		local ENABLESERVICE_XML 
		ENABLESERVICE_XML=$(
			cat <<- XML
				<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
					<soapenv:Body>
						<UpdateServicePolicy xmlns="urn:vim25">
							<_this type="HostServiceSystem">${SERVICESYSTEM_MOREF}</_this>
							<id>${SVCID}</id>
							<policy>on</policy>
						</UpdateServicePolicy>
					</soapenv:Body>
				</soapenv:Envelope>
			XML
		)

		local HTTP_CODE
		HTTP_CODE=$(
			curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_host_services_enable" -X POST \
				-H "Content-Type: text/xml; charset=UTF-8" \
				-H "SOAPAction: \"urn:vim25/8.0\"" \
				-d "${ENABLESERVICE_XML}" \
				-b "${COOKIE_FILE}" \
				"https://${ESXI_HOSTNAME}/sdk" \
				2>&1
		)

		if [[ "${HTTP_CODE}" == "200" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, ✓ enabling the service with SVCID ${SVCID} is successful (HTTP CODE ${HTTP_CODE})"
			log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_host_services_enable")"

			local TASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' "${BASHAPP_TMPDIR}/cmd_host_services_enable")

			if [[ -n "${TASKID}" ]]
			then
				log_debug "function: ${FUNCNAME[0]}, enabling service task created: ${TASKID}"
        
				if cmd_tasks_monitor "${TASKID}"
				then
					log_debug "function: ${FUNCNAME[0]}, ✓ service with SVCID ${SVCID} has been enabled successfully"
				else
					log_error "function: ${FUNCNAME[0]}, ✗ has failed to enable the service with SVCID ${SVCID}"
				fi

			else
				log_error "function: ${FUNCNAME[0]}, no TASK ID returned"
			fi

		else
			log_error "function: ${FUNCNAME[0]}, ✗ has failed to enable the service with SVCID ${SVCID} (HTTP CODE ${HTTP_CODE})"
			log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_host_services_enable") (HTTP CODE ${HTTP_CODE})"
		fi

	done <<< "${SVCS_SELECTED}"

}


# host services disable command handler
cmd_host_services_disable() {

	log_debug "${FUNCNAME[0]} is called"

	local SERVICESYSTEM_XML=$(
		cat <<- XML
			<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
					<RetrievePropertiesEx xmlns="urn:vim25">
						<_this type="PropertyCollector">ha-property-collector</_this>
						<specSet>
							<propSet>
								<type>HostSystem</type>
								<pathSet>configManager.serviceSystem</pathSet>
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
			-d "${SERVICESYSTEM_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	log_debug "function: ${FUNCNAME[0]}, ${RESPONSE}"
    
	RESPONSE=$(echo "$RESPONSE" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g')
	local SERVICESYSTEM_MOREF=$(echo "${RESPONSE}" | xmllint --xpath "string(//val)" - 2>/dev/null)
    
	[[ -z "${SERVICESYSTEM_MOREF}" ]] && { log_error "function: ${FUNCNAME[0]}, failed to get service system MoRef"; return 1; }
    
    log_debug "function: ${FUNCNAME[0]}, host service system MoRef: ${SERVICESYSTEM_MOREF}"

	local LISTSERVICES_XML=$(
		cat <<- XML
			<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
					<RetrievePropertiesEx xmlns="urn:vim25">
						<_this type="PropertyCollector">ha-property-collector</_this>
						<specSet>
							<propSet>
								<type>HostSystem</type>
								<pathSet>config.service.service</pathSet>
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

	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LISTSERVICES_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	log_debug "function: ${FUNCNAME[0]}, ${RESPONSE}"

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
	
	SVCS_SELECTED=$(
		{
			echo -e "SVCID\tNAME\tRUNNING\tPOLICY\tREQUIRED"
			echo "${RESPONSE}" | grep -oP '<HostService.*?</HostService>' | \
			while read -r svc_block
			do
		    
			    [[ -z "${svc_block}" ]] && continue
			
			    SVCID=$(echo "${svc_block}" | xmllint --xpath "string(//key)" - 2>/dev/null)
			    NAME=$(echo "${svc_block}" | xmllint --xpath "string(//label)" - 2>/dev/null)
			    RUNNING=$(echo "${svc_block}" | xmllint --xpath "string(//running)" - 2>/dev/null)
			    POLICY=$(echo "${svc_block}" | xmllint --xpath "string(//policy)" - 2>/dev/null)
			    REQUIRED=$(echo "${svc_block}" | xmllint --xpath "string(//required)" - 2>/dev/null)
		
		    echo -e "${SVCID}\t${NAME}\t${RUNNING}\t${POLICY}\t${REQUIRED}"
		
			done
		} | column -t -s $'\t' | \
		fzf --cycle \
	              --border=rounded \
	              --border-label=" ESXi host's '${ESXI_HOSTNAME}' services " \
	              --preview-window=right:50% \
	              --preview "echo 'Service ID: {1}';
							 echo 'Service name: {2..-4}';
							 echo 'Service running: {-3}';
							 echo 'Policy: {-2}';
							 echo 'Service required: {-1}';" \
	              --preview-window=hidden --bind 'ctrl-p:toggle-preview' \
				  --bind 'ctrl-a:select-all' \
				  --bind 'ctrl-d:deselect-all'  \
	              --bind 'ctrl-b:become(exit 2)' \
	              --header-lines=1 \
	              --header "Select esxi host services to disable | ctrl-p: (un)toggle service's info view | ctrl-a/d: select/deselect all services" \
	              --layout reverse -m
	)

	local fzf_exit_code=$?
	[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
	[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
	[[ -z "${SVCS_SELECTED}" ]] && return

	while IFS= read -r line
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

		local SVCID=$(echo "${line}" | awk '{print $1}')
		[[ -z "${SVCID}" ]] && continue

		log_debug "function: ${FUNCNAME[0]}, disabling the service ${SVCID}"

		local DISABLESERVICE_XML 
		DISABLESERVICE_XML=$(
			cat <<- XML
				<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
					<soapenv:Body>
						<UpdateServicePolicy xmlns="urn:vim25">
							<_this type="HostServiceSystem">${SERVICESYSTEM_MOREF}</_this>
							<id>${SVCID}</id>
							<policy>off</policy>
						</UpdateServicePolicy>
					</soapenv:Body>
				</soapenv:Envelope>
			XML
		)

		local HTTP_CODE
		HTTP_CODE=$(
			curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_host_services_disable" -X POST \
				-H "Content-Type: text/xml; charset=UTF-8" \
				-H "SOAPAction: \"urn:vim25/8.0\"" \
				-d "${DISABLESERVICE_XML}" \
				-b "${COOKIE_FILE}" \
				"https://${ESXI_HOSTNAME}/sdk" \
				2>&1
		)

		if [[ "${HTTP_CODE}" == "200" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, ✓ disabling the service with SVCID ${SVCID} is successful (HTTP CODE ${HTTP_CODE})"
			log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_host_services_disable")"

			local TASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' "${BASHAPP_TMPDIR}/cmd_host_services_disable")

			if [[ -n "${TASKID}" ]]
			then
				log_debug "function: ${FUNCNAME[0]}, disabling service task created: ${TASKID}"
        
				if cmd_tasks_monitor "${TASKID}"
				then
					log_debug "function: ${FUNCNAME[0]}, ✓ service with SVCID ${SVCID} has been disabled successfully"
				else
					log_error "function: ${FUNCNAME[0]}, ✗ has failed to disable the service with SVCID ${SVCID}"
				fi

			else
				log_error "function: ${FUNCNAME[0]}, no TASK ID returned"
			fi

		else
			log_error "function: ${FUNCNAME[0]}, ✗ has failed to disable the service with SVCID ${SVCID} (HTTP CODE ${HTTP_CODE})"
			log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_host_services_disable") (HTTP CODE ${HTTP_CODE})"
		fi

	done <<< "${SVCS_SELECTED}"

}


# host services auto command handler
cmd_host_services_auto() {

	log_debug "${FUNCNAME[0]} is called"

	local SERVICESYSTEM_XML=$(
		cat <<- XML
			<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
					<RetrievePropertiesEx xmlns="urn:vim25">
						<_this type="PropertyCollector">ha-property-collector</_this>
						<specSet>
							<propSet>
								<type>HostSystem</type>
								<pathSet>configManager.serviceSystem</pathSet>
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
			-d "${SERVICESYSTEM_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	log_debug "function: ${FUNCNAME[0]}, ${RESPONSE}"
    
	RESPONSE=$(echo "$RESPONSE" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g')
	local SERVICESYSTEM_MOREF=$(echo "${RESPONSE}" | xmllint --xpath "string(//val)" - 2>/dev/null)
    
	[[ -z "${SERVICESYSTEM_MOREF}" ]] && { log_error "function: ${FUNCNAME[0]}, failed to get service system MoRef"; return 1; }
    
    log_debug "function: ${FUNCNAME[0]}, host service system MoRef: ${SERVICESYSTEM_MOREF}"

	local LISTSERVICES_XML=$(
		cat <<- XML
			<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
					<RetrievePropertiesEx xmlns="urn:vim25">
						<_this type="PropertyCollector">ha-property-collector</_this>
						<specSet>
							<propSet>
								<type>HostSystem</type>
								<pathSet>config.service.service</pathSet>
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

	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LISTSERVICES_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	log_debug "function: ${FUNCNAME[0]}, ${RESPONSE}"

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
	
	SVCS_SELECTED=$(
		{
			echo -e "SVCID\tNAME\tRUNNING\tPOLICY\tREQUIRED"
			echo "${RESPONSE}" | grep -oP '<HostService.*?</HostService>' | \
			while read -r svc_block
			do
		    
			    [[ -z "${svc_block}" ]] && continue
			
			    SVCID=$(echo "${svc_block}" | xmllint --xpath "string(//key)" - 2>/dev/null)
			    NAME=$(echo "${svc_block}" | xmllint --xpath "string(//label)" - 2>/dev/null)
			    RUNNING=$(echo "${svc_block}" | xmllint --xpath "string(//running)" - 2>/dev/null)
			    POLICY=$(echo "${svc_block}" | xmllint --xpath "string(//policy)" - 2>/dev/null)
			    REQUIRED=$(echo "${svc_block}" | xmllint --xpath "string(//required)" - 2>/dev/null)
		
		    echo -e "${SVCID}\t${NAME}\t${RUNNING}\t${POLICY}\t${REQUIRED}"
		
			done
		} | column -t -s $'\t' | \
		fzf --cycle \
	              --border=rounded \
	              --border-label=" ESXi host's '${ESXI_HOSTNAME}' services " \
	              --preview-window=right:50% \
	              --preview "echo 'Service ID: {1}';
							 echo 'Service name: {2..-4}';
							 echo 'Service running: {-3}';
							 echo 'Policy: {-2}';
							 echo 'Service required: {-1}';" \
	              --preview-window=hidden --bind 'ctrl-p:toggle-preview' \
				  --bind 'ctrl-a:select-all' \
				  --bind 'ctrl-d:deselect-all'  \
	              --bind 'ctrl-b:become(exit 2)' \
	              --header-lines=1 \
	              --header "Select esxi host services to enable in auto mode | ctrl-p: (un)toggle service's info view | ctrl-a/d: select/deselect all services" \
	              --layout reverse -m
	)

	local fzf_exit_code=$?
	[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
	[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
	[[ -z "${SVCS_SELECTED}" ]] && return

	while IFS= read -r line
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

		local SVCID=$(echo "${line}" | awk '{print $1}')
		[[ -z "${SVCID}" ]] && continue

		log_debug "function: ${FUNCNAME[0]}, enabling the service ${SVCID} in auto mode"

		local AUTOSERVICE_XML 
		AUTOSERVICE_XML=$(
			cat <<- XML
				<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
					<soapenv:Body>
						<UpdateServicePolicy xmlns="urn:vim25">
							<_this type="HostServiceSystem">${SERVICESYSTEM_MOREF}</_this>
							<id>${SVCID}</id>
							<policy>automatic</policy>
						</UpdateServicePolicy>
					</soapenv:Body>
				</soapenv:Envelope>
			XML
		)

		local HTTP_CODE
		HTTP_CODE=$(
			curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_host_services_auto" -X POST \
				-H "Content-Type: text/xml; charset=UTF-8" \
				-H "SOAPAction: \"urn:vim25/8.0\"" \
				-d "${AUTOSERVICE_XML}" \
				-b "${COOKIE_FILE}" \
				"https://${ESXI_HOSTNAME}/sdk" \
				2>&1
		)

		if [[ "${HTTP_CODE}" == "200" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, ✓ enabling the service in auto mode with SVCID ${SVCID} is successful (HTTP CODE ${HTTP_CODE})"
			log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_host_services_auto")"

			local TASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' "${BASHAPP_TMPDIR}/cmd_host_services_auto")

			if [[ -n "${TASKID}" ]]
			then
				log_debug "function: ${FUNCNAME[0]}, enabling service in auto mode task created: ${TASKID}"
        
				if cmd_tasks_monitor "${TASKID}"
				then
					log_debug "function: ${FUNCNAME[0]}, ✓ service with SVCID ${SVCID} has been enabled in auto mode successfully"
				else
					log_error "function: ${FUNCNAME[0]}, ✗ has failed to enable the service with SVCID ${SVCID} in auto mode"
				fi

			else
				log_error "function: ${FUNCNAME[0]}, no TASK ID returned"
			fi

		else
			log_error "function: ${FUNCNAME[0]}, ✗ has failed to enable the service with SVCID ${SVCID} in auto mode (HTTP CODE ${HTTP_CODE})"
			log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_host_services_auto") (HTTP CODE ${HTTP_CODE})"
		fi

	done <<< "${SVCS_SELECTED}"

}

# host services unknown command handler
cmd_host_services_unknown() {

	log_debug "${FUNCNAME[0]} is called"
	
	local ACTION="$1"

	log_error "function: ${FUNCNAME[0]}, unknown command '${ACTION}' for host services action."

	echo "Unknown host services command: ${ACTION}"
	echo "Use '${BASHAPP_NAME}' help or/and documentation for the correct usage information"

}

# host unknown command handler
cmd_host_unknown() {

	log_debug "${FUNCNAME[0]} is called"
	
	local ACTION="$1"

	log_error "function: ${FUNCNAME[0]}, unknown command '${ACTION}' for host action."

	echo "Unknown host command: ${ACTION}"
	echo "Use '${BASHAPP_NAME}' help or/and documentation for the correct usage information"

}
