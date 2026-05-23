# Commands handlers functions

# version command handler
cmd_version() {

	log_debug "${FUNCNAME[0]} is called"

	[[ -f ${BASHAPP_DIR}/.version ]] && cat "${BASHAPP_DIR}"/.version || echo "unknown version of the ${BASHAPP_NAME} application"
}

# describe command handler
cmd_describe() {
	
	log_debug "${FUNCNAME[0]} is called"

	[[ -f ${BASHAPP_DIR}/.description ]] && cat "${BASHAPP_DIR}"/.description || echo "There is no description for the ${BASHAPP_NAME} application"
}

# help command handler
cmd_help() {

	log_debug "${FUNCNAME[0]} is called"

	[[ -f ${BASHAPP_DIR}/.help ]] && cat ${BASHAPP_DIR}/.help || echo "currently there is no help available for the ${BASHAPP_NAME} application."
}

# setup command handler
cmd_setup() {

	log_debug "${FUNCNAME[0]} is called"

	echo

	while [[ -z "${ESXI_HOSTNAME}" || \
			 -z "${ESXI_USERNAME}" || \
			 -z "${ESXI_PWD}" || \
			 -z "${CACERT}" ]]
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

	    # Check and prompt for each variable individually
	    if [[ -z "${ESXI_HOSTNAME}" ]]
		then

			log_debug "function: ${FUNCNAME[0]}, if #1"

			local PROMPT="Enter ESXi server hostname with port (if non-standard) (esxi10.int.clusteresx.xyz): "
	        read -r -e -p "${PROMPT}" ESXI_HOSTNAME

			log_debug "function: ${FUNCNAME[0]}, array ESXI_HOSTNAME=${ESXI_HOSTNAME}"

	    fi
	
	    if [[ -z "${ESXI_USERNAME}" ]]
		then

			log_debug "function: ${FUNCNAME[0]}, if #2"

	        read -r -e -p "Enter a ESXi admin username : " ESXI_USERNAME

			log_debug "function: ${FUNCNAME[0]}, ESXI_USERNAME=${ESXI_USERNAME}"

	    fi
	    
	    if [[ -z "${ESXI_PWD}" ]]
		then

			log_debug "function: ${FUNCNAME[0]}, if #4"

			local PWD
	        read -r -s -p "Enter an ESXi admin password: " PWD
			ESXI_PWD=$(echo -n "${PWD}" | base64)
	        echo

			log_debug "function: ${FUNCNAME[0]}, ESXI_PWD=${ESXI_PWD}"

	    fi

	    if [[ -z "${CACERT}" ]]
		then

			log_debug "function: ${FUNCNAME[0]}, if #6"

	        read -r -e -p "Enter the full path to CA certificate (ESXi server(s) certificate(s) signed with): " CACERT

			log_debug "function: ${FUNCNAME[0]}, CACERT=${CACERT}"

			cp "${CACERT}" "${BASHAPP_DIR}/${BASHAPP_CONFDIR}" || { log_error "function: ${FUNCNAME[0]}, error copying the ${CACERT} into the ${BASHAPP_DIR}/${BASHAPP_CONFDIR}"; exit 1; }
			CACERT=$(basename "${CACERT}")
	    fi
	done

	log_debug "function: ${FUNCNAME[0]}, generating the ${BASHAPP_DIR}/${BASHAPP_CONFDIR}/.configvars file"

	# if we get here then all the required variables are entered and generated
	# writing them to the .configvars

	cat <<- CONFIGVARS > "${BASHAPP_DIR}/${BASHAPP_CONFDIR}/.configvars"
	export ESXI_HOSTNAME="${ESXI_HOSTNAME}"
	export ESXI_USERNAME="${ESXI_USERNAME}"
	export ESXI_PWD="${ESXI_PWD}"
	export ESXI_VERSION=""
	export COOKIE_FILE="\${BASHAPP_SESSIONS}/esxi_cookie"
	export ESXI_API_ENDPOINT="sdk"
	export CACERT="\${BASHAPP_DIR}/\${BASHAPP_CONFDIR}/$CACERT"
	CONFIGVARS

	# creating the symlink to the .configvars:

	log_debug "function: ${FUNCNAME[0]}, creating the symlink .configvars to the ${BASHAPP_CONFDIR}/.configvars"

	cd "${BASHAPP_DIR}" || { log_error "function: ${FUNCNAME[0]}, error cding into the ${BASHAPP_DIR}"; exit 1; }
	[[ ! -L .configvars ]] && ln -s "${BASHAPP_CONFDIR}/.configvars" .configvars
	chmod 600 "${BASHAPP_CONFDIR}/.configvars"

	echo "setup has been completed successfully."

}

