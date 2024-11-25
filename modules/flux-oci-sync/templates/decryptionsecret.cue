package templates

import (
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	timoniv1 "timoni.sh/core/v1alpha1"
)

#DecryptionSecret: corev1.#Secret & {
	#config:    #Config
	apiVersion: "v1"
	kind:       "Secret"
	metadata: metav1.#ObjectMeta & {
		name:         #config.decryption.providerSpec.secretName
		namespace:    #config.metadata.namespace
		labels:       #config.metadata.labels
		annotations?: timoniv1.#Annotations
		if #config.metadata.annotations != _|_ {
			annotations: #config.metadata.annotations
		}
	}
	data: {
		if #config.decryption.providerSpec.secretValue != _|_ {
			"identity.asc": #config.decryption.providerSpec.secretValue
			// TODO : Manage other secret encryption providers :
			//  # Exemplary age private key
			//  identity.agekey: <BASE64>
			//  # Exemplary Hashicorp Vault token
			//  sops.vault-token: <BASE64>
			//  sops.aws-kms: |
			//        aws_access_key_id: some-access-key-id
			//        aws_secret_access_key: some-aws-secret-access-key
			//        aws_session_token: some-aws-session-token # this field is optional
			//  # Exemplary Azure Service Principal with Secret
			//  sops.azure-kv: |
			//    tenantId: some-tenant-id
			//    clientId: some-client-id
			//    clientSecret: some-client-secret
		}
	}
}
