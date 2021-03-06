#!/usr/bin/env bash
set -xE

trap display_status ERR

#############
# FUNCTIONS #
#############
EXEC_COMMAND="kubectl -n rook-ceph exec $(kubectl get pod -l app=rook-ceph-tools -n rook-ceph -o jsonpath='{.items[0].metadata.name}') -- ceph --connect-timeout 3"

function wait_for_daemon () {
  timeout=90
  daemon_to_test=$1
  while [ $timeout -ne 0 ]; do
    if eval $daemon_to_test; then
      return 0
    fi
    sleep 1
    let timeout=timeout-1
  done

  return 1
}

function test_demo_mon {
  # shellcheck disable=SC2046
  return $(wait_for_daemon "$EXEC_COMMAND -s | grep -sq quorum")
}

function test_demo_mgr {
  # shellcheck disable=SC2046
  return $(wait_for_daemon "$EXEC_COMMAND -s | grep -sq 'mgr:'")
}

function test_demo_osd {
  # shellcheck disable=SC2046
  return $(wait_for_daemon "$EXEC_COMMAND -s | grep -sq '1 osds: 1 up.*, 1 in.*'")
}

function test_demo_rgw {
  # shellcheck disable=SC2046
  return $(wait_for_daemon "$EXEC_COMMAND -s | grep -sq 'rgw:'")
}

function test_demo_mds {
  echo "Waiting for the MDS to be ready"
  # NOTE: metadata server always takes up to 5 sec to run
  # so we first check if the pools exit, from that we assume that
  # the process will start. We stop waiting after 10 seconds.
  # shellcheck disable=SC2046
  return $(wait_for_daemon "$EXEC_COMMAND osd dump | grep -sq cephfs && $EXEC_COMMAND -s | grep -sq 'up:active'")
}

function test_demo_rgw {
  # shellcheck disable=SC2046
  return $(wait_for_daemon "$EXEC_COMMAND -s | grep -sq 'rgw:'")
}

function test_demo_rbd_mirror {
  # shellcheck disable=SC2046
  return $(wait_for_daemon "$EXEC_COMMAND -s | grep -sq 'rbd-mirror:'")
}

function test_demo_pool {
  # shellcheck disable=SC2046
  return $(wait_for_daemon "$EXEC_COMMAND -s | grep -sq '11 pools'")
}

function test_csi {
  # shellcheck disable=SC2046
  return $(wait_for_daemon "test $(kubectl -n rook-ceph get pods --field-selector=status.phase=Running|grep -c ^csi-) -eq 4")
}

function display_status {
  set +x
  echo "failed to wait for daemon to be ready"
  $EXEC_COMMAND -s
  $EXEC_COMMAND osd dump

  kubectl -n rook-ceph logs "$(kubectl -n rook-ceph -l app=rook-ceph-operator get pods -o jsonpath='{.items[*].metadata.name}')"
  kubectl -n rook-ceph get pods
  set -x

  exit 1
}

########
# MAIN #
########
test_csi
test_demo_mon
test_demo_mgr
test_demo_osd
test_demo_rgw
test_demo_mds
test_demo_rbd_mirror

echo "Ceph is up and running, have a look!"
$EXEC_COMMAND -s
kubectl -n rook-ceph get pods