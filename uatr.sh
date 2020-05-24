#!/usr/bin/env bash

function get_role_name {
  echo $(cat $1/meta/main.yml | grep role_name | cut -d ':' -f2)
}

root=$(git rev-parse --show-toplevel)
loc="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
dir_log="/var/tmp/uatr/${role_name}"
env_log_path="${dir_log}/env.log"

if [ ! -d $dir_log ]; then
  mkdir -p $dir_log
fi

echo "Using ${root}"

role_name=$(get_role_name ${root})

if [[ "${role_name}" == "" ]]; then
  echo "Could not determine tested role name"
  exit 2
fi

echo "Testing ${role_name}"

tests=$(find $root -mindepth 1 -type d -name "test-*" | sort)
tests_failed=0
tests_succeeded=0
tests_run=0
failed_list=""

if [[ "$*" == *"--verbose"* ]]; then
  verbose=1
else
  verbose=0
fi

if [[ "$*" == *"--inspect"* ]]; then
  inspect=1
else
  inspect=0
fi

if [[ "$*" == *"--debug"* ]]; then
  debug=1
else
  debug=0
fi

if [[ "${#tests}" == "0" ]]; then
  echo "No tests found"
  exit 1
fi

if [[ "$debug" != "1" ]]; then
  echo "Preparing test environment container"
  $loc/prepare-env.sh &> ${env_log_path}
fi

PORT=$(docker port hosting-test 22 | cut -d ':' -f2)

for test in $tests; do
  test_name=$(basename ${test})
  test_path=$(realpath ${test})
  test_log_path="${dir_log}/${test_name}.log"
  echo -en "\e[43m \e[30mRUNS \e[0m ${test_name}"

  # Make role accessible
  mkdir ${test_path}/roles 2> /dev/null

  if [ -f ${test_path}/requirements.yml ]; then
    ansible-galaxy install -r ${test_path}/requirements.yml -p ${test_path}/roles &> /dev/null
  fi
  ln -s ../../.. ${test_path}/roles/practical-ansible.${role_name} 2> /dev/null

  ansible_user=""
  . ${test_path}/.env &> /dev/null

  if [[ "$ansible_user" == "" ]]; then
    ansible_user=root
  fi

  # Prepare test inventory
  echo -e "[test]\n${ansible_user}@127.0.0.1 ansible_port=${PORT} ansible_password=test" > ${test_path}/inventory

  # Increment total test runs
  ((tests_run=tests_run+1))

  # Do not check for key when connecting locally
  export ANSIBLE_HOST_KEY_CHECKING=False
 
  if [[ "$verbose" == "1" ]] || [[ "$debug" == "1" ]]; then
    params="-vvv"
  fi

  ansible-playbook ${test_path}/playbook.yml -i ${test_path}/inventory $params &> ${test_log_path}
  test_result=$?
  inverse_result=$(echo ${test_name} | grep "^test-fails-" | wc -l)

  if [ $inverse_result -eq 1 ]; then
    if [ $test_result -eq 0 ]; then
      test_result=255
    else
      test_result=0
    fi
  fi

  if [[ "$inspect" != "1" ]] && [[ "$debug" != "1" ]]; then
    docker stop ${test_name} &> /dev/null
  fi

  if [ $test_result -ne 0 ] ; then
    echo -e "\r\e[101m \e[30mFAIL \e[0m ${test_name}"
    if [ $inverse_result -eq 1 ]; then
      echo Test should have failed, but it was successful instead
    fi
    cat ${test_log_path} 1>&2
    failed_list="${test_path} ${failed_list}"
    ((tests_failed=tests_failed+1))
  else
    echo -e "\r\e[102m \e[30mPASS \e[0m ${test_name}"
    ((tests_succeeded=tests_succeeded+1))
  fi

  rm -r ${test_path}/roles &> /dev/null
  rm ${test_path}/inventory &> /dev/null
  rm ${test_path}/*.tar &> /dev/null
done

if [[ "$inspect" != "1" ]] && [[ "$debug" != "1" ]]; then
  echo "Tearing down test environment"
  docker stop hosting-test &> ${env_log_path}
fi

if [ $tests_failed -eq 0 ]; then
  echo "Finished ${tests_run} tests successfully"
  exit 0
else
  echo 'Test output'
  echo '========'

  for failed_test in $failed_list; do
    echo Output of ${failed_test}
    cat ${failed_test}/log
  done

  echo
  echo "Ran ${tests_run} tests, ${tests_succeeded} succeeded and ${tests_failed} failed."
  exit 1
fi
