# Сборка и загрузка образов контейнеров в реестр

Посмотрим структуру директории `./apps`
```bash
tree ./apps
```

Увидим там два каталога с `go` приложениями и `Dockerfile` к ним, которые мы будем дальше разворачивать. Оба они
обслуживают (serve) HTTP на порту `:80`
- `clock` - на `GET` в ответе возвращает текущее время
- `translate`
    - на `POST` переводит тело запроса в сервисе Yandex Translate
        - в query параметре `to` (`en` по-умолчанию) можно указать целевой язык
    - требует передачи ключа сервисного аккаунта, через флаг `--service-account-key`, для авторизации в API Yandex
      Translate

Чтобы узлы Kubernetes могли их развернуть, нам нужно создать Yandex Container Registry и загрузить туда собранные docker
образы.

## Создание container registry

Создадим Terraform файл описывающий Yandex Container Registry в нашем каталоге выполнив команду:
```bash
cp steps/4_build_and_push_container_images/container_registry.tf .
cat container_registry.tf
```

Применим изменения как обычно:
```bash
terraform apply
```

Аутентифицируем `docker`, для работы с Yandex Container Registry:

```bash 
yc config get token | docker login --username oauth  --password-stdin cr.yandex
```

## Сборка, проверка и загрузка контейнерных образов в Container Registry

### Приложение `clock`

Соберём образ контейнера и загрузим его в реестр.
```bash
cat ./apps/clock/build_and_push_conatiner_image.sh
CLOCK_IMG=$(./apps/clock/build_and_push_conatiner_image.sh v1)
```

Проверим, что контейнер с приложением работает. Для этого в основном окне терминала запустим его, пробросив порт `80`:
```bash
docker run -p 127.0.0.1:80:80 "${CLOCK_IMG:?}"
```
Приложение напишет в лог о том что запустилось и заблокирует окно до прерывания.

А во вспомогательном окне терминала сделаем HTTP запрос:
```bash
curl 127.0.0.1:80
```
Увидим что в ответе пришло текущее время в UTC.

Вернёмся в основное окно терминала, и прервём приложение нажав `Ctrl+C`.

### Приложение `translate`

Соберём образ контейнера и загрузим его в регистр:
```bash
TRANSLATE_IMG=$(./apps/translate/build_and_push_conatiner_image.sh v1)
```

Попробуем запустить образ:
```bash 
docker run -p 127.0.0.1:80:80 "${TRANSLATE_IMG:?}"
```

Увидим, что для работы требуется ключ сервисного аккаунта.

Создадим Terraform файл описывающий отдельный сервисный аккаунт:
```bash
cp steps/4_build_and_push_container_images/translate_app.tf .
cat translate_app.tf
```

Применим целевую конфигурацию как обычно:
```bash
terraform apply
```

Создадим ключ для этого сервисного аккаунта:
```bash 
FOLDER_ID="$(yc config get folder-id)"
FOLDER_NAME="$(yc resource folder get --id ${FOLDER_ID} --format json | jq .name -r)"
yc iam key create --service-account-name ${FOLDER_NAME}-translate --output apps/translate/key.json
```

Теперь запустим приложение передав ключ:
```bash 
docker run -p 127.0.0.1:80:80 -v "$(pwd)/apps/translate/key.json:/key.json:" \
  "${TRANSLATE_IMG:?}" --service-account-key /key.json
```
Приложение напишет в лог о том что запустилось и заблокирует окно до прерывания.

Для проверки, во вспомогательном окне терминала выполним:
```bash
for LANG in en es fr; do
  curl -X POST "127.0.0.1:80/?to=${LANG:?}" \
    --data 'Мы рады, что вы участвуете в нашем практикуме!'
  echo
done
```

Если всё работает, вы увидите предложение переведённое на Английский, Испанский и Французкий.

**Заметка**: если вы получаете
ошибку `Translate failed: error dialing endpoint 'api.cloud.yandex.net:443': context deadline exceeded`
вероятно у вас macOS и хост резолвится только в ipv6, который на маке в докере не работает. Если у вас есть `go`, то
можете запустить программу так: 
```bash
(cd ./apps/translate && go run . --service-account-key key.json)
```
И после этого повторить команду проверки.

Вернёмся в основное окно терминала, и прервём приложение нажав `Ctrl+C`.

### [cледующий этап >>>](../5_deploy_apps_to_kubernetes/README.md)
