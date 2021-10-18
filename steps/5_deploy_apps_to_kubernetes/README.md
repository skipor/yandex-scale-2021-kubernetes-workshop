# Разворачивание приложений в kubernetes

Для начала настроим `kubectl` на кластер:
```bash
yc k8s cluster --name workshop get-credentials --external --force
kubectl cluster-info
```

Укажем `kubectl` использовать по-умолчанию namespace workshop.
```bash 
kubectl get namespace workshop
kubectl config set-context --current --namespace=workshop
```

Подготовим директорию с Kubernetes YAML файлами, с которыми будем работать дальше:
```bash
./steps/5_deploy_apps_to_kubernetes/gen_deploy_dir.sh
```

## Приложение `clock`

Развёртывать будем с помощью простого деплоймента:
```bash
cat deploy/clock/deployment.yaml
```

Применим его:
```bash
kubectl apply -f deploy/clock/deployment.yaml
# Дождёмся пока деплоймент раскатится:
kubectl rollout status deployment/clock --timeout 1m
# Посмотрим на поды
kubectl get pod -l app=clock -o wide
```

На текущем этапе проведём деплой без открытия доступа к приложению через интернет, т.е. выделения публичного IP адреса.
Применим `ClusterIP` сервис, который выделит IP адрес доступный только внутри кластера Kubernetes:
```bash
cat deploy/clock/service.yaml
kubectl apply -f deploy/clock/service.yaml
```

Не все знают, но к `ClusterIP` сервису можно получить доступ извне кластера через
[apiserver proxy](https://kubernetes.io/docs/tasks/access-application-cluster/access-cluster/#manually-constructing-apiserver-proxy-urls)
. Проще говоря, можно сделать запрос к Control Plane (Master) Kubernetes, по пути вида
`api/v1/namespaces/<NAMESPACE>/services/<SERVICE>/proxy/<PATH>`, а Control Plane узел перенаправит его в сервис.

Обратиться к Control Plane проще всего через `kubectl proxy`, который возьмет на себя аутентификацию. Откроем
дополнительное, **отдельное окно терминала** и запустим:
```bash
# Необходимо выполнить в **дополнительном** окне терминала.
# Окно терминала заблокируется. После этого нужно вернуться в основное окно.
kubectl proxy --port=8001
```

Вернувшись в отдельное окно терминала сделаем запрос в Control Plane:
```bash
curl http://localhost:8001/api/v1/namespaces/workshop/services/clock/proxy/
```
В ответе придёт текущее время в UTC - сервис отвечает.

## Приложение `translate`

Приложение `translate` отличается от `clock` наличием секрета - ключа сервисного аккаунта для доступа к API сервиса
Yandex Cloud Translate. Поэтому сначала создадим этот секрет, из файла который мы создали во время локального
тестирования приложения:
```bash
kubectl create secret generic translate-sa-key --from-file ./apps/translate/key.json
```

В кластере включено шифрование через KMS Provider, поэтому секрет не попадёт на диск Control Plane узла незашифрованным.
Однако, такой способ не является безопасным, в случае, если есть необходимость ограничить получение секретов со стороны
выполняющих деплой. Кроме того, отсутствует версионирование, аудит лог изменений и возникнут проблемы с использованием
из разных namespace и кластеров Kubernetes. Что с этим делать мы обсудим позже.

Деплоймент `translate` отличается от `clock` монтированием секрета:
```bash
cat deploy/translate/deployment.yaml
```

Сервис `ClusterIP` аналогичен тому что было в `clock`. Применим их:
```bash
kubectl apply -f deploy/translate
# Дождёмся пока деплоймент раскатится:
kubectl rollout status deployment/translate --timeout 1m
# Посмотрим на поды
kubectl get pod -l app=translate -o wide
```

Проверим сервис:
```bash
curl -X POST 'http://localhost:8001/api/v1/namespaces/workshop/services/translate/proxy/?to=en' \
  --data 'Этот сервис запущен в Managed Kubernetes!'; echo
```


### [cледующий этап >>>](../6_publish_apps_using_application_load_balancer/README.md)
