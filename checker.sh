#!/bin/bash
# author: ke.yi (aaron)
echo '     _____  _____  _  __'
echo '    |  __ \|  __ \| |/ /'
echo '_  _| |__) | |  | |   / '
echo ' \/ /  ___/| |  | |  <  '
echo '>  <| |    | |__| | . \ '
echo '_/\_\_|    |_____/|_|\_\'
echo -e "\033[42;30mservice deployment helper\033[0m"
echo 
function get_nr_processor()
{
    grep '^processor' /proc/cpuinfo | wc -l
}
function get_nr_socket()
{
    grep 'physical id' /proc/cpuinfo | awk -F: '{
            print $2 | "sort -un"}' | wc -l
}
function get_nr_siblings()
{
    grep 'siblings' /proc/cpuinfo | awk -F: '{
            print $2 | "sort -un"}'
}
function get_nr_cores_of_socket()
{
    grep 'cpu cores' /proc/cpuinfo | awk -F: '{
            print $2 | "sort -un"}'
}

function cpu_layout()
{
echo -e "\033[44;37m**********CPU layout**********\033[0m"
echo -e '=====\t\tCPU Brief\t\t====='
nr_processor=`get_nr_processor`
echo "Logical processors: $nr_processor"
nr_socket=`get_nr_socket`
echo "Physical socket: $nr_socket"
nr_siblings=`get_nr_siblings`
echo "Siblings in one socket: $nr_siblings"
nr_cores=`get_nr_cores_of_socket`
echo "Cores in one socket: $nr_cores"
let nr_cores*=nr_socket
echo "Cores in total: $nr_cores"
if [ "$nr_cores" = "$nr_processor" ]; then
    echo "Hyper-Threading: off"
else
    echo "Hyper-Threading: on"
fi

echo
echo -e '=====\t\tCPU Layout\t\t ====='
tabs 3
awk -F: '{
    if ($1 ~ /processor/) {
        gsub(/ /,"",$2);
        p_id=$2;
    } else if ($1 ~ /physical id/){
        gsub(/ /,"",$2);
        s_id=$2;
        arr[s_id]=arr[s_id] "\t" p_id
    }
}
END{
    for (i in arr)
        printf "Socket %s:%s\n", i, arr[i];
}' /proc/cpuinfo

#if [ -z "$(grep -i 'isolcpus' /etc/default/grub)" ]; then
#    echo 'NO cpu isolation configured'
#else
#    echo $(grep -i 'isolcpus' /etc/default/grub)
#fi
if [ -z "$(cat /sys/devices/system/cpu/isolated)" ]; then
    echo 'NO cpu isolation configured'
else
    echo 'isolated CPU are: '$(cat /sys/devices/system/cpu/isolated)
fi

tabs 6
echo -e "\033[47;34mthreads on per cores:\033[0m"
num=$nr_cores
echo -e 'core id\t\tthreads'
while [ "$num" -gt 0 ]
do
    echo -e core[$num]'\t\t'$(ps -eLo ruser,pid,ppid,lwp,psr,args | awk '{if($5=='$num') print $0}' | wc -l)
    let "num--"
done
echo -e '=====\t\tFeatures\t\t====='
if [ -z "$(dmesg | grep -e DMAR -e IOMMU)" ]; then
    echo 'IOMMU NOT enabled'
    else echo 'IOMMU enabled'
fi

if [ -z "$(egrep -e '^flags.*(vmx|svm)' /proc/cpuinfo)" ]; then
    echo 'KVM not supported'
    else echo 'KVM supported'
fi

if [ -z "$(lsmod | grep vfio)" ]; then
    echo 'VFIO module NOT loaded'
else
    echo 'VFIO module loaded'
fi

if [ -z "$(lsmod | grep uio)" ]; then
    echo 'UIO module NOT loaded'
else
    echo 'UIO module loaded'
fi

if [ -z "$(lsmod | grep kvm)" ]; then
    echo 'KVM module NOT loaded'
else
    echo 'KVM module loaded'
fi
}

