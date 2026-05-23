# datastores commands handlers functions

# datastores manage command handler
cmd_datastores_manage() {

	log_debug "${FUNCNAME[0]} is called"

	local ACTION
	ACTION=$(
		fzf --cycle \
			--border=rounded \
			--border-label=" ESXi host's '${ESXI_HOSTNAME}' datastore actions " \
            --preview-window=right:50% \
            --preview "cmd_datastores_action_help {}" \
            --preview-window=hidden --bind 'ctrl-h:toggle-preview' \
			--header "Choose please an action for datastores | ctrl-h: help for an action" \
			--layout reverse \
			<<-	ACTIONS
				browse
				rename
				refresh
				unmount
				mount
			ACTIONS
	)

	[[ -z "${ACTION}" ]] && return

	case "${ACTION}" in
		browse)		cmd_datastores_browse		;;
		rename)		cmd_datastores_rename		;;
		refresh)	cmd_datastores_refresh		;;
		unmount)	cmd_datastores_unmount		;;
		mount)		cmd_datastores_mount		;;
		*)			cmd_datastores_unknown "${ACTION}" ;; 
	esac

}

# datastores action help handler
cmd_datastores_action_help() {

	log_debug "${FUNCNAME[0]} is called"

	local ACTION
	ACTION="$1"

	[[ -z "${ACTION}" ]] && return
	
	case "${ACTION}" in
		browse)
			echo "Browses the contents of selected datastore"
			;;
		rename)
			echo "Renames selected datastore"
			;;
		refresh)
			echo "Refreshes selected datastore information"
			echo "including free-space, capacity, and detailed usage of virtual machines"
			;;
		unmount)
			echo "Unmounts selected VMFS datastore checking before if there are registered vms on it"
			echo "If there are registered vms on it the unmount operation is cancelled"
			echo "Be careful with this operation"
			;;
		mount)
			echo "Mounts selected VMFS datastore"
			;;
		*)
			echo "Unknown action. No help available."
			;;
	esac

}
export -f cmd_datastores_action_help

# datastores datastore info command handler
cmd_datastores_info() {

	log_debug "${FUNCNAME[0]} is called"

	VIEWEDDS="$1"
	ESXI_HOST="$2"

	[[ -z "${VIEWEDDS}" || -z "${ESXI_HOST}" ]] && return
	
	log_debug "function: ${FUNCNAME[0]}, VIEWEDDS=${VIEWEDDS}"
	log_debug "function: ${FUNCNAME[0]}, ESXI_HOST=${ESXI_HOST}"

	VIEWEDDSID=$(echo ${VIEWEDDS} | awk '{print $1}')

	local DSPROPERTIES_XML
	DSPROPERTIES_XML=$(
		cat <<- XML
			<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
					<RetrievePropertiesEx xmlns="urn:vim25">
						<_this type="PropertyCollector">ha-property-collector</_this>
						<specSet>
							<propSet>
								<type>Datastore</type>
								<pathSet>name</pathSet>
								<pathSet>summary.freeSpace</pathSet>
								<pathSet>summary.capacity</pathSet>
								<pathSet>summary.type</pathSet>
								<pathSet>summary.accessible</pathSet>
							</propSet>
							<objectSet>
								<obj type="Datastore">${VIEWEDDSID}</obj>
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
			-d "${DSPROPERTIES_XML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)
    
	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g')
    
	local VIEWEDDS_NAME=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='name']/val)" - 2>/dev/null)
	local VIEWEDDS_FREESPACE=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='summary.freeSpace']/val)" - 2>/dev/null)
	local VIEWEDDS_CAPACITY=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='summary.capacity']/val)" - 2>/dev/null)
	local VIEWEDDS_TYPE=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='summary.type']/val)" - 2>/dev/null)
	local VIEWEDDS_ACCESSIBLE=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='summary.accessible']/val)" - 2>/dev/null)

	echo -e "ESXi host ${ESXI_HOST} datastore info:"
	echo -e "------------------------------------------------------------"
	echo
	echo -e "datastore id: ${VIEWEDDSID}"
	echo -e "name: ${VIEWEDDS_NAME}"
	echo -e "free space: $((VIEWEDDS_FREESPACE/1073741824))GB"
	echo -e "capacity: $((VIEWEDDS_CAPACITY/1073741824))GB"
	echo -e "type: ${VIEWEDDS_TYPE}"
	echo -e "accessible: ${VIEWEDDS_ACCESSIBLE}"

}
export -f cmd_datastores_info

