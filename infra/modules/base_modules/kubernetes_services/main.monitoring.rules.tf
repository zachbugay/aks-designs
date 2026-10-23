# https://learn.microsoft.com/en-us/azure/azure-monitor/containers/prometheus-metrics-scrape-default#recording-rules
# https://learn.microsoft.com/en-us/azure/azure-monitor/containers/kubernetes-monitoring-enable?tabs=terraform
# https://github.com/Azure/prometheus-collector/blob/main/AddonTerraformTemplate/main.tf
resource "azurerm_monitor_alert_prometheus_rule_group" "node_recording_rules_rule_group" {
  name                = "NodeRecordingRulesRuleGroup-${local.aks_cluster_name}"
  location            = module.locations.name
  resource_group_name = data.azurerm_resource_group.rg.name
  cluster_name        = local.aks_cluster_name
  description         = "Node Recording Rules Rule Group for Linux Nodes"
  rule_group_enabled  = true
  interval            = "PT1M"
  scopes              = [var.monitor_workspace_id, azurerm_kubernetes_cluster.this.id]
  tags                = local.tags

  rule {
    enabled    = true
    record     = "instance:node_num_cpu:sum"
    expression = <<-PROMQL
      count without (cpu, mode) (node_cpu_seconds_total{job="node",mode="idle"})
    PROMQL
  }

  rule {
    enabled    = true
    record     = "instance:node_cpu_utilisation:rate5m"
    expression = <<-PROMQL
      1 - avg without (cpu) (sum without (mode) (rate(node_cpu_seconds_total{job="node",mode=~"idle|iowait|steal"}[5m])))
    PROMQL
  }

  rule {
    enabled    = true
    record     = "instance:node_load1_per_cpu:ratio"
    expression = <<-PROMQL
      node_load1{job="node"} / instance:node_num_cpu:sum{job="node"}
    PROMQL
  }

  rule {
    enabled    = true
    record     = "instance:node_memory_utilisation:ratio"
    expression = <<-PROMQL
      1 - (
        (
          node_memory_MemAvailable_bytes{job="node"}
          or (
            node_memory_Buffers_bytes{job="node"}
            + node_memory_Cached_bytes{job="node"}
            + node_memory_MemFree_bytes{job="node"}
            + node_memory_Slab_bytes{job="node"}
          )
        ) / node_memory_MemTotal_bytes{job="node"}
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "instance:node_vmstat_pgmajfault:rate5m"
    expression = <<-PROMQL
      rate(node_vmstat_pgmajfault{job="node"}[5m])
    PROMQL
  }

  rule {
    enabled    = true
    record     = "instance_device:node_disk_io_time_seconds:rate5m"
    expression = <<-PROMQL
      rate(node_disk_io_time_seconds_total{job="node",device!=""}[5m])
    PROMQL
  }

  rule {
    enabled    = true
    record     = "instance_device:node_disk_io_time_weighted_seconds:rate5m"
    expression = <<-PROMQL
      rate(node_disk_io_time_weighted_seconds_total{job="node",device!=""}[5m])
    PROMQL
  }

  rule {
    enabled    = true
    record     = "instance:node_network_receive_bytes_excluding_lo:rate5m"
    expression = <<-PROMQL
      sum without (device) (rate(node_network_receive_bytes_total{job="node",device!="lo"}[5m]))
    PROMQL
  }

  rule {
    enabled    = true
    record     = "instance:node_network_transmit_bytes_excluding_lo:rate5m"
    expression = <<-PROMQL
      sum without (device) (rate(node_network_transmit_bytes_total{job="node",device!="lo"}[5m]))
    PROMQL
  }

  rule {
    enabled    = true
    record     = "instance:node_network_receive_drop_excluding_lo:rate5m"
    expression = <<-PROMQL
      sum without (device) (rate(node_network_receive_drop_total{job="node",device!="lo"}[5m]))
    PROMQL
  }

  rule {
    enabled    = true
    record     = "instance:node_network_transmit_drop_excluding_lo:rate5m"
    expression = <<-PROMQL
      sum without (device) (rate(node_network_transmit_drop_total{job="node",device!="lo"}[5m]))
    PROMQL
  }
}

resource "azurerm_monitor_alert_prometheus_rule_group" "kubernetes_recording_rules_rule_group" {
  name                = "KubernetesRecordingRulesRuleGroup-${local.aks_cluster_name}"
  location            = module.locations.name
  resource_group_name = data.azurerm_resource_group.rg.name
  cluster_name        = local.aks_cluster_name
  description         = "Kubernetes Recording Rules Rule Group for Linux Nodes"
  rule_group_enabled  = true
  interval            = "PT1M"
  scopes              = [var.monitor_workspace_id, azurerm_kubernetes_cluster.this.id]
  tags                = local.tags

  rule {
    enabled    = true
    record     = "node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate"
    expression = <<-PROMQL
      sum by (cluster, namespace, pod, container) (
        irate(container_cpu_usage_seconds_total{job="cadvisor",image!=""}[5m])
      )
      * on (cluster, namespace, pod) group_left(node)
      topk by (cluster, namespace, pod) (
        1, max by (cluster, namespace, pod, node) (kube_pod_info{node!=""})
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "node_namespace_pod_container:container_memory_working_set_bytes"
    expression = <<-PROMQL
      container_memory_working_set_bytes{job="cadvisor",image!=""}
      * on (cluster, namespace, pod) group_left(node)
      topk by (cluster, namespace, pod) (
        1, max by (cluster, namespace, pod, node) (kube_pod_info{node!=""})
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "node_namespace_pod_container:container_memory_rss"
    expression = <<-PROMQL
      container_memory_rss{job="cadvisor",image!=""}
      * on (cluster, namespace, pod) group_left(node)
      topk by (cluster, namespace, pod) (
        1, max by (cluster, namespace, pod, node) (kube_pod_info{node!=""})
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "node_namespace_pod_container:container_memory_cache"
    expression = <<-PROMQL
      container_memory_cache{job="cadvisor",image!=""}
      * on (cluster, namespace, pod) group_left(node)
      topk by (cluster, namespace, pod) (
        1, max by (cluster, namespace, pod, node) (kube_pod_info{node!=""})
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "node_namespace_pod_container:container_memory_swap"
    expression = <<-PROMQL
      container_memory_swap{job="cadvisor",image!=""}
      * on (cluster, namespace, pod) group_left(node)
      topk by (cluster, namespace, pod) (
        1, max by (cluster, namespace, pod, node) (kube_pod_info{node!=""})
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "cluster:namespace:pod_memory:active:kube_pod_container_resource_requests"
    expression = <<-PROMQL
      kube_pod_container_resource_requests{resource="memory",job="kube-state-metrics"}
      * on (namespace, pod, cluster) group_left()
      max by (namespace, pod, cluster) (kube_pod_status_phase{phase=~"Pending|Running"} == 1)
    PROMQL
  }

  rule {
    enabled    = true
    record     = "namespace_memory:kube_pod_container_resource_requests:sum"
    expression = <<-PROMQL
      sum by (namespace, cluster) (
        sum by (namespace, pod, cluster) (
          max by (namespace, pod, container, cluster) (
            kube_pod_container_resource_requests{resource="memory",job="kube-state-metrics"}
          )
          * on (namespace, pod, cluster) group_left()
          max by (namespace, pod, cluster) (kube_pod_status_phase{phase=~"Pending|Running"} == 1)
        )
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests"
    expression = <<-PROMQL
      kube_pod_container_resource_requests{resource="cpu",job="kube-state-metrics"}
      * on (namespace, pod, cluster) group_left()
      max by (namespace, pod, cluster) (kube_pod_status_phase{phase=~"Pending|Running"} == 1)
    PROMQL
  }

  rule {
    enabled    = true
    record     = "namespace_cpu:kube_pod_container_resource_requests:sum"
    expression = <<-PROMQL
      sum by (namespace, cluster) (
        sum by (namespace, pod, cluster) (
          max by (namespace, pod, container, cluster) (
            kube_pod_container_resource_requests{resource="cpu",job="kube-state-metrics"}
          )
          * on (namespace, pod, cluster) group_left()
          max by (namespace, pod, cluster) (kube_pod_status_phase{phase=~"Pending|Running"} == 1)
        )
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "cluster:namespace:pod_memory:active:kube_pod_container_resource_limits"
    expression = <<-PROMQL
      kube_pod_container_resource_limits{resource="memory",job="kube-state-metrics"}
      * on (namespace, pod, cluster) group_left()
      max by (namespace, pod, cluster) (kube_pod_status_phase{phase=~"Pending|Running"} == 1)
    PROMQL
  }

  rule {
    enabled    = true
    record     = "namespace_memory:kube_pod_container_resource_limits:sum"
    expression = <<-PROMQL
      sum by (namespace, cluster) (
        sum by (namespace, pod, cluster) (
          max by (namespace, pod, container, cluster) (
            kube_pod_container_resource_limits{resource="memory",job="kube-state-metrics"}
          )
          * on (namespace, pod, cluster) group_left()
          max by (namespace, pod, cluster) (kube_pod_status_phase{phase=~"Pending|Running"} == 1)
        )
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "cluster:namespace:pod_cpu:active:kube_pod_container_resource_limits"
    expression = <<-PROMQL
      kube_pod_container_resource_limits{resource="cpu",job="kube-state-metrics"}
      * on (namespace, pod, cluster) group_left()
      max by (namespace, pod, cluster) (kube_pod_status_phase{phase=~"Pending|Running"} == 1)
    PROMQL
  }

  rule {
    enabled    = true
    record     = "namespace_cpu:kube_pod_container_resource_limits:sum"
    expression = <<-PROMQL
      sum by (namespace, cluster) (
        sum by (namespace, pod, cluster) (
          max by (namespace, pod, container, cluster) (
            kube_pod_container_resource_limits{resource="cpu",job="kube-state-metrics"}
          )
          * on (namespace, pod, cluster) group_left()
          max by (namespace, pod, cluster) (kube_pod_status_phase{phase=~"Pending|Running"} == 1)
        )
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "namespace_workload_pod:kube_pod_owner:relabel"
    expression = <<-PROMQL
      max by (cluster, namespace, workload, pod) (
        label_replace(
          label_replace(
            kube_pod_owner{job="kube-state-metrics",owner_kind="ReplicaSet"},
            "replicaset", "$1", "owner_name", "(.*)"
          )
          * on (cluster, replicaset, namespace) group_left(owner_name)
          topk by (cluster, replicaset, namespace) (
            1, max by (cluster, replicaset, namespace, owner_name) (
              kube_replicaset_owner{job="kube-state-metrics"}
            )
          ),
          "workload", "$1", "owner_name", "(.*)"
        )
      )
    PROMQL
    labels = {
      workload_type = "deployment"
    }
  }

  rule {
    enabled    = true
    record     = "namespace_workload_pod:kube_pod_owner:relabel"
    expression = <<-PROMQL
      max by (cluster, namespace, workload, pod) (
        label_replace(
          kube_pod_owner{job="kube-state-metrics",owner_kind="DaemonSet"},
          "workload", "$1", "owner_name", "(.*)"
        )
      )
    PROMQL
    labels = {
      workload_type = "daemonset"
    }
  }

  rule {
    enabled    = true
    record     = "namespace_workload_pod:kube_pod_owner:relabel"
    expression = <<-PROMQL
      max by (cluster, namespace, workload, pod) (
        label_replace(
          kube_pod_owner{job="kube-state-metrics",owner_kind="StatefulSet"},
          "workload", "$1", "owner_name", "(.*)"
        )
      )
    PROMQL
    labels = {
      workload_type = "statefulset"
    }
  }

  rule {
    enabled    = true
    record     = "namespace_workload_pod:kube_pod_owner:relabel"
    expression = <<-PROMQL
      max by (cluster, namespace, workload, pod) (
        label_replace(
          kube_pod_owner{job="kube-state-metrics",owner_kind="Job"},
          "workload", "$1", "owner_name", "(.*)"
        )
      )
    PROMQL
    labels = {
      workload_type = "job"
    }
  }

  rule {
    enabled    = true
    record     = ":node_memory_MemAvailable_bytes:sum"
    expression = <<-PROMQL
      sum by (cluster) (
        node_memory_MemAvailable_bytes{job="node"}
        or (
          node_memory_Buffers_bytes{job="node"}
          + node_memory_Cached_bytes{job="node"}
          + node_memory_MemFree_bytes{job="node"}
          + node_memory_Slab_bytes{job="node"}
        )
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "cluster:node_cpu:ratio_rate5m"
    expression = <<-PROMQL
      sum by (cluster) (
        rate(node_cpu_seconds_total{job="node",mode!="idle",mode!="iowait",mode!="steal"}[5m])
      )
      / count by (cluster) (sum by (cluster, instance, cpu) (node_cpu_seconds_total{job="node"}))
    PROMQL
  }
}

resource "azurerm_monitor_alert_prometheus_rule_group" "ux_recording_rules_rule_group" {
  name                = "UXRecordingRulesRuleGroup-${local.aks_cluster_name}"
  location            = module.locations.name
  resource_group_name = data.azurerm_resource_group.rg.name
  cluster_name        = local.aks_cluster_name
  description         = "UX Recording Rules for Linux"
  rule_group_enabled  = true
  interval            = "PT1M"
  scopes              = [var.monitor_workspace_id, azurerm_kubernetes_cluster.this.id]
  tags                = local.tags

  rule {
    enabled    = true
    record     = "ux:pod_cpu_usage:sum_irate"
    expression = <<-PROMQL
      sum by (namespace, pod, cluster, microsoft_resourceid) (
        irate(container_cpu_usage_seconds_total{container!="",pod!="",job="cadvisor"}[5m])
      )
      * on (pod, namespace, cluster, microsoft_resourceid) group_left(node, created_by_name, created_by_kind)
      max by (node, created_by_name, created_by_kind, pod, namespace, cluster, microsoft_resourceid) (
        kube_pod_info{pod!="",job="kube-state-metrics"}
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "ux:controller_cpu_usage:sum_irate"
    expression = <<-PROMQL
      sum by (namespace, node, cluster, created_by_name, created_by_kind, microsoft_resourceid) (
        ux:pod_cpu_usage:sum_irate
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "ux:pod_workingset_memory:sum"
    expression = <<-PROMQL
      sum by (namespace, pod, cluster, microsoft_resourceid) (
        container_memory_working_set_bytes{container!="",pod!="",job="cadvisor"}
      )
      * on (pod, namespace, cluster, microsoft_resourceid) group_left(node, created_by_name, created_by_kind)
      max by (node, created_by_name, created_by_kind, pod, namespace, cluster, microsoft_resourceid) (
        kube_pod_info{pod!="",job="kube-state-metrics"}
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "ux:controller_workingset_memory:sum"
    expression = <<-PROMQL
      sum by (namespace, node, cluster, created_by_name, created_by_kind, microsoft_resourceid) (
        ux:pod_workingset_memory:sum
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "ux:pod_rss_memory:sum"
    expression = <<-PROMQL
      sum by (namespace, pod, cluster, microsoft_resourceid) (
        container_memory_rss{container!="",pod!="",job="cadvisor"}
      )
      * on (pod, namespace, cluster, microsoft_resourceid) group_left(node, created_by_name, created_by_kind)
      max by (node, created_by_name, created_by_kind, pod, namespace, cluster, microsoft_resourceid) (
        kube_pod_info{pod!="",job="kube-state-metrics"}
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "ux:controller_rss_memory:sum"
    expression = <<-PROMQL
      sum by (namespace, node, cluster, created_by_name, created_by_kind, microsoft_resourceid) (
        ux:pod_rss_memory:sum
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "ux:pod_container_count:sum"
    expression = <<-PROMQL
      sum by (node, created_by_name, created_by_kind, namespace, cluster, pod, microsoft_resourceid) (
        (
          sum by (container, pod, namespace, cluster, microsoft_resourceid) (
            kube_pod_container_info{container!="",pod!="",container_id!="",job="kube-state-metrics"}
          )
          or sum by (container, pod, namespace, cluster, microsoft_resourceid) (
            kube_pod_init_container_info{container!="",pod!="",container_id!="",job="kube-state-metrics"}
          )
        )
        * on (pod, namespace, cluster, microsoft_resourceid) group_left(node, created_by_name, created_by_kind)
        max by (node, created_by_name, created_by_kind, pod, namespace, cluster, microsoft_resourceid) (
          kube_pod_info{pod!="",job="kube-state-metrics"}
        )
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "ux:controller_container_count:sum"
    expression = <<-PROMQL
      sum by (node, created_by_name, created_by_kind, namespace, cluster, microsoft_resourceid) (
        ux:pod_container_count:sum
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "ux:pod_container_restarts:max"
    expression = <<-PROMQL
      max by (node, created_by_name, created_by_kind, namespace, cluster, pod, microsoft_resourceid) (
        (
          max by (container, pod, namespace, cluster, microsoft_resourceid) (
            kube_pod_container_status_restarts_total{container!="",pod!="",job="kube-state-metrics"}
          )
          or sum by (container, pod, namespace, cluster, microsoft_resourceid) (
            kube_pod_init_container_status_restarts_total{container!="",pod!="",job="kube-state-metrics"}
          )
        )
        * on (pod, namespace, cluster, microsoft_resourceid) group_left(node, created_by_name, created_by_kind)
        max by (node, created_by_name, created_by_kind, pod, namespace, cluster, microsoft_resourceid) (
          kube_pod_info{pod!="",job="kube-state-metrics"}
        )
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "ux:controller_container_restarts:max"
    expression = <<-PROMQL
      max by (node, created_by_name, created_by_kind, namespace, cluster, microsoft_resourceid) (
        ux:pod_container_restarts:max
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "ux:pod_resource_limit:sum"
    expression = <<-PROMQL
      (
        sum by (cluster, pod, namespace, resource, microsoft_resourceid) (
          max by (cluster, microsoft_resourceid, pod, container, namespace, resource) (
            kube_pod_container_resource_limits{container!="",pod!="",job="kube-state-metrics"}
          )
        )
        unless (
          count by (pod, namespace, cluster, resource, microsoft_resourceid) (
            kube_pod_container_resource_limits{container!="",pod!="",job="kube-state-metrics"}
          )
          != on (pod, namespace, cluster, microsoft_resourceid) group_left()
          sum by (pod, namespace, cluster, microsoft_resourceid) (
            kube_pod_container_info{container!="",pod!="",job="kube-state-metrics"}
          )
        )
      )
      * on (namespace, pod, cluster, microsoft_resourceid) group_left(node, created_by_kind, created_by_name)
      kube_pod_info{pod!="",job="kube-state-metrics"}
    PROMQL
  }

  rule {
    enabled    = true
    record     = "ux:controller_resource_limit:sum"
    expression = <<-PROMQL
      sum by (cluster, namespace, created_by_name, created_by_kind, node, resource, microsoft_resourceid) (
        ux:pod_resource_limit:sum
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "ux:controller_pod_phase_count:sum"
    expression = <<-PROMQL
      sum by (cluster, phase, node, created_by_kind, created_by_name, namespace, microsoft_resourceid) (
        (
          kube_pod_status_phase{job="kube-state-metrics",pod!=""}
          or label_replace(
            count by (namespace, pod, cluster, microsoft_resourceid) (
              kube_pod_deletion_timestamp{job="kube-state-metrics",pod!=""}
            )
            * count by (namespace, pod, cluster, microsoft_resourceid) (
              kube_pod_status_reason{reason="NodeLost",job="kube-state-metrics"} == 0
            ),
            "phase", "terminating", "", ""
          )
        )
        * on (pod, namespace, cluster, microsoft_resourceid) group_left(node, created_by_name, created_by_kind)
        max by (node, created_by_name, created_by_kind, pod, namespace, cluster, microsoft_resourceid) (
          kube_pod_info{job="kube-state-metrics",pod!=""}
        )
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "ux:cluster_pod_phase_count:sum"
    expression = <<-PROMQL
      sum by (cluster, phase, node, namespace, microsoft_resourceid) (
        ux:controller_pod_phase_count:sum
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "ux:node_cpu_usage:sum_irate"
    expression = <<-PROMQL
      sum by (instance, cluster, microsoft_resourceid) (
        1 - irate(node_cpu_seconds_total{job="node",mode="idle"}[5m])
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "ux:node_memory_usage:sum"
    expression = <<-PROMQL
      sum by (instance, cluster, microsoft_resourceid) (
        node_memory_MemTotal_bytes{job="node"}
        - node_memory_MemFree_bytes{job="node"}
        - node_memory_Cached_bytes{job="node"}
        - node_memory_Buffers_bytes{job="node"}
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "ux:node_network_receive_drop_total:sum_irate"
    expression = <<-PROMQL
      sum by (instance, cluster, microsoft_resourceid) (
        irate(node_network_receive_drop_total{job="node",device!="lo"}[5m])
      )
    PROMQL
  }

  rule {
    enabled    = true
    record     = "ux:node_network_transmit_drop_total:sum_irate"
    expression = <<-PROMQL
      sum by (instance, cluster, microsoft_resourceid) (
        irate(node_network_transmit_drop_total{job="node",device!="lo"}[5m])
      )
    PROMQL
  }
}
