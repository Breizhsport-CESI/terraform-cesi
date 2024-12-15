# Pre-requis

```bash
export SCW_ACCESS_KEY="SCWH*****"

export SCW_SECRET_KEY="f1d**********"
```

Installation de Tofu ou de Terraform

Ensuite initialiser le projet

```bash
tofu init -chdir=cluster && tofu -chdir=config
```

## Lancement

```bash
./allconfig.sh
```

## Cleanup

```bash
tofu destroy -chdir=cluster -auto-approve
```