# datastores browse command handler
cmd_datastores_browse() {

	# step 1: list and select datastore to browse
	# step 2: get datastore browser moref
	# step 3: main browser loop

	log_debug "${FUNCNAME[0]} is called"
	
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

	local DSSELECTED=$(
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
	              --header "Select datastore to browse | ctrl-p: (un)toggle datastore's info view" \
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

	local RESPONSE
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

    		if [[ "${TASK_STATE}" == "error" ]]; then
        		log_error "function: ${FUNCNAME[0]}, SearchDatastore_Task has failed (inaccessible datastore?)"
        		break
    		fi

		done

		if [[ "${TASK_STATE}" != "success" ]]
		then
			log_error "function: ${FUNCNAME[0]}, datastore is inaccessible or search failed."
			return 1
		fi

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
				if [[ "${FTYPE}" == *"Folder"* ]]
				then
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
					echo -e "📁\t${FNAME}\t${FSIZE_HR}\t${FMOD}"
				else
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
				--header "Enter: open/cd | ctrl-d: delete file/folder | ctrl-r: rename file/folder| ctrl-u: go up | ctrl-q or esc: quit datastore browsing" \
				--layout reverse \
				--expect=ctrl-d,ctrl-r,ctrl-u,ctrl-q,esc,enter
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
				fi
				continue
				;;

			ctrl-d)

				log_debug "function: ${FUNCNAME[0]}, ctrl-d pressed"

				[[ -z "${SELECTED_NAME}" ]] && continue
				# protect "." and ".." folders from deletion
				[[ "${SELECTED_NAME}" == "." || "${SELECTED_NAME}" == ".." ]] && continue

				local DELETE_FULLPATH
				if [[ "${CURRENT_PATH}" == "[${DATASTORENAME}]" ]]
				then
					DELETE_FULLPATH="[${DATASTORENAME}] ${SELECTED_NAME}"
				else
					DELETE_FULLPATH="${CURRENT_PATH}/${SELECTED_NAME}"
				fi

				echo ""
				read -e -r -p "Delete '${DELETE_FULLPATH}'? [Y/N] " CONFIRM
				[[ "${CONFIRM}" != "y" && "${CONFIRM}" != "Y" ]] && continue

				local DELETEFILE_XML
				DELETEFILE_XML=$(
					cat <<- XML
						<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
							<soapenv:Body>
								<DeleteDatastoreFile_Task xmlns="urn:vim25">
									<_this type="FileManager">ha-nfc-file-manager</_this>
									<name>${DELETE_FULLPATH}</name>
									<datacenter type="Datacenter">ha-datacenter</datacenter>
								</DeleteDatastoreFile_Task>
							</soapenv:Body>
						</soapenv:Envelope>
					XML
				)

				local DEL_HTTP_CODE
				DEL_HTTP_CODE=$(
					curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_datastores_browse_delete" -X POST \
						-H "Content-Type: text/xml; charset=UTF-8" \
						-H "SOAPAction: \"urn:vim25/8.0\"" \
						-d "${DELETEFILE_XML}" \
						-b "${COOKIE_FILE}" \
						"https://${ESXI_HOSTNAME}/sdk" \
						2>&1
				)

				if [[ "${DEL_HTTP_CODE}" == "200" ]]
				then
					local DEL_TASKID
					DEL_TASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' "${BASHAPP_TMPDIR}/cmd_datastores_browse_delete")
					cmd_tasks_monitor "${DEL_TASKID}" 120 true "deleting ${SELECTED_NAME}"
				else
					log_error "function: ${FUNCNAME[0]}, ✗ delete failed (HTTP ${DEL_HTTP_CODE})"
					log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_datastores_browse_delete")"
				fi
				continue
				;;

			ctrl-r)

				log_debug "function: ${FUNCNAME[0]}, ctrl-r pressed"

				[[ -z "${SELECTED_NAME}" ]] && continue
				# protect the "." and ".." folders from renaming
				[[ "${SELECTED_NAME}" == "." || "${SELECTED_NAME}" == ".." ]] && continue

				local RENAME_SRCPATH
				if [[ "${CURRENT_PATH}" == "[${DATASTORENAME}]" ]]
				then
					RENAME_SRCPATH="[${DATASTORENAME}] ${SELECTED_NAME}"
				else
					RENAME_SRCPATH="${CURRENT_PATH}/${SELECTED_NAME}"
				fi

				echo ""
				read -e -r -p "Rename '${SELECTED_NAME}' to (Press Enter to skip renaming): " NEW_NAME
				[[ -z "${NEW_NAME}" ]] && continue

				local RENAME_DESTPATH
				if [[ "${CURRENT_PATH}" == "[${DATASTORENAME}]" ]]
				then
					RENAME_DESTPATH="[${DATASTORENAME}] ${NEW_NAME}"
				else
					RENAME_DESTPATH="${CURRENT_PATH}/${NEW_NAME}"
				fi

				local RENAMEFILE_XML
				RENAMEFILE_XML=$(
					cat <<- XML
						<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
							<soapenv:Body>
								<MoveDatastoreFile_Task xmlns="urn:vim25">
									<_this type="FileManager">ha-nfc-file-manager</_this>
									<sourceName>${RENAME_SRCPATH}</sourceName>
									<sourceDatacenter type="Datacenter">ha-datacenter</sourceDatacenter>
									<destinationName>${RENAME_DESTPATH}</destinationName>
									<destinationDatacenter type="Datacenter">ha-datacenter</destinationDatacenter>
									<force>false</force>
								</MoveDatastoreFile_Task>
							</soapenv:Body>
						</soapenv:Envelope>
					XML
				)

				local REN_HTTP_CODE
				REN_HTTP_CODE=$(
					curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_datastores_browse_rename" -X POST \
						-H "Content-Type: text/xml; charset=UTF-8" \
						-H "SOAPAction: \"urn:vim25/8.0\"" \
						-d "${RENAMEFILE_XML}" \
						-b "${COOKIE_FILE}" \
						"https://${ESXI_HOSTNAME}/sdk" \
						2>&1
				)

				if [[ "${REN_HTTP_CODE}" == "200" ]]
				then
					local REN_TASKID
					REN_TASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' "${BASHAPP_TMPDIR}/cmd_datastores_browse_rename")
					cmd_tasks_monitor "${REN_TASKID}" 60 true "renaming ${SELECTED_NAME} → ${NEW_NAME}"
				else
					log_error "function: ${FUNCNAME[0]}, ✗ rename failed (HTTP ${REN_HTTP_CODE})"
					log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_datastores_browse_rename")"
				fi
				continue
				;;

		esac

	done

}

