#!/bin/bash
set -euo pipefail

IMSI="${IMSI:-001010000059449}"
UE_IP="${UE_IP:-10.0.0.6}"
SIM_K="${SIM_K:-5686e601f3a1942d4c5cd262ba6b4b20}"
SIM_OPC="${SIM_OPC:-aeb1cabd8ed7a09b48d17eb3d8af172c}"

echo "[CN seed] Ensuring subscriber IMSI $IMSI exists in oai_db..."

docker exec -i mysql mysql -u root -plinux -D oai_db <<SQL
REPLACE INTO AuthenticationSubscription
    (ueid, authenticationMethod, encPermanentKey, protectionParameterId, sequenceNumber,
     authenticationManagementField, algorithmId, encOpcKey, encTopcKey,
     vectorGenerationInHss, n5gcAuthMethod, rgAuthenticationInd, supi)
VALUES
    ('$IMSI', '5G_AKA', '$SIM_K', '$SIM_K',
     '{"sqn": "000000000000", "sqnScheme": "NON_TIME_BASED", "lastIndexes": {"ausf": 0}}',
     '8000', 'milenage', '$SIM_OPC', NULL, NULL, NULL, NULL, '$IMSI');

REPLACE INTO SessionManagementSubscriptionData
    (ueid, servingPlmnid, singleNssai, dnnConfigurations)
VALUES
    ('$IMSI', '00101', '{"sst": 1, "sd": "FFFFFF"}',
     '{"oai":{"pduSessionTypes":{"defaultSessionType":"IPV4"},"sscModes":{"defaultSscMode":"SSC_MODE_1"},"5gQosProfile":{"5qi":6,"arp":{"priorityLevel":15,"preemptCap":"NOT_PREEMPT","preemptVuln":"PREEMPTABLE"},"priorityLevel":1},"sessionAmbr":{"uplink":"1000Mbps","downlink":"1000Mbps"},"staticIpAddress":[{"ipv4Addr":"$UE_IP"}]},"ims":{"pduSessionTypes":{"defaultSessionType":"IPV4V6"},"sscModes":{"defaultSscMode":"SSC_MODE_1"},"5gQosProfile":{"5qi":2,"arp":{"priorityLevel":15,"preemptCap":"NOT_PREEMPT","preemptVuln":"PREEMPTABLE"},"priorityLevel":1},"sessionAmbr":{"uplink":"1000Mbps","downlink":"1000Mbps"}}}');
SQL

docker exec mysql mysql -u root -plinux -D oai_db -e \
    "SELECT ueid, supi FROM AuthenticationSubscription WHERE supi='$IMSI'; SELECT ueid, servingPlmnid, JSON_EXTRACT(dnnConfigurations, '$.oai.staticIpAddress[0].ipv4Addr') AS ue_ip FROM SessionManagementSubscriptionData WHERE ueid='$IMSI';" 2>/dev/null

echo "[CN seed] Done."
