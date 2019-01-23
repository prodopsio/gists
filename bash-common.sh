#!/bin/bash

# Common utility functions for bash scripts,
# - f -- fatal, use like `some_cmd || f "Some cmd failed"`
# - d -- debug, use like `d "This is a debug message"`
# - t -- timer, use like `t some_cmd` as a wrapper
#
# Source this bash like so: `. bash-common.sh`
#
# Debug and timer is only printed when DEBUG=1
# Output is printed as JSON when JSON_OUTPUT=1
#

f() {
    # exit process with an error message
    # use json syntax when JSON_OUTPUT is defined
    rc=$?
    if [ -z "$JSON_OUTPUT" ]; then
      echo "E $(date -u +%s%3N) ${BASH_SOURCE[1]}:${BASH_LINENO[1]}:${FUNCNAME[1]}:error:$rc: $*" >&2
    else
      echo "{\"type\":\"fatal\",\"time\":\"$(date -u +%s%3N)\",\"source\":\"${BASH_SOURCE[1]}\",\"line\":\"${BASH_LINENO[1]}\",\"func\":\"${FUNCNAME[1]}\",\"code\":\"$rc\",\"message\":\"$*\"}" \
        | jq -Sc . >&2
    fi
    exit $rc
}

d() {
    # print a debug message to stderr when DEBUG is defined;
    # use json syntax when JSON_OUTPUT is defined
    [ -z "$DEBUG" ] && return
    if [ -z "$JSON_OUTPUT" ]; then
      echo "D $(date -u +%s%3N) ${BASH_SOURCE[1]}:${BASH_LINENO[1]}:${FUNCNAME[1]}:debug: $*" >&2
    else
      echo "{\"type\":\"debug\",\"time\":\"$(date -u +%s%3N)\",\"source\":\"${BASE_SOURCE[1]}\",\"line\":\"${BASH_LINENO[1]}\",\"func\":\"${FUNCNAME[1]}\",\"message\":\"$*\"}" \
        | jq -Sc . >&2
    fi
}

t() {
    # execute a command and print its timing to stderr
    # use json syntax when JSON_OUTPUT is defined
    # in json format, capture the command stdout and stderr into json
    [ -z "$DEBUG" ] && { "$@"; return $?; }
    START=$(date +%s%3N)
    if [ -z "$JSON_OUTPUT" ]; then
      "$@"; rc=$?
      END=$(date +%s%3N)
      echo "T $(date -u +%s%3N) ${BASH_SOURCE[1]}:${BASH_LINENO[1]}:${FUNCNAME[1]}:$(( END - START ))ms: $*" >&2
    else
      stdout_pipe=$(mktemp -u)
      stderr_pipe=$(mktemp -u)
      trap 'cat $stdout_pipe >/dev/null 2>&1; cat $stderr_pipe >/dev/null 2>&1; rm -f $stdout_pipe $stderr_pipe' RETURN
      "$@" 1>"$stdout_pipe" 2>"$stderr_pipe"; rc=$?
      END=$(date +%s%3N)
      echo "{\"type\":\"time\",\"time\":\"$(date -u +%s%3N)\",\"source\":\"${BASE_SOURCE[1]}\",\"line\":\"${BASH_LINENO[1]}\",\"func\":\"${FUNCNAME[1]}\",\"ms\":\"$(( END - START ))\",\"cmd\":\"$*\"}" \
        | jq -Sc --arg stdout "$(cat "$stdout_pipe")" --arg stderr "$(cat "$stderr_pipe")" '. * { "stdout": $stdout, "stderr": $stderr }' >&2
    fi
    return $rc
}
