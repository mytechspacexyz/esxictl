#!/usr/bin/env bash

export BASHAPP_DIR=$(dirname "$(readlink -f "$0")")

[[ -f ${BASHAPP_DIR}/.common_configvars ]] && . "${BASHAPP_DIR}"/.common_configvars || echo "There is no .common_configvars file available in this package"
[[ -f ${BASHAPP_DIR}/.configvars ]] && . ${BASHAPP_DIR}/.configvars || echo "There is no .configvars file available in this package"
[[ -f ${BASHAPP_DIR}/${BASHAPP_SRCDIR}/.functions.bash ]] && . ${BASHAPP_DIR}/${BASHAPP_SRCDIR}/.functions.bash || echo "There is no .functions.bash file available in this package"

# Trap the SIGINT signal (Ctrl+C)
trap cleanup_and_exit INT

# Main bash application function
main() {

	log_info "${BASHAPP_NAME} is running."

	log_debug "${FUNCNAME[0]} is called"
	log_debug "with the arguments: $@"

	check_for_app_deps

    if [[ $# -eq 0 ]]
	then
        cmd_help
		log_info "${BASHAPP_NAME} has finished."
        return 0
    fi
    
    local command="$1"
    shift
    
    case "${command}" in
       "setup")
            cmd_setup
            ;;
		"debug")
			# turn debug mode on/off
			cmd_debug "$1"
            ;;
		"themes")
			cmd_themes
			;;
		"manage")
			# checking bash application connectivity and authentication
			check_app_connectivity
			check_esxi_version
			# if connectivity and authentication have succeeded
			# then proceed to the manage command handler
			cmd_manage
			;;
        "version")
            cmd_version
            ;;
        "describe")
            cmd_describe
            ;;
        "help")
            cmd_help
            ;;
        *)
			cmd_unknown "${command}"
			return 1
			;;
    esac

	cleanup_and_exit

}

# Run main bash application function with all the arguments
main "$@"
