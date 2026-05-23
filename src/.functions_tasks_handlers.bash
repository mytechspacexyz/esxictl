# tasks commands handlers functions

# tasks monitor command handler
cmd_tasks_monitor() {

	log_debug "${FUNCNAME[0]} is called"

	local TASKID="$1"

	[[ -z "${TASKID}" ]] && { log_error "function: ${FUNCNAME[0]}, task id is not set!" && return; }
	# default 5 minutes timeout
	local MAXWAIT="${2:-300}"
	# show task progress or not in the debug logs (default: false)
	local SHOW_PROGRESS="${3:-true}"
	# label for visual progress
	local LABEL="${4:-processing task}"
	# elapsed time
	local ELAPSED=0

	# braille spinner frames
	local FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
	local FRAME_IDX=0

	# ANSI color codes
	local BLUE='\033[0;34m'
	local GREEN='\033[0;32m'
	local RED='\033[0;31m'
	local BOLD='\033[1m'
	local NC='\033[0m'

	# hide cursor, restore on any exit
	printf '\033[?25l'
	trap 'printf "\033[?25h"' RETURN INT TERM EXIT
    
	log_debug "function: ${FUNCNAME[0]}, monitoring task: ${TASKID}"
    
	while [[ "${ELAPSED}" -lt "${MAXWAIT}" ]]
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

		local TASK_XML
		TASK_XML=$(
			cat <<- XML
				<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
					<soapenv:Body>
						<RetrieveProperties xmlns="urn:vim25">
							<_this type="PropertyCollector">ha-property-collector</_this>
							<specSet>
								<propSet>
									<type>Task</type>
									<pathSet>info.state</pathSet>
									<pathSet>info.progress</pathSet>
									<pathSet>info.error</pathSet>
									<pathSet>info.startTime</pathSet>
									<pathSet>info.completeTime</pathSet>
								</propSet>
								<objectSet>
									<obj type="Task">${TASKID}</obj>
								</objectSet>
							</specSet>
						</RetrieveProperties>
					</soapenv:Body>
				</soapenv:Envelope>
			XML
		)
        
		local RESPONSE=$(
			curl ${CURL_OPTS} ${CACERT} -X POST \
				-H "Content-Type: text/xml; charset=UTF-8" \
				-H "SOAPAction: \"urn:vim25/8.0\"" \
				-d "${TASK_XML}" \
				-b "${COOKIE_FILE}" \
				"https://${ESXI_HOSTNAME}/sdk" \
				2>&1
		)
        
		RESPONSE=$(echo "${RESPONSE}" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g')
        
		local TASK_STATE=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='info.state']/val)" - 2>/dev/null)
		local PROGRESS=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='info.progress']/val)" - 2>/dev/null)
		local ERROR=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='info.error']//localizedMessage)" - 2>/dev/null)
		local TASK_STARTTIME=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='info.startTime']/val)" - 2>/dev/null)
		local TASK_COMPLETETIME=$(echo "${RESPONSE}" | xmllint --xpath "string(//propSet[name='info.completeTime']/val)" - 2>/dev/null)
        
		[[ "${SHOW_PROGRESS}" == "true" && -n "${PROGRESS}" && "${PROGRESS}" != "-1" ]] && \
		log_debug "function: ${FUNCNAME[0]}, task '${TASKID}' progress: ${PROGRESS}%"
        
        case "${TASK_STATE}" in
            success)
				log_debug "function: ${FUNCNAME[0]}, task ${TASKID} has started at ${TASK_STARTTIME}"
				log_debug "function: ${FUNCNAME[0]}, task ${TASKID} has completed at ${TASK_COMPLETETIME}"
                log_debug "function: ${FUNCNAME[0]}, task ${TASKID} completed successfully"
				printf "\r\033[K${GREEN}✔${NC} ${BOLD}%s${NC} Done!\n" "${LABEL}"
				printf '\033[?25h'
				trap - RETURN INT TERM EXIT
                return 0
                ;;
            error)
				log_debug "function: ${FUNCNAME[0]}, task ${TASKID} has started at ${TASK_STARTTIME}"
				log_debug "function: ${FUNCNAME[0]}, task ${TASKID} has completed at ${TASK_COMPLETETIME}"
                log_error "function: ${FUNCNAME[0]}, task ${TASKID} failed: ${ERROR:-Unknown error}"
				printf "\r\033[K${RED}✗${NC} ${BOLD}%s${NC} Failed: %s\n" "${LABEL}" "${ERROR:-Unknown error}"
				printf '\033[?25h'
				trap - RETURN INT TERM EXIT
                return 1
                ;;
            running|queued)
				local FRAME="${FRAMES[$((FRAME_IDX % 10))]}"
				printf "\r\033[K ${BLUE}%s${NC} ${BOLD}%s${NC}%s" "${FRAME}" "${LABEL}" "${PROGRESS_SUFFIX}"
				((FRAME_IDX++))
                sleep 0.5
                ((ELAPSED+=2))
                ;;
            *)
                log_error "function: ${FUNCNAME[0]}, unknown task '${TASKID}' state: ${TASK_STATE}"
				printf "\r\033[K${RED}✗${NC} ${BOLD}%s${NC} Failed: unknown task state '%s'\n" "${LABEL}" "${TASK_STATE}"
				printf '\033[?25h'
				trap - RETURN INT TERM EXIT
                return 1
                ;;
        esac

    done
    
    log_error "function: ${FUNCNAME[0]}, task '${TASKID}' timed out after ${MAXWAIT}s"
	printf "\r\033[K${RED}✗${NC} ${BOLD}%s${NC} Timed out after %ss\n" "${LABEL}" "${MAXWAIT}"
	printf '\033[?25h'
	trap - RETURN INT TERM EXIT
    return 1

}
