import unittest
from utility import utilities as util
from utility import env as env
import hwconftest as hwconf
import globalvar

"""
Testcases related to software configuration
and runtime env variables
"""

@unittest.skipIf(globalvar.CONF_PID_IS_VALID == False,
                 "PID in dpdk.conf is invalid")
class swconftest(unittest.TestCase):

    cpu = env.g_env_conf.cpu_conf
    sw = env.g_env_conf.sw_conf
    nics = env.g_env_conf.nics_conf

    """
    Verify software thread number is less than the
    number of total CPU cores
    """
    def test_thread_num_less_than_cpu_core(self):
        nr_cpu = self.cpu.cpu_core_total_num
        nr_thread = self.sw.thread_num
        self.assertLess(nr_thread, nr_cpu)

    """
    Verify masked CPU(s) are at the same NUMA node
    """
    def test_masked_cpu_numa_node(self):
        util.testcase_append_suggestions(self._testMethodName, "Masked CPU(s) should on the same NUMA node")
        cpu_ids = self.sw.get_cpu_list_by_mask(self.cpu.cpu_core_total_num)
        prev_cpu_node = 0
        cnt = 0
        for cpu_id in cpu_ids:
            cpu = self.cpu.get_single_CPU_conf_by_id(cpu_id)
            if cnt == 0:
                prev_cpu_node = cpu.numa_node
            cnt = cnt + 1
            self.assertEqual(prev_cpu_node, cpu.numa_node)

    """
    Verify DPDK worker is not running on CPU 0
    """
    def test_worker_not_CPU0(self):
        util.testcase_append_suggestions(self._testMethodName, "Do not assign CPU0 to DPDK worker thread")
        cpu_ids = self.sw.get_cpu_list_by_mask(self.cpu.cpu_core_total_num)
        worker_cpu0 = False
        if 0 in cpu_ids:
            worker_cpu0 = True
        self.assertEqual(worker_cpu0, False)

    """
    Verify if DPDK NICs and pinning CPU cores are at the same
    NUMA node
    """
    def test_CPU_NIC_same_NUMA(self):
        util.testcase_append_suggestions(self._testMethodName, "Set CPU mask or PCI whitelist to use CPU cores and NICs which are on the same NUMA node")
        cpu_ids = self.sw.get_cpu_list_by_mask(self.cpu.cpu_core_total_num)
        numa_node_list = []
        for cpu_id in cpu_ids:
            cpu = self.cpu.get_single_CPU_conf_by_id(cpu_id)
            numa_node = cpu.numa_node
            numa_node_list.append(numa_node)
        for nic in self.nics.nics_conf:
            numa_node = nic.NUMA_node
            numa_node_list.append(numa_node)

        prev_numa_node = numa_node_list[0]
        for node in numa_node_list:
            self.assertEqual(prev_numa_node, node)
            prev_numa_node = node
