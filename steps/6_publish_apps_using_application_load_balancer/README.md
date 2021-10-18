# Публикуем приложения используя Application Load Balancer

В кластере
запущен [ALB Ingress Controller](https://cloud.yandex.ru/docs/managed-kubernetes/solutions/alb-ingress-controller)
который увидит создание (обновление) Ingress, и создаст (настроит) Application Load Balancer в облаке.
Его под можно увидеть так:
```bash 
kubectl get pod -n yc-alb-ingress
```

Application Load Balancer юниты запущены за пределами кластера, и не могут подавать трафик на `ClusterIP`, поэтому
придётся поменять тип сервисов на `NodePort`.

Добавим `deploy/ingress.yaml` и заменим тип сервисов на `NodePort`:
```bash
./steps/6_publish_apps_using_application_load_balancer/transform_deploy_dir.sh
cat deploy/ingress.yaml
```

В выведенном `ingress.yaml` видно маршрутизацию на хосте `scale-2021-k8s-workshop.yandex.cloud` по префиксам:
* `/clock` в сервис `clock`
* `/translate` в сервис `translate`

Кроме этого есть аннотации `ingress.alb.yc.io` указывающие на то, что этот Ingress управляется ALB Ingress Controller,
и передающие ему необходимые параметры.


Применим обновлённую конфигурацию:
```bash
kubectl apply -f deploy/ingress.yaml -f deploy/clock -f deploy/translate
```

Для практикума Application Load Balancer был предварительно создан:
```bash
yc application-load-balancer load-balancer list --format yaml
```

Поэтому после применения Ingress, настройки балансировки быстро обновятся. В реальности первичное создание ALB занимает
около 5 минут. Посмотрим на карту балансировки ALB в Web UI, по ссылке которую выведет команда:
```bash
./steps/6_publish_apps_using_application_load_balancer/alb_web_ui_link.sh
```

Должен быть виден HTTP router с маршрутами из Ingress: `/clock` и `/translate`. Если этого нет сразу, обновите
страницу.

Вернёмся в терминал. Попробуем обратиться к нашим сервисам через ALB. Т.к. DNS записи мы не заводили, при обращении
придётся указать адрес ALB, а хост передать заголовком:
```bash
ALB_IP=$(yc vpc address get --name alb-ingress --format json  | jq '.external_ipv4_address.address' -r)
echo "Адрес балансера: '${ALB_IP}'"
curl -H "Host: scale-2021-k8s-workshop.yandex.cloud" "http://${ALB_IP:?}/clock" 
echo
curl -H "Host: scale-2021-k8s-workshop.yandex.cloud" "http://${ALB_IP:?}/translate?to=en" --data 'Этот запрос сделан через Application Load Balancer!' 
echo
```

В реальности, DNS запись должна быть ваша, нужно её делегировать Yandex Cloud DNS, и там указать IP ALB. С моделируем
это добавив запись в `/etc/hosts` скриптом:
```bash
cat steps/6_publish_apps_using_application_load_balancer/patch_etc_hosts.sh
```

Запустим его под `sudo`, чтобы получить права на изменения `/etc/hosts`:
```bash
sudo steps/6_publish_apps_using_application_load_balancer/patch_etc_hosts.sh
# Проверим результат:
grep -e scale-2021-k8s-workshop.yandex.cloud /etc/hosts
ping scale-2021-k8s-workshop.yandex.cloud -c 1 && echo 'Хост "scale-2021-k8s-workshop.yandex.cloud" успешно резолвится!'
```

Теперь можно обращаться к нашему сервису без указания адреса подключения:
```bash
curl "http://scale-2021-k8s-workshop.yandex.cloud/clock"
echo
curl -X POST 'http://scale-2021-k8s-workshop.yandex.cloud/translate?to=en' --data 'Этот запрос сделан через Application Load Balancer!'
```

Теперь вернёмся в браузер с открытым Web UI.

Слева выберем раздел _Логи_, найдём и раскроем строчку от `curl`.

Слева выберем раздел _Мониторинг_, слева вверху временной интервал _1h_, увидим, что наши запросы отобразились на
метриках.

### [cледующий этап >>>](../7_blue_green_deploy_using_application_load_balancer/README.md)


