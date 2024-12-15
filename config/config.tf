# Charger le JSON brut depuis un fichier
locals {
  kubeconfig_data = jsondecode(file("${path.module}/cluster_output.json"))
}

# Fournir les données JSON directement au provider
provider "kubernetes" {
  host                   = local.kubeconfig_data.host
  token                  = local.kubeconfig_data.token
  cluster_ca_certificate = base64decode(local.kubeconfig_data.cluster_ca_certificate)
}

resource "kubernetes_manifest" "cluster_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt"
    }
    spec = {
      acme = {
        server                = "https://acme-v02.api.letsencrypt.org/directory"
        email                 = "killian.stein@viacesi.fr"
        privateKeySecretRef = {
          name = "letsencrypt"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = "nginx"
              }
            }
          }
        ]
      }
    }
  }
}
