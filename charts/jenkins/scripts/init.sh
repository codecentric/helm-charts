#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

readonly PLUGINS_CHECKSUM_FILE=/var/jenkins_home/plugins.sha256

install_plugins() {
    rm -rf /usr/share/jenkins/ref/plugins/*
    /usr/local/bin/install-plugins.sh < /var/jenkins_ref/plugins.txt
}

main() {
    local jenkins_image_repo="${1?Specify Jenkins image repo}"
    local jenkins_image_tag="${2?Specify Jenkins image version}"
    local force_plugin_updates="${3?Specify whether plugins should be updated}"

    echo '************************************************************************'
    echo '*                                                                      *'
    echo '*                 Jenkins Helm Chart by codecentric AG                 *'
    echo '*                                                                      *'
    echo '************************************************************************'
    echo
    echo "Jenkins Docker image: $jenkins_image_repo:$jenkins_image_tag"
    echo

    if [[ -d /var/jenkins_ref/ ]]; then
        echo 'Copying reference data...'
        cp -rfL /var/jenkins_ref/* /var/jenkins_home

        if [[ -f /var/jenkins_ref/plugins.txt ]]; then
            if [[ -f "$PLUGINS_CHECKSUM_FILE" ]]; then
                if ! sha256sum --check < "$PLUGINS_CHECKSUM_FILE" > /dev/null; then
                    echo "SHA256 of 'plugins.txt' changed. Updating plugins..."
                    install_plugins
                elif [[ "$force_plugin_updates" == true ]]; then
                    echo 'Updating plugins...'
                    install_plugins
                else
                    echo 'No plugins updates detected.'
                fi
            else
              echo 'Installing plugins...'
              install_plugins
            fi

            echo "Writing checksum for 'plugins.txt'..."
            sha256sum /var/jenkins_ref/plugins.txt > "$PLUGINS_CHECKSUM_FILE"
        else
            echo "'plugins.txt' does not exist. Skipping plugin installations."
        fi
    fi

    echo 'Disabling upgrade wizard...'
    echo "$jenkins_image_tag" > /usr/share/jenkins/ref/jenkins.install.UpgradeWizard.state
    echo "$jenkins_image_tag" > /usr/share/jenkins/ref/jenkins.install.InstallUtil.lastExecVersion
}

main "$@"
