#!/bin/bash

source /opt/harvester/bin/activate
export X509_USER_PROXY=/data/atlpan/proxy/atlpilo1_latest_x509up.rfc.proxy

export PYTHONPATH="/opt/harvester_src/harvester/examples/hpc:$PYTHONPATH"

# python /opt/harvester_src/harvester/examples/hpc/get_globus_token_orig.py  --facilities nersc --validate-iri


# nersc
# 1) login
# python /opt/harvester_src/harvester/examples/hpc/generate_iri_token_to_panda.py --facilities nersc --force-login --panda_secret_key NERSC_IRI_ACCESS --iri_config /opt/harvester/etc/panda/nersc_iri_config.yaml

# 2) generate access token and uploads it to panda, with validation
python /opt/harvester_src/harvester/examples/hpc/generate_iri_token_to_panda.py --facilities nersc --refresh-only --panda_secret_key NERSC_IRI_ACCESS --iri_config /opt/harvester/etc/panda/nersc_iri_config.yaml --validate-iri

# a separate validation
# python /opt/harvester_src/harvester/examples/hpc/generate_iri_token_to_panda.py --facilities nersc  --refresh-only --validate-iri

# 3) download access token from panda (if step 2 is running at the same node, no need step 3)
# python /opt/harvester_src/harvester/examples/hpc/generate_iri_token_to_panda.py --download-from-panda --panda_secret_key NERSC_IRI_ACCESS --iri_config /opt/harvester/etc/panda/nersc_iri_config.yaml


# alcf crux
# 1) login
# python /opt/harvester_src/harvester/examples/hpc/generate_iri_token_to_panda.py --facilities alcf --force-login --panda_secret_key ALCF_IRI_ACCESS --iri_config /opt/harvester/etc/panda/alcf_iri_config.yaml

# 2) generate access token and uploads it to panda, with validation
python /opt/harvester_src/harvester/examples/hpc/generate_iri_token_to_panda.py --facilities alcf --refresh-only --panda_secret_key ALCF_IRI_ACCESS --iri_config /opt/harvester/etc/panda/alcf_iri_config.yaml --base_url https://api.alcf.anl.gov --resource_id 8b9b42f7-572a-4909-8472-a0453436304c --validate-iri

# a separate validation
# python /opt/harvester_src/harvester/examples/hpc/generate_iri_token_to_panda.py --facilities alcf  --refresh-only --validate-iri

# 3) download access token from panda (if step 2 is running at the same node, no need step 3)
# python /opt/harvester_src/harvester/examples/hpc/generate_iri_token_to_panda.py --download-from-panda --panda_secret_key ALCF_IRI_ACCESS --iri_config /opt/harvester/etc/panda/alcf_iri_config.yaml


### Generate globus transfer token
# 1) generate globus transfer refresh token, it's the refresh token and it should only be stored locally. This refresh token has a long lifetime. It runs manually.
# python /opt/harvester_src/harvester/examples/hpc/generate_transfer_token_to_panda.py --generate_refresh_token --output /opt/harvester/etc/panda/usatlas_hpc_globus_transfer_refresh.yaml
# 2) read the refresh token to generate an access token and update the access token to PanDA. This refresh token's lifetime is short. This one can be a cron job running on a private machine. It can also run on the harvester machine (if it runs on the harvester machine, it will write the access token to the file that harvester can access directly. Then we don't need step 3.
# python /opt/harvester_src/harvester/examples/hpc/generate_transfer_token_to_panda.py --generate_access_token --input /opt/harvester/etc/panda/usatlas_hpc_globus_transfer_refresh.yaml --output /opt/harvester/etc/panda/usatlas_hpc_globus_transfer_access.yaml --panda_secret_key USATLAS_HPC_TRANSFER_TOKEN
# 3) It download the access token from PanDA and write it to a local file. This one needs to run on the harvester machine. It downloads the access token from PanDA, which is generate from step 2.
# python /opt/harvester_src/harvester/examples/hpc/generate_transfer_token_to_panda.py --get_access_token --output /opt/harvester/etc/panda/usatlas_hpc_globus_transfer_access.yaml --panda_secret_key USATLAS_HPC_TRANSFER_TOKEN



### Generate NERSC https refresh token
# 1) generate refresh token
# python /opt/harvester_src/harvester/examples/hpc/generate_https_token_to_panda.py --generate_refresh_token  --site NERSC  --output /opt/harvester/etc/panda/NERSC_https_refresh_token.yaml
# 2) read the refresh token to generate the access token and upload it to panda
python /opt/harvester_src/harvester/examples/hpc/generate_https_token_to_panda.py --generate_access_token  --site NERSC --panda_secret_key NERSC_HTTPS_TOKEN --input /opt/harvester/etc/panda/NERSC_https_refresh_token.yaml --output /opt/harvester/etc/panda/NERSC_https_access_token.yaml
# 3) download the access token from panda
# python /opt/harvester_src/harvester/examples/hpc/generate_https_token_to_panda.py --get_access_token  --site NERSC --panda_secret_key NERSC_HTTPS_TOKEN --output /opt/harvester/etc/panda/NERSC_https_access_token.yaml



### Generate ALCF CRUX https refresh token
# 1) generate refresh token
# python /opt/harvester_src/harvester/examples/hpc/generate_https_token_to_panda.py --generate_refresh_token  --site CRUX  --output /opt/harvester/etc/panda/ALCF_CRUX_https_refresh_token.yaml
# 2) read the refresh token to generate the access token and upload it to panda
python /opt/harvester_src/harvester/examples/hpc/generate_https_token_to_panda.py --generate_access_token  --site CRUX --panda_secret_key ALCF_CRUX_HTTPS_TOKEN --input /opt/harvester/etc/panda/ALCF_CRUX_https_refresh_token.yaml --output /opt/harvester/etc/panda/ALCF_CRUX_https_access_token.yaml
# 3) download the access token from panda
# python /opt/harvester_src/harvester/examples/hpc/generate_https_token_to_panda.py --get_access_token  --site CRUX --panda_secret_key ALCF_CRUX_HTTPS_TOKEN --output /opt/harvester/etc/panda/ALCF_CRUX_https_access_token.yaml


