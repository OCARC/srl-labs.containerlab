*** Settings ***
Library           OperatingSystem
Library           String
Suite Setup       Setup
Suite Teardown    Run    sudo containerlab --runtime ${runtime} destroy -t ${CURDIR}/01-linux-nodes.clab.yml --cleanup

*** Variables ***
${lab-name}       2-linux-nodes
${runtime}        docker
# runtime command to execute tasks in a container
# defaults to docker exec. Will be rewritten to containerd `ctr` if needed in "Define runtime exec" test
${runtime-cli-exec-cmd}    sudo docker exec
${bind-orig-path}    /tmp/clab-01-test.txt
${n2-ipv4}        172.20.20.100/24
${n2-ipv6}        2001:172:20:20::100/64

*** Test Cases ***
Deploy ${lab-name} lab
    Log    ${CURDIR}
    ${rc}    ${output} =    Run And Return Rc And Output
    ...    sudo containerlab --runtime ${runtime} deploy -t ${CURDIR}/01-linux-nodes.clab.yml
    Log    ${output}
    Should Be Equal As Integers    ${rc}    0

Inspect ${lab-name} lab
    ${rc}    ${output} =    Run And Return Rc And Output
    ...    sudo containerlab --runtime ${runtime} inspect -n ${lab-name}
    Log    ${output}
    Should Be Equal As Integers    ${rc}    0

Define runtime exec command
    IF    "${runtime}" == "containerd"
        Set Suite Variable    ${runtime-cli-exec-cmd}    sudo ctr -n clab t exec --exec-id clab
    END

Verify links in node l1
    ${rc}    ${output} =    Run And Return Rc And Output
    ...    ${runtime-cli-exec-cmd} clab-${lab-name}-l1 ip link show eth1
    Log    ${output}
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    state UP
    ${rc}    ${output} =    Run And Return Rc And Output
    ...    ${runtime-cli-exec-cmd} clab-${lab-name}-l1 ip link show eth2
    Log    ${output}
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    state UP

Verify links in node l2
    ${rc}    ${output} =    Run And Return Rc And Output
    ...    ${runtime-cli-exec-cmd} clab-${lab-name}-l2 ip link show eth1
    Log    ${output}
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    state UP
    ${rc}    ${output} =    Run And Return Rc And Output
    ...    ${runtime-cli-exec-cmd} clab-${lab-name}-l2 ip link show eth2
    Log    ${output}
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    state UP

Ensure "inspect all" outputs IP addresses
    ${rc}    ${output} =    Run And Return Rc And Output
    ...    sudo containerlab --runtime ${runtime} inspect --all
    Log    ${output}
    Should Be Equal As Integers    ${rc}    0
    ${line} =    String.Get Line    ${output}    -2
    Log    ${line}
    @{data} =    Split String    ${line}    |
    Log    ${data}
    # verify ipv4 address
    ${ipv4} =    String.Strip String    ${data}[10]
    Should Match Regexp    ${ipv4}    ^[\\d\\.]+/\\d{1,2}$
    # verify ipv6 address
    ${ipv6} =    String.Strip String    ${data}[11]
    Should Match Regexp    ${ipv6}    ^[\\d:abcdef]+/\\d{1,2}$

Verify bind mount in l1 node
    ${rc}    ${output} =    Run And Return Rc And Output
    ...    ${runtime-cli-exec-cmd} clab-2-linux-nodes-l1 cat 01-test.txt
    Log    ${output}
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    Hello, containerlab

Verify port forwarding for node l2
    ${rc}    ${output} =    Run And Return Rc And Output
    ...    curl localhost:56180
    Log    ${output}
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    Thank you for using nginx

Verify static mgmt addressing for l2
    Skip If    '${runtime} != docker'
    ${rc}    ${ipv4} =    Run And Return Rc And Output
    ...    ${runtime-cli-exec-cmd} clab-2-linux-nodes-l2 ip -o -4 a sh eth0 | cut -d ' ' -f7
    Log    ${ipv4}
    Should Be Equal As Strings    ${ipv4}    ${n2-ipv4}
    ${rc}    ${ipv6} =    Run And Return Rc And Output
    ...    ${runtime-cli-exec-cmd} clab-2-linux-nodes-l2 ip -o -6 a sh eth0 | cut -d ' ' -f7 | head -1
    Log    ${ipv6}
    Should Be Equal As Strings    ${ipv6}    ${n2-ipv6}

Destroy ${lab-name} lab
    ${rc}    ${output} =    Run And Return Rc And Output
    ...    sudo containerlab --runtime ${runtime} destroy -t ${CURDIR}/01-linux-nodes.clab.yml --cleanup
    Log    ${output}
    Should Be Equal As Integers    ${rc}    0

*** Keywords ***
Setup
    Run    rm -rf ${bind-orig-path}
    OperatingSystem.Create File    ${bind-orig-path}    Hello, containerlab
