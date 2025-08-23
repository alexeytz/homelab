#!/bin/bash
#-/usr/bin/env bash

export NAMESPACE=rse
export REC_NAME=${NAMESPACE}-rec-18x
export REC_REST_INGRESS_NAME=${REC_NAME}-rest-ingress
export BASE_FQDN=example.com
export DEFAULT_DB_NAME=${NAMESPACE}-enterprise-database
export DEFAULT_DB_PORT=10001
export AA_PEER_REC_NAME=${NAMESPACE}-rec-8x
export AA_dbFqdnSuffix=-db-aa-${REC_NAME}.$BASE_FQDN