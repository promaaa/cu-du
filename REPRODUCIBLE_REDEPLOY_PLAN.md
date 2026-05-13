# Plan: Make The Local Repo Fully Reproducible For serber-firecell And serber-pi

Goal: the local `cu-du` repo should become the single source of truth for rebuilding and redeploying the current working CU + core + Pi DU setup if `/home/serber/cu-du` or `/home/serber/monolithic` are deleted on the remote machines.

## 1. Make The Working Config The Local Source Of Truth

Update local config files to match the deployed configuration exactly:

- `conf/cu-cfg.yml`
  - Set `cu.f1c_port` to `2152`.
  - Keep `cu.f1c_ip = 10.76.170.38`.
  - Keep `cu.ng_ip = 192.168.70.129`.
  - Keep `amf.ip = 192.168.70.132`.
- `conf/pi-cfg.yml`
  - Set `cu.f1c_ip = 10.76.170.94`.
  - Set `cu.f1u_ip = 10.76.170.94`.
  - Set `cu.f1c_port = 2152`.
  - Set `cu.remote_f1c_ip = 10.76.170.38`.
  - Set `cu.remote_f1c_port = 2152`.
  - Set `usrp.serial = 35F8ABA`.
  - Set `usrp.prb = 106`.
  - Set `usrp.att_tx = 3`.
  - Set `usrp.att_rx = 12`.
  - Set `usrp.searchSpaceZero = 2`.
  - Set `usrp.controlResourceSetZero = 12`.
  - Set `usrp.ssb_perRACH_OccasionAndCB_PreamblesPerSSB = 14`.
  - Set `usrp.absoluteFrequencySSB = 641280`.
  - Set `usrp.dl_absoluteFrequencyPointA = 640008`.
- Regenerate and commit:
  - `source/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-cu.conf`
  - `source/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-pi.conf`

The local repo currently does not match the deployed state: local `conf/pi-cfg.yml` still contains the failed 51 PRB profile and older gain/port values.

## 2. Fix The Config Generator

Update `scripts/generate-configs.py` so generated configs always match the working deployment:

- Use `cfg['cu']['f1c_port']` for DU/PI `local_n_portd` and `remote_n_portd` instead of hard-coding `2777`.
- Keep the corrected `initialULBWPlocationAndBandwidth` spelling.
- Ensure 106 PRB maps to `initialDLBWPlocationAndBandwidth = 28875` and `initialULBWPlocationAndBandwidth = 28875`.
- Ensure optional fields are supported and tested:
  - `absoluteFrequencySSB`
  - `dl_absoluteFrequencyPointA`
  - `controlResourceSetZero`
  - `searchSpaceZero`
  - `ssb_perRACH_OccasionAndCB_PreamblesPerSSB`
  - `ssPBCH_BlockPower`
- Add a generator validation mode that fails if:
  - PI PRB is not `106`.
  - PI F1 ports are not `2152`.
  - PI USRP serial is not `35F8ABA`.
  - CU NGU IP is not `192.168.70.129`.

## 3. Stop Depending On The Monolithic Tree By Accident

Completed immediate change: the working CU has been moved to:

```text
/home/serber/cu-du/source/openairinterface5g
```

The repo should keep this as the only supported CU runtime path. The compatibility path using `/home/serber/monolithic/openairinterface5g` has been removed from the CU runtime flow.

## 4. Vendor Or Fetch The Core Network Reproducibly

The core runtime should use:

```text
~/cu-du/source/oai-cn5g/docker-compose.yml
```

Make this explicit:

- Add a `roles/cn/bootstrap.sh` that downloads or clones the exact OAI CN5G tutorial resources used by the working deployment.
- Pin the source commit or archive URL.
- Store the expected Docker compose path in `conf/env.sh`.
- Add `roles/cn/start.sh`, `roles/cn/stop.sh`, and `roles/cn/health-check.sh` that all use the same path.
- Add a post-start command to apply UPF shaping:

```bash
docker exec oai-upf tc qdisc replace dev tun0 root tbf rate 1500kbit burst 64kbit latency 400ms
```

- Make the shaping idempotent and verify it in health checks.
- Seed the physical Nothing Phone subscriber from the repo, not from `~/monolithic`:
  - IMSI `001010000059449`
  - UE IP `10.0.0.6`
  - Ki `5686e601f3a1942d4c5cd262ba6b4b20`
  - OPc `aeb1cabd8ed7a09b48d17eb3d8af172c`
  - AMF `8000`
  - `5G_AKA` / `milenage`

## 5. Add A Real Pi Bootstrap

Create a Pi bootstrap script, for example:

```text
roles/pi/bootstrap-system.sh
```

It should:

- Install OS packages needed for OAI/UHD.
- Enable Pi USB current:

