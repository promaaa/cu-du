#!/bin/bash
# Shared environment variables for CU/DU split deployment

export OAI_COMMIT=102965a669b9444857c27843ec8ce62780bf9d37
export UHD_VERSION=v4.8.0.0
export LOG_DIR=/tmp
export CU_DU_BASE=~/cu-du

# F1 subnet (existing LAN)
export F1_SUBNET=10.76.170.0/25

# CU host
export CU_IP=10.76.170.38
export CU_HOST=serber-firecell

# PI host (Raspberry Pi 5 DU)
export PI_IP=10.76.170.94
export PI_HOST=serber-pi
export PI_F1C_IP=10.76.170.94
export PI_F1U_IP=10.76.170.94

# NTP
export NTP_IP=10.76.170.1
