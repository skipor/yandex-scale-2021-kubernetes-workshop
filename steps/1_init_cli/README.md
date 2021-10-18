# Авторизация в облачной консоли и настройка `yc` CLI

## Настройка yc

Для начала авторизуемся в аккаунте выданном на время практикума
* Откроем **в новой вкладке** (`Ctrl+Клик` или `Cmd + Клик`) [консоль облака](https://console.cloud.yandex.ru) и, вверху
  справа, временно выйдем из текущих аккаунтов, чтобы они нам не помешали.
* Откроем **в новой вкладке** <a href="https://passport.yandex.ru/auth?mode=add-user&retpath=https%3A%2F%2Fconsole.cloud.yandex.ru%2F" target="_blank">
  ссылку</a> где вам будет предложено авторизоваться в Яндекс ID
* Введём имя и пароль пользователя, который был выдан для практикума
* Произойдёт перенаправление в консоль Yandex Cloud
* Среди доступных облаков должно быть только `cloud-practicum-k8s`
    * Если это не так, кликните на аватаку справа вверху, и выберете аккаунт выданный для практикума. Если виден только
      ваш текущий аккаунт, то нажмите на значёк _Выйти_ справа от имени

Получим и сохраним в env переменную токен для работы с Yandex Cloud.

Кликнем на блок кода, ниже, чтобы его скопировать. Вставим в терминал, но не будем нажимать `enter`:
```bash
# После символа '=' нужно будет вставить полученный токен
OAUTH_TOKEN=
```
* Откроем в **в новой
  вкладке** <a href="https://oauth.yandex.ru/authorize?response_type=token&client_id=1a6990aa636648e9b2ef855fa7bec2fb" target="_blank">
  ссылку</a> для получения токена для работы с Yandex Cloud
* **Убедитесь, что в правом верхнем углу имя вашего аккаунта на время практикума**
    * Если нет, выберите аккаунт на время практикума
* _Скопируем токен_
* Вернёмся в терминал, вставим, чтобы получилось `OAUTH_TOKEN=AQAE....Tuw` и нажмём `enter`

Несколько приёмов использования командной строки которые будут встречаться далее:
* Получение значения переменной с добавлением `:?` к имени, вроде `${VAR_NAME:?}`, требует чтобы переменная была
  выставлена ранее
* Вызов `yc` CLI с флагом `--format json` выводит объект в формате JSON
* `| jq .id -r` возвращает JSON значение поля `id`

Работать с настройками `yc` CLI будем
используя [команды не интерактивной настройки](https://cloud.yandex.ru/docs/cli/cli-ref/managed-yc/config/)
- `yc config`. Создадим профиль `yc` CLI в котором будем работать и выставим туда токен
```bash
yc config profile create workshop
yc config set token ${OAUTH_TOKEN:?}
echo "Token set to '$(yc config get token)'"
```

Проверим, что токен скопирован корректно, и появился доступ к Облаку в котором будем работать:
```bash
yc resource cloud list
```

Выставим ID Облака в конфиг `yc` CLI
```bash
CLOUD_NAME=cloud-practicum-k8s
CLOUD_ID=$(yc resource cloud get --name ${CLOUD_NAME:?} --format json | jq .id -r)
yc config set cloud-id ${CLOUD_ID:?}
echo "В конфиг yc CLI добавлен ID Облака: '$(yc config get cloud-id)'"
```

У вашего аккаунта будет к одному каталогу вида `y-scale-participant-<номер>`:
```bash
echo "Ваш каталог участника:"
FOLDER=$(yc resource folder list --format json | jq '.[]' -c | grep y-scale-participant)
jq <<< "$FOLDER" '"Имя: " + .name + " " + "ID: " + .id' -r
```

Сохраним его ID в конфиг yc CLI:
```bash
yc config set folder-id $(jq -r <<< "$FOLDER" .id)
echo "В конфиг yc CLI добавлен ID каталога: '$(yc config get folder-id)'"
```

## Подготовка виртуальной машины

**Если вы [подготовили окружение](../../README.md#настройка-окружения) на своём компьютере, _пропустите этот шаг, и
переходите к следующему этапу_**

### [cледующий этап >>>](../2_terraform_import_existing_resources/README.md)

Образ доступен во время проведения практикума. Если вы выполняете задание после окончания практикума, пропустите этот
шаг. Вы можете самостоятельно подготовить аналогичный образ или подготовить
окружение [по инструкции](../../README.md#настройка-окружения)

1. Убедитесь, что у вас есть SSH-ключ или сгенерируйте новый (
   подробная [инструкция](https://cloud.yandex.ru/docs/compute/operations/vm-connect/ssh#creating-ssh-keys)).
```bash
ssh-keygen -t rsa -b 4096 # генерация нового ssh-ключа
cat ~/.ssh/id_rsa.pub
```

2. Создайте виртуальную машину с помощью yc
```bash
IMAGE_ID=$(yc compute image get yandex-scale-2021-kubernetes-workshop --folder-name public-image --format json | jq -r .id)
yc compute instance create --name workshop-vm \
 --create-boot-disk image-id="${IMAGE_ID:?}",size=60 \
 --public-ip \
 --ssh-key ~/.ssh/id_rsa.pub --zone ru-central1-a
```
3. Скопируйте публичный IP адрес
```bash
IP_ADDRESS=$(yc compute instance get workshop-vm --format json | jq -r '.network_interfaces[0].primary_v4_address.one_to_one_nat.address')
```
4. Скопируйте свой конфиг yc на ВМ:
```bash
ssh yc-user@$IP_ADDRESS sudo mkdir -p /home/yc-user/.config/yandex-cloud
scp ~/.config/yandex-cloud/config.yaml yc-user@$IP_ADDRESS:/home/yc-user/.config/yandex-cloud/config.yaml
```
5. Войдите на созданную ВМ по SSH
```bash
ssh yc-user@$IP_ADDRESS
```
6. Проверьте, что на ВМ работает yc
```bash
yc compute instance list
```
7. Перейдите в директорию со скачанным репозиторием и обновите его;
```bash
cd /opt/yandex-scale-2021-kubernetes-workshop && git pull
```

Дальнейшие команды выполняйте на созданной ВМ. Когда понадобится дополнительно окно терминала, откройте новую
вкладку/окно терминала, и там сделайте:
```bash
ssh yc-user@$IP_ADDRESS
cd /opt/yandex-scale-2021-kubernetes-workshop
```

### [cледующий этап >>>](../2_terraform_import_existing_resources/README.md)

