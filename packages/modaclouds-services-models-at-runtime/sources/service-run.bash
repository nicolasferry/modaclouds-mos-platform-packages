#!/bin/bash

set -e -E -u -o pipefail -o noclobber -o noglob +o braceexpand || exit 1
trap 'printf "[ee] failed: %s\n" "${BASH_COMMAND}" >&2' ERR || exit 1

if test "$( getent passwd -- mos-services | cut -f 3 -d : || printf '%s' "${UID}" )" -ne "${UID}" ; then
	exec sudo -u mos-services -g mos-services -E -n -- "${0}" "${@}"
	exit 1
fi

if ! test "${#}" -eq 0 ; then
	printf '[ii] invalid arguments; aborting!\n' >&2
	exit 1
fi

umask 0027

exec </dev/null >&2


_variable_defaults=(
		
		_MRT_DISTRIBUTION='@{definitions:environment:MRT_DISTRIBUTION}'
		_MRT_ENDPOINT_IP='@{definitions:environment:MRT_ENDPOINT_IP}'
		_MRT_ENDPOINT_PORT='@{definitions:environment:MRT_ENDPOINT_PORT}'
		
		_LOAD_BALANCER_CONTROLLER_ENDPOINT_IP='@{definitions:environment:MODACLOUDS_LOAD_BALANCER_CONTROLLER_ENDPOINT_IP}'
		_LOAD_BALANCER_CONTROLLER_ENDPOINT_PORT='@{definitions:environment:MODACLOUDS_LOAD_BALANCER_CONTROLLER_ENDPOINT_PORT}'
		
		_MONITORING_MANAGER_ENDPOINT_IP='@{definitions:environment:MODACLOUDS_MONITORING_MANAGER_ENDPOINT_IP}'
		_MONITORING_MANAGER_ENDPOINT_PORT='@{definitions:environment:MODACLOUDS_MONITORING_MANAGER_ENDPOINT_PORT}'
		
		_JAVA_HOME='@{definitions:environment:JAVA_HOME}'
		_PATH='@{definitions:environment:PATH}'
		_TMPDIR='@{definitions:environment:TMPDIR}'
)
declare "${_variable_defaults[@]}"


if test -n "${modaclouds_service_temporary:-}" ; then
	_TMPDIR="${modaclouds_service_temporary:-}"
elif test -n "${modaclouds_temporary:-}" ; then
	_TMPDIR="${modaclouds_temporary}/services/${_identifier}"
else
	_TMPDIR="${_TMPDIR}/${_identifier}"
fi


_variable_overrides=(
		
		_MRT_DISTRIBUTION="${MODACLOUDS_MODELS_AT_RUNTIME_DISTRIBUTION:-${_MRT_DISTRIBUTION}}"
		_MRT_ENDPOINT_IP="${MODACLOUDS_MODELS_AT_RUNTIME_ENDPOINT_IP:-${_MRT_ENDPOINT_IP}}"
		_MRT_ENDPOINT_PORT="${MODACLOUDS_MODELS_AT_RUNTIME_ENDPOINT_PORT:-${_MRT_ENDPOINT_PORT}}"
		
		
		_LOAD_BALANCER_CONTROLLER_ENDPOINT_IP="${MODACLOUDS_MODELS_AT_RUNTIME_DISTRIBUTION:-${_LOAD_BALANCER_CONTROLLER_ENDPOINT_IP}}"
		_LOAD_BALANCER_CONTROLLER_ENDPOINT_PORT="${MODACLOUDS_MODELS_AT_RUNTIME_DISTRIBUTION:-${_LOAD_BALANCER_CONTROLLER_ENDPOINT_PORT}}"
		_MONITORING_MANAGER_ENDPOINT_IP="${MODACLOUDS_MODELS_AT_RUNTIME_DISTRIBUTION:-${_MONITORING_MANAGER_ENDPOINT_IP}}"
		_MONITORING_MANAGER_ENDPOINT_PORT="${MODACLOUDS_MODELS_AT_RUNTIME_DISTRIBUTION:-${_MONITORING_MANAGER_ENDPOINT_PORT}}"
		
		_JAVA_HOME="${MODACLOUDS_MODELS_AT_RUNTIME_JAVA_HOME:-${_JAVA_HOME}}"
		_PATH="${MODACLOUDS_MODELS_AT_RUNTIME_PATH:-${_PATH}}"
		_TMPDIR="${MODACLOUDS_MODELS_AT_RUNTIME_TMPDIR:-${_TMPDIR}}"
)
declare "${_variable_overrides[@]}"


export PATH="${_PATH}"


if test ! -e "${_TMPDIR}" ; then
	mkdir -p -- "${_TMPDIR}"
	mkdir -- "${_TMPDIR}/tmp"
	mkdir -- "${_TMPDIR}/home"
fi


exec {_lock}<"${_TMPDIR}"
if ! flock -x -n "${_lock}" ; then
	printf '[ee] failed to acquire lock; aborting!\n' >&2
	exit 1
fi


if test -d "${_TMPDIR}/cwd" ; then
	chmod -R u+w -- "${_TMPDIR}/cwd"
	rm -R -- "${_TMPDIR}/cwd"
fi
mkdir -- "${_TMPDIR}/cwd"

cd -- "${_TMPDIR}/cwd"


_environment=(
		PATH="${_PATH}"
		TMPDIR="${_TMPDIR}/tmp"
		HOME="${_TMPDIR}/home"
		USER='modaclouds-services'
)


_environment+=(
		MODACLOUDS_MODELS_AT_RUNTIME_ENDPOINT_IP="${_MRT_ENDPOINT_IP}"
		MODACLOUDS_MODELS_AT_RUNTIME_ENDPOINT_PORT="${_MRT_ENDPOINT_PORT}"
)


printf '[--]\n' >&2
printf '[ii] parameters:\n' >&2
printf '[ii]   * environment:\n' >&2
for _variable in "${_environment[@]}" ; do
	printf '[ii]       * `%s`;\n' "${_variable}" >&2
done
printf '[ii]   * workding directory: `%s`;\n' "${PWD}" >&2
printf '[--]\n' >&2

printf '[ii] starting service...\n' >&2
printf '[--]\n' >&2


exec \
	env \
			-i "${_environment[@]}" \
	"${_JAVA_HOME}/bin/java" \
			-jar "${_MRT_DISTRIBUTION}/service.jar"


exit 1