# datastores rename command handler
cmd_datastores_rename() {

	log_debug "${FUNCNAME[0]} is called"
	
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

	#RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/xsi:type="[^"]*"//g')
	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/ xsi:type="[^"]*"//g' -e 's/val >/val>/g')
	
	log_debug "function: ${FUNCNAME[0]}, RESPONSE for the datastores list is: \n ${RESPONSE}"

	DATASTORES_SELECTED=$(
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
				  --bind 'ctrl-a:select-all' \
				  --bind 'ctrl-d:deselect-all'  \
	              --bind 'ctrl-b:become(exit 2)' \
	              --header-lines=1 \
	              --header "Select datastore(s) to rename: | ctrl-p: (un)toggle datastore's info view | ctrl-a/d: select/deselect all datastores" \
	              --layout reverse -m
	)

	local fzf_exit_code=$?
	[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
	[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
	[[ -z "${DATASTORES_SELECTED}" ]] && return

	while IFS= read -r line
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

		local DATASTOREID NAME
		#DATASTOREID=$(echo "${line}" | awk '{print $1}')
		#NAME=$(echo "${line}" | awk '{print $2}')
		DATASTOREID=$(echo "${line}" | cut -f1 | xargs)
		NAME=$(echo "${line}" | cut -f2 | xargs)
		[[ -z "${DATASTOREID}" ]] && continue

		log_debug "function: ${FUNCNAME[0]}, renaming the datastore ${DATASTOREID}"

		local NEW_DATASTORE_NAME
		read -e -r -p "Enter a name for the datastore id ${DATASTOREID} named ${NAME} to rename to: " NEW_DATASTORE_NAME < /dev/tty
		[[ -z ${NEW_DATASTORE_NAME} ]] && { log_error "function: ${FUNCNAME[0]}, no name entered, skipping renaming ..."; continue; }

		local RENAMEDATASTORE_XML
		RENAMEDATASTORE_XML=$(
			cat <<- XML
				<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:vim25">
					<soapenv:Body>
						<RenameDatastore xmlns="urn:vim25">
							<_this type="Datastore">${DATASTOREID}</_this>
							<newName>${NEW_DATASTORE_NAME}</newName>
						</RenameDatastore>
					</soapenv:Body>
				</soapenv:Envelope>
			XML
		)

		local HTTP_CODE
		HTTP_CODE=$(
			curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_datastores_rename" -X POST \
				-H "Content-Type: text/xml; charset=UTF-8" \
				-H "SOAPAction: \"urn:vim25/8.0\"" \
				-d "${RENAMEDATASTORE_XML}" \
				-b "${COOKIE_FILE}" \
				"https://${ESXI_HOSTNAME}/sdk" \
				2>&1
		)

		if [[ "${HTTP_CODE}" == "200" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, ✓ renaming of the datastore with datastoreid=${DATASTOREID} is successful (HTTP CODE ${HTTP_CODE})"
			log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_datastores_rename")"
		else
			log_error "function: ${FUNCNAME[0]}, ✗ has failed to rename the datastore with DATASTOREID = ${DATASTOREID} (HTTP CODE ${HTTP_CODE})"
			log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_datastores_rename") (HTTP CODE ${HTTP_CODE})"
		fi

	done <<< "${DATASTORES_SELECTED}"

}

# datastores refresh command handler
cmd_datastores_refresh() {

	log_debug "${FUNCNAME[0]} is called"

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

	DATASTORES_SELECTED=$(
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
		} | column -t -s $'\t' | \
		fzf --cycle \
	              --border=rounded \
	              --border-label=" ESXi host's '${ESXI_HOSTNAME}' datastores " \
	              --preview-window=right:50% \
	              --preview "cmd_datastores_info {} ${ESXI_HOSTNAME}" \
	              --preview-window=hidden --bind 'ctrl-p:toggle-preview' \
				  --bind 'ctrl-a:select-all' \
				  --bind 'ctrl-d:deselect-all'  \
	              --bind 'ctrl-b:become(exit 2)' \
	              --header-lines=1 \
	              --header "Select datastore(s) to refresh | ctrl-p: (un)toggle datastore's info view | ctrl-a/d: select/deselect all datastores" \
	              --layout reverse -m
	)

	local fzf_exit_code=$?
	[[ "${fzf_exit_code}" -eq 130 ]] && return    # Ctrl-C or Esc
	[[ "${fzf_exit_code}" -eq 2 ]] && return      # Ctrl-B
	[[ -z "${DATASTORES_SELECTED}" ]] && return

	while IFS= read -r line
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

		local DATASTOREID=$(echo "${line}" | awk '{print $1}')
		[[ -z "${DATASTOREID}" ]] && continue

		log_debug "function: ${FUNCNAME[0]}, refreshing the datastore ${DATASTOREID}"

		local REFRESHDATASTORE_XML
		REFRESHDATASTORE_XML=$(
			cat <<- XML
				<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:vim25">
					<soapenv:Body>
						<RefreshDatastoreStorageInfo xmlns="urn:vim25">
							<_this type="Datastore">${DATASTOREID}</_this>
						</RefreshDatastoreStorageInfo>
					</soapenv:Body>
				</soapenv:Envelope>
			XML
		)

		local HTTP_CODE
		HTTP_CODE=$(
			curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_datastores_refresh" -X POST \
				-H "Content-Type: text/xml; charset=UTF-8" \
				-H "SOAPAction: \"urn:vim25/8.0\"" \
				-d "${REFRESHDATASTORE_XML}" \
				-b "${COOKIE_FILE}" \
				"https://${ESXI_HOSTNAME}/sdk" \
				2>&1
		)

		if [[ "${HTTP_CODE}" == "200" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, ✓ refreshing the datastore with datastoreid=${DATASTOREID} is successful (HTTP CODE ${HTTP_CODE})"
			log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_datastores_refresh")"
		else
			log_error "function: ${FUNCNAME[0]}, ✗ has failed to refresh the datastore with DATASTOREID = ${DATASTOREID} (HTTP CODE ${HTTP_CODE})"
			log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_datastores_refresh") (HTTP CODE ${HTTP_CODE})"
		fi

	done <<< "${DATASTORES_SELECTED}"

}

# datastores unmount command handler
cmd_datastores_unmount() {

	# step 1: list and select datastore to mount
	# step 2: get datastore vmfs uuid
	# step 3: check for vms on selected datastore
	# 		  and cancel unmounting if there are registered vms there
	# step 4: get hoststoragesystem moref
	# step 5: confirm and unmount selected vmfs datastore

	log_debug "${FUNCNAME[0]} is called"

	# step 1: list and select datastore to mount
	local LISTDATASTORESXML
	LISTDATASTORESXML=$(
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
			-d "${LISTDATASTORESXML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)
	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/ xsi:type="[^"]*"//g')

	local DSSELECTED
	DSSELECTED=$(
		{
			echo -e "DATASTOREID\tNAME\tCAPACITY\tFREESPACE\tTYPE\tACCESSIBLE"
			echo "${RESPONSE}" | xmllint --xpath "//objects" - 2>/dev/null | sed 's/<\/objects>/<\/objects>\n/g' | \
			while read -r line
			do
				[[ -z "${line}" ]] && continue
				local DSID DSNAME DSCAPACITY DSFREESPACE DSTYPE DSACCESSIBLE
				DSID=$(echo "${line}"         | xmllint --xpath "string(//obj)" - 2>/dev/null)
				DSNAME=$(echo "${line}"       | xmllint --xpath "string(//propSet[name='name']/val)" - 2>/dev/null)
				DSCAPACITY=$(echo "${line}"   | xmllint --xpath "string(//propSet[name='summary.capacity']/val)" - 2>/dev/null)
				DSFREESPACE=$(echo "${line}"  | xmllint --xpath "string(//propSet[name='summary.freeSpace']/val)" - 2>/dev/null)
				DSTYPE=$(echo "${line}"       | xmllint --xpath "string(//propSet[name='summary.type']/val)" - 2>/dev/null)
				DSACCESSIBLE=$(echo "${line}" | xmllint --xpath "string(//propSet[name='summary.accessible']/val)" - 2>/dev/null)
				echo -e "${DSID}\t${DSNAME}\t$((DSCAPACITY/1073741824))GB\t$((DSFREESPACE/1073741824))GB\t${DSTYPE}\t${DSACCESSIBLE}"
			done
		} | column -t -s $'\t' -o $'\t' | \
		fzf --cycle \
			--border=rounded \
			--border-label=" ESXi host's '${ESXI_HOSTNAME}' datastores " \
			--preview-window=hidden \
			--bind 'ctrl-b:become(exit 2)' \
			--header-lines=1 \
			--header "Select datastore to unmount | ctrl-b: cancel" \
			--layout reverse
	)

	local FZFEXITCODE=$?
	[[ "${FZFEXITCODE}" -eq 130 ]] && return
	[[ "${FZFEXITCODE}" -eq 2 ]]   && return
	[[ -z "${DSSELECTED}" ]]        && return

	local DATASTOREID DATASTORENAME
	DATASTOREID=$(echo "${DSSELECTED}"   | cut -f1 | xargs)
	DATASTORENAME=$(echo "${DSSELECTED}" | cut -f2 | xargs)

	log_debug "function: ${FUNCNAME[0]}, DATASTOREID=${DATASTOREID}"
	log_debug "function: ${FUNCNAME[0]}, DATASTORENAME=${DATASTORENAME}"

	# step 2: get datastore vmfs uuid
	local GETUUIDXML
	GETUUIDXML=$(
		cat <<- XML
			<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
					<RetrievePropertiesEx xmlns="urn:vim25">
						<_this type="PropertyCollector">ha-property-collector</_this>
						<specSet>
							<propSet>
								<type>Datastore</type>
								<pathSet>info</pathSet>
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
			-d "${GETUUIDXML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	log_debug "function: ${FUNCNAME[0]}, RESPONSE=${RESPONSE}"

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/ xsi:type="[^"]*"//g')

	local VMFSUUID
	VMFSUUID=$(echo "${RESPONSE}" | xmllint --xpath "//*[local-name()='uuid']/text()" - 2>/dev/null)

	[[ -z "${VMFSUUID}" ]] && {
		log_error "function: ${FUNCNAME[0]}, ✗ failed to get VMFS UUID for ${DATASTORENAME}"
		return 1
	}

	log_debug "function: ${FUNCNAME[0]}, VMFSUUID=${VMFSUUID}"

	# step 3: check for vms on selected datastore
	local LISTVMSXML
	LISTVMSXML=$(
		cat <<- XML
			<soapenv:Envelope
				xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
				xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
				<soapenv:Body>
					<RetrievePropertiesEx xmlns="urn:vim25">
						<_this type="PropertyCollector">ha-property-collector</_this>
						<specSet>
							<propSet>
								<type>VirtualMachine</type>
								<pathSet>name</pathSet>
								<pathSet>config.files.vmPathName</pathSet>
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

	RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LISTVMSXML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)
	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/ xsi:type="[^"]*"//g')

	local VMSONDSCOUNT
	VMSONDSCOUNT=$(echo "${RESPONSE}" | xmllint --xpath "count(//propSet[name='config.files.vmPathName'][contains(val,'[${DATASTORENAME}]')])" - 2>/dev/null)

	log_debug "function: ${FUNCNAME[0]}, VMSONDSCOUNT=${VMSONDSCOUNT}"

	if [[ "${VMSONDSCOUNT}" -gt 0 ]]
	then
		log_error "function: ${FUNCNAME[0]}, ✗ cannot unmount '${DATASTORENAME}' — ${VMSONDSCOUNT} VM(s) are registered on it"
		echo ""
		echo "  The following VMs must be unregistered before unmounting:"
		echo "${RESPONSE}" | xmllint --xpath "//objects[propSet[name='config.files.vmPathName'][contains(val,'[${DATASTORENAME}]')]]" - 2>/dev/null | \
		grep -oP '(?<=<propSet><name>name<\/name><val>)[^<]+' | \
		while read -r VMNAME
		do
			echo "    - ${VMNAME}"
		done
		echo ""
		return 1
	fi

	# step 4: get hoststoragesystem moref
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
								<pathSet>configManager.storageSystem</pathSet>
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
			-d "${GETCONFIGMGRXML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)
	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/ xsi:type="[^"]*"//g')

	local STORAGESYSTEMMOREF
	STORAGESYSTEMMOREF=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='configManager.storageSystem']/val)" - 2>/dev/null)

	[[ -z "${STORAGESYSTEMMOREF}" ]] && {
		log_error "function: ${FUNCNAME[0]}, ✗ failed to get HostStorageSystem MoRef"
		return 1
	}

	log_debug "function: ${FUNCNAME[0]}, STORAGESYSTEMMOREF=${STORAGESYSTEMMOREF}"

	# step 5: confirm and unmount
	echo ""
	read -r -p "Unmount datastore '${DATASTORENAME}' (UUID: ${VMFSUUID})? [Y/N] " CONFIRM
	[[ "${CONFIRM}" != "y" && "${CONFIRM}" != "Y" ]] && return

	local UNMOUNTXML
	UNMOUNTXML=$(
		cat <<- XML
			<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
					<UnmountVmfsVolumeEx_Task xmlns="urn:vim25">
						<_this type="HostStorageSystem">${STORAGESYSTEMMOREF}</_this>
						<vmfsUuid>${VMFSUUID}</vmfsUuid>
					</UnmountVmfsVolumeEx_Task>
				</soapenv:Body>
			</soapenv:Envelope>
		XML
	)

	local HTTP_CODE
	HTTP_CODE=$(
		curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_datastores_unmount" -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${UNMOUNTXML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	log_debug "function: ${FUNCNAME[0]}, HTTP_CODE=${HTTP_CODE}"
	log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_datastores_unmount")"

	if [[ "${HTTP_CODE}" == "200" ]]
	then
		log_debug "function: ${FUNCNAME[0]}, ✓ datastore ${DATASTORENAME} has been unmounted successfully (HTTP CODE ${HTTP_CODE})"
		log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_datastores_unmount")"

		local TASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' "${BASHAPP_TMPDIR}/cmd_datastores_unmount")

		if [[ -n "${TASKID}" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, unmounting datastore task created: ${TASKID}"
    
			if cmd_tasks_monitor "${TASKID}" 120 true "unmounting datastore ${DATASTORENAME}"
			then
				log_debug "function: ${FUNCNAME[0]}, ✓ datastore ${DATASTORENAME} has been unmounted successfully"
			else
				log_error "function: ${FUNCNAME[0]}, ✗ has failed to unmount datastore ${DATASTORENAME}"
			fi

		else
			log_error "function: ${FUNCNAME[0]}, no TASK ID returned"
		fi

	else
		log_error "function: ${FUNCNAME[0]}, ✗ has failed to unmount datastore ${DATASTORENAME} (HTTP CODE ${HTTP_CODE})"
		log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_datastores_unmount") (HTTP CODE ${HTTP_CODE})"
	fi

}

# datastores mount command handler
cmd_datastores_mount() {

	# step 1: list and select datastore to mount
	# step 2: get datastore vmfs uuid
	# step 3: get hoststoragesystem moref 
	# step 4: confirm and mount selected vmfs datastore

	log_debug "${FUNCNAME[0]} is called"

	# step 1: list and select datastore to mount
	local LISTDATASTORESXML
	LISTDATASTORESXML=$(
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
			-d "${LISTDATASTORESXML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)
	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/ xsi:type="[^"]*"//g')

	local DSSELECTED
	DSSELECTED=$(
		{
			echo -e "DATASTOREID\tNAME\tCAPACITY\tFREESPACE\tTYPE\tACCESSIBLE"
			echo "${RESPONSE}" | xmllint --xpath "//objects" - 2>/dev/null | sed 's/<\/objects>/<\/objects>\n/g' | \
			while read -r line
			do
				[[ -z "${line}" ]] && continue
				local DSID DSNAME DSCAPACITY DSFREESPACE DSTYPE DSACCESSIBLE
				DSID=$(echo "${line}"         | xmllint --xpath "string(//obj)" - 2>/dev/null)
				DSNAME=$(echo "${line}"       | xmllint --xpath "string(//propSet[name='name']/val)" - 2>/dev/null)
				DSCAPACITY=$(echo "${line}"   | xmllint --xpath "string(//propSet[name='summary.capacity']/val)" - 2>/dev/null)
				DSFREESPACE=$(echo "${line}"  | xmllint --xpath "string(//propSet[name='summary.freeSpace']/val)" - 2>/dev/null)
				DSTYPE=$(echo "${line}"       | xmllint --xpath "string(//propSet[name='summary.type']/val)" - 2>/dev/null)
				DSACCESSIBLE=$(echo "${line}" | xmllint --xpath "string(//propSet[name='summary.accessible']/val)" - 2>/dev/null)
				echo -e "${DSID}\t${DSNAME}\t$((DSCAPACITY/1073741824))GB\t$((DSFREESPACE/1073741824))GB\t${DSTYPE}\t${DSACCESSIBLE}"
			done
		} | column -t -s $'\t' -o $'\t' | \
		fzf --cycle \
			--border=rounded \
			--border-label=" ESXi host's '${ESXI_HOSTNAME}' datastores " \
			--preview-window=hidden \
			--bind 'ctrl-b:become(exit 2)' \
			--header-lines=1 \
			--header "Select datastore to unmount | ctrl-b: cancel" \
			--layout reverse
	)

	local FZFEXITCODE=$?
	[[ "${FZFEXITCODE}" -eq 130 ]] && return
	[[ "${FZFEXITCODE}" -eq 2 ]]   && return
	[[ -z "${DSSELECTED}" ]]        && return

	local DATASTOREID DATASTORENAME
	DATASTOREID=$(echo "${DSSELECTED}"   | cut -f1 | xargs)
	DATASTORENAME=$(echo "${DSSELECTED}" | cut -f2 | xargs)

	log_debug "function: ${FUNCNAME[0]}, DATASTOREID=${DATASTOREID}"
	log_debug "function: ${FUNCNAME[0]}, DATASTORENAME=${DATASTORENAME}"

	# step 2: get datastore vmfs uuid
	local GETUUIDXML
	GETUUIDXML=$(
		cat <<- XML
			<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
					<RetrievePropertiesEx xmlns="urn:vim25">
						<_this type="PropertyCollector">ha-property-collector</_this>
						<specSet>
							<propSet>
								<type>Datastore</type>
								<pathSet>info</pathSet>
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
			-d "${GETUUIDXML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	log_debug "function: ${FUNCNAME[0]}, RESPONSE=${RESPONSE}"

	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/ xsi:type="[^"]*"//g')

	local VMFSUUID
	VMFSUUID=$(echo "${RESPONSE}" | xmllint --xpath "//*[local-name()='uuid']/text()" - 2>/dev/null)

	[[ -z "${VMFSUUID}" ]] && {
		log_error "function: ${FUNCNAME[0]}, ✗ failed to get VMFS UUID for ${DATASTORENAME}"
		return 1
	}

	log_debug "function: ${FUNCNAME[0]}, VMFSUUID=${VMFSUUID}"

	# step 3: get hoststoragesystem moref 
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
								<pathSet>configManager.storageSystem</pathSet>
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
			-d "${GETCONFIGMGRXML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)
	RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/ xsi:type="[^"]*"//g')

	local STORAGESYSTEMMOREF
	STORAGESYSTEMMOREF=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='configManager.storageSystem']/val)" - 2>/dev/null)

	[[ -z "${STORAGESYSTEMMOREF}" ]] && {
		log_error "function: ${FUNCNAME[0]}, ✗ failed to get HostStorageSystem MoRef"
		return 1
	}

	log_debug "function: ${FUNCNAME[0]}, STORAGESYSTEMMOREF=${STORAGESYSTEMMOREF}"

	# step 4: confirm and mount selected vmfs datastore
	echo ""
	read -r -p "Mount datastore '${DATASTORENAME}' (UUID: ${VMFSUUID})? [Y/N] " CONFIRM
	[[ "${CONFIRM}" != "y" && "${CONFIRM}" != "Y" ]] && return

	local MOUNTXML
	MOUNTXML=$(
		cat <<- XML
			<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
					<MountVmfsVolumeEx_Task xmlns="urn:vim25">
						<_this type="HostStorageSystem">${STORAGESYSTEMMOREF}</_this>
						<vmfsUuid>${VMFSUUID}</vmfsUuid>
					</MountVmfsVolumeEx_Task>
				</soapenv:Body>
			</soapenv:Envelope>
		XML
	)

	local HTTP_CODE
	HTTP_CODE=$(
		curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/cmd_datastores_mount" -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${MOUNTXML}" \
			-b "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	log_debug "function: ${FUNCNAME[0]}, HTTP_CODE=${HTTP_CODE}"
	log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_datastores_mount")"

	if [[ "${HTTP_CODE}" == "200" ]]
	then
		log_debug "function: ${FUNCNAME[0]}, ✓ datastore ${DATASTORENAME} has been mounted successfully (HTTP CODE ${HTTP_CODE})"
		log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_datastores_mount")"

		local TASKID=$(grep -oP '(?<=<returnval type="Task">)[^<]+' "${BASHAPP_TMPDIR}/cmd_datastores_mount")

		if [[ -n "${TASKID}" ]]
		then
			log_debug "function: ${FUNCNAME[0]}, mounting datastore task created: ${TASKID}"
    
			if cmd_tasks_monitor "${TASKID}" 120 true "mounting datastore ${DATASTORENAME}"
			then
				log_debug "function: ${FUNCNAME[0]}, ✓ datastore ${DATASTORENAME} has been mounted successfully"
			else
				log_error "function: ${FUNCNAME[0]}, ✗ has failed to mount datastore ${DATASTORENAME}"
			fi

		else
			log_error "function: ${FUNCNAME[0]}, no TASK ID returned"
		fi

	else
		log_error "function: ${FUNCNAME[0]}, ✗ has failed to mount datastore ${DATASTORENAME} (HTTP CODE ${HTTP_CODE})"
		log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/cmd_datastores_mount") (HTTP CODE ${HTTP_CODE})"
	fi

}

# datastores unknown command handler
cmd_datastores_unknown() {

	log_debug "${FUNCNAME[0]} is called"

	local ACTION="$1"

	log_error "function: ${FUNCNAME[0]}, unknown command '${ACTION}' for datastores action."

	echo "Unknown datastores command: ${ACTION}"
	echo "Use '${BASHAPP_NAME}' help or/and documentation for the correct usage information"

}
