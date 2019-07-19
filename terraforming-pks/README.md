## pre-requisites

- Install jq, yq, uaac

## setup
- Create a file .env
```
export ADMIN_USER=
export ADMIN_PASSWORD=
export PKS_PRODUCT=
```
- Create a directory ".tmp"
- Run `source .env`
- Run `source setup_opsmanager.sh`
- Run `./configure_bosh.sh`


- Run `source generate-certs.sh`
- Run `./install_pks_1.4.0-build31.sh`