# debug command handler
cmd_debug() {

	log_debug "${FUNCNAME[0]} is called"

	local ONOFF="$1"

	if [[ -z "${ONOFF}" ]]
	then

		log_debug "function: ${FUNCNAME[0]}, if #1"

		echo -e "Incorrect or missing argument to the debug command.\nUse '${BASHAPP_NAME} help' for usage information"
		log_error "function: ${FUNCNAME[0]}, incorrect or missing argument to the debug command"
		exit 1
	else
		if [[ "${ONOFF}" == "on" ]]
		then
			sed -i 's/^export DEBUGAPP=.*/export DEBUGAPP=1/' "${BASHAPP_DIR}/${BASHAPP_CONFDIR}"/.common_configvars
			log_info "function: ${FUNCNAME[0]}, debug mode on"
			echo "debug mode on"
		elif [[ "${ONOFF}" == "off" ]]
		then
			sed -i 's/^export DEBUGAPP=.*/export DEBUGAPP=0/' "${BASHAPP_DIR}/${BASHAPP_CONFDIR}"/.common_configvars
			log_info "function: ${FUNCNAME[0]}, debug mode off"
			echo "debug mode off"
		else
			echo "Incorrect 'debug' command argument '${ONOFF}'."
			echo "Can be only 'on' or 'off'."
			echo "Use '${BASHAPP_NAME} help' for usage information"
			log_error "function: ${FUNCNAME[0]}, incorrect 'debug' command argument '${ONOFF}'"
		fi
	fi

}

# themes command handler
cmd_themes() {

	log_debug "${FUNCNAME[0]} is called"

	local THEME
	THEME=$(
		fzf --cycle \
			--border=rounded \
			--border-label=" Themes available " \
			--header "Choose please a theme for the ${BASHAPP_NAME}:" \
			--layout reverse <<-THMS
								dark
								light
								solarized-dark
								solarized-light
								nord
								gruvbox
								tokyo-night
								monokai
								catppuccin
								rose-pine
								one-dark
								everforest
								night-owl
								synthwave
								THMS
	)

	fzf_exit_code=$?
	[[ "$fzf_exit_code" -eq 130 ]] && return		# Ctrl-C or Esc
	[[ -z "${THEME}" ]] && return

	log_debug "function: ${FUNCNAME[0]}, selected theme: ${THEME}"

	case "${THEME}" in
		dark)
			sed -i 's/^export FZF_SET_SCHEME=.*/export FZF_SET_SCHEME="${FZF_DARK_SCHEME}"/' "${BASHAPP_DIR}/${BASHAPP_CONFDIR}"/.common_configvars
			echo "${THEME} theme selected"
			;;
		light)
			sed -i 's/^export FZF_SET_SCHEME=.*/export FZF_SET_SCHEME="${FZF_LIGHT_SCHEME}"/' "${BASHAPP_DIR}/${BASHAPP_CONFDIR}"/.common_configvars
			echo "${THEME} theme selected"
			;;
		solarized-dark)
			sed -i 's/^export FZF_SET_SCHEME=.*/export FZF_SET_SCHEME="${FZF_SOLARIZED_DARK_SCHEME}"/' "${BASHAPP_DIR}/${BASHAPP_CONFDIR}"/.common_configvars
			echo "${THEME} theme selected"
			;;
		solarized-light)
			sed -i 's/^export FZF_SET_SCHEME=.*/export FZF_SET_SCHEME="${FZF_SOLARIZED_LIGHT_SCHEME}"/' "${BASHAPP_DIR}/${BASHAPP_CONFDIR}"/.common_configvars
			echo "${THEME} theme selected"
			;;
		nord)
			sed -i 's/^export FZF_SET_SCHEME=.*/export FZF_SET_SCHEME="${FZF_NORD_SCHEME}"/' "${BASHAPP_DIR}/${BASHAPP_CONFDIR}"/.common_configvars
			echo "${THEME} theme selected"
			;;
		gruvbox)
			sed -i 's/^export FZF_SET_SCHEME=.*/export FZF_SET_SCHEME="${FZF_GRUVBOX_SCHEME}"/' "${BASHAPP_DIR}/${BASHAPP_CONFDIR}"/.common_configvars
			echo "${THEME} theme selected"
			;;
		tokio-night)
			sed -i 's/^export FZF_SET_SCHEME=.*/export FZF_SET_SCHEME="${FZF_TOKIO_NIGHT_SCHEME}"/' "${BASHAPP_DIR}/${BASHAPP_CONFDIR}"/.common_configvars
			echo "${THEME} theme selected"
			;;
		monokai)
			sed -i 's/^export FZF_SET_SCHEME=.*/export FZF_SET_SCHEME="${FZF_MONOKAI_SCHEME}"/' "${BASHAPP_DIR}/${BASHAPP_CONFDIR}"/.common_configvars
			echo "${THEME} theme selected"
			;;
		catppuccin)
			sed -i 's/^export FZF_SET_SCHEME=.*/export FZF_SET_SCHEME="${FZF_CATPPUCCIN_SCHEME}"/' "${BASHAPP_DIR}/${BASHAPP_CONFDIR}"/.common_configvars
			echo "${THEME} theme selected"
			;;
		rose-pine)
			sed -i 's/^export FZF_SET_SCHEME=.*/export FZF_SET_SCHEME="${FZF_ROSE_PINE_SCHEME}"/' "${BASHAPP_DIR}/${BASHAPP_CONFDIR}"/.common_configvars
			echo "${THEME} theme selected"
			;;
		one-dark)
			sed -i 's/^export FZF_SET_SCHEME=.*/export FZF_SET_SCHEME="${FZF_ONE_DARK_SCHEME}"/' "${BASHAPP_DIR}/${BASHAPP_CONFDIR}"/.common_configvars
			echo "${THEME} theme selected"
			;;
		everforest)
			sed -i 's/^export FZF_SET_SCHEME=.*/export FZF_SET_SCHEME="${FZF_EVERFOREST_SCHEME}"/' "${BASHAPP_DIR}/${BASHAPP_CONFDIR}"/.common_configvars
			echo "${THEME} theme selected"
			;;
		night-owl)
			sed -i 's/^export FZF_SET_SCHEME=.*/export FZF_SET_SCHEME="${FZF_NIGHT_OWL_SCHEME}"/' "${BASHAPP_DIR}/${BASHAPP_CONFDIR}"/.common_configvars
			echo "${THEME} theme selected"
			;;
		synthwave)
			sed -i 's/^export FZF_SET_SCHEME=.*/export FZF_SET_SCHEME="${FZF_SYNTHWAVE_SCHEME}"/' "${BASHAPP_DIR}/${BASHAPP_CONFDIR}"/.common_configvars
			echo "${THEME} theme selected"
			;;
		*)
			log_error "function: ${FUNCNAME[0]}, unknown theme: ${THEME}"
			;;
	esac

}

