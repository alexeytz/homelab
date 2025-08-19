#!/bin/bash
#-/usr/bin/env bash

# -------------------------------------------------------------
# Functions
# -------------------------------------------------------------
msg() {
    local level="$1"; shift
    case "$level" in
        info)  echo -e "\e[32m[INFO] $(date +"%d/%m/%y %H:%M:%S")\e[0m $*"
               ;;
        warn)  echo -e "\e[33m[WARN] $(date +"%d/%m/%y %H:%M:%S")\e[0m $*"
               ;;
        error) echo -e "\e[31m[ERROR] $(date +"%d/%m/%y %H:%M:%S")\e[0m $*"
               ;;
        *)     echo "$*"
               ;;
    esac
}

abort() {
    msg error "$1"
    exit 1
}