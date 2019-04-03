#!/bin/bash

# This script iterates over Route53 zone records, and DELETES the records
# that point to an ELB in the chosen EC2 region that does not exist anymore.

R53_HOSTED_ZONE_ID="ZXXXXXXXXXXXXX"

TMPFILE="$(mktemp --tmpdir "$0.XXXXXXXXXXXX")"
trap 'rm $TMPFILE' EXIT

debug() { echo "$(date +%s%3N) $*" >&2; }
tm() {
    START=$(date +%s%3N)
    debug "executing: $*"
    "$@"
    rc=$?
    END=$(date +%s%3N)
    debug "--> took $(( END - START ))ms"
    return $rc
}

# exponential retry
# https://docs.aws.amazon.com/general/latest/gr/api-retries.html
retry() {
  retries=0
  until "$@"; do
    duration=$(( 2 ** retries ))
    retries=$(( retries + 1))
    debug "--> Retrying after ${duration}s"
    sleep $duration
  done
}

delete_record() {
    RECORD_SET="$(jq -c .ResourceRecordSets[0] "${TMPFILE}")"
    echo '{ "HostedZoneId": "'"$R53_HOSTED_ZONE_ID"'", "ChangeBatch": { "Changes": [ {"Action": "DELETE", "ResourceRecordSet": '"$RECORD_SET"'} ] } }' > "${TMPFILE}"
    debug "Deleting $RECORD_SET"
    retry tm aws route53 change-resource-record-sets --cli-input-json "file://$TMPFILE"
    rm "$TMPFILE"
}

retry tm aws route53 list-resource-record-sets \
    --hosted-zone-id "${R53_HOSTED_ZONE_ID}" \
    --max-items=1 --page-size=10 > "${TMPFILE}"
NEXT_TOKEN="$(jq -r -c .NextToken "${TMPFILE}")"

while [ -n "$NEXT_TOKEN" ] && [ "$NEXT_TOKEN" != "null" ]; do
    if [ -n "$ALIAS_TARGET" ] && [ "$ALIAS_TARGET" != "null" ]; then
        ELB_NAME="$(echo "$ALIAS_TARGET" | sed -e 's!^\(dualstack.\)*\([^-.]*\).*!\2!')"
        debug "Checking if ELB ${ELB_NAME} exists"
        if tm aws elb describe-load-balancers --load-balancer-names "${ELB_NAME}" --max-items=1 2>&1 \
            | grep "ACTIVE Load Balancer"; then
            delete_record
        else
            debug "ELB exists"
        fi
    fi
    debug "Finding next Route53 record in zone ${R53_HOSTED_ZONE_ID}..."
    retry tm aws route53 list-resource-record-sets \
        --hosted-zone-id "${R53_HOSTED_ZONE_ID}" \
        --max-items=1 --page-size=10 \
        --starting-token "${NEXT_TOKEN}" > "${TMPFILE}"
    NEXT_TOKEN="$(jq -r -c .NextToken "${TMPFILE}")"
    ALIAS_TARGET="$(jq -r -c .ResourceRecordSets[0].AliasTarget.DNSName "${TMPFILE}")"
done

debug "Done."
