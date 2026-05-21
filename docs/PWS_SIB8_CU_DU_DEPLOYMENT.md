# PWS/SIB8 CU/DU Deployment

This repository carries a deployable OAI patch for PWS/emergency warning
broadcast through SIB8 in the CU/DU split topology.

The tested setup is:

- CU + 5GC on `serber-firecell`
- DU + USRP B210 on `serber-minipc`
- OAI base commit `102965a669b9444857c27843ec8ce62780bf9d37`
- CU actual OAI source: `/home/serber/cu-du/source/openairinterface5g`
- DU actual OAI source: `/home/serber/monolithic/openairinterface5g`

## Patch

Patch file:

```bash
patches/oai-pws-sib8-cu-du.patch
```

Apply it locally or remotely with:

```bash
scripts/apply-pws-sib8-cu-du.sh /path/to/openairinterface5g
scripts/apply-pws-sib8-cu-du.sh serber-firecell:/home/serber/cu-du/source/openairinterface5g
scripts/apply-pws-sib8-cu-du.sh serber-minipc:/home/serber/monolithic/openairinterface5g
```

The patch adds:

- SIB8 construction from `sib8.conf`
- GSM 7-bit and UCS2 warning text support
- Warning segmentation into one or more SIB8 SI messages
- Runtime SIB8 config polling and update triggering
- CU-side `F1AP_WRITE_REPLACE_WARNING` dispatch
- F1AP `WriteReplaceWarningRequest` encode/decode
- DU MAC `write_replace_warning_req` handling
- SIB1 SI scheduling updates for SIB8
- DU BCCH-DL-SCH scheduling of the SIB8 `SystemInformation`
- A scheduler fix so other-SI allocation scans later free RB islands instead of
  failing on the first small island

## Runtime Path

```text
CU RRC SIB8 config
  -> encoded SIB8 segments
  -> F1AP_WRITE_REPLACE_WARNING ITTI
  -> F1AP WriteReplaceWarningRequest / PWSSystemInformation
  -> DU F1AP decode
  -> DU MAC SystemInformation + SIB1 SI scheduling update
  -> BCCH-DL-SCH scheduler
  -> PHY/RU radio broadcast
```

## Warning Configuration

The patch installs `sib8.conf` at the OAI source root. The running softmodem
loads it from the build directory using `../../../sib8.conf`.

Example:

```ini
messageIdentifier = 1112
serialNumber = FF00
dataCodingScheme = 48
warningType = 0000
text = "Hello this is a test warning message."
mode = 0
```

Notes:

- `dataCodingScheme = 48` uses GSM 7-bit default alphabet.
- UCS2 is supported by the SIB8 builder.
- Use `|` inside `text` when you want a newline in the emitted warning.
- The parser accepts whitespace around `=` and optional quoted values.

## Build

Build CU on `serber-firecell`:

```bash
ssh serber-firecell \
  'cd /home/serber/cu-du/source/openairinterface5g/cmake_targets && sudo ./build_oai -w USRP --ninja --gNB -C'
```

Build DU on `serber-minipc`:

```bash
ssh serber-minipc \
  'cd /home/serber/monolithic/openairinterface5g/cmake_targets && sudo ./build_oai -w USRP --ninja --gNB -C'
```

For incremental rebuilds after editing only C sources:

```bash
ssh serber-firecell \
  'cd /home/serber/cu-du/source/openairinterface5g/cmake_targets/ran_build/build && sudo cmake --build . --target nr-softmodem -- -j16'

ssh serber-minipc \
  'cd /home/serber/monolithic/openairinterface5g/cmake_targets/ran_build/build && sudo cmake --build . --target nr-softmodem -- -j4'
```

## Run

Start the core:

```bash
ssh serber-firecell \
  'cd /home/serber/cu-du-minipc/oai-cn5g-minipc && docker compose -f docker-compose-minipc.yaml up -d'
```

Start CU:

```bash
ssh serber-firecell \
  'cd /home/serber/cu-du-minipc-backhaul/source/openairinterface5g/cmake_targets/ran_build/build && sudo ./nr-softmodem -O /home/serber/cu-du-minipc-backhaul/source/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-cu-minipc.conf --log_config.global_log_level info'
```

Start DU:

```bash
ssh serber-minipc \
  'cd /home/serber/cu-du/source/openairinterface5g/cmake_targets/ran_build/build && sudo ./nr-softmodem -O /home/serber/cu-du/source/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-minipc.conf --log_config.global_log_level info -E'
```

## Validation

Expected CU log evidence:

```text
CU_handle_F1_SETUP_REQUEST
[SIB8] segments numer:0 and number of segments:1
CU Task Received F1AP_WRITE_REPLACE_WARNING
```

Expected DU log evidence:

```text
DU_handle_WriteReplaceWarning: sib_type=8
received Write Replace Warning Request from CU
Configured PWS/SIB8 SI segment 0
Configured PWS/SIB8 SI: 1 segment(s)
RU 0 RF started
```

Useful checks:

```bash
ssh serber-firecell \
  "tail -n 260 /tmp/cu-minipc.log | grep -Ei 'sib8|warning|pws|systeminformation|f1|f1ap|setup|error|failed'"

ssh serber-minipc \
  "tail -n 260 /tmp/du-minipc.log | grep -Ei 'sib8|warning|pws|systeminformation|f1|f1ap|bcch|si|mac|rf started|assert|exiting|couldn'"

ssh serber-firecell \
  "docker logs oai-cn5g-minipc-oai-amf-1 --tail 160 2>&1 | grep -E 'gNB|5GMM|REGISTERED|Connected|Disconnected'"
```

Phone-side validation from the tested run:

- The phone received the PWS emergency warning message.
- UE registration and internet worked after selecting the `oai` APN/DNN instead
  of routing data through `ims`.

## Troubleshooting

If the phone has 5G bars and receives PWS but no internet:

1. Verify the UE is registered in AMF logs.
2. Verify SMF created the `oai` PDU session, not only `ims`.
3. On Android, select or create an APN using DNN/APN `oai`, then toggle airplane
   mode.
4. Check UPF logs for access-side PDR errors:

```bash
ssh serber-firecell \
  "docker logs oai-cn5g-minipc-oai-upf-1 --tail 300 2>&1 | grep -Ei 'look_up_pack_in_access|PDR|TEID|UE IPv4|error|fail'"
```

If stale PFCP state appears after many attach attempts, stop CU/DU, restart
`oai-amf`, `oai-smf`, and `oai-upf`, then start CU/DU again.