```bash
sudo grep -q '^usb_max_current_enable=1' /boot/firmware/config.txt || \
  echo 'usb_max_current_enable=1' | sudo tee -a /boot/firmware/config.txt
```

- Set CPU governors to `performance`.
- Install a persistent governor service, or document that the setting must be applied on each boot.
- Verify:
  - `vcgencmd get_throttled` is `0x0`.
  - B210 appears with serial `35F8ABA`.
  - USB bus is SuperSpeed/USB3.

## 6. Make Deployment Scripts Idempotent

Replace the current mix of scripts with one predictable flow:

```bash
scripts/deploy-firecell.sh --bootstrap --build --start
scripts/deploy-pi.sh --bootstrap --build --start
scripts/start-working-stack.sh
scripts/stop-working-stack.sh
scripts/check-working-stack.sh
```

Expected behavior:

- If the repo is missing on a remote host, clone it.
- If OAI is missing, clone it at `OAI_COMMIT`.
- If UHD is missing, build/install `UHD_VERSION`.
- If OAI is already built, do not rebuild unless `--rebuild` is passed.
- Always regenerate configs from local YAML before start.
- Always copy `sib8.conf` to the OAI tree if needed.
- Start order:
  1. core
  2. CU
  3. DU
- Stop order:
  1. DU
  2. CU
  3. core, unless `--keep-core` is passed

## 7. Add Health Checks That Match This Setup

Update `scripts/check-health.sh` so it checks `serber-pi`, not only `serber-minipc`, and uses the right log/config paths.

Checks should include:

- CU process and command line.
- DU process and command line, including `-E`.
- F1 Setup Response in CU and DU logs.
- NG Setup Response from AMF.
- PDU Session 1 and DRB 1 creation.
- F1-U GTP-U on UDP/2152 between `10.76.170.38` and `10.76.170.94`.
- N3 GTP-U on UDP/2152 between `192.168.70.129` and `192.168.70.134`.
- UPF `tun0` exists and has `10.0.0.1/24`.
- UPF qdisc is `tbf rate 1500Kbit`.
- Host NAT rule for `192.168.70.128/26`.
- Pi CPU governor is `performance`.
- Pi throttling is `0x0`.
- B210 serial is `35F8ABA`.

## 8. Capture Known-Bad Profiles As Profiles, Not Accidents

Move radio profiles into explicit files, for example:

```text
conf/profiles/pi-106prb-working.yml
conf/profiles/pi-51prb-failed-nothing-phone.yml
conf/profiles/pi-106prb-full-gain-unstable.yml
```

Default `conf/pi-cfg.yml` should point to `pi-106prb-working.yml`.

Document:

- 51 PRB did not produce 5G bars or internet on the Nothing Phone.
- Full gain (`att_tx=0`, `att_rx=0`) attached but destabilized downlink.
- Working user-confirmed baseline is 106 PRB, `att_tx=3`, `att_rx=12`, UPF shaping `1500kbit`.

## 9. Add A Rebuild From Empty Hosts Runbook

Add a top-level runbook:

```text
REDEPLOY_FROM_EMPTY_HOSTS.md
```

It should cover:

1. Clone repo locally.
2. Export `SSHPASS`.
3. Bootstrap `serber-firecell`.
4. Bootstrap `serber-pi`.
5. Build OAI/UHD.
6. Start core and CU.
7. Start DU.
8. Toggle airplane mode on the phone if needed.
9. Run health checks.
10. Confirm expected phone behavior: 5G bars and internet.

## 10. Add Regression Tests

Add a local validation script:

```text
scripts/validate-working-config.sh
```

It should fail fast if generated config drifts from the known working values:

- no `2777` in generated CU/PI F1 data ports
- `dl_carrierBandwidth = 106`
- `ul_carrierBandwidth = 106`
- `absoluteFrequencySSB = 641280`
- `dl_absoluteFrequencyPointA = 640008`
- `initialULBWPlocationAndBandwidth = 28875`
- `sdr_addrs = "serial=35F8ABA"`
- `att_tx = 3`
- `att_rx = 12`

This is the guardrail that would have caught the local repo drifting back to 51 PRB and `2777`.

## Suggested Implementation Order

1. Done: update local YAML and generator to match the deployed working configuration.
2. Done: regenerate CU/PI configs locally and validate the working baseline.
3. In progress: update start/stop scripts to use `serber-firecell` + `serber-pi` as the default pair.
4. Done: add UPF shaping as an idempotent core post-start step.
5. Pending: add Pi bootstrap for USB current and CPU governor.
6. Started: add validation and health-check scripts.
7. Add the empty-host redeploy runbook.
8. Test by deploying to the existing hosts without deleting anything.
9. Only after that, test a clean rebuild path on one host or in a disposable directory.
