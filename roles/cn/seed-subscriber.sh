#!/bin/bash
set -euo pipefail

IMSI="${IMSI:-001010000059449}"
UE_IP="${UE_IP:-10.0.0.6}"

echo "[CN seed] Ensuring subscriber IMSI $IMSI exists in oai_db..."

docker exec -i mysql mysql -u root -plinux -D oai_db <<SQL
REPLACE INTO AuthenticationSubscription
    (ueid, authenticationMethod, encPermanentKey, protectionParameterId, sequenceNumber,
     authenticationManagementField, algorithmId, encOpcKey, encTopcKey,
     vectorGenerationInHss, n5gcAuthMethod, rgAuthenticationInd, supi)
VALUES
    ('$IMSI', '5G_AKA', 'fec86ba6eb707ed08905757b1bb44b8f', 'fec86ba6eb707ed08905757b1bb44b8f',
     '{"sqn": "000000000000", "sqnScheme": "NON_TIME_BASED", "lastIndexes": {"ausf": 0}}',
     '8000', 'milenage', 'C42449363BBAD02B66D16BC975D77CC1', NULL, NULL, NULL, NULL, '$IMSI');

REPLACE INTO SessionManagementSubscriptionData
    (ueid, servingPlmnid, singleNssai, dnnConfigurations)
VALUES
    ('$IMSI', '00101', '{"sst": 1, "sd": "FFFFFF"}',
     '{"oai":{"pduSessionTypes":{"defaultSessionType":"IPV4"},"sscModes":{"defaultSscMode":"SSC_MODE_1"},"5gQosProfile":{"5qi":6,"arp":{"priorityLevel":15,"preemptCap":"NOT_PREEMPT","preemptVuln":"PREEMPTABLE"},"priorityLevel":1},"sessionAmbr":{"uplink":"1000Mbps","downlink":"1000Mbps"},"staticIpAddress":[{"ipv4Addr":"$UE_IP"}]},"ims":{"pduSessionTypes":{"defaultSessionType":"IPV4V6"},"sscModes":{"defaultSscMode":"SSC_MODE_1"},"5gQosProfile":{"5qi":2,"arp":{"priorityLevel":15,"preemptCap":"NOT_PREEMPT","preemptVuln":"PREEMPTABLE"},"priorityLevel":1},"sessionAmbr":{"uplink":"1000Mbps","downlink":"1000Mbps"}}}');
SQL

docker exec mysql mysql -u root -plinux -D oai_db -e \
    "SELECT ueid, supi FROM AuthenticationSubscription WHERE supi='$IMSI'; SELECT ueid, servingPlmnid, JSON_EXTRACT(dnnConfigurations, '$.oai.staticIpAddress[0].ipv4Addr') AS ue_ip FROM SessionManagementSubscriptionData WHERE ueid='$IMSI';" 2>/dev/null

echo "[CN seed] Done."
