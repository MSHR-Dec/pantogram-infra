.PHONY: apply/api
apply/api:
	kubectl kustomize manifest/api/overlays/k3s/ | kubectl apply -f -
.PHONY: apply/datastore
apply/datastore:
	kubectl kustomize manifest/datastore/overlays/k3s/ | kubectl apply -f -
.PHONY: apply/timeseries
apply/timeseries:
	kubectl kustomize manifest/timeseries/overlays/k3s/ | kubectl apply -f -
.PHONY: apply/mysql
apply/mysql:
	kubectl kustomize manifest/mysql/overlays/k3s/ | kubectl apply -f -
.PHONY: apply/influxdb
apply/influxdb:
	kubectl kustomize manifest/influxdb/overlays/k3s/ | kubectl apply -f -
.PHONY: apply/chronograf
apply/chronograf:
	kubectl kustomize manifest/chronograf/overlays/k3s/ | kubectl apply -f -
.PHONY: apply/jaeger
apply/jaeger:
	kubectl kustomize manifest/jaeger/overlays/k3s/ | kubectl apply -f -
.PHONY: apply/es
apply/es:
	kubectl kustomize manifest/es/overlays/k3s/ | kubectl apply -f -
.PHONY: apply/fluentbit
apply/fluentbit:
	kubectl kustomize manifest/fluentbit/overlays/k3s/ | kubectl apply -f -

.PHONY: apply
apply: apply/mysql apply/influxdb apply/datastore apply/timeseries apply/api apply/jaeger

.PHONY: delete/api
delete/api:
	kubectl kustomize manifest/api/overlays/k3s/ | kubectl delete -f -
.PHONY: delete/datastore
delete/datastore:
	kubectl kustomize manifest/datastore/overlays/k3s/ | kubectl delete -f -
.PHONY: delete/timeseries
delete/timeseries:
	kubectl kustomize manifest/timeseries/overlays/k3s/ | kubectl delete -f -
.PHONY: delete/mysql
delete/mysql:
	kubectl kustomize manifest/mysql/overlays/k3s/ | kubectl delete -f -
.PHONY: delete/influxdb
delete/influxdb:
	kubectl kustomize manifest/influxdb/overlays/k3s/ | kubectl delete -f -
.PHONY: delete/chronograf
delete/chronograf:
	kubectl kustomize manifest/chronograf/overlays/k3s/ | kubectl delete -f -
.PHONY: delete/jaeger
delete/jaeger:
	kubectl kustomize manifest/jaeger/overlays/k3s/ | kubectl delete -f -
.PHONY: delete/es
delete/es:
	kubectl kustomize manifest/es/overlays/k3s/ | kubectl delete -f -
.PHONY: delete/fluentbit
delete/fluentbit:
	kubectl kustomize manifest/fluentbit/overlays/k3s/ | kubectl delete -f -

.PHONY: delete
delete: delete/mysql delete/influxdb delete/datastore delete/timeseries delete/api delete/jaeger
