#!/bin/bash

# Étape 1 : Appliquer le premier plan
tofu -chdir=cluster apply -auto-approve

# Étape 2 : Exporter les outputs
tofu -chdir=cluster output -json kubeconfig > config/cluster_output.json
# Étape 3 : Appliquer le deuxième plan
tofu -chdir=config -auto-approve