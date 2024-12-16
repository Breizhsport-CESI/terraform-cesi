# Pre-requis

```bash
export SCW_ACCESS_KEY="SCWH*****"

export SCW_SECRET_KEY="f1d**********"
```

Installation de Tofu ou de Terraform

Ensuite initialiser le projet

```bash
cd cluster && tofu init && cd .. && cd config && tofu init && cd ..
```

## Lancement

```bash
./allconfig.sh
```

## Cleanup

```bash
tofu destroy -chdir=cluster -auto-approve
```