function mem_layout()
{
echo -e "\033[44;37m**********Memory layout**********\033[0m"
if [ -z "$(egrep -i 'hugepage' /proc/meminfo)" ];
then
    echo 'no hugepages configured'
else
    echo $(grep -i 'Hugepagesize' /proc/meminfo)
    echo $(grep -i 'Hugepages_total' /proc/meminfo)
    echo $(grep -i 'Hugepages_free' /proc/meminfo)
fi
echo
echo -e "\033[47;34mboard information\033[0m"
echo $(dmidecode -t 2 | grep -A 5 'Base Board Information')
echo
echo -e "\033[47;34mmemory physical layout\033[0m"
dmidecode -t 16 | grep -A 6 'Physical Memory Array'
echo
echo 'all physical DIMM and capacity:'
for dmi_slot in $(lshw -C memory | grep _DIMM_ | awk -F: '{printf $2}')
do
    echo $dmi_slot : $(dmidecode -t 17 | grep -B 3 $dmi_slot | grep Size: | awk -F: '{printf $2}')
done
echo
echo -e "\033[47;34mrunning memory dimm\033[0m"
#dmidecode -t 17 | grep -C 7 'Size: [0-9]'
dmidecode -t 17 | grep -C 7 'Size: [0-9]' | awk -F: '{
    if ($2 ~ /DIMM_/) {
        gsub(/ /,"",$2);
        p_id=$2;
    } else if ($1 ~ /Bank Locator/){
        gsub(/ /,"",$2);
        s_id=$2;
        arr[s_id]=arr[s_id] "\t" p_id
    } else if ($1 ~ /Speed/){
        gsub(/ /,"",$2);
        arr[s_id]=arr[s_id]"("$2")"
    }	
}
END{
    for (i in arr) {
        printf "Memory %s:%s\n", i, arr[i];
    }
}'
}

