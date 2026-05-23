# Various init functions

# cleanup function when app exits
cleanup_and_exit() {

	log_debug "${FUNCNAME[0]} is called"

	# disarm the trap first so not to be called twice
	trap - EXIT INT

	# stopping active session keepalive
	esxi_session_keepalive_stop

	# logging out if not yet
	esxi_session_logout
	
	log_debug "${FUNCNAME[0]}, deleting temp files from the bash app temp folder ${BASHAPP_TMPDIR}/"
	[[ -d "${BASHAPP_TMPDIR}" ]] && { rm -f "${BASHAPP_TMPDIR}"/cmd_*; \
									  rm -f "${BASHAPP_TMPDIR}"/check_app_connectivity; \
									  rm -f "${BASHAPP_TMPDIR}"/esxi_session_login; \
									  rm -f "${BASHAPP_TMPDIR}"/esxi_session_logout; \
									  rm -f "${BASHAPP_TMPDIR}"/session_keepalive_response
									}

	log_debug "${FUNCNAME[0]}, deleting the esxi login session cookie file ${COOKIE_FILE}"
	[[ -f "${COOKIE_FILE}" ]] && rm -f "${COOKIE_FILE}"

	log_info "${FUNCNAME[0]}, ${BASHAPP_NAME} has finished."

    exit 0 # Exit cleanly
}