# manage command handler
cmd_manage() {

	log_debug "${FUNCNAME[0]} is called"

	while true
	do

		log_debug "function: ${FUNCNAME[0]}, while loop"

		local ESXI_OBJECT
		ESXI_OBJECT=$(
			echo -e "vms\ndatastores\nnetworks\nhost" | \
			fzf --cycle \
				--border=rounded \
				--border-label=" ESXi node '${ESXI_HOSTNAME}' objects " \
				--bind 'ctrl-b:become(exit 2)' \
				--header "Choose please esxi objects to work with:" \
				--layout reverse
		)

		fzf_exit_code=$?
		[[ "$fzf_exit_code" -eq 130 ]] && break		# Ctrl-C or Esc
		[[ "$fzf_exit_code" -eq 2 ]] && continue	# Ctrl-B
		[[ -z "$ESXI_OBJECT" ]] && continue

		log_debug "function: ${FUNCNAME[0]}, selected esxi object type: ${ESXI_OBJECT}"

		case "${ESXI_OBJECT}" in
			vms)
				cmd_vms_manage
				;;
			datastores)
				cmd_datastores_manage
				;;
			networks)
				cmd_networks_manage
				;;
			host)
				cmd_host_manage
				;;
			*)
				log_error "function: ${FUNCNAME[0]}, unknown object type: ${ESXI_OBJECT}"
				;;
		esac

	done

}

# unknown command handler
cmd_unknown() {

	log_debug "${FUNCNAME[0]} is called"

	local COMMAND="$1"

	echo "Unknown command: ${COMMAND}"
	echo "Use '${BASHAPP_NAME} help' for usage information"

	log_error "Unknown command '${COMMAND}' for the ${BASHAPP_NAME}."

}

. "${BASHAPP_DIR}/${BASHAPP_SRCDIR}"/.functions_vms_handlers.bash
. "${BASHAPP_DIR}/${BASHAPP_SRCDIR}"/.functions_datastores_handlers.bash
. "${BASHAPP_DIR}/${BASHAPP_SRCDIR}"/.functions_networks_handlers.bash
. "${BASHAPP_DIR}/${BASHAPP_SRCDIR}"/.functions_host_handlers.bash
. "${BASHAPP_DIR}/${BASHAPP_SRCDIR}"/.functions_tasks_handlers.bash