function nic_layout()
{
echo -e "\033[44;37m**********NIC layout**********\033[0m"
echo
echo -e '=====\t\tNIC Cap and DPDK-Support checking\t\t====='
#refer to command below to generate dpdk supported device id(supported_nic_dev_id) based on actual envioroment:
#cd $DPDK_FOLDER
#echo $(find . -name "*.h" | xargs grep '_DEV_ID_' | grep -v '_SUBSYS_' | grep -v 'MASK' | grep '\<0x[0-9][a-zA-Z0-9]\{3\}\>' | awk -F '0x' '{print substr($2, 1,4)}' | sort | uniq)
supported_nic_dev_id='0438 043A 043C 0440 1000 1001 1004 1008 1009 100C 100D 100E 100F 1010 1011 1012 1013 1014 1015 1016 1017 1018 1019 101A 101D 101E 1026 1027 1028 1049 104A 104B 104C 104D 105E 105F 1060 1075 1076 1077 1078 1079 107A 107B 107C 107D 107E 107F 108A 108B 108C 1096 1098 1099 109A 10A4 10A5 10A7 10A9 10B5 10B6 10B9 10BA 10BB 10BC 10BD 10BF 10C0 10C2 10C3 10C4 10C5 10C6 10C7 10C8 10C9 10CA 10CB 10CC 10CD 10CE 10D3 10D5 10D6 10D9 10DA 10DB 10DD 10DE 10DF 10E1 10E5 10E6 10E7 10E8 10EA 10EB 10EC 10ED 10EF 10F0 10F1 10F4 10F5 10F6 10F7 10F8 10F9 10FB 10FC 1501 1502 1503 1507 1508 150A 150B 150C 150D 150E 150F 1510 1511 1514 1515 1516 1517 1518 151C 1520 1521 1522 1523 1524 1525 1526 1527 1528 1529 152A 152D 152E 152F 1530 1533 1534 1535 1536 1537 1538 1539 153A 153B 1546 154A 154C 154D 154F 1557 1558 1559 155A 155C 155D 1560 1563 1564 1565 156F 1570 1571 1572 1574 157B 157C 1580 1581 1583 1584 1585 1586 1587 1588 1589 158A 158B 15A0 15A1 15A2 15A3 15A4 15A5 15A8 15A9 15AA 15AB 15AC 15AD 15AE 15B0 15B4 15B7 15B8 15B9 15BB 15BC 15BD 15BE 15C2 15C3 15C4 15C5 15C6 15C7 15C8 15CA 15CC 15CE 15D0 15D1 15D5 15D6 15D7 15D8 15E3 15E4 15E5 1889 1F40 1F41 1F45 294C 374C 374D 37CD 37CE 37CF 37D0 37D1 37D2 37D3'

#for item in $(lspci -nn | grep 'Ethernet controller' | grep '\[\<[a-zA-Z0-9]\{4\}\>:\<[a-zA-Z0-9]\{4\}\>\]')
#do
    #dev_name+=("$item")
#done
#echo ${dev_name[*]}

#make it all upper case
#for dev_id in $(lspci -nn | grep 'Ethernet controller' | grep '\[\<[a-zA-Z0-9]\{4\}\>:\<[a-zA-Z0-9]\{4\}\>\]' | awk -F ']' '{print $2}' | cut -d":" -f 3 | tr "[:lower:]" "[:upper:]")
#do
#    if [[ $supported_nic_dev_id =~ $dev_id  ]];
#    then
#        #echo 'NIC supported in current DPDK version, device id is 0x'$dev_id
#        echo '.'
#    else
#        echo -e 'there are NICs NOT supported in current DPDK version, they are\n'$(lspci -nn | grep -i $dev_id)
#    fi
#done
#echo 'NIC checking done'

for bdf in $(lspci -nn | grep 'Ethernet controller' | awk '{print $1}')
do
    echo $(lspci -s $bdf)
    echo $(lspci -s $bdf -vv | grep -i 'lnksta\|lnkcap')
    dev_id=$(lspci -nns $bdf | grep '\[\<[a-zA-Z0-9]\{4\}\>:\<[a-zA-Z0-9]\{4\}\>\]' | awk -F ']' '{print $2}' | cut -d":" -f 3 | tr "[:lower:]" "[:upper:]")
    if [[ $supported_nic_dev_id =~ $dev_id  ]];
    then
        echo -e "\033[32mNIC supported in current DPDK version \033[0m"
    else
        echo -e "\033[31mNIC NOT supported in current DPDK version \033[0m"
    fi
    echo
done

echo
echo -e "\033[47;34mMTU/queue per NIC\033[0m"
echo -e "Try to use command 'echo > \$bitmask /proc/irq/\$irq_index/smp_affinity' to isolate cpu from interupts"
printf "%-16s%-16s%-16s%-16s" 'net_device' 'MTU' 'queue avai' 'irq number per queue '
echo -e '\n===================================================================='
    for net_dev in $(ls /sys/class/net); do
        #echo -e $net_dev'\t\t\t'$(cat /sys/class/net/$net_dev/mtu)'\t\t\t'$(ethtool -l $net_dev | grep Combined | grep -n "" | grep "^2" | awk -F: '{print $3}')
        printf "%-16s%-16s%-16s%-16s\n" $net_dev $(cat /sys/class/net/$net_dev/mtu) $(ethtool -l $net_dev | grep Combined | grep -n "" | grep "^2" | awk -F: '{print $3}') $(cat /proc/interrupts | grep $net_dev | awk '{print $1}' | wc -l)
        #echo -e $(ethtool -l $net_dev)
        #printf "%-12s %-20s %-12s\n" $blk_dev $(cat /sys/block/$blk_dev/queue/scheduler) $(cat /sys/block/$blk_dev/queue/read_    ahead_kb)

    done
    echo

echo -e "\033[44;37m**********DPDK layout**********\033[0m"
echo -e '=====\t\tOVS checking\t\t====='
if [ -n "$(ps -aux | grep ovs-vswitchd)" ] && [ -n "$(test -e /var/run/openvswitch/db.sock && echo "true")" ];
then
    echo 'ovs configured and running'
else
    echo 'ovs not running, configuration like dpdk-socket-mem, dpdk-lcore-mask, pmd-cpu-mask will not be probed'
fi

# check dpdk-socket-mem, dpdk-lcore-mask, and pmd-cpu-mask in configuration in ovs thread
# TBD
}

