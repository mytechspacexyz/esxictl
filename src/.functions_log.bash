# Logging functions
log_info() {
	# $1 is an info message
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') [INFO]: $1" >> "${BASHAPP_DIR}/${BASHAPP_LOGDIR}/${BASHAPP_LOGFILE}"
}
export -f log_info

log_warning() {
	# $1 is an warning message
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') [WARNING]: $1" >> "${BASHAPP_DIR}/${BASHAPP_LOGDIR}/${BASHAPP_LOGFILE}"
}
export -f log_warning

log_error() {
	# $1 is an error message
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') [ERROR]: $1" >> "${BASHAPP_DIR}/${BASHAPP_LOGDIR}/${BASHAPP_LOGFILE}"
}
export -f log_error

log_debug() {
	# $1 is a debug message
	if [[ "$DEBUGAPP" -eq 1 ]]
	then
		echo -e "$(date '+%Y-%m-%d %H:%M:%S') [DEBUG]: $1" >> "${BASHAPP_DIR}/${BASHAPP_LOGDIR}/${BASHAPP_LOGFILE}"
	fi
}
export -f log_debug
