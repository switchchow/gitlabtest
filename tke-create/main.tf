# 名字标识
variable "name" {
  default = "zwstke"
}

#区域
variable "region" {
  default = "ap-bangkok"
}

# k8s 版本
variable "k8s_ver" {
  default = "1.21.1"
}

# pod ip 地址段
variable "pod_ip_seg" {
  default = "172.16"
}

# vpc ip 地址段
variable "vpc_ip_seg" {
  default = "10.0"
}

# 机型
variable "default_instance_type" {
  default = "S2.MEDIUM4"
}

# node 密码
variable "node_password" {
  default = "zws@@123"
}

terraform {
  required_providers {
    tencentcloud = {
      source = "tencentcloudstack/tencentcloud"
    }
  }
}

# 指定腾讯云和其大区
provider "tencentcloud" {
  region = var.region
}

# 定义安全组
resource "tencentcloud_security_group" "sg01" {
  name        = "${var.name}-sg"
  description = "${var.name} security group @ powered by terraform"
}

resource "tencentcloud_security_group_lite_rule" "sg01-rule" {
  security_group_id = tencentcloud_security_group.sg01.id

  ingress = [
    "ACCEPT#0.0.0.0/0#ALL#ICMP",
    "ACCEPT#0.0.0.0/0#22#TCP",
    "ACCEPT#0.0.0.0/0#30000-32768#TCP",
    "ACCEPT#0.0.0.0/0#30000-32768#UDP",
  ]

  egress = [
    "ACCEPT#0.0.0.0/0#ALL#ALL",
  ]
}

# 查询当前可用区, 将设置到节点池
data "tencentcloud_availability_zones" "all_zones" {
}

# 定义一个 VPC 网络
resource "tencentcloud_vpc" "vpc01" {
  name         = "${var.name}-01"
  cidr_block   = "${var.vpc_ip_seg}.0.0/16"
  is_multicast = false

  tags = {
    "user" = var.name
  }
}


# 定义子网，这里会给每个 zone 定义一个子网
resource "tencentcloud_subnet" "subset01" {
  count             = length(data.tencentcloud_availability_zones.all_zones.zones)
  name              = "${var.name}-subset-${count.index}"
  vpc_id            = tencentcloud_vpc.vpc01.id
  availability_zone = data.tencentcloud_availability_zones.all_zones.zones[count.index].name
  cidr_block        = "${var.vpc_ip_seg}.${count.index}.0/24"
  is_multicast      = false
  tags = {
    "user" = var.name
  }
}

# 创建 TKE 集群
resource "tencentcloud_kubernetes_cluster" "tke_managed" {
  vpc_id                                     = tencentcloud_vpc.vpc01.id
  cluster_version                            = var.k8s_ver
  cluster_cidr                               = "${var.pod_ip_seg}.0.0/16"
  cluster_max_pod_num                        = 64
  cluster_name                               = "${var.name}-tke-01"
  cluster_desc                               = "created by terraform"
  cluster_max_service_num                    = 2048
  cluster_internet                           = true
  managed_cluster_internet_security_policies = ["0.0.0.0/0"]
  cluster_deploy_type                        = "MANAGED_CLUSTER"
  cluster_os                                 = "tlinux2.4x86_64"
  container_runtime                          = "containerd"
  deletion_protection                        = false

  worker_config {
    instance_name              = "${var.name}-node"
    availability_zone          = data.tencentcloud_availability_zones.all_zones.zones[0].name
    instance_type              = var.default_instance_type
    system_disk_type           = "CLOUD_SSD"
    system_disk_size           = 50
    internet_charge_type       = "TRAFFIC_POSTPAID_BY_HOUR"
    internet_max_bandwidth_out = 1
    public_ip_assigned         = true
    subnet_id                  = tencentcloud_subnet.subset01[0].id
    security_group_ids         = [tencentcloud_security_group.sg01.id]

    enhanced_security_service = false
    enhanced_monitor_service  = false
    password                  = var.node_password
  }


  labels = {
    "user" = var.name
  }
}

#  创建一个节点池
resource "tencentcloud_kubernetes_node_pool" "node-pool" {
  name                 = "${var.name}-pool"
  cluster_id           = tencentcloud_kubernetes_cluster.tke_managed.id
  max_size             = 10
  min_size             = 0
  vpc_id               = tencentcloud_vpc.vpc01.id
  subnet_ids           = [for s in tencentcloud_subnet.subset01 : s.id]
  retry_policy         = "INCREMENTAL_INTERVALS"
  desired_capacity     = 0
  enable_auto_scale    = true
  delete_keep_instance = false
  node_os              = "tlinux2.4x86_64"

  auto_scaling_config {
    instance_type      = var.default_instance_type
    system_disk_type   = "CLOUD_PREMIUM"
    system_disk_size   = "200"
    security_group_ids = [tencentcloud_security_group.sg01.id]

    data_disk {
      disk_type = "CLOUD_PREMIUM"
      disk_size = 500
    }

    internet_charge_type       = "TRAFFIC_POSTPAID_BY_HOUR"
    internet_max_bandwidth_out = 10
    public_ip_assigned         = true
    password                   = var.node_password
    enhanced_security_service  = false
    enhanced_monitor_service   = false

  }

  labels = {
    "user" = var.name,
  }

}

output "KUBECONFIG" {
  description = "下面的配置是 kubeconfig，请拷贝并妥善存储"
  value       = tencentcloud_kubernetes_cluster.tke_managed.kube_config
}