function spdk_layout()
{
echo -e "\033[44;37m**********SPDK layout**********\033[0m"
echo -e '=====\t\tdisk probing\t\t====='

# backport disk probe function from community
tabs 8 
function iter_pci_class_code() {
        local class="$(printf %02x $((0x$1)))"
        local subclass="$(printf %02x $((0x$2)))"
        local progif="$(printf %02x $((0x$3)))"

        if hash lspci &>/dev/null; then
                if [ "$progif" != "00" ]; then
                        lspci -mm -n -D | \
                                grep -i -- "-p${progif}" | \
                                awk -v cc="\"${class}${subclass}\"" -F " " \
                                '{if (cc ~ $2) print $1}' | tr -d '"'
                else
                        lspci -mm -n -D | \
                                awk -v cc="\"${class}${subclass}\"" -F " " \
                                '{if (cc ~ $2) print $1}' | tr -d '"'
                fi
        elif hash pciconf &>/dev/null; then
                addr=($(pciconf -l | grep -i "class=0x${class}${subclass}${progif}" | \
                        cut -d$'\t' -f1 | sed -e 's/^[a-zA-Z0-9_]*@pci//g' | tr ':' ' '))
                printf "%04x:%02x:%02x:%x\n" ${addr[0]} ${addr[1]} ${addr[2]} ${addr[3]}
        else
                echo "Missing PCI enumeration utility"
                exit 1
        fi
}

function iter_pci_dev_id() {
        local ven_id="$(printf %04x $((0x$1)))"
        local dev_id="$(printf %04x $((0x$2)))"

        if hash lspci &>/dev/null; then
                lspci -mm -n -D | awk -v ven="\"$ven_id\"" -v dev="\"${dev_id}\"" -F " " \
                        '{if (ven ~ $3 && dev ~ $4) print $1}' | tr -d '"'
        elif hash pciconf &>/dev/null; then
                addr=($(pciconf -l | grep -i "chip=0x${dev_id}${ven_id}" | \
                        cut -d$'\t' -f1 | sed -e 's/^[a-zA-Z0-9_]*@pci//g' | tr ':' ' '))
                printf "%04x:%02x:%02x:%x\n" ${addr[0]} ${addr[1]} ${addr[2]} ${addr[3]}
        else
                echo "Missing PCI enumeration utility"
                exit 1
        fi
}

echo "NVMe devices"
echo -e "BDF\t\tNuma Node\tDriver name\t\tDevice name"
for bdf in $(iter_pci_class_code 01 08 02); do
    driver=`grep DRIVER /sys/bus/pci/devices/$bdf/uevent |awk -F"=" '{print $2}'`
    node=`cat /sys/bus/pci/devices/$bdf/numa_node`;
    if [ "$driver" = "nvme" -a -d /sys/bus/pci/devices/$bdf/nvme ]; then
        name="\t"`ls /sys/bus/pci/devices/$bdf/nvme`;
    else
        name="-";
    fi
    echo -e "$bdf\t$node\t\t$driver\t\t$name";
done

echo "I/OAT DMA"

#collect all the device_id info of ioat devices.
#TMP=`grep "PCI_DEVICE_ID_INTEL_IOAT" $rootdir/include/spdk/pci_ids.h | awk -F"x" '{print $2}'`
TMP='3c20 3c21 3c22 3c23 3c24 3c25 3c26 3c27 3c2e 3c2f 0e20 0e21 0e22 0e23 0e24 0e25 0e26 0e27 0e2e 0e2f 2f20 2f21 2f22 2f23 2f24 2f25 2f26 2f27 2f2e 2f2f 0C50 0C51 0C52 0C53 6f50 6f51 6f52 6f53 6f20 6f21 6f22 6f23 6f24 6f25 6f26 6f27 6f2e 6f2f 2021'
echo -e "BDF\t\tNuma Node\tDriver Name"
for dev_id in $TMP; do
    for bdf in $(iter_pci_dev_id 8086 $dev_id); do
        driver=`grep DRIVER /sys/bus/pci/devices/$bdf/uevent |awk -F"=" '{print $2}'`
        node=`cat /sys/bus/pci/devices/$bdf/numa_node`;
        echo -e "$bdf\t$node\t\t$driver"
    done
done
}

