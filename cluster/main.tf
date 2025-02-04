provider "scaleway" {
  project_id = "ace0a8c0-8b24-4ad3-a030-6bcae7502e93"
  region     = "nl-ams" # 
}

resource "scaleway_vpc_private_network" "pnpoc" {
  name   = "poc-private-network"
  region = "nl-ams"
}

resource "scaleway_k8s_cluster" "cluster" {
  name    = "cesi-poc-demo"
  type    = "kapsule"
  version = "1.31.2"
  cni     = "cilium"
  private_network_id = scaleway_vpc_private_network.pnpoc.id
  delete_additional_resources = false
}

resource "scaleway_k8s_pool" "pool" {
  cluster_id  = scaleway_k8s_cluster.cluster.id
  name        = "cesi-pool-poc-demo"
  node_type   = "DEV1-M"
  size        = 1
  min_size    = 0
  max_size    = 1
  autoscaling = true
  autohealing = true
  zone = "nl-ams-1"
}

resource "null_resource" "kubeconfig" {
  depends_on = [scaleway_k8s_pool.pool] # at least one pool here
  triggers = {
    host                   = scaleway_k8s_cluster.cluster.kubeconfig[0].host
    token                  = scaleway_k8s_cluster.cluster.kubeconfig[0].token
    cluster_ca_certificate = scaleway_k8s_cluster.cluster.kubeconfig[0].cluster_ca_certificate
  }
}

provider "helm" {
  kubernetes {
    host = null_resource.kubeconfig.triggers.host
    token = null_resource.kubeconfig.triggers.token
    cluster_ca_certificate = base64decode(
    null_resource.kubeconfig.triggers.cluster_ca_certificate
    )
  }
}

provider "kubernetes" {
  host                   = null_resource.kubeconfig.triggers.host
  token                  = null_resource.kubeconfig.triggers.token
  cluster_ca_certificate = base64decode(null_resource.kubeconfig.triggers.cluster_ca_certificate)
}


resource "scaleway_lb_ip" "nginx_ip" {
  zone       = "nl-ams-1"
  project_id = scaleway_k8s_cluster.cluster.project_id
}

resource "kubernetes_namespace" "ingress_nginx" {
  depends_on = [null_resource.kubeconfig]
  metadata {
    name = "ingress-nginx"
  }
}


resource "helm_release" "nginx_ingress" {
  name      = "nginx-ingress"
  namespace = kubernetes_namespace.ingress_nginx.metadata[0].name

  repository = "https://kubernetes.github.io/ingress-nginx"
  chart = "ingress-nginx"

  set {
    name = "controller.service.loadBalancerIP"
    value = scaleway_lb_ip.nginx_ip.ip_address
  }

  // enable proxy protocol to get client ip addr instead of loadbalancer one
  set {
    name = "controller.config.use-proxy-protocol"
    value = "true"
  }
  set {
    name = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/scw-loadbalancer-proxy-protocol-v2"
    value = "true"
  }

  // indicates in which zone to create the loadbalancer
  set {
    name = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/scw-loadbalancer-zone"
    value = scaleway_lb_ip.nginx_ip.zone
  }

  // enable to avoid node forwarding
  set {
    name = "controller.service.externalTrafficPolicy"
    value = "Local"
  }

  // enable this annotation to use cert-manager
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/scw-loadbalancer-use-hostname"
    value = "true"
  }
}

resource "kubernetes_namespace" "cert_manager" {
  depends_on = [null_resource.kubeconfig]
  metadata {
    name = "cert-manager"
  }
}


# Helm Release pour Cert-Manager
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "1.16.2" 

  set {
    name  = "installCRDs"
    value = "true"
  }
  depends_on = [null_resource.kubeconfig]
}

output "kubeconfig" {
  value = {
    host                   = scaleway_k8s_cluster.cluster.kubeconfig[0].host
    token                  = scaleway_k8s_cluster.cluster.kubeconfig[0].token
    cluster_ca_certificate = scaleway_k8s_cluster.cluster.kubeconfig[0].cluster_ca_certificate
  }
  sensitive = true
}

resource "local_file" "kubeconfig_yaml" {
  depends_on = [null_resource.kubeconfig]
  content = <<EOT
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${scaleway_k8s_cluster.cluster.kubeconfig[0].cluster_ca_certificate}
    server: ${scaleway_k8s_cluster.cluster.kubeconfig[0].host}
  name: scaleway-cluster
contexts:
- context:
    cluster: scaleway-cluster
    user: scaleway-user
  name: scaleway-context
current-context: scaleway-context
kind: Config
preferences: {}
users:
- name: scaleway-user
  user:
    token: ${scaleway_k8s_cluster.cluster.kubeconfig[0].token}
EOT
  filename = "kubeconfig.yaml"
}