# check for app dependencies function
check_for_app_deps() {

	log_debug "${FUNCNAME[0]} is called"

	if [[ -f ${BASHAPP_DIR}/.deps ]]
	then
		while IFS= read -r line
		do
    		if [[ -z "$line" || "$line" =~ ^# ]]; then
        		continue
    		fi
			
			if ! command -v "$line" &> /dev/null
			then
				echo "'$line' is a required dependency but does not exist. Please install it or add to the PATH."
				log_error "function: ${FUNCNAME[0]}, '$line' is a required dependency but does not exist. Please install it or add to the PATH."
				exit 1
			fi

		done < "${BASHAPP_DIR}"/.deps
	else
		log_error "function: ${FUNCNAME[0]}, There is no .deps file in the bash application folder."
		echo "There is no .deps file in the bash application folder."
		exit 1
	fi
}

# check app connectivity function
check_app_connectivity() {

	log_debug "${FUNCNAME[0]} is called"

    if [[ -n "${ESXI_HOSTNAME}" && \
		  -n "${ESXI_USERNAME}" && \
		  -n "${ESXI_PWD}" && \
		  -n "${CACERT}" ]]
    then

		log_debug "function: ${FUNCNAME[0]}, if #1"
		log_debug "function: ${FUNCNAME[0]}, ESXI_HOSTNAME = ${ESXI_HOSTNAME}"
		log_debug "function: ${FUNCNAME[0]}, ESXI_USERNAME = ${ESXI_USERNAME}"
		# uncomment the below ESXI_PWD lines debug log if absolutely needed!
		#log_debug "function: ${FUNCNAME[0]}, ESXI_PWD = ${ESXI_PWD}"
		#log_debug "function: ${FUNCNAME[0]}, ESXI_PWD = $(echo "${ESXI_PWD}" | base64 -d)"
		log_debug "function: ${FUNCNAME[0]}, CURL_OPTS = ${CURL_OPTS}"
		log_debug "function: ${FUNCNAME[0]}, CACERT = ${CACERT}"

		esxi_session_login || { echo "The authentication, network connectivity error or some other error."; \
								echo "Check the credentials and the network connectivity. Exiting..."; \
								log_error "function: ${FUNCNAME[0]}, the authentication, network connectivity error or some other error"; \
								log_error "function: ${FUNCNAME[0]}, check the credentials and the network connectivity. Exiting...";
								exit 1
							  }
		esxi_session_keepalive_start

	else
        echo "Some essential vars are not set. Please reference the documentation and examples, and set them in the .configvars file in the app's folder."
        log_error function: ${FUNCNAME[0]}, "Some essential vars are not set. Please reference the documentation and examples, and set them in the .configvars file in the app's folder."
        exit 1
    fi

}

# check esxi version function
check_esxi_version() {

	log_debug "${FUNCNAME[0]} is called"

	[[ -z "${ESXI_HOSTNAME}" ]]	&& return

	local HTTP_RESPONSE=$(
		curl ${CURL_OPTS} ${CACERT} -X GET \
			"https://${ESXI_HOSTNAME}/sdk/vimServiceVersions.xml" \
			2>&1
	)	
	
	ESXI_VERSION=$(echo "${HTTP_RESPONSE}" | xmllint --xpath "string(/namespaces/namespace/version)" - 2>/dev/null)

	log_debug "function: ${FUNCNAME[0]}, ESXI_VERSION = ${ESXI_VERSION}"
	log_debug "function: ${FUNCNAME[0]}, ${HTTP_RESPONSE}"

	if [[ "${ESXI_VERSION}" =~ ^[6-9]\.[0-9]+(\.[0-9]+)+ ]]
	then

		log_debug "function: ${FUNCNAME[0]}, if #1"

		log_debug "ESXI version is ${ESXI_VERSION}"
	else
		log_error "ESXI version of ${ESXI_VERSION} is not supported"
		exit 1
	fi

}

# active session login
esxi_session_login() {

	log_debug "${FUNCNAME[0]} is called"

	# active login session exists, skipping login then ...
	[[ -f "${COOKIE_FILE}" ]] && { log_debug "function: ${FUNCNAME[0]}, active session alive, skipping login"; return 0; }

	local LOGIN_XML
	LOGIN_XML=$(
		cat <<- XML
			<soapenv:Envelope 
				xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" 
				xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" 
				xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
				xmlns:xsd="http://www.w3.org/2001/XMLSchema">
				<soapenv:Body>
					<Login xmlns="urn:vim25">
						<_this type="SessionManager">ha-sessionmgr</_this>
						<userName>${ESXI_USERNAME}</userName>
						<password>$(echo -n "${ESXI_PWD}" | base64 -d)</password>
					</Login>
				</soapenv:Body>
			</soapenv:Envelope>
		XML
	)

	local HTTP_CODE
	HTTP_CODE=$(
		curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/esxi_session_login" -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
			-H "SOAPAction: \"urn:vim25/8.0\"" \
			-d "${LOGIN_XML}" \
			-c "${COOKIE_FILE}" \
			"https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	if [[ "${HTTP_CODE}" == "200" ]]
	then
		log_debug "function: ${FUNCNAME[0]}, ✓ login to the esxi host ${ESXI_HOSTNAME} is successful (HTTP CODE ${HTTP_CODE})"
		log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/esxi_session_login")"
		return 0
	else
		log_error "function: ${FUNCNAME[0]}, ✗ has failed to log in to the esxi host ${ESXI_HOSTNAME} (HTTP CODE ${HTTP_CODE})"
		log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/esxi_session_login")"
		return 1
	fi

}

# active session logout
esxi_session_logout() {

	log_debug "${FUNCNAME[0]} is called"

	[[ ! -f "${COOKIE_FILE}" ]] && { log_debug "function: ${FUNCNAME[0]}, no active api session, skipping logout"; return 0; }

	local LOGOUT_XML
	LOGOUT_XML=$(
		cat <<- XML
			<soapenv:Envelope 
				xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" 
				xmlns:urn="urn:vim25">
					<soapenv:Body>
						<Logout xmlns="urn:vim25">
							<_this type="SessionManager">ha-sessionmgr</_this>
						</Logout>
					</soapenv:Body>
			</soapenv:Envelope>
		XML
	)

	local HTTP_CODE
	HTTP_CODE=$(
		curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/esxi_session_logout" -X POST \
			-H "Content-Type: text/xml; charset=UTF-8" \
	        -H "SOAPAction: \"urn:vim25/8.0\"" \
	        -d "${LOGOUT_XML}" \
	        -b "${COOKIE_FILE}" \
	        "https://${ESXI_HOSTNAME}/sdk" \
			2>&1
	)

	if [[ "$HTTP_CODE" == "200" ]]
	then
		log_debug "function: ${FUNCNAME[0]}, ✓ logout is successful (HTTP CODE ${HTTP_CODE})"
		log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/esxi_session_logout")"
	else
		log_error "function: ${FUNCNAME[0]}, ✗ has failed to log out (HTTP CODE ${HTTP_CODE})"
		log_error "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/esxi_session_logout")"
	fi

}

# active session keepalive start
esxi_session_keepalive_start() {

	local KEEPALIVE_INTERVAL=600
	local KEEPALIVEFILE="${BASHAPP_TMPDIR}/session_keepalive"

	touch "${KEEPALIVEFILE}"

	(
		while [[ -f "${KEEPALIVEFILE}" ]]
		do
			local KEEPALIVE_XML
			KEEPALIVE_XML=$(
				cat <<- XML
					<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
						<soapenv:Body>
							<CurrentTime xmlns="urn:vim25">
								<_this type="ServiceInstance">ServiceInstance</_this>
							</CurrentTime>
						</soapenv:Body>
					</soapenv:Envelope>
				XML
			)

			local KEEPALIVE_HTTP_CODE
			KEEPALIVE_HTTP_CODE=$(
				curl ${CURL_OPTS} ${CACERT} -w "%{http_code}" -o "${BASHAPP_TMPDIR}/session_keepalive_response" -X POST \
					-H "Content-Type: text/xml; charset=UTF-8" \
					-H "SOAPAction: \"urn:vim25/8.0\"" \
					-d "${KEEPALIVE_XML}" \
					-b "${COOKIE_FILE}" \
					--silent \
					"https://${ESXI_HOSTNAME}/sdk" \
					2>&1
			)

			log_debug "function: ${FUNCNAME[0]}, KEEPALIVE_HTTP_CODE=${KEEPALIVE_HTTP_CODE}"
			log_debug "function: ${FUNCNAME[0]}, $(cat "${BASHAPP_TMPDIR}/session_keepalive_response")"

			local KEEPALIVE_RESPONSE
			KEEPALIVE_RESPONSE=$(cat "${BASHAPP_TMPDIR}/session_keepalive_response" | sed -e 's/xmlns="[^"]*"//g' -e 's/soapenv://g' -e 's/ xsi:type="[^"]*"//g')

			local SESSION_ACTIVE
			SESSION_ACTIVE=$(echo "${KEEPALIVE_RESPONSE}" | xmllint --xpath "string(//returnval)" - 2>/dev/null)

			log_debug "function: ${FUNCNAME[0]}, SESSION_ACTIVE=${SESSION_ACTIVE}"

			if [[ "${KEEPALIVE_HTTP_CODE}" != "200" ]]
			then
				log_error "function: ${FUNCNAME[0]}, keepalive ping failed (HTTP CODE ${KEEPALIVE_HTTP_CODE}) — re-logging in"
				esxi_session_login
			elif echo "${KEEPALIVE_RESPONSE}" | grep -q "NotAuthenticated\|not authenticated\|session is not authenticated"; then
				log_error "function: ${FUNCNAME[0]}, session is no longer active — re-logging in"
				esxi_session_login
			else
				log_debug "function: ${FUNCNAME[0]}, session keepalive ping sent successfully — SESSION_ACTIVE=${SESSION_ACTIVE}"
			fi

			sleep "${KEEPALIVE_INTERVAL}"
		done
	) &

	ESXI_KEEPALIVE_PID=$!
	log_debug "function: ${FUNCNAME[0]}, session keepalive started PID=${ESXI_KEEPALIVE_PID}"

}

# active session keepalive stop
esxi_session_keepalive_stop() {
    local KEEPALIVEFILE="${BASHAPP_TMPDIR}/session_keepalive"
    rm -f "${KEEPALIVEFILE}"
    if [[ -n "${ESXI_KEEPALIVE_PID}" ]]; then
        kill "${ESXI_KEEPALIVE_PID}" 2>/dev/null
        wait "${ESXI_KEEPALIVE_PID}" 2>/dev/null
        log_debug "function: ${FUNCNAME[0]}, session keepalive stopped PID=${ESXI_KEEPALIVE_PID}"
    fi
}
