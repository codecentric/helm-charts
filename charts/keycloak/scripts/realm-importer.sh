#!/bin/sh
export PATH=/opt/jboss/keycloak/bin:$PATH
export KEYCLOAK_URL="http://localhost:8080/auth"

function backgroundRealmImporter() {
    while ! curl ${KEYCLOAK_URL} &>/dev/null; do
        echo "[realm-importer] Waiting on keycloak to start"
        sleep 1
    done

    while true; do
        # Process realm configmaps at default every 10 seconds
        sleep ${REALM_UPDATER_INTERVAL:-10}

        if [[ -d "${REALMS_FOLDER}" ]]; then
            for file in ${REALMS_FOLDER}/*; do
                if [[ "${file}" == *.json ]]; then
                    name="$(cat ${file} | jq -r .realm)"
                    echo "[realm-importer] Processing ConfigMap '${file}' (realm: ${name})"

                    echo "[realm-importer] kcadm get credentials"
                    kcadm.sh config credentials --server ${KEYCLOAK_URL} --realm master --user ${KEYCLOAK_USER} --password ${KEYCLOAK_PASSWORD}
                    rc=$?

                    if [ "${rc}" != "0" ];then
                        echo "[realm-importer] kcadm.sh failed to obtain keycloak credentials" >&2
                        continue
                    fi

                    if [ "$(kcadm.sh get realms --fields realm | jq -rS .[].realm | grep -c ${name})" == "1" ]; then
                        echo "[realm-importer] Updating realm '${name}'"
                        kcadm.sh update realms/${name} -f ${file}
                    else
                        echo "[realm-importer] Creating realm '${name}'"
                        kcadm.sh create realms -f ${file}
                    fi
                    rc=$?

                    if [ "${rc}" == "0" ];then
                        echo "[realm-importer] Import complete, moving '${file}' to '${file}.imported'"
                        mv ${file} ${file}.imported
                    else
                        echo "[realm-importer] Import failed, moving '${file}' to '${file}.failed'" >&2
                        mv ${file} ${file}.failed
                    fi
                fi
            done
        fi
    done
}

# Confirm we have required configuration before starting
missing_vars=""
for required_var in REALMS_FOLDER KEYCLOAK_URL KEYCLOAK_USER KEYCLOAK_PASSWORD; do
    if [ -z ${!required_var} ]; then
        echo "Error: required environment var not set: '${required_var}'" >&2
        missing_vars="true"
    fi
done
if [ "${missing_vars}" != "" ]; then exit 1; fi

echo "[realm-importer] Folder '${REALMS_FOLDER}' will be monitored to import realms to ${KEYCLOAK_URL}"
backgroundRealmImporter &
pid=$!
echo "[realm-importer] Background monitoring of ${REALMS_FOLDER} started (pid: ${pid})"
