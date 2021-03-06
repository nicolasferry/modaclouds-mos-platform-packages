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


# NOTE:  The tokens starting with "at" and in brackets are replaced with values at packaging time, and serve as defaults.
#
#   To test the script, manually export the environment variables `MODACLOUDS_SERVICE_X_...` with proper values.
#
#   For example, assuming you've extracted the distribution archive to the current folder, run the following:
#
# env \
#     MODACLOUDS_SERVICE_X_PATH="${PATH}" \
#     MODACLOUDS_SERVICE_X_TMPDIR="${TMPDIR}/modaclouds-service-x" \
#     MODACLOUDS_SERVICE_X_JAVA_HOME=/opt/java \
#     MODACLOUDS_SERVICE_X_DISTRIBUTION="$( readlink -e -- ./distribution )" \
#     MODACLOUDS_SERVICE_X_ENDPOINT_IP=127.0.0.1 \
#     MODACLOUDS_SERVICE_X_ENDPOINT_PORT=8081 \
#     MODACLOUDS_SERVICE_Y_ENDPOINT_IP=127.0.0.1 \
#     MODACLOUDS_SERVICE_Y_ENDPOINT_PORT=8082 \
#     ./service-run.bash


_variable_defaults=(
		
		# NOTE:  Add other definitions that could come from the packaging descriptor, and are needed at runtime.
		#   It enables hard-coding some definitions, which could later be overriden with environment variables.
		
		_SERVICE_X_DISTRIBUTION='@{definitions:environment:SERVICE_X_DISTRIBUTION}'
		_SERVICE_X_ENDPOINT_IP='@{definitions:environment:SERVICE_X_ENDPOINT_IP}'
		_SERVICE_X_ENDPOINT_PORT='@{definitions:environment:SERVICE_X_ENDPOINT_PORT}'
		
		_SERVICE_Y_ENDPOINT_IP='@{definitions:environment:SERVICE_Y_ENDPOINT_IP}'
		_SERVICE_Y_ENDPOINT_PORT='@{definitions:environment:SERVICE_Y_ENDPOINT_PORT}'
		
		_JAVA_HOME='@{definitions:environment:JAVA_HOME}'
		_PATH='@{definitions:environment:PATH}'
		_TMPDIR='@{definitions:environment:TMPDIR}'
)
declare "${_variable_defaults[@]}"


# NOTE:  Don't touch, it enables running multiple instances of the same service at the same time.
_identifier="${modaclouds_service_identifier:-0000000000000000000000000000000000000000}"

# NOTE:  Don't touch, it tries to "auto-discover" the proper temporary folder.
if test -n "${modaclouds_service_temporary:-}" ; then
	_TMPDIR="${modaclouds_service_temporary:-}"
elif test -n "${modaclouds_temporary:-}" ; then
	_TMPDIR="${modaclouds_temporary}/services/${_identifier}"
else
	_TMPDIR="${_TMPDIR}/${_identifier}"
fi


_variable_overrides=(
		
		# NOTE:  Add the same definitions as in the previous case, but keep the pattern as bellow.
		#   It enables overriding some definitions with environment variables, or fallbacks to the hard-coded ones.
		
		_SERVICE_X_DISTRIBUTION="${MODACLOUDS_SERVICE_X_DISTRIBUTION:-${_SERVICE_X_DISTRIBUTION}}"
		_SERVICE_X_ENDPOINT_IP="${MODACLOUDS_SERVICE_X_ENDPOINT_IP:-${_SERVICE_X_ENDPOINT_IP}}"
		_SERVICE_X_ENDPOINT_PORT="${MODACLOUDS_SERVICE_X_ENDPOINT_PORT:-${_SERVICE_X_ENDPOINT_PORT}}"
		
		_SERVICE_Y_ENDPOINT_IP="${MODACLOUDS_SERVICE_Y_ENDPOINT_IP:-${_SERVICE_Y_ENDPOINT_IP}}"
		_SERVICE_Y_ENDPOINT_PORT="${MODACLOUDS_SERVICE_Y_ENDPOINT_PORT:-${_SERVICE_Y_ENDPOINT_PORT}}"
		
		_JAVA_HOME="${MODACLOUDS_SERVICE_X_JAVA_HOME:-${_JAVA_HOME}}"
		_PATH="${MODACLOUDS_SERVICE_X_PATH:-${_PATH}}"
		_TMPDIR="${MODACLOUDS_SERVICE_X_TMPDIR:-${_TMPDIR}}"
)
declare "${_variable_overrides[@]}"


export PATH="${_PATH}"


if test ! -e "${_TMPDIR}" ; then
	mkdir -p -- "${_TMPDIR}"
	mkdir -- "${_TMPDIR}/tmp"
	mkdir -- "${_TMPDIR}/home"
fi


# NOTE:  Don't touch, it tries to ensure that only one instance (with the same identifier) of the same service is running.
exec {_lock}<"${_TMPDIR}"
if ! flock -x -n "${_lock}" ; then
	printf '[ee] failed to acquire lock; aborting!\n' >&2
	exit 1
fi


# NOTE:  Don't touch, it changes the current working directory to an empty one, specific to the service instance.
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
		
		# NOTE:  Add here the environment variables you want to pass to the actual process.
		#   (I.e. just defining them in the previous sections doesn't export them.)
		
		# NOTE:  No other variables, except the ones present in the `_environment` array are exported to the service.
		#   (I.e. the service starts with a clean environment.)
		
		MODACLOUDS_SERVICE_X_ENDPOINT_IP="${_SERVICE_X_ENDPOINT_IP}"
		MODACLOUDS_SERVICE_X_ENDPOINT_PORT="${_SERVICE_X_ENDPOINT_PORT}"
		
		MODACLOUDS_SERVICE_Y_ENDPOINT_IP="${_SERVICE_X_ENDPOINT_IP}"
		MODACLOUDS_SERVICE_Y_ENDPOINT_PORT="${_SERVICE_X_ENDPOINT_PORT}"
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


# NOTE:  Actually execute the service.
exec \
	env \
			-i "${_environment[@]}" \
	"${_JAVA_HOME}/bin/java" \
			-jar "${_SERVICE_X_DISTRIBUTION}/service.jar"


exit 1
