---
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultConnection
metadata:
  name: ${name}
  namespace: ${namespace}
spec:
  address: ${vault_addr}
  skipTLSVerify: true
