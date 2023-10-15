FROM quay.io/keycloak/keycloak:22.0.4

ENV JGROUPS_KUBERNETES_VERSION 1.0.16.Final

# Downlaod JGroups KubePing extension
RUN curl -s -L -o /opt/keycloak/providers/jgroups-kubernetes-$JGROUPS_KUBERNETES_VERSION.jar https://search.maven.org/remotecontent?filepath=org/jgroups/kubernetes/jgroups-kubernetes/$JGROUPS_KUBERNETES_VERSION/jgroups-kubernetes-$JGROUPS_KUBERNETES_VERSION.jar

# Add custom kubeping configuration file
COPY cache-ispn-kubeping.xml /opt/keycloak/conf
