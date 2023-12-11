package templates

import (
	"strings"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	runtime "k8s.io/apimachinery/pkg/runtime"
	timoniv1 "timoni.sh/core/v1alpha1"
)

// Config defines the schema and defaults for the Instance values.
#Config: {
	// Timoni runtime version info
	moduleVersion!: string
	kubeVersion!:   string

	// Metadata (common to all resources)
	metadata: metav1.#ObjectMeta
	metadata: name:      *"flux" | string & =~"^(([A-Za-z0-9][-A-Za-z0-9_.]*)?[A-Za-z0-9])?$" & strings.MaxRunes(63)
	metadata: namespace: *"flux-system" | string & strings.MaxRunes(63)

	metadata: labels: {
		"app.kubernetes.io/name":       metadata.name
		"app.kubernetes.io/version":    version
		"app.kubernetes.io/part-of":    "flux"
		"app.kubernetes.io/managed-by": "timoni"
	}

	metadata: annotations: {
		"app.kubernetes.io/role": "cluster-admin"
	}

	version: string

	controllers: {
		source: {
			image:      timoniv1.#Image
			resources?: corev1.#ResourceRequirements
		}
		kustomize: {
			enabled:    *true | bool
			image:      timoniv1.#Image
			resources?: corev1.#ResourceRequirements
		}
		helm: {
			enabled:    *true | bool
			image:      timoniv1.#Image
			resources?: corev1.#ResourceRequirements
		}
		notification: {
			enabled:    *true | bool
			image:      timoniv1.#Image
			resources?: corev1.#ResourceRequirements
		}
	}

	expose: {
		webhookReceiver:    *false | bool
		notificationServer: *false | bool
		sourceServer:       *false | bool
	}

	proxy: {
		https?: string
		http?:  string
		no:     *".cluster.local.,.cluster.local,.svc" | string
	}

	env?: [string]: string

	securityProfile: "restricted" | "privileged"

	logLevel: *"info" | string

	hostNetwork: *true | bool

	workload: {
		provider: *"" | "aws" | "azure" | "gcp"
		identity: *"" | string
	}

	reconcile: {
		concurrent: *5 | int
		requeue:    *30 | int
	}

	persistence: {
		enabled:      *false | bool
		storageClass: *"standard" | string
		size:         *"8Gi" | string & =~"^([0-9]*)?(Gi)?$"
	}

	tmpfs: {
		enabled:    *false | bool
		sizeLimit?: string & =~"^([0-9]*)?(Mi|Gi)?$"
	}

	resources: corev1.#ResourceRequirements
	resources: requests: cpu:    *"100m" | string & =~"^([0-9]*)?(m)?$"
	resources: requests: memory: *"64Mi" | string & =~"^([0-9]*)?(Mi|Gi)?$"
	resources: limits: memory:   *"1Gi" | string & =~"^([0-9]*)?(Mi|Gi)?$"

	imagePullSecrets?: [...corev1.LocalObjectReference]

	securityContext: *{
		allowPrivilegeEscalation: false
		readOnlyRootFilesystem:   true
		runAsNonRoot:             true
		capabilities: drop: ["ALL"]
		seccompProfile: type: "RuntimeDefault"
	} | corev1.#PodSecurityContext

	affinity: corev1.#Affinity
	affinity: nodeAffinity: requiredDuringSchedulingIgnoredDuringExecution: nodeSelectorTerms: [{
		matchExpressions: [{
			key:      "kubernetes.io/os"
			operator: "In"
			values: ["linux"]
		}]
	}]
	affinity: podAntiAffinity: requiredDuringSchedulingIgnoredDuringExecution: [{
		topologyKey: "kubernetes.io/hostname"
		labelSelector: matchExpressions: [{
			key:      "app.kubernetes.io/name"
			operator: "In"
			values: [metadata.name]
		}]
	}]

	tolerations: *[{
		operator: "Exists"
		key:      "node.kubernetes.io/not-ready"
	}, {
		operator:          "Exists"
		key:               "node.kubernetes.io/unreachable"
		effect:            "NoExecute"
		tolerationSeconds: 300
	}] | [...corev1.#Toleration]

}

// Instance takes the config values and outputs the Kubernetes objects.
#Instance: {
	config:                                 #Config
	containerEnv: #ContainerEnv & {_config: config}

	containers: [
		#SourceController & {_config: config, _env: containerEnv},
		if config.controllers.kustomize.enabled {
			#KustomizeController & {_config: config, _env: containerEnv}
		},
		if config.controllers.helm.enabled {
			#HelmController & {_config: config, _env: containerEnv}
		},
		if config.controllers.notification.enabled {
			#NotificationController & {_config: config, _env: containerEnv}
		},
	]

	objects: [ID=_]: runtime.#Object

	objects: {
		for name, crd in customresourcedefinition {
			"\(name)": crd
			"\(name)": metadata: labels:      config.metadata.labels
			"\(name)": metadata: annotations: config.metadata.annotations
		}
	}

	objects: {
		namespace: #Namespace & {_config: config}
		resourcequota: #ResourceQuota & {_config: config}
		serviceaccount: #ServiceAccount & {_config: config}
		clusterrol: #ClusterRole & {_config: config}
		clusterrolebinding: #ClusterRoleBinding & {_config: config}
		deployment: #Deployment & {
			_config:     config
			_containers: containers
		}
	}

	if config.controllers.notification.enabled && config.expose.webhookReceiver {
		objects: webhookreceiver: #WebhookService & {_config: config}
	}

	if config.controllers.notification.enabled && config.expose.notificationServer {
		objects: notificationserver: #NotificationService & {_config: config}
	}

	if config.expose.sourceServer {
		objects: sourceserver: #SourceService & {_config: config}
	}

	if config.persistence.enabled {
		objects: pvc: #PVC & {_config: config}
	}
}
