#!/usr/bin/env bash

tests=$(find . -mindepth 1 -maxdepth 1 -type d | grep '^test-' | grep -v -e hosting -e roles)
tests_failed=0
tests_succeeded=0
tests_run=0
failed_list=""

if [[ "${#tests}" == "0" ]]; then
  echo "No tests found"
  exit 1
fi

if [[ "$1" != "debug" ]]; then
  echo "Preparing test environment container"
  ./prepare-env.sh
fi

PORT=$(docker port hosting-test 22 | cut -d ':' -f2)

for test in $tests; do
  test_name=${test:2}
  test_path=$(realpath ${test})
  echo -en "\e[43m \e[30mRUNS \e[0m ${test_name}"

  # Make role accessible
  mkdir ${test_path}/roles 2> /dev/null
  ln -s ../../.. ${test_path}/roles/practical-ansible.nginx_docker 2> /dev/null
  
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
  ansible-playbook ${test_path}/playbook.yml -i ${test_path}/inventory -vvv &> ${test_path}/log
  test_result=$?

  if [[ "$1" != "inspect" ]] && [[ "$1" != "debug" ]]; then
    docker stop ${test_name} &> /dev/null
  fi

  if [ $test_result -ne 0 ] ; then
    echo -e "\r\e[101m \e[30mFAIL \e[0m ${test_name}"
    cat ${test_path}/log 1>&2
    failed_list="${test_name} ${failed_list}"
    ((tests_failed=tests_failed+1))
  else
    echo -e "\r\e[102m \e[30mPASS \e[0m ${test_name}"
    ((tests_succeeded=tests_succeeded+1))
  fi

  rm -r ${test_path}/roles &> /dev/null
  rm ${test_path}/inventory &> /dev/null
  rm ${test_path}/*.tar &> /dev/null
done

if [[ "$1" != "inspect" ]] && [[ "$1" != "debug" ]]; then
  echo "Tearing down test environment"
  docker stop hosting-test
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