function dpdk_layout()
{
    #partial function had been move to nic_layout
    echo
}

function pmdk_layout()
{
    #TBD
    echo
}

function kernel_opt_layout()
{
    echo -e "\033[47;34mcpu power model\033[0m"
    echo -e "Try to use command 'echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null'\nto make cpu running in optimized model'"
    nr_cores=`get_nr_processor`
    num=$[$nr_cores-1]
    while [ "$num" -ge 0 ]
    do
        #echo -e core[$num]'\t\t'$(cat /sys/devices/system/cpu/cpu$num/cpufreq/scaling_governor)
        printf "%-8s\t%-10s\t\n" core[$num] $(cat /sys/devices/system/cpu/cpu$num/cpufreq/scaling_governor)
        let "num--"
    done
    echo
    echo -e "\033[47;34mdisk schedule/prefetch model\033[0m"
    echo -e "Try to use 'noop' for ssd and 'dealine' for hdd, and set large value for read_ahead_kb"
    echo -e "\033[32mblock device\t\tschedule model\t\tread_ahead_kb\033[0m"
    for blk_dev in $(lsblk | grep disk | awk '{print $1}'); do 
        echo -e $blk_dev'\t\t'$(cat /sys/block/$blk_dev/queue/scheduler)'\t\t'$(cat /sys/block/$blk_dev/queue/read_ahead_kb)
        #printf "%-12s %-20s %-12s\n" $blk_dev $(cat /sys/block/$blk_dev/queue/scheduler) $(cat /sys/block/$blk_dev/queue/read_ahead_kb)

    done
    echo
    echo -e "\033[47;34mkernel pid max\033[0m"
    echo $(cat /proc/sys/kernel/pid_max)
    echo 
    echo -e "\033[47;34mcgroup options\033[0m"
    echo -e "/sys/fs/cgroup/cpuset/cpuset.cpus" $(cat /sys/fs/cgroup/cpuset/cpuset.cpus)
    echo -e "/sys/fs/cgroup/cpuset/cpuset.mems" $(cat /sys/fs/cgroup/cpuset/cpuset.mems)
    echo -e "For Ceph OSD, try to use command\n'for \$osd_pid in \$(ps -aux | grep osd | grep -v grep | awk '{print \$2}') do echo \$(osd_pid) > /sys/fs/cgroup/cpuset/ceph/cgroup.procs'\nto bind and isolate osd daemons"
    echo
}

ARGS=$(getopt -o hvacf:kmns -- "$@")
if [ $? != 0 ] ; then echo "terminating..." >&2 ; exit ; fi 
if [ $# -lt 1 ] ; then echo "use -h/--help to check available options" >&2 ; exit ; fi 

set -- $ARGS
while true;
do
    case "$1" in
        -a|--all)
            echo "display all information set"
            cpu_layout
	    kernel_opt_layout
            mem_layout
            nic_layout
            dpdk_layout
            spdk_layout
            pmdk_layout
            shift 
            ;;
        -c|--cpu)
            cpu_layout
            shift  
            ;;
        -f|--file)
            #log_to_file $2
            shift 2 
            ;;
        -k|--kernel)
            #log_to_file $2
	    kernel_opt_layout
            shift  
            ;;
        -m|--mem)
            mem_layout
            shift  
            ;;
        -n|--nic)
            nic_layout
            shift  
            ;;
        -s|--spdk)
            spdk_layout
            shift 1 
            ;;
        -v|--version)
            echo "initial version"
            shift
            ;;
        -h|--help)
            echo "script option as follows:"
            echo -e "\t-a: show all set of system information"
            echo -e "\t-c: show cpu layout"
            echo -e "\t-k: show kernel parameters"
            echo -e "\t-m: show memory layout"
            echo -e "\t-n: show nic layout"
            echo -e "\t-s: show spdk layout"
            echo -e "\t-f: [filename] dump info to file"
            shift
            ;;
        --)
            shift
            break
            ;;
        *) 
            echo "unknow options:{$1}"
            exit 1
            ;;
    esac
done
